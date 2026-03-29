"""
services/paciente_service.py
Serviço CRUD para a tabela `paciente` — +Físio +Saúde
"""

from typing import Optional, List
from supabase_client import supabase, supabase_admin


class PacienteService:
    """Operações na tabela paciente."""

    TABLE = "paciente"

    def listar(self, apenas_ativos: bool = True) -> dict:
        """Lista todos os pacientes (filtrando por ativo, se solicitado)."""
        try:
            query = supabase_admin.table(self.TABLE).select("*")
            if apenas_ativos:
                query = query.eq("ativo", True)
            resp = query.order("nome").execute()
            return {"success": True, "data": resp.data, "total": len(resp.data)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_id(self, paciente_id: str) -> dict:
        """Busca um paciente pelo UUID."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").eq("id", paciente_id).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_cpf(self, cpf: str) -> dict:
        """Busca um paciente pelo CPF."""
        try:
            cpf_limpo = cpf.replace(".", "").replace("-", "")
            resp = supabase_admin.table(self.TABLE).select("*").eq("cpf", cpf_limpo).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_email(self, email: str) -> dict:
        """Busca um paciente pelo e-mail."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").eq("email", email.lower()).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar(self, dados: dict) -> dict:
        """Cria um novo paciente."""
        try:
            if "cpf" in dados:
                dados["cpf"] = dados["cpf"].replace(".", "").replace("-", "")
            if "email" in dados:
                dados["email"] = dados["email"].lower().strip()
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def atualizar(self, paciente_id: str, dados: dict) -> dict:
        """Atualiza os dados de um paciente existente."""
        try:
            resp = supabase_admin.table(self.TABLE).update(dados).eq("id", paciente_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def desativar(self, paciente_id: str) -> dict:
        """Desativa um paciente (soft delete)."""
        return self.atualizar(paciente_id, {"ativo": False})

    def pesquisar(self, termo: str) -> dict:
        """Pesquisa pacientes por nome (busca parcial)."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").ilike("nome", f"%{termo}%").execute()
            return {"success": True, "data": resp.data, "total": len(resp.data)}
        except Exception as e:
            return {"success": False, "error": str(e)}


# Instância singleton
paciente_service = PacienteService()
