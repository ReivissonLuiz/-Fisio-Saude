/// Detalhes de uma consulta (visão paciente) — aberto via notificação ou navegação.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';
import 'reagendar_screen.dart';

class ConsultaDetalhesScreen extends StatefulWidget {
  final String consultaId;
  final String pacienteId;
  final String pacienteNome;
  final String? pacienteAvatar;

  const ConsultaDetalhesScreen({
    super.key,
    required this.consultaId,
    required this.pacienteId,
    required this.pacienteNome,
    this.pacienteAvatar,
  });

  @override
  State<ConsultaDetalhesScreen> createState() => _ConsultaDetalhesScreenState();
}

class _ConsultaDetalhesScreenState extends State<ConsultaDetalhesScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _consulta;
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    final res = await _api.getConsultaPorId(widget.consultaId);
    if (!mounted) return;
    if (res['success'] == true && res['data'] != null) {
      setState(() {
        _consulta = res['data'] as Map<String, dynamic>;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _erro = res['message'] as String? ?? 'Consulta não encontrada.';
      });
    }
  }

  String _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'agendada':
        return 'Agendada';
      case 'confirmada':
        return 'Confirmada';
      case 'finalizada':
      case 'realizada':
        return 'Finalizada';
      case 'cancelada':
        return 'Cancelada';
      case 'nao_compareceu':
        return 'Não compareceu';
      default:
        return status ?? '—';
    }
  }

  Future<void> _confirmar() async {
    final c = _consulta!;
    final res = await _api.confirmarConsulta(
      consultaId: c['id'] as String,
      pacienteId: widget.pacienteId,
      profissionalId: c['id_profissional'] as String,
      iniciadoPorProfissional: false,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presença confirmada!')),
      );
      _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao confirmar.')),
      );
    }
  }

  Future<void> _cancelar() async {
    final c = _consulta!;
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancelar Consulta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tem certeza que deseja cancelar esta consulta?'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Cancelar Consulta'),
            ),
          ],
        );
      },
    );
    if (motivo == null || !mounted) return;
    final res = await _api.cancelarConsulta(
      consultaId: c['id'] as String,
      pacienteId: widget.pacienteId,
      profissionalId: c['id_profissional'] as String,
      motivo: motivo.isEmpty ? null : motivo,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta cancelada.')),
      );
      _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao cancelar.')),
      );
    }
  }

  Future<void> _reagendar() async {
    final c = _consulta!;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReagendarScreen(
          consultaId: c['id'] as String,
          pacienteId: widget.pacienteId,
          profissionalId: c['id_profissional'] as String,
          api: _api,
          iniciadoPorProfissional: false,
        ),
      ),
    );
    if (result == true && mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detalhes da Consulta'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(_erro!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _carregar,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildConteudo(),
    );
  }

  Widget _buildConteudo() {
    final c = _consulta!;
    final profissional = c['profissional'] as Map<String, dynamic>?;
    final profId = c['id_profissional'] as String? ?? '';
    final profNome = profissional?['nome'] as String? ?? 'Profissional';
    final status = (c['status'] as String?)?.toLowerCase() ?? '';
    final dt = DateTime.tryParse(c['data_hora'] as String? ?? '');
    final dtFormatada = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : (c['data_hora'] as String? ?? '—');
    final relatorio = c['relatorio'] as String?;
    final observacoes = c['observacoes'] as String?;
    final ativa = status == 'agendada' || status == 'confirmada';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profNome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (profissional?['especialidade'] != null)
                  Text(
                    profissional!['especialidade'] as String,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                const SizedBox(height: 12),
                _linha(Icons.calendar_month_rounded, dtFormatada),
                const SizedBox(height: 8),
                _linha(Icons.info_outline_rounded, _statusLabel(status)),
                if (observacoes != null && observacoes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _linha(Icons.notes_rounded, observacoes),
                ],
              ],
            ),
          ),
          if (relatorio != null && relatorio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relatório do profissional',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(relatorio, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (c['link_meet'] != null && (c['link_meet'] as String).isNotEmpty && ativa)
            ElevatedButton.icon(
              icon: const Icon(Icons.video_camera_front_rounded),
              label: const Text('Entrar na Videochamada'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => launchUrl(
                Uri.parse(c['link_meet'] as String),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (ativa && dt != null &&
              status == 'agendada' &&
              DateTime.now().isAfter(dt.subtract(const Duration(hours: 24))) &&
              DateTime.now().isBefore(dt)) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Confirmar presença'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _confirmar,
            ),
          ],
          if (ativa) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Chat'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            meuId: widget.pacienteId,
                            meuNome: widget.pacienteNome,
                            meuAvatar: widget.pacienteAvatar,
                            outroId: profId,
                            outroNome: profNome,
                            outroAvatar: profissional?['avatar_url'] as String?,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Reagendar'),
                    onPressed: _reagendar,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: const Text('Cancelar consulta'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
              onPressed: _cancelar,
            ),
          ] else if (status == 'cancelada' || status == 'nao_compareceu') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agendar nova consulta'),
              onPressed: () => Navigator.pop(context, 'agendar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linha(IconData icon, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
