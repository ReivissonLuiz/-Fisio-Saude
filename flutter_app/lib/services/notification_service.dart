/// notification_service.dart
/// Serviço de notificações in-app e por e-mail — +Físio +Saúde
library;

import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _sb => Supabase.instance.client;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Cria uma notificação in-app para o profissional.
  Future<Map<String, dynamic>> criarNotificacao({
    required String destinatarioId,
    required String titulo,
    required String mensagem,
    String tipo = 'agendamento',
  }) async {
    try {
      final data = await _sb.from('notificacao').insert({
        'id_destinatario': destinatarioId,
        'titulo': titulo,
        'mensagem': mensagem,
        'tipo': tipo,
        'lida': false,
      }).select().single();
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao criar notificação.'};
    }
  }

  /// Busca notificações de um usuário (mais recentes primeiro).
  Future<Map<String, dynamic>> getNotificacoes(String usuarioId) async {
    try {
      final data = await _sb
          .from('notificacao')
          .select()
          .eq('id_destinatario', usuarioId)
          .order('created_at', ascending: false)
          .limit(50);
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao buscar notificações.'};
    }
  }

  /// Conta notificações não lidas.
  Future<int> contarNaoLidas(String usuarioId) async {
    try {
      final data = await _sb
          .from('notificacao')
          .select('id')
          .eq('id_destinatario', usuarioId)
          .eq('lida', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Marca uma notificação como lida.
  Future<void> marcarComoLida(String notificacaoId) async {
    try {
      await _sb
          .from('notificacao')
          .update({'lida': true})
          .eq('id', notificacaoId);
    } catch (_) {}
  }

  /// Marca todas as notificações de um usuário como lidas.
  Future<void> marcarTodasComoLidas(String usuarioId) async {
    try {
      await _sb
          .from('notificacao')
          .update({'lida': true})
          .eq('id_destinatario', usuarioId)
          .eq('lida', false);
    } catch (_) {}
  }

  /// Envia notificação por e-mail via Edge Function do Supabase.
  Future<void> enviarEmailNotificacao({
    required String emailDestino,
    required String assunto,
    required String corpo,
  }) async {
    try {
      await _sb.functions.invoke(
        'send-email-notification',
        body: {
          'to': emailDestino,
          'subject': assunto,
          'html': corpo,
        },
      );
    } catch (_) {
      // Falha no envio de e-mail não bloqueia o fluxo
    }
  }
}
