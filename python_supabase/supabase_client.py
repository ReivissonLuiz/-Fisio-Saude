"""
supabase_client.py
Cliente base para integração com o Supabase — +Físio +Saúde
Gerencia a conexão, autenticação e operações CRUD nas tabelas.
"""

import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

# ─── Configurações do Supabase ─────────────────────────────────────────────────
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://nkicptibdnuygxxnoaof.supabase.co")
SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY", "")

# ─── Instâncias de cliente ─────────────────────────────────────────────────────
def get_client() -> Client:
    """Retorna cliente com permissão de anon (usuário autenticado)."""
    key = SUPABASE_ANON_KEY or SUPABASE_SERVICE_KEY
    if not key:
        raise ValueError("Nenhuma chave do Supabase configurada. Verifique o arquivo .env")
    return create_client(SUPABASE_URL, key)


def get_admin_client() -> Client:
    """Retorna cliente com service_role (acesso total, ignora RLS)."""
    if not SUPABASE_SERVICE_KEY:
        raise ValueError("SUPABASE_SERVICE_KEY não configurada. Verifique o arquivo .env")
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


# Cliente padrão (singleton simples)
supabase: Client = get_client()
supabase_admin: Client = get_admin_client()
