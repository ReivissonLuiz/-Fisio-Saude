import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AdminDashboardTab extends StatefulWidget {
  final String adminId;
  const AdminDashboardTab({super.key, required this.adminId});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final _api = ApiService();
  bool _isLoading = true;

  List<dynamic> _listaPacientes = [];
  List<dynamic> _listaProfissionais = [];
  List<dynamic> _listaConsultas = [];
  List<dynamic> _listaSintomas = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getAllPacientes(filterAtivo: false),
        _api.getAllProfissionais(filterAtivo: false),
        _api.getAllConsultas(),
        _api.getAllSintomasGlobais(),
      ]);
      if (mounted) {
        setState(() {
          _listaPacientes  = results[0]['success'] ? (results[0]['data'] as List) : [];
          _listaProfissionais = results[1]['success'] ? (results[1]['data'] as List) : [];
          _listaConsultas  = results[2]['success'] ? (results[2]['data'] as List) : [];
          _listaSintomas   = results[3]['success'] ? (results[3]['data'] as List) : [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── derived stats ───────────────────────────────────────────────────────
  int get _totalPacientes      => _listaPacientes.length;
  int get _pacientesAtivos     => _listaPacientes.where((p) => p['ativo'] == true).length;
  int get _totalProf           => _listaProfissionais.length;
  int get _profAtivos          => _listaProfissionais.where((p) => p['ativo'] == true).length;
  int get _totalConsultas  => _listaConsultas.length;
  int get _totalSintomas   => _listaSintomas.length;

  // Consultas em status ativo (agendada ou em_andamento)
  List<dynamic> get _consultasAtivas => _listaConsultas
      .where((c) {
        final s = (c['status'] as String? ?? '').toLowerCase();
        return s == 'agendada' || s == 'em_andamento' || s == 'em andamento';
      })
      .toList();
  int get _totalConsultasAtivas => _consultasAtivas.length;


  /// Consultas do último mês
  List<dynamic> get _consultasUltimoMes {
    final limite = DateTime.now().subtract(const Duration(days: 30));
    return _listaConsultas.where((c) {
      final dt = c['data_hora'] as String?;
      if (dt == null) return false;
      return DateTime.tryParse(dt)?.isAfter(limite) ?? false;
    }).toList();
  }

  /// Profissional com mais consultas no último mês
  String get _topProfissionalNome {
    final consultas = _consultasUltimoMes;
    if (consultas.isEmpty || _listaProfissionais.isEmpty) return 'N/A';
    final Map<String, int> contagem = {};
    for (final c in consultas) {
      final id = c['id_profissional']?.toString() ?? '';
      if (id.isNotEmpty) contagem[id] = (contagem[id] ?? 0) + 1;
    }
    if (contagem.isEmpty) return 'N/A';
    final topId = contagem.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final prof = _listaProfissionais.firstWhere(
      (p) => p['id'].toString() == topId,
      orElse: () => null,
    );
    return prof?['nome'] as String? ?? 'N/A';
  }

  int get _topProfissionalConsultas {
    final consultas = _consultasUltimoMes;
    if (consultas.isEmpty) return 0;
    final Map<String, int> contagem = {};
    for (final c in consultas) {
      final id = c['id_profissional']?.toString() ?? '';
      if (id.isNotEmpty) contagem[id] = (contagem[id] ?? 0) + 1;
    }
    if (contagem.isEmpty) return 0;
    return contagem.values.reduce((a, b) => a >= b ? a : b);
  }

  /// Ranking de profissionais por consultas no último mês (para gráfico de barras)
  List<MapEntry<String, int>> get _rankingProfissionaisUltimoMes {
    final consultas = _consultasUltimoMes;
    final Map<String, int> contagem = {};
    for (final c in consultas) {
      final id = c['id_profissional']?.toString() ?? '';
      if (id.isEmpty) continue;
      final prof = _listaProfissionais.firstWhere(
        (p) => p['id'].toString() == id,
        orElse: () => null,
      );
      final nome = (prof?['nome'] as String? ?? id).split(' ').first;
      contagem[nome] = (contagem[nome] ?? 0) + 1;
    }
    final entries = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  /// Contagem por categoria de sintoma (para pizza)
  Map<String, int> get _categoriasCount {
    final Map<String, int> m = {};
    for (final s in _listaSintomas) {
      final r = s['categoria']?.toString() ?? 'Outros';
      m[r] = (m[r] ?? 0) + 1;
    }
    return m;
  }

  /// Contagem por grupo de intensidade (para pizza)
  Map<String, int> get _intensidadeGrupos {
    int leve = 0, moderada = 0, intensa = 0;
    for (final s in _listaSintomas) {
      final n = ((s['intensidade'] as num?) ?? 0).toInt();
      if (n <= 3) { leve++; } else if (n <= 6) { moderada++; } else { intensa++; }
    }
    return {'Leve (1-3)': leve, 'Moderada (4-6)': moderada, 'Intensa (7-10)': intensa};
  }

  double get _dorMedio {
    if (_listaSintomas.isEmpty) return 0;
    final sum = _listaSintomas.fold<num>(0, (acc, s) => acc + ((s['intensidade'] as num?) ?? 0));
    return sum / _listaSintomas.length;
  }

  /// Pacientes únicos por profissional (para gráfico de barras)
  List<MapEntry<String, int>> get _pacientesPorProfissional {
    final Map<String, Set<String>> mapa = {};
    for (final c in _listaConsultas) {
      final profId = c['id_profissional']?.toString() ?? '';
      final pacId  = c['id_paciente']?.toString() ?? '';
      if (profId.isEmpty || pacId.isEmpty) continue;
      final prof = _listaProfissionais.firstWhere(
        (p) => p['id'].toString() == profId,
        orElse: () => null,
      );
      final nome = (prof?['nome'] as String? ?? profId).split(' ').first;
      mapa.putIfAbsent(nome, () => {}).add(pacId);
    }
    final entries = mapa.entries.map((e) => MapEntry(e.key, e.value.length)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(6).toList();
  }

  List<MapEntry<String, double>> get _rankingAvaliacoes {
    // Calcula a média das avaliações recebidas por cada profissional (com base em consultas finalizadas e avaliadas)
    final Map<String, List<int>> notasPorProfissional = {};
    for (final c in _listaConsultas) {
      final profId = c['id_profissional']?.toString() ?? '';
      final avaliacao = c['avaliacao']; // int ou null
      if (profId.isEmpty || avaliacao == null) continue;
      
      final prof = _listaProfissionais.firstWhere(
        (p) => p['id'].toString() == profId,
        orElse: () => null,
      );
      final nome = (prof?['nome'] as String? ?? profId).split(' ').first;
      
      notasPorProfissional.putIfAbsent(nome, () => []).add((avaliacao as num).toInt());
    }
    
    final Map<String, double> ranking = {};
    for (final entry in notasPorProfissional.entries) {
      final notas = entry.value;
      if (notas.isNotEmpty) {
        final media = notas.fold<int>(0, (a, b) => a + b) / notas.length;
        ranking[entry.key] = media;
      }
    }
    
    final entries = ranking.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  void _abrirDetalhes(String titulo, List<dynamic> dados, String tipoInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalhesBottomSheet(titulo: titulo, dados: dados, tipoInfo: tipoInfo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: Colors.purple,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header gradient ─────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 130,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.purple,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        onPressed: _loadStats,
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Painel Administrativo',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(
                                '$_totalPacientes pacientes · $_totalProf profissionais · $_totalConsultas sessões',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // ── KPIs Grid ─────────────────────────────────
                        _sectionTitle('Métricas Principais'),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.3,
                          children: [
                            _KPICard(
                              label: 'Total Pacientes',
                              value: '$_totalPacientes',
                              sub: '$_pacientesAtivos ativos',
                              icon: Icons.people_rounded,
                              color: AppTheme.primary,
                              onTap: () => _abrirDetalhes('Todos os Pacientes', _listaPacientes, 'paciente'),
                            ),
                            _KPICard(
                              label: 'Fisioterapeutas',
                              value: '$_totalProf',
                              sub: '$_profAtivos ativos',
                              icon: Icons.medical_services_rounded,
                              color: AppTheme.secondary,
                              onTap: () => _abrirDetalhes('Fisioterapeutas', _listaProfissionais, 'profissional'),
                            ),
                            _KPICard(
                              label: 'Sessões Ativas',
                              value: '$_totalConsultasAtivas',
                              sub: 'agendadas / em andamento',
                              icon: Icons.event_available_rounded,
                              color: Colors.green,
                              onTap: () => _abrirDetalhes('Sessões Ativas', _consultasAtivas, 'consulta'),
                            ),
                            _KPICard(
                              label: 'Sessões Históricas',
                              value: '$_totalConsultas',
                              sub: 'total no sistema',
                              icon: Icons.history_rounded,
                              color: Colors.blueGrey,
                              onTap: () => _abrirDetalhes('Todas as Sessões', _listaConsultas, 'consulta'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Insights ──────────────────────────────────
                        _sectionTitle('Insights Clínicos'),
                        const SizedBox(height: 12),

                        _ExpandableChartCard(
                          icon: Icons.emoji_events_rounded,
                          color: Colors.amber,
                          title: 'Profissional Destaque',
                          summary: _topProfissionalConsultas > 0
                              ? '$_topProfissionalNome lidera com $_topProfissionalConsultas sessão(ões) no último mês.'
                              : 'Nenhuma consulta no último mês.',
                          chart: _rankingProfissionaisUltimoMes.isEmpty
                              ? null
                              : _BarChart(dados: _rankingProfissionaisUltimoMes, color: Colors.amber),
                        ),

                        _ExpandableChartCard(
                          icon: Icons.star_rounded,
                          color: Colors.orange,
                          title: 'Avaliações de Pacientes',
                          summary: 'Top profissionais com as melhores notas de feedback.',
                          chart: _listaProfissionais.isEmpty
                              ? null
                              : _AvaliacoesChart(dados: _rankingAvaliacoes, color: Colors.orange),
                        ),
                        _ExpandableChartCard(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFFE91E63),
                          title: 'Principais Queixas de Dores',
                          summary: _categoriasCount.isEmpty
                              ? 'Sem registros de sintomas.'
                              : 'Categoria mais frequente: ${_categoriasCount.entries.reduce((a,b)=>a.value>=b.value?a:b).key}.',
                          chart: _categoriasCount.isEmpty
                              ? null
                              : _PieChart(dados: _categoriasCount, colors: const [
                                  Color(0xFFE91E63), Color(0xFF9C27B0), Colors.blue,
                                  Colors.teal, Colors.orange, Colors.green]),
                        ),
                        _ExpandableChartCard(
                          icon: Icons.speed_rounded,
                          color: Colors.deepOrange,
                          title: 'Distribuição de Intensidade de Dor',
                          summary: _totalSintomas > 0
                              ? 'Média geral: ${_dorMedio.toStringAsFixed(1)}/10.'
                              : 'Nenhum sintoma registrado.',
                          chart: _intensidadeGrupos.values.every((v) => v == 0)
                              ? null
                              : _PieChart(dados: _intensidadeGrupos, colors: const [
                                  Colors.green, Colors.orange, Colors.red]),
                        ),
                        _ExpandableChartCard(
                          icon: Icons.group_work_rounded,
                          color: Colors.indigo,
                          title: 'Pacientes por Profissional',
                          summary: _totalProf > 0
                              ? 'Média de ${(_totalPacientes / _totalProf).toStringAsFixed(1)} pacientes por fisioterapeuta.'
                              : 'Nenhum profissional cadastrado.',
                          chart: _pacientesPorProfissional.isEmpty
                              ? null
                              : _BarChart(dados: _pacientesPorProfissional, color: Colors.indigo),
                        ),

                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary));
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KPICard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KPICard({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
              ],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                  const SizedBox(height: 2),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                  const SizedBox(height: 2),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Expandable Chart Card ────────────────────────────────────────────────────
class _ExpandableChartCard extends StatefulWidget {
  final String title, summary;
  final IconData icon;
  final Color color;
  final Widget? chart;

  const _ExpandableChartCard({
    required this.title, required this.summary,
    required this.icon, required this.color, this.chart,
  });

  @override
  State<_ExpandableChartCard> createState() => _ExpandableChartCardState();
}

class _ExpandableChartCardState extends State<_ExpandableChartCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(widget.summary, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: widget.color.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
            if (_expanded && widget.chart != null) ...[  
              const Divider(color: AppTheme.divider, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: widget.chart!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet de detalhes ──────────────────────────────────────────────────
class _DetalhesBottomSheet extends StatelessWidget {
  final String titulo;
  final List<dynamic> dados;
  final String tipoInfo;

  const _DetalhesBottomSheet({required this.titulo, required this.dados, required this.tipoInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            width: double.infinity,
            color: Colors.white,
            child: Text('${dados.length} registros', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: dados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = dados[i];
                if (tipoInfo == 'paciente' || tipoInfo == 'profissional') {
                  final nome = d['nome'] ?? 'Sem nome';
                  final email = d['email'] ?? '';
                  final sub = tipoInfo == 'profissional'
                      ? (d['especialidade'] ?? 'Fisioterapia')
                      : (d['telefone'] ?? '');
                  final cor = tipoInfo == 'paciente' ? AppTheme.primary : AppTheme.secondary;
                  final ativo = d['ativo'] as bool? ?? true;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ativo ? AppTheme.divider : Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: cor.withValues(alpha: 0.1),
                          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                              style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                          ],
                        )),
                        if (!ativo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
                            child: const Text('INATIVO', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }
                if (tipoInfo == 'sintoma') {
                  final nivel = d['intensidade'] ?? 0;
                  final regiao = d['categoria'] ?? 'Genérico';
                  final desc = d['descricao'] ?? '';
                  final nivelInt = nivel is int ? nivel : (nivel as num).toInt();
                  final cor = nivelInt >= 7 ? Colors.red : (nivelInt >= 4 ? Colors.orange : Colors.green);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: cor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('$nivelInt', style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(regiao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        )),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text('Dor $nivelInt/10', style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                  );
                }
                if (tipoInfo == 'consulta') {
                  final dtStr = d['data_hora'] as String? ?? '';
                  String dtFormatada = 'Sem data';
                  if (dtStr.isNotEmpty) {
                    final dTime = DateTime.tryParse(dtStr);
                    if (dTime != null) {
                      dtFormatada = '${dTime.day.toString().padLeft(2, '0')}/${dTime.month.toString().padLeft(2, '0')}/${dTime.year} às ${dTime.hour.toString().padLeft(2, '0')}:${dTime.minute.toString().padLeft(2, '0')}';
                    }
                  }
                  final status = d['status'] as String? ?? '';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.event_rounded, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Consulta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(dtFormatada, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        )),
                        if (status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(status, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bar Chart ────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<MapEntry<String, int>> dados;
  final Color color;
  const _BarChart({required this.dados, required this.color});

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) return const SizedBox();
    final maxVal = dados.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(
      children: dados.map((e) {
        final pct = maxVal > 0 ? e.value / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(e.key, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.toDouble(),
                    minHeight: 18,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${e.value}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Avaliacoes Bar Chart ─────────────────────────────────────────────────────
class _AvaliacoesChart extends StatelessWidget {
  final List<MapEntry<String, double>> dados;
  final Color color;
  const _AvaliacoesChart({required this.dados, required this.color});

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) return const SizedBox();
    const maxVal = 5.0; // Notas de 0 a 5
    return Column(
      children: dados.map((e) {
        final pct = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(e.key, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 18,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(e.value.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Pie Chart ────────────────────────────────────────────────────────────────
class _PieChart extends StatelessWidget {
  final Map<String, int> dados;
  final List<Color> colors;
  const _PieChart({required this.dados, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = dados.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox();
    final entries = dados.entries.toList();
    return Column(
      children: [
        CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _PieChartPainter(entries: entries, total: total, colors: colors),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: List.generate(entries.length, (i) {
            final pct = (entries[i].value / total * 100).toStringAsFixed(0);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text('${entries[i].key} $pct%', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<MapEntry<String, int>> entries;
  final int total;
  final List<Color> colors;
  const _PieChartPainter({required this.entries, required this.total, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 4;
    double start = -3.14159 / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * 2 * 3.14159;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);
      start += sweep;
    }
    // Hole for donut
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
