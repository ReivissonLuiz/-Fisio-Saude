/// notificacoes_panel.dart
/// Painel lateral de notificações in-app — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class NotificacoesPanel extends StatefulWidget {
  final String usuarioId;
  final VoidCallback? onNavigateToAgenda;
  const NotificacoesPanel({super.key, required this.usuarioId, this.onNavigateToAgenda});

  @override
  State<NotificacoesPanel> createState() => _NotificacoesPanelState();
}

class _NotificacoesPanelState extends State<NotificacoesPanel> {
  final _api = ApiService();
  List<dynamic> _notificacoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final res = await _api.getNotificacoes(widget.usuarioId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) _notificacoes = res['data'] as List? ?? [];
    });
  }

  Future<void> _marcarTodasLidas() async {
    await _api.marcarTodasNotificacoesLidas(widget.usuarioId);
    await _carregar();
  }

  IconData _iconePorTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return Icons.calendar_month_rounded;
      case 'cancelamento': return Icons.event_busy_rounded;
      case 'reagendamento': return Icons.edit_calendar_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _corPorTipo(String tipo) {
    switch (tipo) {
      case 'agendamento': return AppTheme.accent;
      case 'cancelamento': return AppTheme.error;
      case 'reagendamento': return AppTheme.warning;
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Notificações',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  if (_notificacoes.any((n) => n['lida'] == false))
                    TextButton(
                      onPressed: _marcarTodasLidas,
                      child: const Text('Marcar todas', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _notificacoes.isEmpty
                      ? const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.textHint),
                            SizedBox(height: 12),
                            Text('Nenhuma notificação', style: TextStyle(color: AppTheme.textSecondary)),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _carregar,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _notificacoes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final n = _notificacoes[i] as Map<String, dynamic>;
                              final tipo = n['tipo'] as String? ?? 'info';
                              final lida = n['lida'] as bool? ?? false;
                              final cor = _corPorTipo(tipo);
                              final dt = DateTime.tryParse(n['created_at'] as String? ?? '');
                              final dtStr = dt != null
                                  ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                  : '';

                              return GestureDetector(
                                onTap: () async {
                                  if (!lida) {
                                    await _api.marcarNotificacaoLida(n['id'] as String);
                                    await _carregar();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: lida ? Colors.white : cor.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: lida ? AppTheme.divider : cor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: cor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(_iconePorTipo(tipo), color: cor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(n['titulo'] as String? ?? '',
                                                      style: TextStyle(
                                                          fontWeight: lida ? FontWeight.w500 : FontWeight.bold,
                                                          fontSize: 13)),
                                                ),
                                                if (!lida)
                                                  Container(
                                                    width: 8, height: 8,
                                                    decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(n['corpo'] as String? ?? '',
                                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
                                            const SizedBox(height: 4),
                                            Text(dtStr, style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
                                            if (tipo == 'reagendamento' && widget.onNavigateToAgenda != null) ...[
                                              const SizedBox(height: 8),
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  widget.onNavigateToAgenda!();
                                                },
                                                icon: Icon(Icons.calendar_month_rounded, size: 12, color: cor),
                                                label: Text('Acessar Agenda', style: TextStyle(fontSize: 11, color: cor)),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(color: cor.withValues(alpha: 0.5)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                                  minimumSize: const Size(0, 26),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de notificações não lidas.
class NotificacaoBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const NotificacaoBadge({super.key, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4, top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(color: AppTheme.error, borderRadius: BorderRadius.circular(9)),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
