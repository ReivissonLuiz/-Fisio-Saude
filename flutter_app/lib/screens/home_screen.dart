/// Tela principal pós-login do +Fisio +Saúde.
/// Paciente → BottomNavigationBar com 4 abas funcionais.
/// Profissional → Dashboard com cards de acesso rápido (em breve).
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  /// Papel ativo para ADM: 'admin' | 'profissional' | 'paciente'
  /// Permite que o ADM navegue livremente entre as visões de cada papel.
  String _activeView = 'admin';

  // Controle de recuperação de sessão após reload da página
  bool _isLoadingSession = false;
  bool _sessionResolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionResolved) return; // evita rodar mais de uma vez
    _sessionResolved = true;

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

    // Sem argumentos = reload da página (Flutter Web perde os args)
    // Recupera o tipo de usuário direto da sessão Supabase
    if (_args.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resolveFromSession());
    }
  }

  /// Recupera dados do usuário logado via Supabase quando os argumentos
  /// de navegação estão ausentes (ex: reload da página no browser).
  Future<void> _resolveFromSession() async {
    final user = _api.currentUser;
    if (user == null) {
      // Sem sessão ativa → vai para tela inicial
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
      return;
    }

    setState(() => _isLoadingSession = true);

    try {
      final loginData = await Supabase.instance.client
          .from('login')
          .select('tipo_usuario, id_paciente, id_profissional, id_administrador')
          .eq('supabase_user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (loginData == null) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        return;
      }

      setState(() {
        _tipo = loginData['tipo_usuario'] as String? ?? 'Paciente';
        _nome = (user.userMetadata?['nome'] as String?) ??
            user.email ??
            'Usuário';
        _email = user.email ?? '';
        _pacienteId = loginData['id_paciente']?.toString();
        _profissionalId = loginData['id_profissional']?.toString();
        _adminId = loginData['id_administrador']?.toString();
        _isProfissional = _tipo == 'Profissional';
        _isAdmin = _tipo == 'Administrador';
        _isLoadingSession = false;
      });
    } catch (_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  /// Barra de troca de papél — exibida apenas para ADM no topo da tela.
  Widget _buildRoleSwitcher() {
    final bool temProfissional =
        _profissionalId != null && _profissionalId!.isNotEmpty;
    final bool temPaciente = _pacienteId != null && _pacienteId!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('Visão:',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
          const SizedBox(width: 10),
          _RoleChip(
            label: 'ADM',
            icon: Icons.admin_panel_settings_rounded,
            color: Colors.purple,
            isActive: _activeView == 'admin',
            onTap: () => setState(() {
              _activeView = 'admin';
              _tabIndex = 0;
            }),
          ),
          if (temProfissional) ...[
            const SizedBox(width: 6),
            _RoleChip(
              label: 'Profissional',
              icon: Icons.medical_services_rounded,
              color: AppTheme.secondary,
              isActive: _activeView == 'profissional',
              onTap: () => setState(() {
                _activeView = 'profissional';
                _tabIndex = 0;
              }),
            ),
          ],
          if (temPaciente) ...[
            const SizedBox(width: 6),
            _RoleChip(
              label: 'Paciente',
              icon: Icons.person_rounded,
              color: AppTheme.primary,
              isActive: _activeView == 'paciente',
              onTap: () => setState(() {
                _activeView = 'paciente';
                _tabIndex = 0;
              }),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aguardando recuperação da sessão após reload da página
    if (_isLoadingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ---------------------------------------------------------------
    // Visão do Administrador — suporta troca de papel ativo
    // ---------------------------------------------------------------
    if (_isAdmin) {
      // --- Visão ADM pura ------------------------------------
      if (_activeView == 'admin') {
        final adminTabs = [
          AdminDashboardTab(key: UniqueKey(), adminId: _adminId ?? ''),
          _ProfissionalViewTabs(
            profissionalId: _profissionalId,
            nome: _nome,
            onNavigateToProfile: () => setState(() => _tabIndex = 4),
          ),
          _PacienteViewTabs(
            pacienteId: _pacienteId,
            nome: _nome,
            onNavigateToProfile: () => setState(() => _tabIndex = 4),
          ),
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
            onProfissionalRoleAdded: (id) =>
                setState(() => _profissionalId = id),
          ),
        ];


        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildRoleSwitcher(),
                Expanded(child: adminTabs[_tabIndex]),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            backgroundColor: Colors.white,
            indicatorColor: Colors.purple.withValues(alpha: 0.12),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics_rounded,
                      color: Colors.purple),
                  label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.medical_services_outlined),
                  selectedIcon: Icon(Icons.medical_services_rounded,
                      color: AppTheme.secondary),
                  label: 'Profissional'),
              NavigationDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_alt_rounded,
                      color: AppTheme.primary),
                  label: 'Paciente'),
              NavigationDestination(
                  icon: Icon(Icons.settings_suggest_outlined),
                  selectedIcon: Icon(Icons.settings_suggest_rounded,
                      color: Colors.orange),
                  label: 'Gestão'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon:
                      Icon(Icons.person_rounded, color: AppTheme.accent),
                  label: 'Perfil'),
            ],
          ),
        );
      }

      // --- ADM visualizando como Profissional ----------------
      if (_activeView == 'profissional' &&
          _profissionalId != null &&
          _profissionalId!.isNotEmpty) {
        final profTabs = [
          ProfissionalHomeTab(
              profissionalId: _profissionalId!, nome: _nome),
          AgendaTab(profissionalId: _profissionalId!),
          _PacienteViewTabs(
            pacienteId: _pacienteId,
            nome: _nome,
            onNavigateToProfile: () => setState(() => _tabIndex = 3),
          ),
          PerfilProfissionalTab(
            key: UniqueKey(),
            profissionalId: _profissionalId!,
            nome: _nome,
            email: _email,
            supabaseUserId: _supabaseUserId,
            pacienteId: _pacienteId,
            adminId: _adminId,
            isAdmin: true,
            onLogout: _logout,
            onPacienteRoleAdded: (id) => setState(() => _pacienteId = id),
            onProfissionalRoleAdded: (id) =>
                setState(() => _profissionalId = id),
          ),
        ];

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildRoleSwitcher(),
                Expanded(child: profTabs[_tabIndex]),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            backgroundColor: Colors.white,
            indicatorColor: AppTheme.secondary.withValues(alpha: 0.12),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded,
                      color: AppTheme.secondary),
                  label: 'Início'),
              NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note_rounded,
                      color: Color(0xFF9C27B0)),
                  label: 'Agenda'),
              NavigationDestination(
                  icon: Icon(Icons.health_and_safety_outlined),
                  selectedIcon: Icon(Icons.health_and_safety_rounded,
                      color: AppTheme.primary),
                  label: 'Sou Paciente'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon:
                      Icon(Icons.person_rounded, color: AppTheme.accent),
                  label: 'Perfil'),
            ],
          ),
        );
      }

      // --- ADM visualizando como Paciente --------------------
      if (_activeView == 'paciente' &&
          _pacienteId != null &&
          _pacienteId!.isNotEmpty) {
        final patientTabsAdm = [
          PacienteHomeTab(pacienteId: _pacienteId!, nome: _nome),
          const BuscarFisioTab(),
          MinhaSaudeTab(pacienteId: _pacienteId!),
          MeuPerfilTab(
              pacienteId: _pacienteId!,
              nome: _nome,
              email: _email,
              onLogout: _logout),
        ];

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildRoleSwitcher(),
                Expanded(child: patientTabsAdm[_tabIndex]),
              ],
            ),
          ),
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
                  selectedIcon:
                      Icon(Icons.home_rounded, color: AppTheme.primary),
                  label: 'Início'),
              NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon:
                      Icon(Icons.search_rounded, color: AppTheme.primary),
                  label: 'Buscar Fisio'),
              NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart_rounded,
                      color: Color(0xFFE91E63)),
                  label: 'Saúde'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon:
                      Icon(Icons.person_rounded, color: AppTheme.accent),
                  label: 'Meu Perfil'),
            ],
          ),
        );
      }

      // Fallback: se o papel selecionado não está ativado, volta para admin
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => setState(() { _activeView = 'admin'; _tabIndex = 0; }));
    }

    // ---------------------------------------------------------------
    // Visão do Profissional (Menu Profissional + Paciente)
    // ---------------------------------------------------------------
    if (_isProfissional) {
      final profTabs = [
        ProfissionalHomeTab(
            profissionalId: _profissionalId ?? '', nome: _nome),
        AgendaTab(profissionalId: _profissionalId ?? ''),
        _PacienteViewTabs(
          pacienteId: _pacienteId,
          nome: _nome,
          // O perfil do Profissional é sempre a última aba (index 3)
          onNavigateToProfile: () => setState(() => _tabIndex = 3),
        ),
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
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon:
                    Icon(Icons.dashboard_rounded, color: AppTheme.primary),
                label: 'Início'),
            NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note_rounded,
                    color: Color(0xFF9C27B0)),
                label: 'Agenda'),
            NavigationDestination(
                icon: Icon(Icons.health_and_safety_outlined),
                selectedIcon: Icon(Icons.health_and_safety_rounded,
                    color: AppTheme.primary),
                label: 'Sou Paciente'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon:
                    Icon(Icons.person_rounded, color: AppTheme.accent),
                label: 'Perfil'),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------
    // Visão do Paciente (Original 4 abas)
    // ----------------------------------------------------------------------------------
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
  /// Callback chamado quando o ADM clica em "Ir para o Perfil" para ativar o papel
  final VoidCallback? onNavigateToProfile;

  const _ProfissionalViewTabs({
    required this.profissionalId,
    required this.nome,
    this.onNavigateToProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (profissionalId == null || profissionalId!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medical_services_outlined,
                    size: 64, color: AppTheme.secondary.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Papel de Fisioterapeuta não ativado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Acesse a aba "Perfil" para ativar o papel de Fisioterapeuta e ter acesso à agenda e demais funcionalidades.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onNavigateToProfile,
                icon: const Icon(Icons.person_rounded),
                label: const Text('Ir para o Perfil e Ativar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Visão de Fisioterapeuta',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary),
          ),
        ),
        Expanded(child: AgendaTab(profissionalId: profissionalId!)),
      ],
    );
  }
}

class _PacienteViewTabs extends StatelessWidget {
  final String? pacienteId;
  final String nome;
  /// Callback chamado quando o ADM/Profissional clica em "Ir para o Perfil" para ativar o papel
  final VoidCallback? onNavigateToProfile;

  const _PacienteViewTabs({
    required this.pacienteId,
    required this.nome,
    this.onNavigateToProfile,
  });

  @override
  Widget build(BuildContext context) {
    if (pacienteId == null || pacienteId!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline_rounded,
                    size: 64, color: AppTheme.primary.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Papel de Paciente não ativado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Acesse a aba "Perfil" para ativar o papel de Paciente e ter acesso à área de saúde.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onNavigateToProfile,
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Ir para o Perfil e Ativar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Visão de Paciente',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
          ),
        ),
        Expanded(child: BuscarFisioTab()),
      ],
    );
  }
}

// --- Chip de troca de papel (usado pelo seletor de visão do ADM) -------------

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: isActive ? color : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? color : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

