"""
services/consulta_service.py
Serviço CRUD para as tabelas `consulta`, `agenda` e `avaliacao` — +Físio +Saúde
"""

from typing import Optional
from datetime import datetime
from supabase_client import supabase_admin


class AgendaService:
    """Operações na tabela agenda — slots de atendimento."""

    TABLE = "agenda"

    def listar_por_profissional(self, prof_id: str, apenas_futuros: bool = True) -> dict:
        """Lista slots de agenda de um profissional."""
        try:
            query = supabase_admin.table(self.TABLE).select("*, profissional(nome, especialidade), paciente(nome)").eq("id_profissional", prof_id)
            if apenas_futuros:
                query = query.gte("data_hora", datetime.utcnow().isoformat())
            resp = query.order("data_hora").execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def listar_por_paciente(self, paciente_id: str) -> dict:
        """Lista agenda de um paciente."""
        try:
            resp = supabase_admin.table(self.TABLE).select("*, profissional(nome, especialidade)").eq("id_paciente", paciente_id).order("data_hora").execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar_slot(self, id_profissional: str, data_hora: str, duracao_min: int = 50,
                   id_paciente: Optional[str] = None) -> dict:
        """Cria um novo slot de agenda."""
        try:
            dados = {
                "id_profissional": id_profissional,
                "data_hora": data_hora,
                "duracao_min": duracao_min,
                "status": "Agendado",
            }
            if id_paciente:
                dados["id_paciente"] = id_paciente
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def cancelar(self, agenda_id: str) -> dict:
        """Cancela um slot de agenda."""
        try:
            resp = supabase_admin.table(self.TABLE).update({"status": "Cancelado"}).eq("id", agenda_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def concluir(self, agenda_id: str) -> dict:
        """Marca um slot como concluído."""
        try:
            resp = supabase_admin.table(self.TABLE).update({"status": "Concluído"}).eq("id", agenda_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}


class ConsultaService:
    """Operações na tabela consulta."""

    TABLE = "consulta"

    def listar_por_paciente(self, paciente_id: str) -> dict:
        """Lista consultas de um paciente com dados relacionados."""
        try:
            resp = supabase_admin.table(self.TABLE).select(
                "*, paciente(nome), profissional(nome, especialidade), local(nome)"
            ).eq("id_paciente", paciente_id).order("data_hora", desc=True).execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def listar_por_profissional(self, prof_id: str, status: Optional[str] = None) -> dict:
        """Lista consultas de um profissional, opcionalmente filtradas por status."""
        try:
            query = supabase_admin.table(self.TABLE).select(
                "*, paciente(nome, telefone, email), local(nome)"
            ).eq("id_profissional", prof_id)
            if status:
                query = query.eq("status", status)
            resp = query.order("data_hora", desc=True).execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar(self, id_paciente: str, id_profissional: str, data_hora: str,
              tipo: Optional[str] = None, id_local: Optional[str] = None,
              id_agenda: Optional[str] = None) -> dict:
        """Cria um registro de consulta."""
        try:
            dados = {
                "id_paciente": id_paciente,
                "id_profissional": id_profissional,
                "data_hora": data_hora,
                "status": "Agendada",
                "tipo": tipo,
                "id_local": id_local,
                "id_agenda": id_agenda,
            }
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def atualizar_status(self, consulta_id: str, status: str) -> dict:
        """Atualiza o status de uma consulta (Agendada | Realizada | Cancelada)."""
        try:
            resp = supabase_admin.table(self.TABLE).update({"status": status}).eq("id", consulta_id).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}


class AvaliacaoService:
    """Operações na tabela avaliacao — avaliações clínicas."""

    TABLE = "avaliacao"

    def listar_por_paciente(self, paciente_id: str) -> dict:
        """Lista avaliações de um paciente (mais recentes primeiro)."""
        try:
            resp = supabase_admin.table(self.TABLE).select(
                "*, profissional(nome)"
            ).eq("id_paciente", paciente_id).order("data_hora", desc=True).execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def criar(self, id_paciente: str, id_profissional: str,
              nivel_dor: Optional[int] = None,
              pressao_sistolica: Optional[int] = None,
              pressao_diastolica: Optional[int] = None,
              frequencia_cardiaca: Optional[int] = None,
              mobilidade: Optional[str] = None,
              classificacao: Optional[str] = None,
              observacoes: Optional[str] = None,
              id_consulta: Optional[str] = None) -> dict:
        """Registra uma nova avaliação clínica."""
        try:
            dados = {
                "id_paciente": id_paciente,
                "id_profissional": id_profissional,
                "data_hora": datetime.utcnow().isoformat(),
                "nivel_dor": nivel_dor,
                "pressao_sistolica": pressao_sistolica,
                "pressao_diastolica": pressao_diastolica,
                "frequencia_cardiaca": frequencia_cardiaca,
                "mobilidade": mobilidade,
                "classificacao": classificacao,
                "observacoes": observacoes,
                "id_consulta": id_consulta,
            }
            resp = supabase_admin.table(self.TABLE).insert(dados).execute()
            return {"success": True, "data": resp.data[0] if resp.data else None}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def evolucao_dor(self, paciente_id: str) -> dict:
        """Retorna evolução do nível de dor do paciente ao longo do tempo."""
        try:
            resp = supabase_admin.table(self.TABLE).select(
                "data_hora, nivel_dor, classificacao"
            ).eq("id_paciente", paciente_id).not_.is_("nivel_dor", "null").order("data_hora").execute()
            return {"success": True, "data": resp.data}
        except Exception as e:
            return {"success": False, "error": str(e)}


# Instâncias singleton
agenda_service = AgendaService()
consulta_service = ConsultaService()
avaliacao_service = AvaliacaoService()
