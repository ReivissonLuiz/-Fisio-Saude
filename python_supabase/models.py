"""
models.py
Modelos de dados (dataclasses) espelhando as tabelas do Supabase — +Físio +Saúde
"""

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Optional
from enum import Enum


# ─── Enumerações ────────────────────────────────────────────────────────────────

class GeneroEnum(str, Enum):
    MASCULINO = "Masculino"
    FEMININO = "Feminino"
    NAO_BINARIO = "Não-binário"
    NAO_INFORMAR = "Prefiro não informar"
    OUTRO = "Outro"


class TipoUsuarioEnum(str, Enum):
    PACIENTE = "Paciente"
    PROFISSIONAL = "Profissional"
    ADMINISTRADOR = "Administrador"


class StatusConsultaEnum(str, Enum):
    AGENDADA = "Agendada"
    REALIZADA = "Realizada"
    CANCELADA = "Cancelada"


class StatusAgendaEnum(str, Enum):
    AGENDADO = "Agendado"
    CANCELADO = "Cancelado"
    CONCLUIDO = "Concluído"


# ─── Modelos de Dados ────────────────────────────────────────────────────────────

@dataclass
class Administrador:
    """Tabela: administrador — Usuários administrativos do sistema."""
    nome: str
    cpf: str
    email: str
    senha_hash: str
    id: Optional[str] = None
    telefone: Optional[str] = None
    ativo: bool = True
    criado_em: Optional[datetime] = None
    atualizado_em: Optional[datetime] = None


@dataclass
class Paciente:
    """Tabela: paciente — Cadastro de pacientes da clínica."""
    nome: str
    cpf: str
    email: str
    id: Optional[str] = None
    rg: Optional[str] = None
    data_nasc: Optional[date] = None
    genero: Optional[GeneroEnum] = None
    telefone: Optional[str] = None
    ativo: bool = True
    criado_em: Optional[datetime] = None
    atualizado_em: Optional[datetime] = None


@dataclass
class Profissional:
    """Tabela: profissional — Fisioterapeutas e profissionais de saúde."""
    nome: str
    cpf: str
    email: str
    crefito: str
    especialidade: str
    id: Optional[str] = None
    rg: Optional[str] = None
    telefone: Optional[str] = None
    ativo: bool = True
    criado_em: Optional[datetime] = None
    atualizado_em: Optional[datetime] = None


@dataclass
class Local:
    """Tabela: local — Salas e unidades de atendimento."""
    nome: str
    id: Optional[str] = None
    rua: Optional[str] = None
    numero: Optional[str] = None
    cep: Optional[str] = None
    cidade: Optional[str] = None
    estado: Optional[str] = None
    referencia: Optional[str] = None
    ativo: bool = True


@dataclass
class Agenda:
    """Tabela: agenda — Slots de atendimento dos profissionais."""
    id_profissional: str
    data_hora: datetime
    id: Optional[str] = None
    id_paciente: Optional[str] = None
    duracao_min: int = 50
    status: StatusAgendaEnum = StatusAgendaEnum.AGENDADO


@dataclass
class Consulta:
    """Tabela: consulta — Consultas/sessões programadas."""
    id_paciente: str
    id_profissional: str
    data_hora: datetime
    id: Optional[str] = None
    id_local: Optional[str] = None
    id_agenda: Optional[str] = None
    tipo: Optional[str] = None
    status: StatusConsultaEnum = StatusConsultaEnum.AGENDADA
    criado_em: Optional[datetime] = None
    atualizado_em: Optional[datetime] = None


@dataclass
class Avaliacao:
    """Tabela: avaliacao — Avaliações clínicas e sinais vitais."""
    id_paciente: str
    id_profissional: str
    data_hora: datetime
    id: Optional[str] = None
    id_consulta: Optional[str] = None
    nivel_dor: Optional[int] = None          # 0-10
    pressao_sistolica: Optional[int] = None
    pressao_diastolica: Optional[int] = None
    frequencia_cardiaca: Optional[int] = None
    mobilidade: Optional[str] = None
    classificacao: Optional[str] = None
    observacoes: Optional[str] = None


@dataclass
class Exercicio:
    """Tabela: exercicio — Biblioteca de exercícios."""
    id_profissional: str
    titulo: str
    id: Optional[str] = None
    descricao: Optional[str] = None
    tipo: Optional[str] = None
    video_url: Optional[str] = None
    ativo: bool = True


@dataclass
class Login:
    """Tabela: login — Vínculo entre Supabase Auth e entidades locais."""
    supabase_user_id: str
    email: str
    tipo_usuario: TipoUsuarioEnum
    id: Optional[str] = None
    id_paciente: Optional[str] = None
    id_profissional: Optional[str] = None
    id_administrador: Optional[str] = None


@dataclass
class RegistroSintomas:
    """Tabela: registro_sintomas — Relatos de sintomas do paciente."""
    id_paciente: str
    data_hora: datetime
    id: Optional[str] = None
    descricao: Optional[str] = None
    nivel_dor: Optional[int] = None
    regiao: Optional[str] = None


@dataclass
class Relatorio:
    """Tabela: relatorio — Prontuários e documentos clínicos."""
    id_paciente: str
    id_profissional: str
    data_hora: datetime
    id: Optional[str] = None
    tipo: Optional[str] = None
    conteudo: Optional[str] = None
    url_arquivo: Optional[str] = None


@dataclass
class LgpdConsentimento:
    """Tabela: lgpd_consentimento — Termos de aceite de dados (LGPD)."""
    id_paciente: str
    aceito: bool
    id: Optional[str] = None
    ip_origem: Optional[str] = None
    data_aceite: Optional[datetime] = None
    versao_termo: Optional[str] = None


@dataclass
class LogAuditoria:
    """Tabela: logs_auditoria — Auditoria imutável de ações do sistema."""
    acao: str
    id: Optional[str] = None
    tabela: Optional[str] = None
    registro_id: Optional[str] = None
    usuario_id: Optional[str] = None
    dados_antes: Optional[dict] = None
    dados_depois: Optional[dict] = None
    criado_em: Optional[datetime] = None
