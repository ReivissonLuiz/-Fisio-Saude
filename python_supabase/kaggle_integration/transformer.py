"""
kaggle_integration/transformer.py
Transformação dos dados do Heart Disease Dataset para o esquema Supabase — +Físio +Saúde

Mapeamento de colunas:
  age         → avaliacao_cardiaca.idade
  sex         → avaliacao_cardiaca.sexo            (1=M, 0=F)
  cp          → avaliacao_cardiaca.tipo_dor_peito  (0-3)
  trestbps    → avaliacao_cardiaca.pressao_repouso + avaliacao.pressao_sistolica
  chol        → avaliacao_cardiaca.colesterol
  fbs         → avaliacao_cardiaca.glicemia_jejum  (bool)
  restecg     → avaliacao_cardiaca.ecg_repouso     (0-2)
  thalach     → avaliacao_cardiaca.freq_cardiaca_max + avaliacao.frequencia_cardiaca
  exang       → avaliacao_cardiaca.angina_exercicio (bool)
  oldpeak     → avaliacao_cardiaca.depressao_st
  slope       → avaliacao_cardiaca.inclinacao_st   (0-2)
  ca          → avaliacao_cardiaca.vasos_principais (0-3)
  thal        → avaliacao_cardiaca.thal             (0-2)
  target      → avaliacao_cardiaca.doenca_cardiaca  (bool)
"""

import uuid
import hashlib
from datetime import datetime, date, timezone
from pathlib import Path
from typing import Tuple

try:
    import pandas as pd
    import numpy as np
except ImportError:
    raise ImportError(
        "❌ Bibliotecas 'pandas' e 'numpy' não instaladas.\n"
        "   Execute: pip install pandas numpy"
    )


# ─── Constantes ──────────────────────────────────────────────────────────────

KAGGLE_SOURCE = "kaggle:johnsmith88/heart-disease-dataset"

# Data fictícia de avaliação (usada como data_hora nas tabelas avaliacao/paciente)
IMPORT_DATE = datetime(2019, 6, 6, tzinfo=timezone.utc)  # Data de publicação do dataset


class HeartDiseaseTransformer:
    """
    Transforma o CSV do Kaggle em dois DataFrames prontos para inserção:
      - df_pacientes: registros anonimizados para a tabela `paciente`
      - df_avaliacoes: registros para `avaliacao` e `avaliacao_cardiaca`
    """

    def __init__(self, csv_path: Path):
        self.csv_path = csv_path
        self._raw: pd.DataFrame | None = None

    # ─── Público ─────────────────────────────────────────────────────────────

    def transform(self) -> Tuple[list, list, list]:
        """
        Executa a transformação completa.

        Returns:
            Tupla (pacientes, avaliacoes, avaliacoes_cardiacas)
            Cada item é uma lista de dicts pronta para inserção no Supabase.
        """
        self._raw = self._load_csv()
        self._validate()
        self._clean()

        pacientes           = self._build_pacientes()
        avaliacoes          = self._build_avaliacoes(pacientes)
        avaliacoes_cardiacas = self._build_avaliacoes_cardiacas(pacientes, avaliacoes)

        print(f"  🔄 Transformação concluída:")
        print(f"     • {len(pacientes)} pacientes fictícios gerados")
        print(f"     • {len(avaliacoes)} avaliações base geradas")
        print(f"     • {len(avaliacoes_cardiacas)} avaliações cardíacas geradas")

        return pacientes, avaliacoes, avaliacoes_cardiacas

    def get_summary(self) -> dict:
        """Retorna estatísticas básicas do dataset."""
        if self._raw is None:
            self._raw = self._load_csv()
        df = self._raw
        return {
            "total_registros": len(df),
            "com_doenca_cardiaca": int(df["target"].sum()),
            "sem_doenca_cardiaca": int((df["target"] == 0).sum()),
            "idade_media": round(float(df["age"].mean()), 1),
            "colunas": list(df.columns),
        }

    # ─── Privado ─────────────────────────────────────────────────────────────

    def _load_csv(self) -> pd.DataFrame:
        """Carrega o CSV e faz parse básico."""
        print(f"  📂 Carregando CSV: {self.csv_path}")
        df = pd.read_csv(self.csv_path)
        print(f"  📊 {len(df)} registros encontrados | Colunas: {list(df.columns)}")
        return df

    def _validate(self):
        """Valida que as colunas esperadas estão presentes."""
        required = {"age", "sex", "cp", "trestbps", "chol", "fbs",
                    "restecg", "thalach", "exang", "oldpeak", "slope",
                    "ca", "thal", "target"}
        missing = required - set(self._raw.columns)
        if missing:
            raise ValueError(
                f"  ❌ Colunas ausentes no CSV: {missing}\n"
                f"  Colunas encontradas: {list(self._raw.columns)}"
            )

    def _clean(self):
        """Limpeza e normalização dos dados."""
        df = self._raw

        # Remove linhas com valores nulos em campos críticos
        critical_cols = ["age", "sex", "trestbps", "thalach", "target"]
        before = len(df)
        df = df.dropna(subset=critical_cols)
        after = len(df)
        if before != after:
            print(f"  ⚠  {before - after} linha(s) removidas por valores nulos em campos críticos")

        # Converte tipos
        df["age"]      = df["age"].astype(int)
        df["sex"]      = df["sex"].astype(int)
        df["target"]   = df["target"].astype(int)
        df["trestbps"] = df["trestbps"].astype(int)
        df["thalach"]  = df["thalach"].astype(int)

        # Normaliza ca e thal (podem ter valores nulos ou float no dataset)
        df["ca"]   = pd.to_numeric(df["ca"],   errors="coerce").fillna(0).astype(int)
        df["thal"] = pd.to_numeric(df["thal"], errors="coerce").fillna(0).astype(int)

        # Garante valores dentro dos intervalos válidos
        df["cp"]        = df["cp"].clip(0, 3).astype(int)
        df["restecg"]   = df["restecg"].clip(0, 2).astype(int)
        df["slope"]     = df["slope"].clip(0, 2).astype(int)
        df["ca"]        = df["ca"].clip(0, 3)
        df["thal"]      = df["thal"].clip(0, 2)

        # Reseta índice após remoções
        df = df.reset_index(drop=True)
        self._raw = df

    def _build_pacientes(self) -> list:
        """
        Gera registros fictícios/anonimizados para a tabela `paciente`.
        Um paciente por linha do dataset, sem dados pessoais reais.
        """
        pacientes = []
        df = self._raw

        for idx, row in df.iterrows():
            # UUID determinístico baseado no índice da linha + fonte
            # Garante idempotência: mesma linha sempre gera o mesmo UUID
            seed = f"{KAGGLE_SOURCE}:row:{idx}"
            paciente_id = str(uuid.UUID(hashlib.md5(seed.encode()).hexdigest()))

            sexo_label = "M" if int(row["sex"]) == 1 else "F"
            genero = "Masculino" if int(row["sex"]) == 1 else "Feminino"

            pacientes.append({
                "id":          paciente_id,
                "nome":        f"Paciente Kaggle {idx + 1:03d} ({sexo_label})",
                "cpf":         _gerar_cpf_ficticio(idx),
                "email":       f"kaggle.hd.{idx + 1:04d}@pesquisa.fisio.local",
                "genero":      genero,
                "data_nasc":   _estimar_data_nascimento(int(row["age"])),
                "ativo":       True,
                "criado_em":   IMPORT_DATE.isoformat(),
                "atualizado_em": IMPORT_DATE.isoformat(),
            })

        return pacientes

    def _build_avaliacoes(self, pacientes: list) -> list:
        """
        Gera registros para a tabela `avaliacao` com os campos já mapeados.
        """
        avaliacoes = []
        df = self._raw

        for idx, row in df.iterrows():
            seed = f"{KAGGLE_SOURCE}:avaliacao:{idx}"
            avaliacao_id = str(uuid.UUID(hashlib.md5(seed.encode()).hexdigest()))
            paciente_id  = pacientes[idx]["id"]

            # Classificação básica de risco baseada no target
            classificacao = "Risco Cardiovascular Alto" if int(row["target"]) == 1 \
                            else "Sem Indicativo de Doença Cardíaca"

            avaliacoes.append({
                "id":                   avaliacao_id,
                "id_paciente":          paciente_id,
                "id_profissional":      None,   # Sem profissional para dados de pesquisa
                "data_hora":            IMPORT_DATE.isoformat(),
                "pressao_sistolica":    int(row["trestbps"]),
                "pressao_diastolica":   None,   # Não disponível no dataset
                "frequencia_cardiaca":  int(row["thalach"]),
                "nivel_dor":            _cp_para_nivel_dor(int(row["cp"])),
                "classificacao":        classificacao,
                "observacoes":          (
                    f"Importado do dataset Kaggle Heart Disease. "
                    f"Colesterol: {int(row['chol'])} mg/dl. "
                    f"Fonte: {KAGGLE_SOURCE}"
                ),
            })

        return avaliacoes

    def _build_avaliacoes_cardiacas(self, pacientes: list, avaliacoes: list) -> list:
        """
        Gera registros para a tabela `avaliacao_cardiaca` com todos os campos do dataset.
        """
        avaliacoes_cardiacas = []
        df = self._raw

        for idx, row in df.iterrows():
            paciente_id  = pacientes[idx]["id"]
            avaliacao_id = avaliacoes[idx]["id"]

            # UUID determinístico para avaliacao_cardiaca
            seed = f"{KAGGLE_SOURCE}:cardiaca:{idx}"
            avc_id = str(uuid.UUID(hashlib.md5(seed.encode()).hexdigest()))

            # Calcula importado_em com offset para garantir unicidade na constraint
            import_ts = datetime(
                2019, 6, 6,
                hour=0, minute=0, second=idx % 60,
                microsecond=(idx // 60) * 1000,
                tzinfo=timezone.utc
            ).isoformat()

            avaliacoes_cardiacas.append({
                "id":                  avc_id,
                "id_avaliacao":        avaliacao_id,
                "id_paciente":         paciente_id,
                "idade":               int(row["age"]),
                "sexo":                int(row["sex"]),
                "tipo_dor_peito":      int(row["cp"]),
                "pressao_repouso":     int(row["trestbps"]),
                "colesterol":          int(row["chol"]),
                "glicemia_jejum":      bool(int(row["fbs"])),
                "ecg_repouso":         int(row["restecg"]),
                "freq_cardiaca_max":   int(row["thalach"]),
                "angina_exercicio":    bool(int(row["exang"])),
                "depressao_st":        float(row["oldpeak"]),
                "inclinacao_st":       int(row["slope"]),
                "vasos_principais":    int(row["ca"]),
                "thal":                int(row["thal"]),
                "doenca_cardiaca":     bool(int(row["target"])),
                "fonte":               KAGGLE_SOURCE,
                "importado_em":        import_ts,
            })

        return avaliacoes_cardiacas


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _gerar_cpf_ficticio(idx: int) -> str:
    """Gera CPF fictício baseado no índice — formato sem pontuação."""
    base = str(idx + 900_000_001).zfill(9)
    # Dígitos verificadores fictícios (não válidos intencionalmente)
    return f"{base}00"


def _estimar_data_nascimento(idade: int) -> str:
    """Estima data de nascimento aproximada baseada na idade em 2019."""
    ano_nasc = 2019 - idade
    return date(ano_nasc, 1, 1).isoformat()


def _cp_para_nivel_dor(cp: int) -> int | None:
    """
    Converte tipo de dor no peito (cp) para escala de dor 0-10.
      0 = angina típica      → 7
      1 = angina atípica     → 4
      2 = dor não-anginosa   → 2
      3 = assintomático      → 0
    """
    mapping = {0: 7, 1: 4, 2: 2, 3: 0}
    return mapping.get(cp)
