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
  int get _totalConsultas      => _listaConsultas.length;
  int get _totalSintomas       => _listaSintomas.length;
  double get _receitaEstimada  => _totalConsultas * 120.0;

  String get _receitaFmt {
    final v = _receitaEstimada;
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Profissional com mais consultas
  String get _topProfissionalNome {
    if (_listaConsultas.isEmpty || _listaProfissionais.isEmpty) return 'N/A';
    final Map<String, int> contagem = {};
    for (final c in _listaConsultas) {
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
    if (_listaConsultas.isEmpty) return 0;
    final Map<String, int> contagem = {};
    for (final c in _listaConsultas) {
      final id = c['id_profissional']?.toString() ?? '';
      if (id.isNotEmpty) contagem[id] = (contagem[id] ?? 0) + 1;
    }
    if (contagem.isEmpty) return 0;
    return contagem.values.reduce((a, b) => a >= b ? a : b);
  }

  /// Região de sintoma mais comum
  String get _regiaoMaisComum {
    if (_listaSintomas.isEmpty) return 'N/A';
    final Map<String, int> contagem = {};
    for (final s in _listaSintomas) {
      final r = s['regiao']?.toString() ?? 'Não informado';
      contagem[r] = (contagem[r] ?? 0) + 1;
    }
    return contagem.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get _dorMedio {
    if (_listaSintomas.isEmpty) return 0;
    final sum = _listaSintomas.fold<num>(0, (acc, s) => acc + ((s['nivel_dor'] as num?) ?? 0));
    return sum / _listaSintomas.length;
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
                              label: 'Sessões Marcadas',
                              value: '$_totalConsultas',
                              sub: 'total no sistema',
                              icon: Icons.event_available_rounded,
                              color: Colors.green,
                              onTap: () => _abrirDetalhes('Consultas', _listaConsultas, 'consulta'),
                            ),
                            _KPICard(
                              label: 'Registros de Sintomas',
                              value: '$_totalSintomas',
                              sub: 'apontamentos',
                              icon: Icons.monitor_heart_rounded,
                              color: const Color(0xFFE91E63),
                              onTap: () => _abrirDetalhes('Sintomas Globais', _listaSintomas, 'sintoma'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Receita full-width
                        _FullWidthKPI(
                          label: 'Receita Estimada Global',
                          value: _receitaFmt,
                          sub: 'R\$ 120,00 estimado por sessão',
                          icon: Icons.payments_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 24),

                        // ── Insights ──────────────────────────────────
                        _sectionTitle('Insights Clínicos'),
                        const SizedBox(height: 12),

                        _InsightCard(
                          icon: Icons.emoji_events_rounded,
                          color: Colors.amber,
                          title: 'Profissional Destaque',
                          description: _topProfissionalConsultas > 0
                              ? '$_topProfissionalNome lidera com $_topProfissionalConsultas sessão(ões) registradas.'
                              : 'Nenhuma consulta registrada ainda.',
                          onTap: () => _abrirDetalhes('Fisioterapeutas', _listaProfissionais, 'profissional'),
                        ),
                        _InsightCard(
                          icon: Icons.location_on_rounded,
                          color: const Color(0xFFE91E63),
                          title: 'Região mais acometida',
                          description: _totalSintomas > 0
                              ? '"$_regiaoMaisComum" é a região corporal com maior frequência de sintomas.'
                              : 'Sem registros de sintomas.',
                          onTap: () => _abrirDetalhes('Sintomas Globais', _listaSintomas, 'sintoma'),
                        ),
                        _InsightCard(
                          icon: Icons.speed_rounded,
                          color: Colors.deepOrange,
                          title: 'Dor média reportada',
                          description: _totalSintomas > 0
                              ? 'Os pacientes reportam nível médio de ${_dorMedio.toStringAsFixed(1)}/10 de dor.'
                              : 'Nenhum sintoma registrado.',
                          onTap: () => _abrirDetalhes('Sintomas Globais', _listaSintomas, 'sintoma'),
                        ),
                        _InsightCard(
                          icon: Icons.how_to_reg_rounded,
                          color: Colors.teal,
                          title: 'Taxa de ativação',
                          description: _totalPacientes > 0
                              ? '${((_pacientesAtivos / _totalPacientes) * 100).toStringAsFixed(0)}% dos pacientes estão com conta ativa (${_totalPacientes - _pacientesAtivos} inativos).'
                              : 'Nenhum paciente cadastrado.',
                          onTap: () => _abrirDetalhes('Todos os Pacientes', _listaPacientes, 'paciente'),
                        ),
                        _InsightCard(
                          icon: Icons.group_work_rounded,
                          color: Colors.indigo,
                          title: 'Relação paciente / profissional',
                          description: _totalProf > 0
                              ? 'Média de ${(_totalPacientes / _totalProf).toStringAsFixed(1)} pacientes por fisioterapeuta.'
                              : 'Nenhum profissional cadastrado ainda.',
                          onTap: () {},
                        ),
                        _InsightCard(
                          icon: Icons.trending_up_rounded,
                          color: Colors.green,
                          title: 'Uso da plataforma',
                          description: 'Total de ${_totalConsultas + _totalSintomas} interações (consultas + sintomas) registradas no sistema.',
                          onTap: () {},
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-width KPI ────────────────────────────────────────────────────────────
class _FullWidthKPI extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;

  const _FullWidthKPI({
    required this.label, required this.value, required this.sub,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight Card ─────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InsightCard({
    required this.title, required this.description,
    required this.icon, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.4), size: 18),
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
                  final nivel = d['nivel_dor'] ?? 0;
                  final regiao = d['regiao'] ?? 'Genérico';
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
                  final dt = d['data_hora'] as String? ?? 'Sem data';
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
                            Text(dt, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
