/// home_screen.dart
/// Tela principal pós-login do +Físio +Saúde.
/// Paciente → BottomNavigationBar com 4 abas funcionais.
/// Profissional → Dashboard com cards de acesso rápido (em breve).
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'paciente/paciente_home_tab.dart';
import 'paciente/buscar_fisio_tab.dart';
import 'paciente/minha_saude_tab.dart';
import 'paciente/meu_perfil_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _api = ApiService();

  late final Map<String, dynamic> _args;
  late final String _nome;
  late final String _tipo;
  late final String _email;
  late final String? _pacienteId;
  late final bool _isPaciente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args = (ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?) ??
        {};
    _nome = _args['nome'] as String? ?? 'Usuário';
    _tipo = _args['tipo'] as String? ?? 'Paciente';
    _email = _args['email'] as String? ?? '';
    _pacienteId = _args['id_paciente'] as String?;
    _isPaciente = _tipo == 'Paciente';
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // ── Visão do Profissional ─────────────────────────────────────────────────
    if (!_isPaciente) {
      return _ProfissionalHome(nome: _nome, onLogout: _logout);
    }

    // ── Visão do Paciente — abas ──────────────────────────────────────────────
    final tabs = [
      PacienteHomeTab(
          pacienteId: _pacienteId ?? '',
          nome: _nome),
      const BuscarFisioTab(),
      MinhaSaudeTab(pacienteId: _pacienteId ?? ''),
      MeuPerfilTab(
          pacienteId: _pacienteId ?? '',
          nome: _nome,
          email: _email,
          onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(child: tabs[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior:
            NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
            label: 'Buscar Fisio',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart_rounded,
                color: Color(0xFFE91E63)),
            label: 'Saúde',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon:
                Icon(Icons.person_rounded, color: AppTheme.accent),
            label: 'Meu Perfil',
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard do Profissional (placeholder) ──────────────────────────────────

class _ProfissionalHome extends StatelessWidget {
  final String nome;
  final Future<void> Function() onLogout;

  const _ProfissionalHome({required this.nome, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.primary,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Olá, ${nome.split(' ').first}! 👋',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withOpacity(0.2),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: const Text('🩺 Fisioterapeuta',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ),
                                ],
                              ),
                              CircleAvatar(
                                radius: 26,
                                backgroundColor:
                                    Colors.white.withOpacity(0.25),
                                child: Text(
                                  nome.isNotEmpty
                                      ? nome[0].toUpperCase()
                                      : 'F',
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded,
                      color: Colors.white),
                  tooltip: 'Sair',
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppTheme.secondary.withOpacity(0.15),
                        AppTheme.primary.withOpacity(0.1)
                      ]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🚀', style: TextStyle(fontSize: 32)),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Painel do Profissional',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary)),
                              SizedBox(height: 4),
                              Text(
                                'As funcionalidades do profissional serão disponibilizadas em breve.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Acesso Rápido',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: const [
                      _QuickCard(
                          icon: Icons.people_rounded,
                          label: 'Pacientes',
                          color: AppTheme.primary),
                      _QuickCard(
                          icon: Icons.calendar_month_rounded,
                          label: 'Agenda',
                          color: AppTheme.secondary),
                      _QuickCard(
                          icon: Icons.bar_chart_rounded,
                          label: 'Relatórios',
                          color: Color(0xFF9C27B0)),
                      _QuickCard(
                          icon: Icons.person_rounded,
                          label: 'Meu Perfil',
                          color: AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Card (profissional) ────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickCard(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Em breve',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
