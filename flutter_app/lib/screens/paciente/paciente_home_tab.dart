/// paciente_home_tab.dart
/// Aba "Início" do dashboard do paciente — +Fisio +Saúde
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notificacoes_panel.dart';
import '../shared/reagendar_screen.dart';
import 'agendar_consulta_screen.dart';

class PacienteHomeTab extends StatefulWidget {
  final String pacienteId;
  final String nome;

  const PacienteHomeTab({
    super.key,
    required this.pacienteId,
    required this.nome,
  });

  @override
  State<PacienteHomeTab> createState() => _PacienteHomeTabState();
}

class _PacienteHomeTabState extends State<PacienteHomeTab> {
  final _api = ApiService();
  final _notif = NotificationService();

  List<dynamic> _sintomas = [];
  List<dynamic> _consultas = [];
  bool _loading = true;
  int _notifCount = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _api.getPaciente(widget.pacienteId),
      _api.getSintomas(widget.pacienteId),
      _api.getConsultas(widget.pacienteId),
    ]);
    final nCount = await _notif.contarNaoLidas(widget.pacienteId);

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (results[1]['success'] == true) {
        _sintomas = results[1]['data'] as List? ?? [];
      }
      if (results[2]['success'] == true) {
        _consultas = results[2]['data'] as List? ?? [];
      }
      _notifCount = nCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          // --- Header ------------------------------------------------------
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(
                          widget.nome.isNotEmpty
                              ? widget.nome[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, ${widget.nome.split(' ').first}!',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Text('Paciente',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      // Botão de notificações com badge
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_rounded,
                                color: Colors.white, size: 26),
                            tooltip: 'Notificações',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificacoesPanel(
                                    usuarioId: widget.pacienteId,
                                    // Ao clicar em "Agendar Nova Consulta" numa notificação
                                    // de cancelamento ou reagendamento, abre a tela de agendamento.
                                    onNavigateToAgenda: () {
                                      Navigator.pop(context); // Fecha o painel de notificações
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => AgendarConsultaScreen(pacienteId: widget.pacienteId)),
                                      ).then((_) => _carregarDados());
                                    },
                                  ),
                                ),
                              ).then((_) => _carregarDados());
                            },
                          ),
                          if (_notifCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _notifCount > 9 ? '9+' : '$_notifCount',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ——— Conteúdo —————————————————————————————————————————————
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _consultasParaAvaliar(),

                  // --- Consultas Agendadas -------------------------------------------
                  const _SectionTitle(
                      title: 'Consultas Agendadas',
                      icon: Icons.calendar_month_rounded),
                  const SizedBox(height: 10),
                  _proximaConsulta(),
                  const SizedBox(height: 24),

                  // --- Último Sintoma Registrado -----------------------------------
                  const _SectionTitle(
                      title: 'Último Sintoma Registrado',
                      icon: Icons.monitor_heart_rounded),
                  const SizedBox(height: 10),
                  _ultimoSintoma(),
                  const SizedBox(height: 24),

                  // --- Resumo Rápido -----------------------------------------------
                  const _SectionTitle(
                      title: 'Resumo', icon: Icons.bar_chart_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Sintomas\nRegistrados',
                          value: '${_sintomas.length}',
                          icon: Icons.healing_rounded,
                          color: const Color(0xFFE91E63),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Consultas\nRealizadas',
                          value:
                              '${_consultas.where((c) => (c['status'] as String?)?.toLowerCase() == 'realizada').length}',
                          icon: Icons.medical_services_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _consultasParaAvaliar() {
    final paraAvaliar = _consultas.where((c) {
      final status = (c['status'] as String?)?.toLowerCase();
      final avaliacao = c['avaliacao']; // int or null
      return status == 'finalizada' && avaliacao == null;
    }).toList();

    if (paraAvaliar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Avalie seu Atendimento', icon: Icons.star_rounded),
        const SizedBox(height: 10),
        ...paraAvaliar.map((c) {
          final profissional = c['profissional'] as Map<String, dynamic>?;
          final nomeProf = profissional?['nome'] ?? 'Profissional';
          final dataHora = c['data_hora'] as String? ?? '';
          final dt = DateTime.tryParse(dataHora);
          final dtFormatada = dt != null ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : dataHora;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Como foi sua sessão com $nomeProf?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Realizada em $dtFormatada', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _mostrarDialogAvaliacao(c),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Avaliar Agora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _mostrarDialogAvaliacao(Map<String, dynamic> c) async {
    int nota = 5;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Avalie o Atendimento', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Quantas estrelas você dá para esta sessão?', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < nota ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setStateSB(() => nota = index + 1),
                    );
                  }),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mais tarde')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, nota),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                child: const Text('Enviar Avaliação'),
              ),
            ],
          );
        });
      },
    );

    if (result != null && mounted) {
      final res = await _api.avaliarConsulta(consultaId: c['id'] as String, nota: result);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avaliação enviada com sucesso! Obrigado pelo feedback.')));
        _carregarDados();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] as String? ?? 'Erro ao enviar avaliação.')));
      }
    }
  }

  Widget _proximaConsulta() {
    final proximas = _consultas
        .where((c) => ['agendada', 'confirmada'].contains((c['status'] as String?)?.toLowerCase()))
        .toList();

    if (proximas.isEmpty) {
      return Column(
        children: [
          const _EmptyCard(
            icon: Icons.calendar_today_rounded,
            message: 'Nenhuma consulta agendada.',
            sub: 'Busque um fisioterapeuta para agendar.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agendar Consulta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AgendarConsultaScreen(pacienteId: widget.pacienteId)),
                );
                if (result == true) _carregarDados();
              },
            ),
          ),
        ],
      );
    }

    // Sort by date ascending (closest date first)
    proximas.sort((a, b) {
      final da = DateTime.tryParse(a['data_hora'] ?? '') ?? DateTime(2100);
      final db = DateTime.tryParse(b['data_hora'] ?? '') ?? DateTime(2100);
      return da.compareTo(db);
    });

    return Column(
      children: proximas.map((c) {
        final profissional = c['profissional'] as Map<String, dynamic>?;
        final dataHora = c['data_hora'] as String? ?? '';
        final dt = DateTime.tryParse(dataHora);
        final dtFormatada = dt != null
            ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
            : dataHora;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  AppTheme.secondary.withValues(alpha: 0.08)
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profissional?['nome'] ?? 'Profissional',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(profissional?['especialidade'] ?? '',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(dtFormatada,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (c['status'] as String?)?.toLowerCase() == 'confirmada'
                            ? Colors.green.withValues(alpha: 0.12)
                            : AppTheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text((c['status'] as String?)?.toLowerCase() == 'confirmada' ? 'Confirmada' : 'Agendada',
                          style: TextStyle(
                              color: (c['status'] as String?)?.toLowerCase() == 'confirmada'
                                  ? Colors.green
                                  : AppTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((c['status'] as String?)?.toLowerCase() == 'agendada' &&
                    dt != null &&
                    DateTime.now().isAfter(dt.subtract(const Duration(hours: 24))) &&
                    DateTime.now().isBefore(dt))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Fazer Check-in (Confirmar Presença)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _confirmar(c),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                        label: const Text('Reagendar', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _reagendar(c),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_busy_rounded, size: 16),
                        label: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _cancelar(c),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmar(Map<String, dynamic> c) async {
    final profId = c['id_profissional'] as String? ?? '';
    final res = await _api.confirmarConsulta(
      consultaId: c['id'] as String,
      pacienteId: widget.pacienteId,
      profissionalId: profId,
      iniciadoPorProfissional: false,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presença confirmada! O profissional foi notificado.')),
      );
      _carregarDados();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao confirmar.')),
      );
    }
  }

  Future<void> _cancelar(Map<String, dynamic> c) async {
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Cancelar Consulta'),
            ),
          ],
        );
      },
    );
    if (motivo == null || !mounted) return;
    final profId = c['id_profissional'] as String? ?? '';
    final res = await _api.cancelarConsulta(
      consultaId: c['id'] as String,
      pacienteId: widget.pacienteId,
      profissionalId: profId,
      motivo: motivo.isEmpty ? null : motivo,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta cancelada. O profissional foi notificado.')),
      );
      _carregarDados();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao cancelar.')),
      );
    }
  }

  Future<void> _reagendar(Map<String, dynamic> c) async {
    final profId = c['id_profissional'] as String? ?? '';
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReagendarScreen(
          consultaId: c['id'] as String,
          pacienteId: widget.pacienteId,
          profissionalId: profId,
          api: _api,
          iniciadoPorProfissional: false,
        ),
      ),
    );
    if (result == true && mounted) _carregarDados();
  }

  Widget _ultimoSintoma() {
    if (_sintomas.isEmpty) {
      return const _EmptyCard(
        icon: Icons.monitor_heart_outlined,
        message: 'Nenhum sintoma registrado.',
        sub: 'Use a aba Saúde para registrar seus sintomas.',
      );
    }
    final s = _sintomas.first;
    final nivel = s['intensidade'] as int? ?? 0;
    final descricao = s['descricao'] as String? ?? 'Sem descrição';
    final regiao = s['categoria'] as String?;
    final dataHora = s['data_hora'] as String? ?? '';
    final dt = DateTime.tryParse(dataHora);
    final dtFormatada = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : dataHora;

    final corNivel = nivel <= 3
        ? AppTheme.accent
        : nivel <= 6
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: corNivel.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text('$nivel/10',
                  style: TextStyle(
                      color: corNivel,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(descricao,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (regiao != null)
                  Text('Região: $regiao',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                Text(dtFormatada,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Widgets auxiliares -----------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;
  const _EmptyCard({required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textHint, size: 32),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textHint, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.3)),
        ],
      ),
    );
  }
}


