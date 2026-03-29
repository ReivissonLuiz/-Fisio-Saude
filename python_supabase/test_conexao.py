"""
test_conexao.py
Script de teste rápido para validar a integração com o Supabase — +Físio +Saúde
Execute: python test_conexao.py
"""

import sys
import os

# Adiciona o diretório pai ao path para importações relativas
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from supabase_client import SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY
from services import (
    auth_service,
    paciente_service,
    profissional_service,
    consulta_service,
    agenda_service,
    exercicio_service,
)

# Cores para output no terminal
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"

def ok(msg): print(f"  {GREEN}✅ {msg}{RESET}")
def fail(msg): print(f"  {RED}❌ {msg}{RESET}")
def info(msg): print(f"  {BLUE}ℹ  {msg}{RESET}")
def warn(msg): print(f"  {YELLOW}⚠  {msg}{RESET}")
def header(msg): print(f"\n{BOLD}{BLUE}{'─'*50}\n  {msg}\n{'─'*50}{RESET}")


def test_configuracao():
    header("1. Configuração")
    if SUPABASE_URL:
        ok(f"URL configurada: {SUPABASE_URL}")
    else:
        fail("SUPABASE_URL não configurada!")

    if SUPABASE_ANON_KEY:
        ok(f"Anon Key: {SUPABASE_ANON_KEY[:40]}...")
    else:
        fail("SUPABASE_ANON_KEY não configurada!")

    if SUPABASE_SERVICE_KEY:
        ok(f"Service Key: {SUPABASE_SERVICE_KEY[:40]}...")
    else:
        warn("SUPABASE_SERVICE_KEY não configurada (operações admin podem falhar).")


def test_listar_pacientes():
    header("2. Listagem de Pacientes")
    result = paciente_service.listar()
    if result["success"]:
        total = result["total"]
        ok(f"Conexão com tabela `paciente` OK — {total} registro(s) encontrado(s)")
        for p in result["data"][:3]:  # Mostra até 3
            info(f"  Paciente: {p.get('nome')} | {p.get('email')}")
    else:
        fail(f"Erro: {result['error']}")


def test_listar_profissionais():
    header("3. Listagem de Profissionais")
    result = profissional_service.listar(apenas_ativos=False)
    if result["success"]:
        total = result["total"]
        ok(f"Conexão com tabela `profissional` OK — {total} registro(s) encontrado(s)")
        for p in result["data"][:3]:
            info(f"  Profissional: {p.get('nome')} | CREFITO: {p.get('crefito')}")
    else:
        fail(f"Erro: {result['error']}")


def test_listar_exercicios():
    header("4. Biblioteca de Exercícios")
    result = exercicio_service.listar()
    if result["success"]:
        ok(f"Conexão com tabela `exercicio` OK — {result['total']} exercício(s)")
        for e in result["data"][:3]:
            info(f"  Exercício: {e.get('titulo')} | Tipo: {e.get('tipo')}")
    else:
        fail(f"Erro: {result['error']}")


def test_recuperar_senha():
    header("5. Recuperação de Senha (Auth)")
    # Teste com e-mail fictício — apenas valida que a chamada chega ao Supabase
    result = auth_service.solicitar_recuperacao_senha("teste_inexistente@fisio.com")
    if result["success"]:
        ok("Endpoint de recuperação de senha respondeu OK")
    else:
        warn(f"Recuperação de senha retornou: {result.get('error', 'sem detalhes')}")


def main():
    print(f"\n{BOLD}{'='*50}")
    print("   +Físio +Saúde — Teste de Integração Supabase")
    print(f"{'='*50}{RESET}")

    test_configuracao()
    test_listar_pacientes()
    test_listar_profissionais()
    test_listar_exercicios()
    test_recuperar_senha()

    print(f"\n{BOLD}{GREEN}{'='*50}")
    print("   Testes concluídos!")
    print(f"{'='*50}{RESET}\n")


if __name__ == "__main__":
    main()
