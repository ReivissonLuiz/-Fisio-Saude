"""
kaggle_integration/loader.py
Carregamento dos dados transformados para o Supabase — +Físio +Saúde

Estratégia: upsert por ID determinístico (idempotente).
Re-executar o pipeline não duplica registros.
"""

import sys
import os

# Garante importação correta quando executado como módulo
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from supabase_client import get_admin_client

# Tamanho do lote para inserção em massa (evita timeout)
BATCH_SIZE = 50


class SupabaseLoader:
    """
    Insere/atualiza registros nas tabelas do Supabase via upsert.
    Utiliza o cliente admin (service_role) para ignorar RLS.
    """

    def __init__(self, dry_run: bool = False):
        """
        Args:
            dry_run: Se True, simula a inserção sem modificar o banco.
        """
        self.dry_run = dry_run
        self._client = None if dry_run else get_admin_client()

    # ─── Público ─────────────────────────────────────────────────────────────

    def load_all(
        self,
        pacientes: list,
        avaliacoes: list,
        avaliacoes_cardiacas: list,
    ) -> dict:
        """
        Executa o carregamento completo na ordem correta (respeitando FKs):
          1. paciente
          2. avaliacao
          3. avaliacao_cardiaca

        Returns:
            Dicionário com resultados de cada tabela.
        """
        results = {}

        print("\n  📤 Iniciando carga no Supabase...")

        results["paciente"]            = self._upsert("paciente",            pacientes)
        results["avaliacao"]           = self._upsert("avaliacao",           avaliacoes)
        results["avaliacao_cardiaca"]  = self._upsert("avaliacao_cardiaca",  avaliacoes_cardiacas)

        return results

    # ─── Privado ─────────────────────────────────────────────────────────────

    def _upsert(self, table: str, records: list) -> dict:
        """
        Faz upsert em lotes na tabela especificada.

        Args:
            table:   Nome da tabela no Supabase.
            records: Lista de dicts a inserir/atualizar.

        Returns:
            Dicionário com: inserted, errors, total
        """
        if not records:
            print(f"  ⚠  Tabela `{table}`: nenhum registro para inserir.")
            return {"inserted": 0, "errors": 0, "total": 0}

        total    = len(records)
        inserted = 0
        errors   = 0

        if self.dry_run:
            print(f"  🔍 [DRY-RUN] Tabela `{table}`: {total} registro(s) seriam inseridos")
            return {"inserted": 0, "errors": 0, "total": total, "dry_run": True}

        print(f"  ⬆  Tabela `{table}`: inserindo {total} registro(s) em lotes de {BATCH_SIZE}...")

        for i in range(0, total, BATCH_SIZE):
            batch = records[i : i + BATCH_SIZE]
            batch_num = (i // BATCH_SIZE) + 1
            total_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE

            try:
                # Upsert: insert + update se já existir (baseado na PK `id`)
                resp = (
                    self._client
                    .table(table)
                    .upsert(batch, on_conflict="id")
                    .execute()
                )
                inserted += len(resp.data) if resp.data else len(batch)
                print(f"     Lote {batch_num}/{total_batches} — OK ({len(batch)} registros)")

            except Exception as e:
                errors += len(batch)
                print(f"     Lote {batch_num}/{total_batches} — ❌ ERRO: {e}")

        status = "✅" if errors == 0 else "⚠ "
        print(f"  {status} Tabela `{table}`: {inserted} inseridos | {errors} erros")

        return {"inserted": inserted, "errors": errors, "total": total}
