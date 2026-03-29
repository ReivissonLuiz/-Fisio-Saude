"""
services/exercicio_service.py
Serviço CRUD para a tabela `exercicio` — +Físio +Saúde
"""

from typing import Optional
from supabase_client import supabase_admin


class ExercicioService:
    """Operações na tabela exercicio — biblioteca de exercícios."""

    TABLE = "exercicio"

    def listar(self, apenas_ativos: bool = True) -> dict:
        """Lista todos os exercícios da biblioteca."""
        try:
            query = supabase_admin.table(self.TABLE).select("*, profissional(nome)")
            if apenas_ativos:
                query = query.eq("ativo", True)
            resp = query.order("titulo").execute()
            return {"success": True, "data": resp.data, "total": len(resp.data)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def listar_por_profissional(self, prof_id: str) -> dict:
        """Lista exercícios cadastrados por um profissional específico."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").eq("id_profissional", prof_id).eq("ativo", True).order("titulo").execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def listar_por_tipo(self, tipo: str) -> dict:
        """Filtra exercícios por tipo (ex: Fortalecimento, Alongamento, etc.)."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").ilike("tipo", f"%{tipo}%").eq("ativo", True).execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def buscar_por_id(self, exercicio_id: str) -> dict:
        """Busca um exercício pelo UUID."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*, profissional(nome)").eq("id", exercicio_id).single().execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def pesquisar(self, termo: str) -> dict:
        """Pesquisa exercícios por título ou descrição."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*").or_(
                f"titulo.ilike.%{termo}%,descricao.ilike.%{termo}%"
            ).eq("ativo", True).execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar(self, id_profissional: str, titulo: str,
              descricao: Optional[str] = None,
              tipo: Optional[str] = None,
              video_url: Optional[str] = None) -> dict:
        """Cadastra um novo exercício na biblioteca."""
        try:
            dados = {
                "id_profissional": id_profissional,
                "titulo": titulo.strip(),
                "descricao": descricao,
                "tipo": tipo,
                "video_url": video_url,
                "ativo": True,
            }
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def atualizar(self, exercicio_id: str, dados: dict) -> dict:
        """Atualiza um exercício existente."""
        try:
            resp = supabase_admin.table(self.TABLE).update(dados).eq("id", exercicio_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def desativar(self, exercicio_id: str) -> dict:
        """Remove (soft delete) um exercício da biblioteca."""
        return self.atualizar(exercicio_id, {"ativo": False})


# Instância singleton
exercicio_service = ExercicioService()
