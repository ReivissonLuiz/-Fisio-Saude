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
import 'profissional/profissional_home_tab.dart';
import 'profissional/meus_pacientes_tab.dart';
import 'profissional/agenda_tab.dart';
import 'profissional/perfil_profissional_tab.dart';

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
  late final String? _profissionalId;
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
    _profissionalId = _args['id_profissional'] as String?;
    _isPaciente = _tipo == 'Paciente';
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // ── Visão do Profissional — abas ──────────────────────────────────────────
    if (!_isPaciente) {
      final profTabs = [
        ProfissionalHomeTab(
            profissionalId: _profissionalId ?? '', nome: _nome),
        MeusPacientesTab(profissionalId: _profissionalId ?? ''),
        AgendaTab(profissionalId: _profissionalId ?? ''),
        PerfilProfissionalTab(
            profissionalId: _profissionalId ?? '',
            nome: _nome,
            email: _email,
            onLogout: _logout),
      ];

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(child: profTabs[_tabIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon:
                  Icon(Icons.dashboard_rounded, color: AppTheme.primary),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon:
                  Icon(Icons.people_alt_rounded, color: AppTheme.secondary),
              label: 'Pacientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded,
                  color: Color(0xFF9C27B0)),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent),
              label: 'Perfil',
            ),
          ],
        ),
      );
    }

    // ── Visão do Paciente — abas ──────────────────────────────────────────────
    final patientTabs = [
      PacienteHomeTab(pacienteId: _pacienteId ?? '', nome: _nome),
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
      body: SafeArea(child: patientTabs[_tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
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
            selectedIcon:
                Icon(Icons.monitor_heart_rounded, color: Color(0xFFE91E63)),
            label: 'Saúde',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent),
            label: 'Meu Perfil',
          ),
        ],
      ),
    );
  }
}

