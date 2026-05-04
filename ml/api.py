"""
api.py
API REST do Motor de Recomendação ML — +Físio +Saúde
Servidor: FastAPI + Uvicorn

Endpoints:
    POST /recomendar  — Recebe sintomas do paciente, retorna exercícios recomendados
    GET  /catalogo    — Lista todos os exercícios disponíveis
    GET  /health      — Status da API

Deploy: Railway.app (https://railway.app) — gratuito, 24/7, sem servidor local

Como rodar localmente para testes:
    pip install -r requirements.txt
    python api.py
    → API disponível em http://localhost:8000
    → Documentação automática em http://localhost:8000/docs
"""

from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from recomendador import RecomendadorFisioterapia

# ─────────────────────────────────────────────────────────────────────────────
# Inicialização do modelo (carregado uma única vez na startup da API)
# ─────────────────────────────────────────────────────────────────────────────
recomendador_global: Optional[RecomendadorFisioterapia] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Carrega o modelo de ML na inicialização e libera ao encerrar."""
    global recomendador_global
    print("Carregando modelo de ML...")
    recomendador_global = RecomendadorFisioterapia()
    print(f"Modelo carregado! {len(recomendador_global.listar_catalogo())} exercicios no catalogo.")
    yield
    print("🛑 Encerrando API...")


# ─────────────────────────────────────────────────────────────────────────────
# Configuração da API
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="+Físio +Saúde — API de Recomendação ML",
    description=(
        "Motor de Machine Learning para recomendação personalizada de exercícios "
        "de fisioterapia baseado no perfil de sintomas do paciente.\n\n"
        "Algoritmo: **Content-Based Filtering** com **TF-IDF + Cosine Similarity**.\n\n"
        "Dataset: [PHYSIO-DATASET Kaggle](https://www.kaggle.com/datasets/toobasaeed11/physiotherapy)"
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — permite que o app Flutter (web) chame a API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Em produção, restringir para o domínio do app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# Modelos de Dados (Pydantic)
# ─────────────────────────────────────────────────────────────────────────────
class SintomaInput(BaseModel):
    descricao: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description="Descrição textual do sintoma relatado pelo paciente",
        examples=["Dor aguda ao levantar o braço acima da cabeça"],
    )
    categoria: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Região do corpo afetada (conforme seleção no app)",
        examples=["Ombro direito"],
    )
    intensidade: int = Field(
        default=5,
        ge=0,
        le=10,
        description="Intensidade da dor de 0 (sem dor) a 10 (dor máxima)",
        examples=[7],
    )


class RecomendacaoRequest(BaseModel):
    sintomas: list[SintomaInput] = Field(
        ...,
        min_length=1,
        description="Lista de sintomas registrados pelo paciente",
    )
    top_n: int = Field(
        default=5,
        ge=1,
        le=10,
        description="Quantidade de exercícios a retornar (padrão: 5)",
    )
    paciente_id: Optional[str] = Field(
        default=None,
        description="ID do paciente (opcional, para log futuro)",
    )
    profissional_id: Optional[str] = Field(
        default=None,
        description="ID do profissional solicitante (opcional)",
    )


class ExercicioRecomendado(BaseModel):
    id: str
    pasta_kaggle: str
    nome_pt: str
    nome_en: str
    regiao_display: str
    descricao: str
    nivel_dificuldade: str
    duracao_min: int
    url_video: str
    lateralidade: str
    score_similaridade: float
    indicacoes: list[str]


class RecomendacaoResponse(BaseModel):
    sucesso: bool
    total_recomendados: int
    algoritmo: str
    exercicios: list[ExercicioRecomendado]
    perfil_sintomas_resumo: str


class HealthResponse(BaseModel):
    status: str
    modelo_carregado: bool
    total_exercicios_catalogo: int
    versao: str


# ─────────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health", response_model=HealthResponse, tags=["Sistema"])
async def health_check():
    """Verifica se a API e o modelo estão operacionais."""
    return HealthResponse(
        status="online",
        modelo_carregado=recomendador_global is not None,
        total_exercicios_catalogo=(
            len(recomendador_global.listar_catalogo())
            if recomendador_global else 0
        ),
        versao="1.0.0",
    )


@app.get("/catalogo", tags=["Catálogo"])
async def listar_catalogo():
    """
    Retorna todos os exercícios disponíveis no catálogo.
    Útil para o profissional visualizar os exercícios antes de recomendar.
    """
    if recomendador_global is None:
        raise HTTPException(status_code=503, detail="Modelo não inicializado.")

    catalogo = recomendador_global.listar_catalogo()
    return {
        "sucesso": True,
        "total": len(catalogo),
        "exercicios": catalogo,
    }


@app.post("/recomendar", response_model=RecomendacaoResponse, tags=["Recomendação"])
async def recomendar_exercicios(request: RecomendacaoRequest):
    """
    **Principal endpoint do sistema de ML.**

    Recebe o perfil de sintomas do paciente e retorna os exercícios de
    fisioterapia mais adequados, ordenados por score de similaridade.

    **Algoritmo:**
    - TF-IDF vectoriza o catálogo de exercícios e o perfil do paciente
    - Cosine Similarity mede a proximidade semântica
    - Exercícios da região afetada recebem um boost de 80% no score

    **Exemplo de uso:**
    ```json
    {
        "sintomas": [
            {
                "descricao": "Dor ao levantar o braço acima da cabeça",
                "categoria": "Ombro direito",
                "intensidade": 8
            }
        ],
        "top_n": 5
    }
    ```
    """
    if recomendador_global is None:
        raise HTTPException(status_code=503, detail="Modelo não inicializado.")

    try:
        # Converte os modelos Pydantic para dicts simples
        sintomas_dict = [s.model_dump() for s in request.sintomas]

        # Detecta a região predominante para o filtro
        regiao_predominante = None
        if sintomas_dict:
            # Usa a região do sintoma com maior intensidade
            sintoma_mais_intenso = max(sintomas_dict, key=lambda s: s["intensidade"])
            regiao_predominante = sintoma_mais_intenso.get("categoria")

        # Executa a recomendação
        exercicios = recomendador_global.recomendar(
            sintomas=sintomas_dict,
            top_n=request.top_n,
            filtrar_regiao=regiao_predominante,
        )

        # Resumo do perfil para log/transparência
        regioes = list({s["categoria"] for s in sintomas_dict if s.get("categoria")})
        intensidade_media = sum(s["intensidade"] for s in sintomas_dict) / len(sintomas_dict)
        perfil_resumo = (
            f"Região(ões): {', '.join(regioes)} | "
            f"Intensidade média: {intensidade_media:.1f}/10 | "
            f"{len(sintomas_dict)} sintoma(s)"
        )

        return RecomendacaoResponse(
            sucesso=True,
            total_recomendados=len(exercicios),
            algoritmo="TF-IDF + Cosine Similarity (Content-Based Filtering)",
            exercicios=exercicios,
            perfil_sintomas_resumo=perfil_resumo,
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao processar recomendação: {str(e)}",
        )


@app.get("/exercicio/{exercicio_id}", tags=["Catálogo"])
async def buscar_exercicio(exercicio_id: str):
    """Busca os detalhes de um exercício específico pelo ID."""
    if recomendador_global is None:
        raise HTTPException(status_code=503, detail="Modelo não inicializado.")

    exercicio = recomendador_global.buscar_por_id(exercicio_id)
    if exercicio is None:
        raise HTTPException(status_code=404, detail=f"Exercício '{exercicio_id}' não encontrado.")

    return {"sucesso": True, "exercicio": exercicio}


# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn

    print("Iniciando +Fisio +Saude ML API...")
    print("Documentacao: http://localhost:8000/docs")
    uvicorn.run("api:app", host="0.0.0.0", port=8000, reload=True)
