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
  Map<String, dynamic> _stats = {
    'pacientes': 0,
    'profissionais': 0,
    'consultas': 0,
    'novas_contas': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final resPac = await _api.getAllPacientes();
      final resProf = await _api.getAllProfissionais();
      
      if (mounted) {
        setState(() {
          _stats = {
            'pacientes': resPac['success'] ? (resPac['data'] as List).length : 0,
            'profissionais': resProf['success'] ? (resProf['data'] as List).length : 0,
            'consultas': 356,
            'faturamento_estimado': 'R\$ 15.420,00',
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard ADM', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.purple), onPressed: _loadStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MÃ©tricas de Crescimento (BI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Grid de KPIs
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _KPICard(label: 'Total Pacientes', value: _stats['pacientes'].toString(), icon: Icons.people_rounded, color: AppTheme.primary),
                      _KPICard(label: 'Fisioterapeutas', value: _stats['profissionais'].toString(), icon: Icons.medical_services_rounded, color: AppTheme.secondary),
                      _KPICard(label: 'Consultas Realizadas', value: _stats['consultas'].toString(), icon: Icons.event_available_rounded, color: Colors.green),
                      _KPICard(label: 'Faturamento Total', value: _stats['faturamento_estimado'], icon: Icons.payments_rounded, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // SeÃ§Ã£o Insights
                  const Text('Recentes e Insights', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const _InsightItem(
                    title: 'Aumento de 12% em registros',
                    description: 'Comparado ao mÃªs anterior, houve um aumento na criaÃ§Ã£o de contas de profissionais.',
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                  ),
                  const _InsightItem(
                    title: 'Novos Profissionais Pendentes',
                    description: 'Existem 5 profissionais aguardando revisão cadastral (opcional).',
                    icon: Icons.notification_important_rounded,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 32),
                  
                  // Gráfico de Barras Fictício
                  const Text('Consultas Mensais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _SimpleBarChart(),
                  
                  const SizedBox(height: 40),
                ],
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

  const _KPICard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: color, size: 20),
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.north_east_rounded, size: 10, color: Colors.green)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _InsightItem({required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(40, 'Jan'),
          _bar(60, 'Fev'),
          _bar(100, 'Mar'),
          _bar(80, 'Abr'),
          _bar(120, 'Mai'),
          _bar(140, 'Jun'),
        ],
      ),
    );
  }

  Widget _bar(double height, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(width: 24, height: height, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }
}
