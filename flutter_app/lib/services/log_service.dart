/// log_service.dart
/// Serviço centralizado de log de navegação e eventos do app +Físio +Saúde.
/// Registra na tabela `log_navegacao` do Supabase.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _sb => Supabase.instance.client;

class LogService {
  static final LogService instance = LogService._();
  LogService._();

  String? _usuarioId;

  /// Define o ID do usuário logado. Chamar após login bem-sucedido.
  void setUsuario(String? id) => _usuarioId = id;

  /// Registra navegação para uma tela.
  Future<void> logTela(String tela, {String? acao, Map<String, dynamic>? dados}) async {
    // Se não houver ID de usuário, não registra log (evita logs de sistema/pré-login)
    if (_usuarioId == null) return;

    try {
      await _sb.from('log_navegacao').insert({
        'id_usuario': _usuarioId,
        'tela': tela,
        if (acao != null) 'acao': acao,
        if (dados != null) 'dados_extras': dados,
      });
    } catch (_) {
      // Falha no log não deve bloquear o fluxo
    }
  }

  /// Registra uma ação genérica dentro de uma tela.
  Future<void> logAcao(String tela, String acao, {Map<String, dynamic>? dados}) =>
      logTela(tela, acao: acao, dados: dados);
}

/// NavigatorObserver que registra automaticamente cada troca de rota.
class AppRouteObserver extends NavigatorObserver {
  final LogService _log = LogService.instance;

  String _nomeRota(Route<dynamic>? route) {
    if (route == null) return 'desconhecida';
    return route.settings.name ?? route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.logTela(_nomeRota(route), acao: 'push',
        dados: previousRoute != null ? {'de': _nomeRota(previousRoute)} : null);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log.logTela(_nomeRota(previousRoute), acao: 'pop',
        dados: {'de': _nomeRota(route)});
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log.logTela(_nomeRota(newRoute), acao: 'replace',
        dados: oldRoute != null ? {'de': _nomeRota(oldRoute)} : null);
  }
}
