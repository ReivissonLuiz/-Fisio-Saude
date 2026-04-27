/// Tela principal pós-login do +Físio +Saúde.
/// Usa a nova tabela unificada `usuario` com FK para `permissao`.
/// Permissões: 1=Paciente, 2=Profissional, 3=Administrador.
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/notificacoes_panel.dart';
import 'paciente/paciente_home_tab.dart';
import 'paciente/buscar_fisio_tab.dart';
import 'paciente/minha_saude_tab.dart';
import 'paciente/meu_perfil_tab.dart';
import 'profissional/profissional_home_tab.dart';
import 'profissional/agenda_tab.dart';
import 'profissional/perfil_profissional_tab.dart';
import 'admin/admin_dashboard_tab.dart';
import 'admin/admin_management_tab.dart';
import 'admin/admin_perfil_tab.dart';

/// Modos de visão disponíveis para o usuário (para o switcher superior).
enum _VisaoAtiva { admin, profissional, paciente }

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
  String _email = '';
  String? _supabaseUserId;
  String? _usuarioId;     // ID interno da tabela `usuario`
  int _idPermissao = 1;   // 1=Paciente, 2=Profissional, 3=Administrador

  bool _isLoadingSession = false;
  bool _sessionResolved = false;

  // Visão ativa no switcher (começa igual à permissão real do usuário)
  _VisaoAtiva _visaoAtiva = _VisaoAtiva.paciente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionResolved) return;
    _sessionResolved = true;

    _args = (ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?) ??
        {};

    _nome = _args['nome'] as String? ?? 'Usuário';
    _email = _args['email'] as String? ?? '';
    _supabaseUserId = _args['id'] as String?;
    _usuarioId = _args['id_usuario'] as String?;
    _idPermissao = (_args['id_permissao'] as int?) ?? 1;
    _visaoAtiva = _visaoFromPermissao(_idPermissao);

    // Sem argumentos = reload da página (Flutter Web perde os args)
    if (_args.isEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resolveFromSession());
    }
  }

  _VisaoAtiva _visaoFromPermissao(int permissao) {
    switch (permissao) {
      case Permissao.administrador:
        return _VisaoAtiva.admin;
      case Permissao.profissional:
        return _VisaoAtiva.profissional;
      default:
        return _VisaoAtiva.paciente;
    }
  }

  /// Recupera dados do usuário logado via Supabase quando os argumentos
  /// de navegação estão ausentes (ex: reload da página no browser).
  Future<void> _resolveFromSession() async {
    final user = _api.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
      return;
    }

    setState(() => _isLoadingSession = true);

    try {
      final result = await _api.getUsuarioPorSupabaseId(user.id);

      if (!mounted) return;

      if (result['success'] != true) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
        return;
      }

      final data = result['data'] as Map<String, dynamic>;
      final permissaoData = data['permissao'] as Map<String, dynamic>?;

      setState(() {
        _supabaseUserId = user.id;
        _usuarioId = data['id'] as String?;
        _nome = data['nome'] as String? ?? user.email ?? 'Usuário';
        _email = data['email'] as String? ?? user.email ?? '';
        _idPermissao = data['id_permissao'] as int? ?? 1;
        // ignore: unused_local_variable
        final tipo = permissaoData?['nome'] as String? ??
            Permissao.nomePorNivel(_idPermissao);
        _visaoAtiva = _visaoFromPermissao(_idPermissao);
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

  void _switchVisao(_VisaoAtiva novaVisao) {
    if (_visaoAtiva == novaVisao) return;
    setState(() {
      _visaoAtiva = novaVisao;
      _tabIndex = 0;
    });
  }

  // ── Banner de alternância de visão ───────────────────────────────────────
  Widget _buildViewSwitcherBanner() {
    // Define quais botões mostrar conforme permissão real do usuário
    final isAdmin = _idPermissao == Permissao.administrador;
    final isProfissional = _idPermissao == Permissao.profissional;

    if (!isAdmin && !isProfissional) return const SizedBox.shrink();

    final List<_SwitcherButton> buttons = [];

    if (isAdmin) {
      buttons.add(const _SwitcherButton(
        label: 'Administrador',
        icon: Icons.admin_panel_settings_rounded,
        visao: _VisaoAtiva.admin,
        activeColor: Colors.purple,
      ));
    }

    buttons.add(const _SwitcherButton(
      label: 'Profissional',
      icon: Icons.medical_services_rounded,
      visao: _VisaoAtiva.profissional,
      activeColor: AppTheme.secondary,
    ));

    buttons.add(const _SwitcherButton(
      label: 'Paciente',
      icon: Icons.person_rounded,
      visao: _VisaoAtiva.paciente,
      activeColor: AppTheme.primary,
    ));

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: buttons.map((b) {
                  final isActive = _visaoAtiva == b.visao;
                  return GestureDetector(
                    onTap: () => _switchVisao(b.visao),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? b.activeColor.withValues(alpha: 0.12)
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? b.activeColor
                              : AppTheme.divider,
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(b.icon,
                              size: 14,
                              color: isActive ? b.activeColor : AppTheme.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            b.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              color: isActive ? b.activeColor : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ---------------------------------------------------------------
    // Visão do Administrador
    // ---------------------------------------------------------------
    if (_visaoAtiva == _VisaoAtiva.admin) {
      final adminTabs = [
        AdminDashboardTab(key: UniqueKey(), adminId: _usuarioId ?? ''),
        AdminManagementTab(key: UniqueKey()),
        AdminPerfilTab(
          key: UniqueKey(),
          nome: _nome,
          email: _email,
          usuarioId: _usuarioId,
          supabaseUserId: _supabaseUserId,
          onLogout: _logout,
        ),
      ];

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildViewSwitcherBanner(),
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
                selectedIcon:
                    Icon(Icons.analytics_rounded, color: Colors.purple),
                label: 'Dashboard'),
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

    // ---------------------------------------------------------------
    // Visão do Profissional
    // ---------------------------------------------------------------
    if (_visaoAtiva == _VisaoAtiva.profissional) {
      final profTabs = [
        ProfissionalHomeTab(
            profissionalId: _usuarioId ?? '', nome: _nome),
        AgendaTab(profissionalId: _usuarioId ?? ''),
        PerfilProfissionalTab(
          key: UniqueKey(),
          profissionalId: _usuarioId ?? '',
          nome: _nome,
          email: _email,
          supabaseUserId: _supabaseUserId,
          onLogout: _logout,
        ),
      ];

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildViewSwitcherBanner(),
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
                icon: Icon(Icons.person_outline),
                selectedIcon:
                    Icon(Icons.person_rounded, color: AppTheme.accent),
                label: 'Perfil'),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------
    // Visão do Paciente (padrão)
    // ---------------------------------------------------------------
    final usuarioIdFinal = _usuarioId ?? '';
    final patientTabs = [
      PacienteHomeTab(pacienteId: usuarioIdFinal, nome: _nome),
      BuscarFisioTab(pacienteId: usuarioIdFinal),
      MinhaSaudeTab(pacienteId: usuarioIdFinal),
      MeuPerfilTab(
          pacienteId: usuarioIdFinal,
          nome: _nome,
          email: _email,
          onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      endDrawer: NotificacoesPanel(
        usuarioId: usuarioIdFinal,
        onNavigateToAgenda: () => setState(() => _tabIndex = 0),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildViewSwitcherBanner(),
            Expanded(child: patientTabs[_tabIndex]),
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
}

class _SwitcherButton {
  final String label;
  final IconData icon;
  final _VisaoAtiva visao;
  final Color activeColor;

  const _SwitcherButton({
    required this.label,
    required this.icon,
    required this.visao,
    required this.activeColor,
  });
}
