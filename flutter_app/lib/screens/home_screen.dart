/// Tela principal pós-login do +Fisio +Saúde.
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
import 'profissional/agenda_tab.dart';
import 'profissional/perfil_profissional_tab.dart';
import 'admin/admin_dashboard_tab.dart';
import 'admin/admin_management_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final _api = ApiService();

  Map<String, dynamic> _args = {};
  String _nome = 'Usuário';
  String _tipo = 'Paciente';
  String _email = '';
  String? _supabaseUserId;
  String? _pacienteId;
  String? _profissionalId;
  String? _adminId;
  bool _isProfissional = false;
  bool _isAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args = (ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?) ??
        {};
    _nome = _args['nome'] as String? ?? 'Usuário';
    _tipo = _args['tipo'] as String? ?? 'Paciente';
    _email = _args['email'] as String? ?? '';
    _supabaseUserId = _args['id'] as String?;
    _pacienteId = _args['id_paciente'] as String?;
    _profissionalId = _args['id_profissional'] as String?;
    _adminId = _args['id_administrador'] as String?;
    _isProfissional = _tipo == 'Profissional';
    _isAdmin = _tipo == 'Administrador';
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // --- Visão do Administrador (3 Menus) ------------------------------
    if (_isAdmin) {
      final adminTabs = [
        AdminDashboardTab(key: UniqueKey(), adminId: _adminId ?? ''),
        _ProfissionalViewTabs(profissionalId: _profissionalId, nome: _nome),
        _PacienteViewTabs(pacienteId: _pacienteId, nome: _nome),
        AdminManagementTab(key: UniqueKey()),
        PerfilProfissionalTab(
            key: UniqueKey(),
            profissionalId: _profissionalId ?? '',
            nome: _nome,
            email: _email,
            supabaseUserId: _supabaseUserId,
            pacienteId: _pacienteId,
            adminId: _adminId,
            isAdmin: true,
            onLogout: _logout,
            onPacienteRoleAdded: (id) => setState(() => _pacienteId = id),
            onProfissionalRoleAdded: (id) => setState(() => _profissionalId = id),
        ),
      ];

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(child: adminTabs[_tabIndex]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: Colors.purple.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded, color: Colors.purple), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services_rounded, color: AppTheme.secondary), label: 'Profissional'),
            NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_alt_rounded, color: AppTheme.primary), label: 'Paciente'),
            NavigationDestination(icon: Icon(Icons.settings_suggest_outlined), selectedIcon: Icon(Icons.settings_suggest_rounded, color: Colors.orange), label: 'Gestão'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent), label: 'Perfil'),
          ],
        ),
      );
    }

    // --- Visão do Profissional (Menu Profissional + Paciente) ----------
    if (_isProfissional) {
      final profTabs = [
        ProfissionalHomeTab(profissionalId: _profissionalId ?? '', nome: _nome),
        AgendaTab(profissionalId: _profissionalId ?? ''),
        _PacienteViewTabs(pacienteId: _pacienteId, nome: _nome),
        PerfilProfissionalTab(
            key: UniqueKey(),
            profissionalId: _profissionalId ?? '',
            nome: _nome,
            email: _email,
            supabaseUserId: _supabaseUserId,
            pacienteId: _pacienteId,
            isAdmin: false,
            onLogout: _logout,
            onPacienteRoleAdded: (id) => setState(() => _pacienteId = id),
        ),
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
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary), label: 'Início'),
            NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded, color: Color(0xFF9C27B0)), label: 'Agenda'),
            NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety_rounded, color: AppTheme.primary), label: 'Sou Paciente'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent), label: 'Perfil'),
          ],
        ),
      );
    }

    // --- Visão do Paciente (Original) ----------------------------------
    final patientTabs = [
      PacienteHomeTab(pacienteId: _pacienteId ?? '', nome: _nome),
      const BuscarFisioTab(),
      MinhaSaudeTab(pacienteId: _pacienteId ?? ''),
      MeuPerfilTab(pacienteId: _pacienteId ?? '', nome: _nome, email: _email, onLogout: _logout),
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search_rounded, color: AppTheme.primary), label: 'Buscar Fisio'),
          NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart_rounded, color: Color(0xFFE91E63)), label: 'Saúde'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent), label: 'Meu Perfil'),
        ],
      ),
    );
  }
}

// --- Helpers de Visão Multi-função ------------------------------------------

class _ProfissionalViewTabs extends StatelessWidget {
  final String? profissionalId;
  final String nome;
  const _ProfissionalViewTabs({required this.profissionalId, required this.nome});

  @override
  Widget build(BuildContext context) {
    if (profissionalId == null) return const Center(child: Text('Acesso profissional Não disponível.'));
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Visão de Fisioterapeuta', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary)),
        ),
        Expanded(child: AgendaTab(profissionalId: profissionalId!)),
      ],
    );
  }
}

class _PacienteViewTabs extends StatelessWidget {
  final String? pacienteId;
  final String nome;
  const _PacienteViewTabs({required this.pacienteId, required this.nome});

  @override
  Widget build(BuildContext context) {
    if (pacienteId == null) return const Center(child: Text('Acesso paciente Não disponível.'));
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Visão de Paciente', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ),
        Expanded(child: BuscarFisioTab()),
      ],
    );
  }
}




