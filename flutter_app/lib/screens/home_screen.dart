/// Tela principal pós-login do +Físio +Saúde.
/// Usa a nova tabela unificada `usuario` com FK para `permissao`.
/// Permissões: 1=Paciente, 2=Profissional, 3=Administrador.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/audit_service.dart';
import '../widgets/notificacoes_panel.dart';
import 'paciente/paciente_home_tab.dart';
import 'paciente/agendar_consulta_screen.dart';
import 'paciente/buscar_fisio_tab.dart';
import 'paciente/minha_saude_tab.dart';
import 'paciente/meu_perfil_tab.dart';
import 'profissional/profissional_home_tab.dart';
import 'profissional/agenda_tab.dart';
import 'profissional/perfil_profissional_tab.dart';
import 'profissional/minha_disponibilidade_tab.dart';
import 'profissional/meus_pacientes_tab.dart';
import 'admin/admin_dashboard_tab.dart';
import 'admin/admin_management_tab.dart';
import 'admin/admin_audit_tab.dart';
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
  String? _avatarUrl;     // URL da foto de perfil do usuário logado
  int _idPermissao = 1;   // 1=Paciente, 2=Profissional, 3=Administrador

  bool _isLoadingSession = false;
  bool _sessionResolved = false;

  // Visão ativa no switcher (começa igual à permissão real do usuário)
  _VisaoAtiva _visaoAtiva = _VisaoAtiva.paciente;

  /// Consulta a abrir na aba Agenda (profissional), vinda de notificação.
  String? _pendingConsultaId;

  /// Subaba de Minha Saúde: 1 = Exercícios (notificação de recomendação).
  int? _pendingSaudeSubTab;

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
    _avatarUrl = _args['avatar_url'] as String?;
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

  // ── Chaves para persistência de estado entre reloads ────────────────────
  static const _kTabIndex  = 'pref_tab_index';
  static const _kVisaoAtiva = 'pref_visao_ativa';

  /// Salva aba e visão ativas no SharedPreferences.
  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTabIndex, _tabIndex);
    await prefs.setString(_kVisaoAtiva, _visaoAtiva.name);
  }

  /// Restaura aba e visão ativas do SharedPreferences.
  /// Deve ser chamado após o perfil do usuário ser carregado, para que
  /// a visão restaurada seja compatível com a permissão real do usuário.
  Future<void> _loadPrefs(int permissao) async {
    final prefs = await SharedPreferences.getInstance();
    final savedTab   = prefs.getInt(_kTabIndex) ?? 0;
    final savedVisao = prefs.getString(_kVisaoAtiva);

    // Determina a visão padrão para a permissão do usuário
    final visaoPadrao = _visaoFromPermissao(permissao);

    // Só restaura a visão se o usuário tiver permissão para ela
    _VisaoAtiva visaoRestaurada = visaoPadrao;
    if (savedVisao != null) {
      final candidata = _VisaoAtiva.values.firstWhere(
        (v) => v.name == savedVisao,
        orElse: () => visaoPadrao,
      );
      // Valida permissão: admin pode ver tudo; profissional não pode ver admin
      final bool permitido = switch (candidata) {
        _VisaoAtiva.admin        => permissao == Permissao.administrador,
        _VisaoAtiva.profissional => permissao >= Permissao.profissional,
        _VisaoAtiva.paciente     => true,
      };
      visaoRestaurada = permitido ? candidata : visaoPadrao;
    }

    // Número de abas por visão — evita índice fora do range
    final maxTab = switch (visaoRestaurada) {
      _VisaoAtiva.admin        => 3,
      _VisaoAtiva.profissional => 4,
      _VisaoAtiva.paciente     => 3,
    };

    setState(() {
      _visaoAtiva = visaoRestaurada;
      _tabIndex   = savedTab.clamp(0, maxTab);
    });
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
      final idPerm = data['id_permissao'] as int? ?? 1;

      setState(() {
        _supabaseUserId = user.id;
        _usuarioId = data['id'] as String?;
        _nome = data['nome'] as String? ?? user.email ?? 'Usuário';
        _email = data['email'] as String? ?? user.email ?? '';
        _avatarUrl = data['avatar_url'] as String?;
        _idPermissao = idPerm;
        // ignore: unused_local_variable
        final tipo = permissaoData?['nome'] as String? ??
            Permissao.nomePorNivel(_idPermissao);
        _isLoadingSession = false;
      });

      // Restaura aba e visão persistidas (após saber a permissão real)
      await _loadPrefs(idPerm);
    } catch (_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    }
  }

  Future<void> _logout() async {
    await AuditService.instance.logLogout();
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
    _savePrefs();
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

    Widget content;

    // ---------------------------------------------------------------
    // Visão do Administrador
    // ---------------------------------------------------------------
    if (_visaoAtiva == _VisaoAtiva.admin) {
      final adminTabs = [
        AdminDashboardTab(key: UniqueKey(), adminId: _usuarioId ?? ''),
        AdminManagementTab(key: UniqueKey()),
        const AdminAuditTab(),
        AdminPerfilTab(
          key: UniqueKey(),
          nome: _nome,
          email: _email,
          usuarioId: _usuarioId,
          supabaseUserId: _supabaseUserId,
          avatarUrl: _avatarUrl,
          onLogout: _logout,
        ),
      ];

      content = Scaffold(
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
          onDestinationSelected: (i) {
            final abas = ['Dashboard', 'Gestão', 'Auditoria', 'Perfil'];
            AuditService.instance.logNavegacaoAba(
              nomeAba: i < abas.length ? abas[i] : 'aba_$i',
              perfil: 'administrador',
            );
            setState(() => _tabIndex = i);
            _savePrefs();
          },
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
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security_rounded,
                    color: Color(0xFF7B1FA2)),
                label: 'Auditoria'),
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
    else if (_visaoAtiva == _VisaoAtiva.profissional) {
      final profId = _usuarioId ?? '';
      final profTabs = [
        ProfissionalHomeTab(
          profissionalId: profId,
          nome: _nome,
          profissionalAvatar: _avatarUrl,
          onOpenConsultaFromNotificacao: (consultaId) {
            setState(() {
              _pendingConsultaId = consultaId;
              _tabIndex = 1;
            });
          },
        ),
        AgendaTab(
          profissionalId: profId,
          initialConsultaId: _pendingConsultaId,
          onInitialConsultaHandled: () {
            if (_pendingConsultaId != null) {
              setState(() => _pendingConsultaId = null);
            }
          },
        ),
        MeusPacientesTab(
          profissionalId: _usuarioId ?? '',
          profissionalNome: _nome,
          profissionalAvatar: _avatarUrl,
        ),
        MinhaDisponibilidadeTab(profissionalId: _usuarioId ?? ''),

        PerfilProfissionalTab(
          key: UniqueKey(),
          profissionalId: _usuarioId ?? '',
          nome: _nome,
          email: _email,
          supabaseUserId: _supabaseUserId,
          onLogout: _logout,
        ),
      ];

      content = Scaffold(
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
          onDestinationSelected: (i) {
            final abas = ['Início', 'Agenda', 'Pacientes', 'Horários', 'Perfil'];
            AuditService.instance.logNavegacaoAba(
              nomeAba: i < abas.length ? abas[i] : 'aba_$i',
              perfil: 'profissional',
            );
            setState(() => _tabIndex = i);
            _savePrefs();
          },
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.secondary.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.secondary),
                label: 'Início'),
            NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note_rounded, color: Color(0xFF9C27B0)),
                label: 'Agenda'),
            NavigationDestination(
                icon: Icon(Icons.people_outline_rounded),
                selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF00897B)),
                label: 'Pacientes'),
            NavigationDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule_rounded, color: Colors.teal),
                label: 'Horários'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded, color: AppTheme.accent),
                label: 'Perfil'),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------
    // Visão do Paciente (padrão)
    // ---------------------------------------------------------------
    else {
      final usuarioIdFinal = _usuarioId ?? '';
      void irParaExerciciosRecomendados() {
        setState(() {
          _tabIndex = 2;
          _pendingSaudeSubTab = 1;
        });
      }

      final patientTabs = [
        PacienteHomeTab(
          pacienteId: usuarioIdFinal,
          nome: _nome,
          avatarUrl: _avatarUrl,
          onOpenExerciciosRecomendados: irParaExerciciosRecomendados,
        ),
        BuscarFisioTab(pacienteId: usuarioIdFinal),
        MinhaSaudeTab(
          pacienteId: usuarioIdFinal,
          initialSubTabIndex: _pendingSaudeSubTab,
          onInitialSubTabHandled: () {
            if (_pendingSaudeSubTab != null) {
              setState(() => _pendingSaudeSubTab = null);
            }
          },
        ),
        MeuPerfilTab(
            pacienteId: usuarioIdFinal,
            nome: _nome,
            email: _email,
            onLogout: _logout),
      ];

      content = Scaffold(
      backgroundColor: AppTheme.background,
      endDrawer: NotificacoesPanel(
        usuarioId: usuarioIdFinal,
        usuarioNome: _nome,
        usuarioAvatar: _avatarUrl,
        onNavigateToSaudeTab: irParaExerciciosRecomendados,
        onAgendarNovaConsulta: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AgendarConsultaScreen(pacienteId: usuarioIdFinal),
            ),
          );
        },
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
        onDestinationSelected: (i) {
          final abas = ['Início', 'Buscar Fisio', 'Saúde', 'Meu Perfil'];
          AuditService.instance.logNavegacaoAba(
            nomeAba: i < abas.length ? abas[i] : 'aba_$i',
            perfil: 'paciente',
          );
          setState(() => _tabIndex = i);
          _savePrefs();
        },
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

    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() {
            _tabIndex = 0;
          });
        }
      },
      child: content,
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
