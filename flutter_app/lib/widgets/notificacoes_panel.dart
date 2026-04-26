/// notificacoes_panel.dart
/// Painel de notificações in-app — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificacoesPanel extends StatefulWidget {
  final String usuarioId;
  const NotificacoesPanel({super.key, required this.usuarioId});

  @override
  State<NotificacoesPanel> createState() => _NotificacoesPanelState();
}

class _NotificacoesPanelState extends State<NotificacoesPanel> {
  final _notif = NotificationService();
  List<dynamic> _notificacoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final res = await _notif.getNotificacoes(widget.usuarioId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _notificacoes = res['data'] as List? ?? [];
      }
    });
  }

  Future<void> _marcarTodasLidas() async {
    await _notif.marcarTodasComoLidas(widget.usuarioId);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notificações',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notificacoes.any((n) => n['lida'] == false))
            TextButton(
              onPressed: _marcarTodasLidas,
              child: const Text('Marcar todas como lidas',
                  style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notificacoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_rounded,
                          size: 54,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Nenhuma notificação.',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notificacoes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _notificacoes[i];
                      final lida = n['lida'] == true;
                      final titulo = n['titulo'] as String? ?? '';
                      final mensagem = n['mensagem'] as String? ?? '';
                      final createdAt = n['created_at'] as String?;
                      final dt = createdAt != null
                          ? DateTime.tryParse(createdAt)
                          : null;
                      final dtFmt = dt != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal())
                          : '';

                      return GestureDetector(
                        onTap: () async {
                          if (!lida) {
                            await _notif.marcarComoLida(n['id'] as String);
                            _carregar();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: lida
                                ? Colors.white
                                : AppTheme.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: lida
                                  ? AppTheme.divider
                                  : AppTheme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lida
                                      ? AppTheme.background
                                      : AppTheme.primary
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.notifications_rounded,
                                  size: 20,
                                  color: lida
                                      ? AppTheme.textHint
                                      : AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(titulo,
                                        style: TextStyle(
                                            fontWeight: lida
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text(mensagem,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text(dtFmt,
                                        style: const TextStyle(
                                            color: AppTheme.textHint,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                              if (!lida)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
