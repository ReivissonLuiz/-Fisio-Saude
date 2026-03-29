"""
services/__init__.py
Exportações dos serviços da integração Supabase — +Físio +Saúde
"""

from .auth_service import auth_service, AuthService
from .paciente_service import paciente_service, PacienteService
from .profissional_service import profissional_service, ProfissionalService
from .consulta_service import (
    agenda_service, AgendaService,
    consulta_service, ConsultaService,
    avaliacao_service, AvaliacaoService,
)
from .exercicio_service import exercicio_service, ExercicioService

__all__ = [
    "auth_service", "AuthService",
    "paciente_service", "PacienteService",
    "profissional_service", "ProfissionalService",
    "agenda_service", "AgendaService",
    "consulta_service", "ConsultaService",
    "avaliacao_service", "AvaliacaoService",
    "exercicio_service", "ExercicioService",
]
