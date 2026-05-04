"""
recomendador.py
Motor de Machine Learning para Recomendação de Exercícios de Fisioterapia
+Físio +Saúde — UniCesumar

Algoritmo: Content-Based Filtering usando TF-IDF + Cosine Similarity.

O catálogo de exercícios é derivado dos nomes das pastas do dataset Kaggle:
https://www.kaggle.com/datasets/toobasaeed11/physiotherapy

Cada pasta do Kaggle (ex: Shoulder_Abduction_Left) é um exercício e contém
toda a informação necessária para a recomendação: região do corpo, tipo
de movimento e lateralidade.

O perfil do paciente é construído a partir dos sintomas registrados no app,
que incluem: região do corpo, descrição textual e intensidade da dor.
"""

import json
import os
import re
import unicodedata
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


def _normalizar_texto(texto: str) -> str:
    """Remove acentos e converte para minúsculas para comparação robusta."""
    texto = unicodedata.normalize("NFKD", texto)
    texto = "".join(c for c in texto if not unicodedata.combining(c))
    return texto.lower().strip()


# ─────────────────────────────────────────────────────────────────────────────
# Mapeamento: termos do app → termos do catálogo
# Garante que regiões selecionadas pelo paciente no app sejam mapeadas para
# as palavras-chave corretas do catálogo de exercícios.
# ─────────────────────────────────────────────────────────────────────────────
MAPA_REGIOES = {
    "cervical (pescoco)": "cervical pescoco coluna isometrico",
    "cervical": "cervical pescoco coluna isometrico",
    "pescoco": "cervical pescoco coluna isometrico",
    "ombro direito": "ombro direito manguito abducao flexao braco",
    "ombro esquerdo": "ombro esquerdo manguito abducao flexao braco",
    "ombro": "ombro manguito abducao flexao braco",
    "coluna lombar": "coluna lombar inclinacao lateral isometrico",
    "coluna toracica": "coluna toracica postura isometrico lateral",
    "coluna": "coluna lombar postura isometrico",
    "quadril": "quadril coluna lombar mobilidade fortalecimento",
    "joelho direito": "joelho direito reabilitacao fortalecimento",
    "joelho esquerdo": "joelho esquerdo reabilitacao fortalecimento",
    "joelho": "joelho reabilitacao fortalecimento",
    "tornozelo / pe": "tornozelo pe flexao plantar panturrilha bilateral",
    "tornozelo": "tornozelo pe flexao plantar panturrilha bilateral",
    "pe": "tornozelo pe flexao plantar panturrilha bilateral",
    "braco / cotovelo": "braco cotovelo ombro circunducao",
    "braco": "braco ombro cotovelo circunducao",
    "cotovelo": "braco cotovelo punho epicondilite",
    "punho / mao": "punho mao antebraco extensao bola preensao",
    "punho": "punho mao antebraco extensao bola preensao",
    "mao": "mao punho antebraco bola preensao dedos",
    "outra regiao": "mobilidade fortalecimento reabilitacao",
}


class RecomendadorFisioterapia:
    """
    Motor de recomendação de exercícios baseado em conteúdo (Content-Based Filtering).

    Fluxo:
        1. Carrega o catálogo de exercícios (catalogo_exercicios.json).
        2. Constrói uma representação textual de cada exercício (campo `texto_tfidf`).
        3. Vetoriza todos os exercícios com TF-IDF.
        4. Para cada novo paciente, monta um "perfil textual" a partir dos
           sintomas e calcula a similaridade de cosseno com o catálogo.
        5. Retorna os Top-N exercícios mais similares.
    """

    def __init__(self, caminho_catalogo: Optional[str] = None):
        if caminho_catalogo is None:
            caminho_catalogo = Path(__file__).parent / "catalogo_exercicios.json"

        with open(caminho_catalogo, "r", encoding="utf-8") as f:
            self._catalogo_raw = json.load(f)

        self._df: Optional[pd.DataFrame] = None
        self._vectorizer: Optional[TfidfVectorizer] = None
        self._matriz_tfidf = None
        self._treinado = False

        self._treinar()

    # ─────────────────────────────────────────────────────────────────────────
    # Treinamento (executado automaticamente no __init__)
    # ─────────────────────────────────────────────────────────────────────────

    def _treinar(self):
        """Vectoriza o catálogo com TF-IDF e armazena a matriz de features."""
        self._df = pd.DataFrame(self._catalogo_raw)

        # Campo unificado para TF-IDF: junta todos os atributos relevantes
        self._df["texto_tfidf"] = self._df.apply(self._montar_texto_tfidf, axis=1)

        self._vectorizer = TfidfVectorizer(
            analyzer="word",
            ngram_range=(1, 2),     # unigramas e bigramas
            min_df=1,
            max_features=5000,
            sublinear_tf=True,      # aplica log no TF para normalizar frequência
        )
        self._matriz_tfidf = self._vectorizer.fit_transform(self._df["texto_tfidf"])
        self._treinado = True

    @staticmethod
    def _montar_texto_tfidf(row: pd.Series) -> str:
        """
        Concatena os campos mais relevantes de um exercício em um único texto.
        Campos com maior peso para o ML são repetidos intencionalmente.
        """
        partes = [
            row.get("nome_pt", "") * 3,       # nome em PT tem peso 3x
            row.get("regiao_corporal", "") * 3, # região tem peso 3x (campo mais crítico)
            row.get("descricao", "") * 2,
            row.get("palavras_chave", "") * 2,
            row.get("lateralidade", ""),
            row.get("nivel_dificuldade", ""),
            " ".join(row.get("indicacoes", [])),
        ]
        return _normalizar_texto(" ".join(str(p) for p in partes))

    # ─────────────────────────────────────────────────────────────────────────
    # Recomendação
    # ─────────────────────────────────────────────────────────────────────────

    def recomendar(
        self,
        sintomas: list[dict],
        top_n: int = 5,
        filtrar_regiao: Optional[str] = None,
    ) -> list[dict]:
        """
        Retorna os top_n exercícios mais adequados para o paciente.

        Args:
            sintomas: Lista de dicts com {descricao, categoria, intensidade}.
                      Exemplo: [{"descricao": "dor ao levantar o braço",
                                 "categoria": "Ombro direito", "intensidade": 7}]
            top_n: Quantidade de exercícios a retornar.
            filtrar_regiao: Se fornecido, filtra exercícios da região específica
                            antes de calcular a similaridade.

        Returns:
            Lista de dicts com os exercícios recomendados + score de similaridade.
        """
        if not self._treinado:
            raise RuntimeError("Modelo não treinado. Execute _treinar() primeiro.")

        # Monta o perfil textual do paciente a partir dos sintomas
        perfil_texto = self._montar_perfil_paciente(sintomas)

        # Vetoriza o perfil usando o mesmo vocabulário do catálogo
        vetor_perfil = self._vectorizer.transform([perfil_texto])

        # Calcula similaridade de cosseno entre o perfil e todos os exercícios
        scores = cosine_similarity(vetor_perfil, self._matriz_tfidf)[0]

        df_trabalho = self._df.copy()
        df_trabalho["score"] = scores

        # Filtragem opcional por região (boost para a região correta)
        if filtrar_regiao:
            regiao_norm = _normalizar_texto(filtrar_regiao)
            # Aplica um multiplicador de score para exercícios da região certa
            for idx, row in df_trabalho.iterrows():
                regiao_exercicio = _normalizar_texto(row["regiao_corporal"])
                regiao_display = _normalizar_texto(row["regiao_display"])
                if (regiao_norm in regiao_exercicio or
                        regiao_norm in regiao_display or
                        any(word in regiao_exercicio for word in regiao_norm.split())):
                    df_trabalho.at[idx, "score"] *= 1.8  # boost de 80%

        # Ordena por score e retorna os top_n
        df_resultado = df_trabalho.sort_values("score", ascending=False).head(top_n)

        resultado = []
        for _, row in df_resultado.iterrows():
            resultado.append({
                "id": row["id"],
                "pasta_kaggle": row["pasta_kaggle"],
                "nome_pt": row["nome_pt"],
                "nome_en": row["nome_en"],
                "regiao_display": row["regiao_display"],
                "descricao": row["descricao"],
                "nivel_dificuldade": row["nivel_dificuldade"],
                "duracao_min": int(row["duracao_min"]),
                "url_video": row["url_video"],
                "lateralidade": row["lateralidade"],
                "score_similaridade": round(float(row["score"]), 4),
                "indicacoes": row.get("indicacoes", []),
            })

        return resultado

    def _montar_perfil_paciente(self, sintomas: list[dict]) -> str:
        """
        Transforma a lista de sintomas do paciente em um texto unificado
        para comparação com o catálogo via TF-IDF.

        A categoria/região tem maior peso pois é o critério mais objetivamente
        mapeável aos exercícios.
        """
        partes = []

        for sintoma in sintomas:
            descricao = str(sintoma.get("descricao", ""))
            categoria = str(sintoma.get("categoria", ""))
            intensidade = int(sintoma.get("intensidade", 5))

            # Mapeia a categoria do app para termos do catálogo
            cat_norm = _normalizar_texto(categoria)
            termos_regiao = MAPA_REGIOES.get(cat_norm, cat_norm)

            # Sintomas mais intensos têm mais peso no perfil
            peso_intensidade = max(1, intensidade // 3)

            partes.append(termos_regiao * 3)           # região tem peso 3x
            partes.append(descricao * peso_intensidade) # descrição proporcional à dor
            partes.append(descricao)                   # adiciona uma vez extra

        return _normalizar_texto(" ".join(partes))

    def listar_catalogo(self) -> list[dict]:
        """Retorna o catálogo completo de exercícios."""
        return self._catalogo_raw

    def buscar_por_id(self, exercicio_id: str) -> Optional[dict]:
        """Busca um exercício específico pelo ID."""
        for ex in self._catalogo_raw:
            if ex["id"] == exercicio_id:
                return ex
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Teste rápido (executar: python recomendador.py)
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=" * 60)
    print("  +Físio +Saúde — Teste do Recomendador ML")
    print("=" * 60)

    rec = RecomendadorFisioterapia()

    # Caso de teste 1: paciente com dor no ombro direito
    sintomas_teste_1 = [
        {
            "descricao": "Sinto uma dor forte ao levantar o braço para cima e para o lado",
            "categoria": "Ombro direito",
            "intensidade": 7,
        }
    ]
    print("\n📋 Caso 1 — Dor no Ombro Direito (intensidade 7/10)")
    print("-" * 50)
    resultados = rec.recomendar(sintomas_teste_1, top_n=3)
    for i, r in enumerate(resultados, 1):
        print(f"  {i}. [{r['score_similaridade']:.3f}] {r['nome_pt']} ({r['regiao_display']})")

    # Caso de teste 2: paciente com dor no pescoço
    sintomas_teste_2 = [
        {
            "descricao": "Dor e rigidez no pescoço ao girar a cabeça para os lados",
            "categoria": "Cervical (pescoço)",
            "intensidade": 5,
        }
    ]
    print("\n📋 Caso 2 — Dor no Pescoço/Cervical (intensidade 5/10)")
    print("-" * 50)
    resultados = rec.recomendar(sintomas_teste_2, top_n=3)
    for i, r in enumerate(resultados, 1):
        print(f"  {i}. [{r['score_similaridade']:.3f}] {r['nome_pt']} ({r['regiao_display']})")

    # Caso de teste 3: dor no tornozelo
    sintomas_teste_3 = [
        {
            "descricao": "Dor e inchaço no tornozelo após entorse, dificuldade ao caminhar",
            "categoria": "Tornozelo / pé",
            "intensidade": 8,
        }
    ]
    print("\n📋 Caso 3 — Dor no Tornozelo (intensidade 8/10)")
    print("-" * 50)
    resultados = rec.recomendar(sintomas_teste_3, top_n=3)
    for i, r in enumerate(resultados, 1):
        print(f"  {i}. [{r['score_similaridade']:.3f}] {r['nome_pt']} ({r['regiao_display']})")

    # Caso de teste 4: múltiplos sintomas
    sintomas_teste_4 = [
        {"descricao": "Formigamento e dor no punho ao digitar", "categoria": "Punho / mão", "intensidade": 6},
        {"descricao": "Dor no antebraço ao estender os dedos", "categoria": "Braço / cotovelo", "intensidade": 4},
    ]
    print("\n📋 Caso 4 — Múltiplos Sintomas: Punho + Braço")
    print("-" * 50)
    resultados = rec.recomendar(sintomas_teste_4, top_n=4)
    for i, r in enumerate(resultados, 1):
        print(f"  {i}. [{r['score_similaridade']:.3f}] {r['nome_pt']} ({r['regiao_display']})")

    print("\n✅ Testes concluídos com sucesso!")
    print("=" * 60)
