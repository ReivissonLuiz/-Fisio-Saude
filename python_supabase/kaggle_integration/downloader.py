"""
kaggle_integration/downloader.py
Download do dataset Heart Disease do Kaggle — +Físio +Saúde

Formas de uso:
  1. Via API Kaggle (requer kaggle.json ou variáveis KAGGLE_USERNAME + KAGGLE_KEY)
  2. Via CSV manual: basta colocar o arquivo em python_supabase/data/heart.csv
"""

import os
import sys
import zipfile
import shutil
from pathlib import Path

# ─── Paths ───────────────────────────────────────────────────────────────────
# python_supabase/
MODULE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR   = MODULE_DIR / "data"
CSV_PATH   = DATA_DIR / "heart.csv"

KAGGLE_DATASET = "johnsmith88/heart-disease-dataset"
KAGGLE_FILE    = "heart.csv"


class KaggleDownloader:
    """
    Gerencia o download do dataset Heart Disease do Kaggle.

    Prioridade de resolução:
      1. CSV já presente em data/heart.csv  →  usa direto (sem download)
      2. Variáveis de ambiente KAGGLE_USERNAME + KAGGLE_KEY definidas
      3. Arquivo ~/.kaggle/kaggle.json presente
    """

    def __init__(self, force: bool = False):
        """
        Args:
            force: Se True, re-baixa mesmo que o CSV já exista localmente.
        """
        self.force = force
        DATA_DIR.mkdir(parents=True, exist_ok=True)

    # ─── Público ─────────────────────────────────────────────────────────────

    def get_csv_path(self) -> Path:
        """
        Garante que o CSV existe localmente e retorna seu caminho.

        Returns:
            Path para o arquivo heart.csv
        Raises:
            FileNotFoundError: Se o download falhar e o CSV não existir.
        """
        if CSV_PATH.exists() and not self.force:
            print(f"  ✅ CSV já existe localmente: {CSV_PATH}")
            return CSV_PATH

        print(f"  📥 CSV não encontrado. Tentando baixar do Kaggle...")
        self._configure_kaggle_auth()
        self._download()
        return CSV_PATH

    # ─── Privado ─────────────────────────────────────────────────────────────

    def _configure_kaggle_auth(self):
        """Configura autenticação via variáveis de ambiente se disponíveis."""
        username = os.getenv("KAGGLE_USERNAME")
        key      = os.getenv("KAGGLE_KEY")

        if username and key:
            os.environ["KAGGLE_USERNAME"] = username
            os.environ["KAGGLE_KEY"]      = key
            print(f"  🔑 Autenticação Kaggle via variáveis de ambiente (usuário: {username})")
        else:
            kaggle_json = Path.home() / ".kaggle" / "kaggle.json"
            if kaggle_json.exists():
                print(f"  🔑 Autenticação Kaggle via {kaggle_json}")
            else:
                raise EnvironmentError(
                    "\n"
                    "  ❌ Credenciais Kaggle não encontradas!\n\n"
                    "  Escolha uma das opções abaixo:\n\n"
                    "  OPÇÃO A — Variáveis de ambiente no .env:\n"
                    "    KAGGLE_USERNAME=seu_usuario\n"
                    "    KAGGLE_KEY=sua_chave_api\n\n"
                    "  OPÇÃO B — Arquivo kaggle.json:\n"
                    "    1. Acesse https://www.kaggle.com/settings\n"
                    "    2. Clique em 'Create New Token'\n"
                    "    3. Salve o arquivo em: ~/.kaggle/kaggle.json\n\n"
                    "  OPÇÃO C — CSV manual (sem API):\n"
                    "    1. Baixe em: https://www.kaggle.com/datasets/johnsmith88/heart-disease-dataset\n"
                    f"   2. Coloque o arquivo heart.csv em: {DATA_DIR}\n"
                )

    def _download(self):
        """Baixa e extrai o dataset via biblioteca kaggle."""
        try:
            import kaggle  # noqa: F401 — valida instalação
        except ImportError:
            raise ImportError(
                "  ❌ Biblioteca 'kaggle' não instalada.\n"
                "  Execute: pip install kaggle"
            )

        from kaggle.api.kaggle_api_extended import KaggleApiExtended
        api = KaggleApiExtended()
        api.authenticate()

        print(f"  ⬇  Baixando dataset '{KAGGLE_DATASET}'...")
        api.dataset_download_files(
            KAGGLE_DATASET,
            path=str(DATA_DIR),
            quiet=False,
            unzip=False,
        )

        # Extrai o ZIP gerado pelo Kaggle
        zip_path = DATA_DIR / f"{KAGGLE_DATASET.split('/')[-1]}.zip"
        if not zip_path.exists():
            # Kaggle às vezes nomeia diferente — procura qualquer .zip
            zips = list(DATA_DIR.glob("*.zip"))
            if zips:
                zip_path = zips[0]
            else:
                raise FileNotFoundError(
                    f"  ❌ ZIP não encontrado em {DATA_DIR} após o download."
                )

        print(f"  📦 Extraindo {zip_path.name}...")
        with zipfile.ZipFile(zip_path, "r") as zf:
            # Extrai apenas o CSV principal
            csv_members = [m for m in zf.namelist() if m.endswith(".csv")]
            if not csv_members:
                raise FileNotFoundError("  ❌ Nenhum CSV encontrado dentro do ZIP.")

            # Pega o primeiro CSV (geralmente heart.csv)
            extracted_name = csv_members[0]
            zf.extract(extracted_name, DATA_DIR)

            # Renomeia para heart.csv se necessário
            extracted_path = DATA_DIR / extracted_name
            if extracted_path != CSV_PATH:
                shutil.move(str(extracted_path), str(CSV_PATH))

        zip_path.unlink(missing_ok=True)  # Remove o ZIP após extração
        print(f"  ✅ Dataset salvo em: {CSV_PATH}")
