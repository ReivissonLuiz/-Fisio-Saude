"""
kaggle_integration/__init__.py
Pacote de integração com o Kaggle — +Físio +Saúde

Uso rápido:
    python -m kaggle_integration.pipeline
    python -m kaggle_integration.pipeline --dry-run
"""

from .downloader import KaggleDownloader
from .transformer import HeartDiseaseTransformer
from .loader import SupabaseLoader

__all__ = ["KaggleDownloader", "HeartDiseaseTransformer", "SupabaseLoader"]
