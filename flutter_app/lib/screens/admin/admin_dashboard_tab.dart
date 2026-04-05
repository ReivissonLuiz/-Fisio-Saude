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

  Map<String, dynamic> _stats = {
    'pacientes': 0,
    'profissionais': 0,
    'consultas': 0,
    'sintomas': 0,
    'faturamento_estimado': 'R\$ 0,00',
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final resPac = await _api.getAllPacientes();
      final resProf = await _api.getAllProfissionais();
      final resCons = await _api.getAllConsultas();
      final resSint = await _api.getAllSintomasGlobais();
      
      if (mounted) {
        setState(() {
          _listaPacientes = resPac['success'] ? (resPac['data'] as List) : [];
          _listaProfissionais = resProf['success'] ? (resProf['data'] as List) : [];
          _listaConsultas = resCons['success'] ? (resCons['data'] as List) : [];
          _listaSintomas = resSint['success'] ? (resSint['data'] as List) : [];
          
          final faturamento = _listaConsultas.length * 120.0; // R$ 120 estimado por sessão
          
          _stats = {
            'pacientes': _listaPacientes.length,
            'profissionais': _listaProfissionais.length,
            'consultas': _listaConsultas.length,
            'sintomas': _listaSintomas.length,
            'faturamento_estimado': 'R\$ ${faturamento.toStringAsFixed(2).replaceAll('.', ',')}',
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      appBar: AppBar(
        title: const Text('Painel ADM (BI Real)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.purple), onPressed: _loadStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: Colors.purple,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Métricas Vitais de Operação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Clique sobre os painéis para expandir os dados detalhados.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    
                    // Grid de KPIs
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _KPICard(
                          label: 'Total Pacientes', 
                          value: _stats['pacientes'].toString(), 
                          icon: Icons.people_rounded, 
                          color: AppTheme.primary,
                          onTap: () => _abrirDetalhes('Todos os Pacientes', _listaPacientes, 'paciente'),
                        ),
                        _KPICard(
                          label: 'Fisioterapeutas', 
                          value: _stats['profissionais'].toString(), 
                          icon: Icons.medical_services_rounded, 
                          color: AppTheme.secondary,
                          onTap: () => _abrirDetalhes('Equipe de Fisioterapeutas', _listaProfissionais, 'profissional'),
                        ),
                        _KPICard(
                          label: 'Sessões Marcadas', 
                          value: _stats['consultas'].toString(), 
                          icon: Icons.event_available_rounded, 
                          color: Colors.green,
                          onTap: () => _abrirDetalhes('Volume Mestre de Consultas', _listaConsultas, 'consulta'),
                        ),
                        _KPICard(
                          label: 'Sintomas Extraídos', 
                          value: _stats['sintomas'].toString(), 
                          icon: Icons.monitor_heart_rounded, 
                          color: const Color(0xFFE91E63),
                          onTap: () => _abrirDetalhes('Sintomas Globais', _listaSintomas, 'sintoma'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KPICard(
                      label: 'Receita Estimada Global', 
                      value: _stats['faturamento_estimado'], 
                      icon: Icons.payments_rounded, 
                      color: Colors.orange,
                      width: double.infinity,
                      height: 100,
                      onTap: () {},
                    ),
                    const SizedBox(height: 32),
                    
                    // Seção Insights
                    const Text('Eventos e Geração de Valor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _InsightItem(
                      title: 'Base de Sintomas Ativa',
                      description: 'Ao todo, ${_stats['sintomas']} apontamentos de sintomas fluíram pelo sistema fornecendo dados de saúde detalhados aos profissionais.',
                      icon: Icons.trending_up_rounded,
                      color: Colors.green,
                      onTap: () => _abrirDetalhes('Sintomas Globais', _listaSintomas, 'sintoma'),
                    ),
                    _InsightItem(
                      title: 'Demografia Clínica',
                      description: 'Existem ${_stats['pacientes']} pacientes procurando assistência e interagindo com os registros do aplicativo.',
                      icon: Icons.map_rounded,
                      color: Colors.blue,
                      onTap: () => _abrirDetalhes('Todos os Pacientes', _listaPacientes, 'paciente'),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const _KPICard({
    required this.label, 
    required this.value, 
    required this.icon, 
    required this.color,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.all(4), 
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), 
                  child: Icon(Icons.touch_app_rounded, size: 14, color: color),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: value.length > 8 ? 20 : 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InsightItem({
    required this.title, 
    required this.description, 
    required this.icon, 
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), 
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), 
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _DetalhesBottomSheet extends StatelessWidget {
  final String titulo;
  final List<dynamic> dados;
  final String tipoInfo;

  const _DetalhesBottomSheet({required this.titulo, required this.dados, required this.tipoInfo});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    
    return Container(
      height: mq.size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            width: double.infinity,
            color: Colors.white,
            child: Text('Exibindo ${dados.length} registros computados.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: dados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final d = dados[index];
                
                if (tipoInfo == 'paciente' || tipoInfo == 'profissional') {
                  final nome = d['nome'] ?? 'Nome não cadastrado';
                  final email = d['email'] ?? 'Sem email';
                  final telefone = d['telefone'] ?? 'Sem telefone';
                  final sub = tipoInfo == 'profissional' ? (d['especialidade'] ?? 'Fisioterapia') : telefone;
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (tipoInfo == 'paciente' ? AppTheme.primary : AppTheme.secondary).withValues(alpha: 0.1),
                          child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?', style: TextStyle(color: (tipoInfo == 'paciente' ? AppTheme.primary : AppTheme.secondary), fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              Text(sub, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (tipoInfo == 'sintoma') {
                  final nivel = d['nivel_dor'] ?? 0;
                  final regiao = d['regiao'] ?? 'Genérico';
                  final desc = d['descricao'] ?? '';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(regiao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text('Dor $nivel/10', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(desc, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                        ],
                      ],
                    ),
                  );
                }
                
                if (tipoInfo == 'consulta') {
                  // Apenas um visual genérico de consulta de BI. Não tem joins aqui de nome pois foca no macro.
                  final dtInfo = d['data_hora'] ?? 'Sem data';
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_rounded, color: Colors.green),
                      title: const Text('Registro Mestre de Consulta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Data: $dtInfo', style: const TextStyle(fontSize: 12)),
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
