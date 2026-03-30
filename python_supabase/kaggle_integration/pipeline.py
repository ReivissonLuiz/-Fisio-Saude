"""
kaggle_integration/pipeline.py
Pipeline principal de ingestão: Kaggle → Supabase — +Físio +Saúde

Uso:
    # Execução completa (baixa CSV e popula o banco)
    python -m kaggle_integration.pipeline

    # Apenas validação (não insere nada no banco)
    python -m kaggle_integration.pipeline --dry-run

    # Força re-download do CSV mesmo se já existir localmente
    python -m kaggle_integration.pipeline --force-download

    # Exibe estatísticas do dataset sem inserir
    python -m kaggle_integration.pipeline --stats

Pré-requisitos:
    1. Crie e configure o arquivo .env (veja .env.example)
    2. Execute o SQL migrations/001_avaliacao_cardiaca.sql no Supabase
    3. pip install -r requirements.txt
"""

import sys
import os
import argparse
import time
from pathlib import Path
from datetime import datetime

# Adiciona o diretório pai ao path para importações
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()

# ─── Cores de terminal ────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
BLUE   = "\033[94m"
CYAN   = "\033[96m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def header(msg):  print(f"\n{BOLD}{BLUE}{'─'*55}\n  {msg}\n{'─'*55}{RESET}")
def ok(msg):      print(f"  {GREEN}✅ {msg}{RESET}")
def fail(msg):    print(f"  {RED}❌ {msg}{RESET}")
def info(msg):    print(f"  {CYAN}ℹ  {msg}{RESET}")
def warn(msg):    print(f"  {YELLOW}⚠  {msg}{RESET}")


# ─── Pipeline ─────────────────────────────────────────────────────────────────

def run_pipeline(dry_run: bool = False, force_download: bool = False, stats_only: bool = False):
    """
    Executa o pipeline completo:
      1. Download  — garante CSV local
      2. Transform — converte colunas para esquema Supabase
      3. Load      — insere/atualiza no banco via upsert
    """
    from kaggle_integration.downloader  import KaggleDownloader
    from kaggle_integration.transformer import HeartDiseaseTransformer
    from kaggle_integration.loader      import SupabaseLoader

    start_time = time.time()

    print(f"\n{BOLD}{'='*55}")
    print("   +Físio +Saúde — Pipeline Kaggle → Supabase")
    if dry_run:
        print(f"   {YELLOW}MODO DRY-RUN: nenhum dado será inserido no banco{RESET}")
    print(f"{'='*55}{RESET}")
    print(f"  Iniciado em: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")

    # ── 1. DOWNLOAD ───────────────────────────────────────────────────────────
    header("1 / 3 — Download do Dataset")
    try:
        downloader = KaggleDownloader(force=force_download)
        csv_path = downloader.get_csv_path()
    except (EnvironmentError, FileNotFoundError, ImportError) as e:
        fail(str(e))
        sys.exit(1)

    # ── 2. TRANSFORM ──────────────────────────────────────────────────────────
    header("2 / 3 — Transformação dos Dados")
    try:
        transformer = HeartDiseaseTransformer(csv_path)

        if stats_only:
            summary = transformer.get_summary()
            print(f"\n{BOLD}  📊 Estatísticas do Dataset:{RESET}")
            info(f"Total de registros : {summary['total_registros']}")
            info(f"Com doença cardíaca: {summary['com_doenca_cardiaca']}")
            info(f"Sem doença cardíaca: {summary['sem_doenca_cardiaca']}")
            info(f"Idade média        : {summary['idade_media']} anos")
            info(f"Colunas            : {', '.join(summary['colunas'])}")
            print(f"\n  {YELLOW}Use sem --stats para executar a ingestão.{RESET}\n")
            return

        pacientes, avaliacoes, avaliacoes_cardiacas = transformer.transform()

    except (ValueError, FileNotFoundError) as e:
        fail(str(e))
        sys.exit(1)

    # ── 3. LOAD ───────────────────────────────────────────────────────────────
    header("3 / 3 — Carga no Supabase")

    if not dry_run:
        service_key = os.getenv("SUPABASE_SERVICE_KEY", "")
        if not service_key:
            fail(
                "SUPABASE_SERVICE_KEY não configurada!\n"
                "  Configure no arquivo .env para executar a ingestão.\n"
                "  Dica: use --dry-run para testar sem inserir dados."
            )
            sys.exit(1)

    try:
        loader  = SupabaseLoader(dry_run=dry_run)
        results = loader.load_all(pacientes, avaliacoes, avaliacoes_cardiacas)
    except Exception as e:
        fail(f"Erro durante a carga: {e}")
        sys.exit(1)

    # ── RESUMO ───────────────────────────────────────────────────────────────
    elapsed = time.time() - start_time
    print(f"\n{BOLD}{'='*55}")
    print("   Resultado Final")
    print(f"{'='*55}{RESET}")

    total_errors = sum(r.get("errors", 0) for r in results.values())

    for table, r in results.items():
        prefix = "✅" if r.get("errors", 0) == 0 else "⚠"
        if dry_run:
            print(f"  {CYAN}🔍 {table}: {r.get('total', 0)} registros seriam inseridos{RESET}")
        else:
            print(f"  {prefix} {table}: {r.get('inserted', 0)}/{r.get('total', 0)} inseridos")

    print(f"\n  ⏱  Tempo total: {elapsed:.1f}s")

    if dry_run:
        print(f"\n  {YELLOW}Dry-run concluído. Para inserir de verdade, remova --dry-run.{RESET}")
    elif total_errors == 0:
        print(f"\n  {GREEN}{BOLD}Pipeline concluído com sucesso! ✅{RESET}")
        print(f"  {GREEN}Os dados do dataset Kaggle já estão no seu Supabase.{RESET}")
    else:
        print(f"\n  {YELLOW}Pipeline concluído com {total_errors} erro(s). Verifique os logs acima.{RESET}")

    print()


# ─── Entrada ──────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="python -m kaggle_integration.pipeline",
        description="+Físio +Saúde — Pipeline de ingestão Kaggle → Supabase",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simula a ingestão sem inserir nada no banco de dados.",
    )
    parser.add_argument(
        "--force-download",
        action="store_true",
        help="Força re-download do CSV mesmo se já existir localmente.",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Exibe estatísticas do dataset sem inserir dados.",
    )

    args = parser.parse_args()
    run_pipeline(
        dry_run=args.dry_run,
        force_download=args.force_download,
        stats_only=args.stats,
    )


if __name__ == "__main__":
    main()
