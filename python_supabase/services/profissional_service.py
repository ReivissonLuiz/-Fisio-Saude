"""
services/profissional_service.py
Serviço CRUD para a tabela `profissional` — +Físio +Saúde
"""

from supabase_client import supabase_admin


class ProfissionalService:
    """Operações na tabela profissional."""

    TABLE = "profissional"

    def listar(self, apenas_ativos: bool = True) -> dict:
        """Lista todos os profissionais."""
        try:
            query = supabase_admin.table(self.TABLE).select("*")
            if apenas_ativos:
                query = query.eq("ativo", True)
            resp = query.order("nome").execute()
            return {"success": True, "data": resp.data, "total": len(resp.data)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_id(self, prof_id: str) -> dict:
        """Busca profissional pelo UUID."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").eq("id", prof_id).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_crefito(self, crefito: str) -> dict:
        """Busca profissional pelo CREFITO."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").eq("crefito", crefito.strip()).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def listar_por_especialidade(self, especialidade: str) -> dict:
        """Lista profissionais de uma especialidade específica."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").ilike("especialidade", f"%{especialidade}%").eq("ativo", True).execute()
            return {"success": True, "data": resp.data, "total": len(resp.data)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar(self, dados: dict) -> dict:
        """Cria um novo profissional (ativo=False por padrão — aguarda aprovação)."""
        try:
            dados.setdefault("ativo", False)
            if "email" in dados:
                dados["email"] = dados["email"].lower().strip()
            if "cpf" in dados:
                dados["cpf"] = dados["cpf"].replace(".", "").replace("-", "")
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def aprovar(self, prof_id: str) -> dict:
        """Aprova um profissional (ativo=True)."""
        try:
            resp = supabase_admin.table(self.TABLE).update({"ativo": True}).eq("id", prof_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def atualizar(self, prof_id: str, dados: dict) -> dict:
        """Atualiza dados do profissional."""
        try:
            resp = supabase_admin.table(self.TABLE).update(dados).eq("id", prof_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def desativar(self, prof_id: str) -> dict:
        """Desativa um profissional (soft delete)."""
        return self.atualizar(prof_id, {"ativo": False})


# Instância singleton
profissional_service = ProfissionalService()
