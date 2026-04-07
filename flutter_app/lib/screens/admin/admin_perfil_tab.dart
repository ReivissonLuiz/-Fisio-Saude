import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Aba de perfil exclusiva para Administradores.
/// Inclui seletor de visão de papel (ADM / Profissional / Paciente).
class AdminPerfilTab extends StatelessWidget {
  final String nome;
  final String email;
  final String activeView;
  final bool hasProfissional;
  final bool hasPaciente;
  final Future<void> Function() onLogout;
  final void Function(String) onSwitchView;

  const AdminPerfilTab({
    super.key,
    required this.nome,
    required this.email,
    required this.activeView,
    required this.hasProfissional,
    required this.hasPaciente,
    required this.onLogout,
    required this.onSwitchView,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.purple,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(
                          nome.isNotEmpty ? nome[0].toUpperCase() : 'A',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nome,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _activeViewLabel(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Conteúdo ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Seletor de Visão ──────────────────────────────────
                const Text(
                  'Mudar Visão',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Como administrador, você pode alternar entre diferentes tipos de acesso do sistema.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _buildViewTile(
                        icon: Icons.admin_panel_settings_rounded,
                        color: Colors.purple,
                        label: 'Administrador',
                        description: 'Dashboard, gestão completa do sistema',
                        viewKey: 'admin',
                        isFirst: true,
                        isLast: !hasProfissional && !hasPaciente,
                      ),
                      if (hasProfissional) ...[
                        const Divider(height: 1, color: AppTheme.divider, indent: 56),
                        _buildViewTile(
                          icon: Icons.medical_services_rounded,
                          color: AppTheme.secondary,
                          label: 'Fisioterapeuta',
                          description: 'Agenda de consultas e pacientes',
                          viewKey: 'profissional',
                          isFirst: false,
                          isLast: !hasPaciente,
                        ),
                      ],
                      if (hasPaciente) ...[
                        const Divider(height: 1, color: AppTheme.divider, indent: 56),
                        _buildViewTile(
                          icon: Icons.person_rounded,
                          color: AppTheme.primary,
                          label: 'Paciente',
                          description: 'Buscar fisios, saúde e consultas',
                          viewKey: 'paciente',
                          isFirst: false,
                          isLast: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Informações da conta ──────────────────────────────
                const Text(
                  'Informações da Conta',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                          Icons.badge_outlined, 'Função', 'Administrador'),
                      const Divider(
                          height: 1, color: AppTheme.divider, indent: 56),
                      _buildInfoTile(Icons.email_outlined, 'E-mail', email),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Configurações ─────────────────────────────────────
                const Text(
                  'Configurações',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                          Icons.notifications_none_rounded, 'Notificações',
                          () {}),
                      const Divider(
                          height: 1, color: AppTheme.divider, indent: 56),
                      _buildMenuTile(
                          Icons.help_outline_rounded, 'Ajuda e Suporte', () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Botão sair ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.error,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.divider),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sair da Conta',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _activeViewLabel() {
    switch (activeView) {
      case 'profissional':
        return 'Visão: Fisioterapeuta';
      case 'paciente':
        return 'Visão: Paciente';
      default:
        return 'Administrador';
    }
  }

  Widget _buildViewTile({
    required IconData icon,
    required Color color,
    required String label,
    required String description,
    required String viewKey,
    required bool isFirst,
    required bool isLast,
  }) {
    final bool isActive = activeView == viewKey;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: isActive ? null : () => onSwitchView(viewKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Ícone do papel
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isActive ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: color.withValues(alpha: isActive ? 1.0 : 0.6),
                    size: 22),
              ),
              const SizedBox(width: 14),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isActive ? color : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Indicador ativo / botão
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Ativo',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textSecondary, size: 20),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
