import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notificacoes_panel.dart';
import '../shared/chat_screen.dart';
import '../shared/contatos_chat_screen.dart';

class ProfissionalHomeTab extends StatefulWidget {
  final String profissionalId;
  final String nome;
  final String? profissionalAvatar;
  final void Function(String consultaId)? onOpenConsultaFromNotificacao;

  const ProfissionalHomeTab({
    super.key,
    required this.profissionalId,
    required this.nome,
    this.profissionalAvatar,
    this.onOpenConsultaFromNotificacao,
  });

  @override
  State<ProfissionalHomeTab> createState() => _ProfissionalHomeTabState();
}

class _ProfissionalHomeTabState extends State<ProfissionalHomeTab> {
  final _api = ApiService();
  final _notif = NotificationService();
  bool _isLoading = true;
  
  List<dynamic> _todasConsultas = [];
  List<dynamic> _consultasHoje = [];
  int _totalPacientes = 0;
  int _notifCount = 0;
  
  int _agendadas = 0;
  int _realizadas = 0;
  int _canceladas = 0;
  
  double _mediaAvaliacao = 0.0;
  double _taxaCancelamento = 0.0;
  List<MapEntry<String, int>> _principaisQueixas = [];

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
      final resSintomas = await _api.getTodosSintomasProfissional();
      final nCount = await _notif.contarNaoLidas(widget.profissionalId);

      if (mounted) {
        setState(() {
          if (resConsultas['success']) {
            _todasConsultas = resConsultas['data'] as List;
            final agora = DateTime.now();
            
            _agendadas = 0;
            _realizadas = 0;
            _canceladas = 0;
            _consultasHoje = [];

            int somaAvaliacao = 0;
            int countAvaliacao = 0;

            for (var c in _todasConsultas) {
              final status = (c['status'] as String?)?.toLowerCase() ?? 'agendada';
              if (status == 'agendada' || status == 'confirmada') {
                _agendadas++;
              } else if (status == 'realizada' || status == 'finalizada') {
                _realizadas++;
              } else if (status == 'cancelada' || status == 'nao_compareceu') {
                _canceladas++;
              }

              if (c['avaliacao'] != null) {
                somaAvaliacao += (c['avaliacao'] as num).toInt();
                countAvaliacao++;
              }

              if (c['data_hora'] != null) {
                final dataC = DateTime.tryParse(c['data_hora']);
                if (dataC != null && dataC.year == agora.year && dataC.month == agora.month && dataC.day == agora.day) {
                  _consultasHoje.add(c);
                }
              }
            }
            
            _mediaAvaliacao = countAvaliacao > 0 ? somaAvaliacao / countAvaliacao : 0.0;
            _taxaCancelamento = _todasConsultas.isNotEmpty ? (_canceladas / _todasConsultas.length) * 100 : 0.0;
            
            // Ordenar consultas de hoje pelo horário
            _consultasHoje.sort((a, b) {
               final dtA = DateTime.tryParse(a['data_hora'] ?? '') ?? DateTime(2000);
               final dtB = DateTime.tryParse(b['data_hora'] ?? '') ?? DateTime(2000);
               return dtA.compareTo(dtB);
            });
          }
          
          if (resPacientes['success']) {
            _totalPacientes = (resPacientes['data'] as List).length;
          }
          
          if (resSintomas['success']) {
            final sintomas = resSintomas['data'] as List;
            final Map<String, int> contagem = {};
            for (var s in sintomas) {
              final cat = s['categoria'] as String? ?? 'Outros';
              contagem[cat] = (contagem[cat] ?? 0) + 1;
            }
            _principaisQueixas = contagem.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            if (_principaisQueixas.length > 5) {
              _principaisQueixas = _principaisQueixas.sublist(0, 5);
            }
          }
          
          _notifCount = nCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPieChart() {
    if (_agendadas == 0 && _realizadas == 0 && _canceladas == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('Sem dados suficientes.', style: TextStyle(color: AppTheme.textHint)),
        ),
      );
    }

    const colorAgendadas  = Color(0xFF42A5F5); // azul
    const colorRealizadas = Color(0xFF66BB6A); // verde
    const colorCanceladas = Color(0xFFEF5350); // vermelho

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 52,
              sections: [
                if (_agendadas > 0)
                  PieChartSectionData(
                    color: colorAgendadas,
                    value: _agendadas.toDouble(),
                    title: '$_agendadas',
                    radius: 58,
                    titleStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                if (_realizadas > 0)
                  PieChartSectionData(
                    color: colorRealizadas,
                    value: _realizadas.toDouble(),
                    title: '$_realizadas',
                    radius: 58,
                    titleStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                if (_canceladas > 0)
                  PieChartSectionData(
                    color: colorCanceladas,
                    value: _canceladas.toDouble(),
                    title: '$_canceladas',
                    radius: 58,
                    titleStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legenda externa
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (_agendadas > 0)
              _LegendItem(color: colorAgendadas,  label: 'Agendadas'),
            if (_realizadas > 0)
              _LegendItem(color: colorRealizadas, label: 'Realizadas'),
            if (_canceladas > 0)
              _LegendItem(color: colorCanceladas, label: 'Canceladas'),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBarChart() {
    final now = DateTime.now();
    final Map<int, int> monthlyCounts = {};
    
    // Inicializar os últimos 6 meses com 0
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1).month;
      monthlyCounts[month] = 0;
    }

    // Contar consultas
    for (var c in _todasConsultas) {
      if (c['data_hora'] == null) continue;
      final dt = DateTime.tryParse(c['data_hora']);
      if (dt != null) {
        final diff = now.difference(dt).inDays;
        if (diff <= 200 && monthlyCounts.containsKey(dt.month)) {
           monthlyCounts[dt.month] = (monthlyCounts[dt.month] ?? 0) + 1;
        }
      }
    }

    int maxCount = 5;
    for (var v in monthlyCounts.values) {
      if (v > maxCount) maxCount = v;
    }
    // Adiciona 30% de margem no topo para o tooltip (balãozinho) não ser cortado
    final maxY = maxCount + (maxCount * 0.3).ceil() + 2;

    List<BarChartGroupData> barGroups = [];
    int xIndex = 0;
    final List<String> monthLabels = [];
    final df = DateFormat('MMM', 'pt_BR');

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      monthLabels.add(df.format(d).toUpperCase());
      final count = monthlyCounts[d.month] ?? 0;
      
      barGroups.add(
        BarChartGroupData(
          x: xIndex,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: AppTheme.primary,
              width: 18,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY.toDouble(),
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
      xIndex++;
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY.toDouble(),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < monthLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        monthLabels[value.toInt()],
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.primary,
        child: CustomScrollView(
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF5E35B1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
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
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Painel Analítico',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
                                    tooltip: 'Mensagens',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ContatosChatScreen(
                                            usuarioId: widget.profissionalId,
                                            usuarioNome: widget.nome,
                                            usuarioAvatar: widget.profissionalAvatar,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Stack(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 28),
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (_) => NotificacoesPanel(
                                              usuarioId: widget.profissionalId,
                                              usuarioNome: widget.nome,
                                              usuarioAvatar: widget.profissionalAvatar,
                                              isProfissional: true,
                                              onOpenConsultaProfissional:
                                                  widget.onOpenConsultaFromNotificacao,
                                            ),
                                          )).then((_) => _loadDashboardData());
                                        },
                                      ),
                                      if (_notifCount > 0)
                                        Positioned(
                                          right: 6, top: 6,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text('$_notifCount',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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
                    // Resumo Topo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Consultas Hoje',
                            value: _isLoading ? '-' : _consultasHoje.length.toString(),
                            details: 'Sessões agendadas para o dia atual.',
                            icon: Icons.calendar_month_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Pacientes',
                            value: _isLoading ? '-' : _totalPacientes.toString(),
                            details: 'Pacientes atualmente vinculados a você.',
                            icon: Icons.people_alt_rounded,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Realizadas',
                            value: _isLoading ? '-' : _realizadas.toString(),
                            details: 'Histórico total de atendimentos concluídos.',
                            icon: Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Avaliação Média',
                            value: _isLoading ? '-' : _mediaAvaliacao.toStringAsFixed(1),
                            details: 'Nota média dada pelos seus pacientes.',
                            icon: Icons.star_rounded,
                            color: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Cancelamentos',
                            value: _isLoading ? '-' : '${_taxaCancelamento.toStringAsFixed(0)}%',
                            details: 'Taxa de faltas e cancelamentos no histórico.',
                            icon: Icons.trending_down_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Seção BI - Gráficos Expansíveis
                    const Text(
                      'Visão Geral (BI)',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
                    else ...[
                      _ExpandableCard(
                        title: 'Evolução de Atendimentos',
                        subtitle: 'Últimos 6 meses',
                        icon: Icons.bar_chart_rounded,
                        initiallyExpanded: true,
                        child: _buildBarChart(),
                      ),
                      const SizedBox(height: 16),
                      _ExpandableCard(
                        title: 'Distribuição por Status',
                        subtitle: 'Todas as consultas registradas',
                        icon: Icons.pie_chart_rounded,
                        child: _buildPieChart(),
                      ),
                      const SizedBox(height: 16),
                      _ExpandableCard(
                        title: 'Principais Queixas',
                        subtitle: 'Sintomas mais relatados (Geral)',
                        icon: Icons.medical_information_rounded,
                        child: _principaisQueixas.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text('Nenhum sintoma registrado pelos pacientes.', style: TextStyle(color: AppTheme.textHint)),
                                ),
                              )
                            : Column(
                                children: _principaisQueixas.map((q) {
                                  final total = _principaisQueixas.fold<int>(0, (sum, e) => sum + e.value);
                                  final percent = total > 0 ? (q.value / total) * 100 : 0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(q.key, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                        ),
                                        Expanded(
                                          flex: 5,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: percent / 100,
                                              backgroundColor: AppTheme.divider,
                                              color: AppTheme.secondary,
                                              minHeight: 8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 36,
                                          child: Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.right),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    
                    // Agenda de Hoje
                    const Text(
                      'Agenda de Hoje',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_consultasHoje.isEmpty)
                      const _EmptyState(
                        icon: Icons.event_available_rounded,
                        message: 'Seu dia está livre! Nenhuma consulta para hoje.',
                      )
                    else
                      ..._consultasHoje.map((c) => _ConsultaTile(
                            consulta: c,
                            profissionalId: widget.profissionalId,
                            profissionalNome: widget.nome,
                            profissionalAvatar: widget.profissionalAvatar,
                          )),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String title;
  final String value;
  final String details;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.details,
    required this.icon,
    required this.color,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        decoration: BoxDecoration(
          color: _isExpanded ? widget.color.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
          border: Border.all(color: widget.color.withValues(alpha: _isExpanded ? 0.5 : 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(widget.value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary)),
            
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                        Divider(height: 1, color: widget.color.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        Text(
                          widget.details,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 6),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppTheme.textHint.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: AppTheme.primary,
          collapsedIconColor: AppTheme.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            )
          ],
        ),
      ),
    );
  }
}

class _ConsultaTile extends StatelessWidget {
  final dynamic consulta;
  final String profissionalId;
  final String profissionalNome;
  final String? profissionalAvatar;

  const _ConsultaTile({
    required this.consulta,
    required this.profissionalId,
    required this.profissionalNome,
    this.profissionalAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final paciente = consulta['paciente'];
    final dataHora = DateTime.tryParse(consulta['data_hora'] ?? '');
    final hora = dataHora != null 
        ? "${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}" 
        : '--:--';
    
    final status = (consulta['status'] as String?)?.toLowerCase() ?? '';
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.schedule_rounded;
    if (status == 'realizada') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'cancelada') {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary.withValues(alpha: 0.1), AppTheme.primary.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(height: 4),
                Text(hora, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (paciente?['nome'] as String?)?.isNotEmpty == true
                        ? paciente!['nome'] as String
                        : 'Paciente Não Identificado',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(consulta['observacao'] ?? 'Consulta fisioterapêutica padrão',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final pacienteId = consulta['id_paciente'] ?? '';
                    final pacienteNome = paciente?['nome'] ?? 'Paciente';
                    final pacienteAvatar = paciente?['avatar_url'] as String?;
                    if (pacienteId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            meuId: profissionalId,
                            meuNome: profissionalNome,
                            meuAvatar: profissionalAvatar,
                            outroId: pacienteId,
                            outroNome: pacienteNome,
                            outroAvatar: pacienteAvatar,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.secondary,
                    side: const BorderSide(color: AppTheme.secondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Item de legenda usado no gráfico de pizza
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
