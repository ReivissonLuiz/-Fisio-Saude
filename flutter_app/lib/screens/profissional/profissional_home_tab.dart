import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ProfissionalHomeTab extends StatefulWidget {
  final String profissionalId;
  final String nome;

  const ProfissionalHomeTab({
    super.key,
    required this.profissionalId,
    required this.nome,
  });

  @override
  State<ProfissionalHomeTab> createState() => _ProfissionalHomeTabState();
}

class _ProfissionalHomeTabState extends State<ProfissionalHomeTab> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _consultasHoje = [];
  int _totalPacientes = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final resConsultas = await _api.getConsultasProfissional(widget.profissionalId);
      final resPacientes = await _api.getPacientesDoProfissional(widget.profissionalId);

      if (mounted) {
        setState(() {
          if (resConsultas['success']) {
             final agora = DateTime.now();
            _consultasHoje = (resConsultas['data'] as List).where((c) {
              final dataC = DateTime.parse(c['data_hora']);
              return dataC.year == agora.year && dataC.month == agora.month && dataC.day == agora.day;
            }).toList();
          }
          if (resPacientes['success']) {
            _totalPacientes = (resPacientes['data'] as List).length;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: AppTheme.primary,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Olá, ${widget.nome.split(' ').first}!',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Painel do Profissional',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            child: Text(
                              widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : 'F',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cards de Resumo
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Consultas Hoje',
                        value: _isLoading ? '...' : _consultasHoje.length.toString(),
                        icon: Icons.calendar_today_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Meus Pacientes',
                        value: _isLoading ? '...' : _totalPacientes.toString(),
                        icon: Icons.people_alt_rounded,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agenda de Hoje',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                else if (_consultasHoje.isEmpty)
                  const _EmptyState(
                    icon: Icons.event_available_rounded,
                    message: 'Nenhuma consulta agendada para hoje.',
                  )
                else
                  ..._consultasHoje.map((c) => _ConsultaTile(consulta: c)),
                
                const SizedBox(height: 24),
                const Text(
                  'Ações Rápidas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _ActionCard(
                      icon: Icons.person_add_rounded,
                      label: 'Novo Paciente',
                      color: Colors.blue,
                      onTap: () {},
                    ),
                    _ActionCard(
                      icon: Icons.history_rounded,
                      label: 'Histórico',
                      color: Colors.orange,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ConsultaTile extends StatelessWidget {
  final dynamic consulta;

  const _ConsultaTile({required this.consulta});

  @override
  Widget build(BuildContext context) {
    final paciente = consulta['paciente'];
    final dataHora = DateTime.parse(consulta['data_hora']);
    // Formatar hora 14:30
    final hora = "${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(height: 2),
                Text(hora, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paciente?['nome'] ?? 'Paciente',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(consulta['observacao'] ?? 'Consulta fisioterapêutica',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            onPressed: () {},
          )
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
