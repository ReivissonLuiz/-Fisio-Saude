"""
services/auth_service.py
Serviço de autenticação via Supabase Auth — +Físio +Saúde
Responsável por: login, registro, logout, recuperação de senha e vínculo com tabela `login`.
"""

from typing import Optional
from supabase_client import supabase, supabase_admin
from models import Login, TipoUsuarioEnum


class AuthService:
    """Serviço de autenticação e gerenciamento de usuários no Supabase."""

    # ── Login ──────────────────────────────────────────────────────────────────

    def login(self, email: str, senha: str) -> dict:
        """
        Autentica o usuário via Supabase Auth.
        Retorna o token de sessão e dados do usuário.
        """
        try:
            response = supabase.auth.sign_in_with_password({
                "email": email,
                "password": senha
            })
            session = response.session
            user = response.user

            # Buscar dados adicionais na tabela login
            login_data = self._buscar_login_por_email(email)

            return {
                "success": True,
                "token": session.access_token if session else None,
                "refresh_token": session.refresh_token if session else None,
                "user": {
                    "id": str(user.id),
                    "email": user.email,
                    "tipo": login_data.get("tipo_usuario") if login_data else None,
                },
                "login_data": login_data,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Registro ───────────────────────────────────────────────────────────────

    def registrar_paciente(self, nome: str, email: str, cpf: str, senha: str,
                           telefone: Optional[str] = None,
                           data_nasc: Optional[str] = None,
                           genero: Optional[str] = None) -> dict:
        """
        Registra um novo paciente:
        1. Cria conta no Supabase Auth
        2. Insere registro na tabela `paciente`
        3. Cria vínculo na tabela `login`
        """
        try:
            # 1. Criar conta no Auth
            auth_resp = supabase_admin.auth.admin.create_user({
                "email": email,
                "password": senha,
                "email_confirm": True,
            })
            user_id = str(auth_resp.user.id)

            # 2. Inserir na tabela paciente
            paciente_data = {
                "nome": nome,
                "cpf": cpf,
                "email": email,
                "telefone": telefone,
                "data_nasc": data_nasc,
                "genero": genero,
                "ativo": True,
            }
            pac_resp = supabase_admin.table("paciente").insert(paciente_data).execute()
            paciente_id = pac_resp.data[0]["id"] if pac_resp.data else None

            # 3. Criar vínculo na tabela login
            login_data = {
                "supabase_user_id": user_id,
                "email": email,
                "tipo_usuario": TipoUsuarioEnum.PACIENTE.value,
                "id_paciente": paciente_id,
            }
            supabase_admin.table("login").insert(login_data).execute()

            return {
                "success": True,
                "message": "Paciente cadastrado com sucesso!",
                "paciente_id": paciente_id,
                "user_id": user_id,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def registrar_profissional(self, nome: str, email: str, cpf: str, senha: str,
                               crefito: str, especialidade: str,
                               telefone: Optional[str] = None) -> dict:
        """
        Registra um novo profissional de saúde:
        1. Cria conta no Supabase Auth
        2. Insere registro na tabela `profissional` (status pendente via RLS)
        3. Cria vínculo na tabela `login`
        """
        try:
            # 1. Criar conta no Auth
            auth_resp = supabase_admin.auth.admin.create_user({
                "email": email,
                "password": senha,
                "email_confirm": False,  # Aguarda confirmação/aprovação
            })
            user_id = str(auth_resp.user.id)

            # 2. Inserir na tabela profissional
            prof_data = {
                "nome": nome,
                "cpf": cpf,
                "email": email,
                "crefito": crefito,
                "especialidade": especialidade,
                "telefone": telefone,
                "ativo": False,  # Aguarda aprovação do administrador
            }
            prof_resp = supabase_admin.table("profissional").insert(prof_data).execute()
            profissional_id = prof_resp.data[0]["id"] if prof_resp.data else None

            # 3. Criar vínculo na tabela login
            login_data = {
                "supabase_user_id": user_id,
                "email": email,
                "tipo_usuario": TipoUsuarioEnum.PROFISSIONAL.value,
                "id_profissional": profissional_id,
            }
            supabase_admin.table("login").insert(login_data).execute()

            return {
                "success": True,
                "message": "Profissional cadastrado! Aguardando aprovação do administrador.",
                "profissional_id": profissional_id,
                "user_id": user_id,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Logout ─────────────────────────────────────────────────────────────────

    def logout(self) -> dict:
        """Encerra a sessão do usuário atual."""
        try:
            supabase.auth.sign_out()
            return {"success": True, "message": "Logout realizado com sucesso."}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Recuperação de Senha ───────────────────────────────────────────────────

    def solicitar_recuperacao_senha(self, email: str) -> dict:
        """Envia e-mail de recuperação de senha via Supabase."""
        try:
            supabase.auth.reset_password_email(email)
            return {
                "success": True,
                "message": "Se este e-mail estiver cadastrado, você receberá o link em breve.",
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def atualizar_senha(self, nova_senha: str) -> dict:
        """Atualiza a senha do usuário autenticado."""
        try:
            supabase.auth.update_user({"password": nova_senha})
            return {"success": True, "message": "Senha atualizada com sucesso!"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    # ── Helpers ────────────────────────────────────────────────────────────────

    def _buscar_login_por_email(self, email: str) -> Optional[dict]:
        """Busca os dados de vínculo na tabela login pelo e-mail."""
        try:
            resp = supabase_admin.table("login").select("*").eq("email", email).single().execute()
            return resp.data
        except Exception:
            return None

    def get_sessao_atual(self) -> Optional[dict]:
        """Retorna a sessão atual do usuário."""
        try:
            session = supabase.auth.get_session()
            if session:
                return {
                    "token": session.access_token,
                    "user_id": str(session.user.id),
                    "email": session.user.email,
                }
            return None
        except Exception:
            return None


# Instância singleton do serviço
auth_service = AuthService()
