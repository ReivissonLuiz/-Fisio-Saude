/// log_service.dart
/// Serviço de log de navegação do +Físio +Saúde.
/// Registra na tabela `log_navegacao` e repassa eventos ao `AuditService`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'audit_service.dart';

SupabaseClient get _sb => Supabase.instance.client;

// ── Mapa de nomes legíveis por rota/tipo ────────────────────────────────────
const _rotaNomes = <String, String>{
  '/': 'Tela de Login',
  '/home': 'Tela Principal',
  '/register': 'Cadastro',
  '/register/paciente': 'Cadastro de Paciente',
  '/register/profissional': 'Cadastro de Profissional',
  '/forgot-password': 'Recuperação de Senha',
  'LoginScreen': 'Tela de Login',
  'HomeScreen': 'Tela Principal',
  'SplashScreen': 'Tela de Carregamento',
  'AgendaTab': 'Agenda',
  'ProfissionalHomeTab': 'Início (Profissional)',
  'PacienteHomeTab': 'Início (Paciente)',
  'MinhaSaudeTab': 'Minha Saúde',
  'BuscarFisioTab': 'Buscar Fisioterapeuta',
  'MeuPerfilTab': 'Meu Perfil',
  'PerfilProfissionalTab': 'Perfil (Profissional)',
  'MeusPacientesTab': 'Meus Pacientes',
  'MinhaDisponibilidadeTab': 'Minha Disponibilidade',
  'AdminDashboardTab': 'Dashboard Admin',
  'AdminManagementTab': 'Gestão de Usuários',
  'AdminPerfilTab': 'Perfil Admin',
  'AdminAuditTab': 'Auditoria',
  'AgendarConsultaScreen': 'Agendamento de Consulta',
  'ReagendarScreen': 'Reagendamento de Consulta',
  '_DetalhesModal': 'Detalhes da Consulta',
  '_RecomendacaoMLModal': 'Recomendação de Exercícios',
  'NotificacoesPanel': 'Painel de Notificações',
};

class LogService {
  static final LogService instance = LogService._();
  LogService._();

  String? _usuarioId;

  /// Define o ID do usuário logado. Chamar após login bem-sucedido.
  void setUsuario(String? id) {
    _usuarioId = id;
    AuditService.instance.setUsuario(id);
  }

  String _nomeLegivel(String rota) =>
      _rotaNomes[rota] ?? rota;

  /// Registra navegação para uma tela na tabela `log_navegacao`.
  Future<void> logTela(String tela, {String? acao, Map<String, dynamic>? dados}) async {
    if (_usuarioId == null) return;

    final nomeLegivel = _nomeLegivel(tela);
    try {
      await _sb.from('log_navegacao').insert({
        'id_usuario': _usuarioId,
        'tela': nomeLegivel,
        if (acao != null) 'acao': acao,
        if (dados != null) 'dados_extras': dados,
      });
    } catch (_) {}

    // Repassa para auditoria apenas "push" (entrada na tela) para não poluir
    if (acao == 'push' || acao == null) {
      await AuditService.instance.logNavegacaoTela(nomeLegivel, acao: acao);
    }
  }

  /// Registra uma ação genérica dentro de uma tela.
  Future<void> logAcao(String tela, String acao, {Map<String, dynamic>? dados}) =>
      logTela(tela, acao: acao, dados: dados);
}

/// NavigatorObserver que registra automaticamente cada troca de rota nomeada.
class AppRouteObserver extends NavigatorObserver {
  final LogService _log = LogService.instance;

  String _nomeRota(Route<dynamic>? route) {
    if (route == null) return 'desconhecida';
    // Prefere o nome da rota, se definido; senão usa o tipo da classe
    final nome = route.settings.name ?? route.runtimeType.toString();
    // Remove prefixos internos do Flutter (ex: "_MaterialPageRoute<...>")
    return nome.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.logTela(_nomeRota(route), acao: 'push',
        dados: previousRoute != null ? {'de': _nomeRota(previousRoute)} : null);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _log.logTela(_nomeRota(previousRoute), acao: 'pop',
          dados: {'de': _nomeRota(route)});
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log.logTela(_nomeRota(newRoute), acao: 'replace',
        dados: oldRoute != null ? {'de': _nomeRota(oldRoute)} : null);
  }
}
