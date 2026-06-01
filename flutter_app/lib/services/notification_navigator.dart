/// Navegação ao tocar em notificações in-app.
library;

import 'package:flutter/material.dart';
import '../screens/shared/chat_screen.dart';
import '../screens/shared/consulta_detalhes_screen.dart';
import '../screens/paciente/minha_saude_tab.dart';
class NotificationNavigator {
  /// Texto exibido no painel (compatível com registros legados).
  static String corpoExibicao(Map<String, dynamic> n) {
    var body = n['mensagem'] as String? ?? n['corpo'] as String? ?? '';
    if ((n['tipo'] as String? ?? '') == 'chat' && body.contains('|||')) {
      return body.split('|||').first;
    }
    return body;
  }

  /// ID de destino: acao_id, id_consulta ou fallback chat (|||).
  static String? resolverAcaoId(Map<String, dynamic> n) {
    final direto = n['acao_id'] as String? ?? n['id_consulta'] as String?;
    if (direto != null && direto.isNotEmpty) return direto;

    if ((n['tipo'] as String? ?? '') == 'chat') {
      final body = n['mensagem'] as String? ?? n['corpo'] as String? ?? '';
      if (body.contains('|||')) {
        final parts = body.split('|||');
        if (parts.length > 1 && parts[1].isNotEmpty) return parts[1];
      }
    }
    return null;
  }

  static Future<void> handleTap({
    required BuildContext context,
    required Map<String, dynamic> notificacao,
    required String usuarioId,
    required String usuarioNome,
    String? usuarioAvatar,
    required bool isProfissional,
    VoidCallback? onNavigateToSaudeTab,
    void Function(String consultaId)? onOpenConsultaProfissional,
    VoidCallback? onAgendarNovaConsulta,
  }) async {
    final navigator = Navigator.of(context);
    final tipo = notificacao['tipo'] as String? ?? 'info';
    final acaoId = resolverAcaoId(notificacao);

    switch (tipo) {
      case 'chat':
        if (acaoId == null) {
          _snack(context, 'Não foi possível abrir o chat.');
          return;
        }
        final outroNome = (notificacao['titulo'] as String? ?? '')
            .replaceFirst('Nova mensagem de ', '');
        navigator.pop();
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              meuId: usuarioId,
              meuNome: usuarioNome,
              meuAvatar: usuarioAvatar,
              outroId: acaoId,
              outroNome: outroNome.isNotEmpty ? outroNome : 'Contato',
            ),
          ),
        );
        return;

      case 'recomendacao':
        navigator.pop();
        if (onNavigateToSaudeTab != null) {
          onNavigateToSaudeTab();
        } else if (!isProfissional) {
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => MinhaSaudeTab(
                pacienteId: usuarioId,
                initialSubTabIndex: 1,
              ),
            ),
          );
        } else {
          _snack(context, 'Acesse a aba Minha Saúde para ver os exercícios.');
        }
        return;

      case 'agendamento':
      case 'cancelamento':
      case 'reagendamento':
      case 'info':
        if (acaoId == null) {
          if (tipo == 'cancelamento' && onAgendarNovaConsulta != null) {
            navigator.pop();
            onAgendarNovaConsulta();
          } else {
            _snack(context, 'Detalhes da consulta indisponíveis.');
          }
          return;
        }
        if (isProfissional) {
          navigator.pop();
          onOpenConsultaProfissional?.call(acaoId);
          return;
        }
        navigator.pop();
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => ConsultaDetalhesScreen(
              consultaId: acaoId,
              pacienteId: usuarioId,
              pacienteNome: usuarioNome,
              pacienteAvatar: usuarioAvatar,
            ),
          ),
        );
        return;

      default:
        if (acaoId != null) {
          if (isProfissional) {
            navigator.pop();
            onOpenConsultaProfissional?.call(acaoId);
          } else {
            navigator.pop();
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => ConsultaDetalhesScreen(
                  consultaId: acaoId,
                  pacienteId: usuarioId,
                  pacienteNome: usuarioNome,
                  pacienteAvatar: usuarioAvatar,
                ),
              ),
            );
          }
        }
    }
  }

  static void _snack(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
