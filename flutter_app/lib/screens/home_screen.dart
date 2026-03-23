/// home_screen.dart
/// Tela inicial (placeholder) exibida após o login bem-sucedido.
/// Mostra o nome do usuário, tipo de perfil e as seções principais do app.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Recupera dados do usuário passados pelo login via arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String nome = args?['nome'] ?? 'Usuário';
    final String tipo = args?['tipo'] ?? 'patient';
    final bool isProfissional = tipo == 'professional';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── AppBar customizada ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppTheme.primary,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Olá, ${nome.split(' ').first}! 👋',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isProfissional ? '🩺 Fisioterapeuta' : '🧑 Paciente',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              // Avatar
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white.withOpacity(0.25),
                                child: Text(
                                  nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: 'Sair',
                  onPressed: () => _confirmLogout(context),
                ),
              ],
            ),

            // ─── Corpo ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // Banner "em breve"
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.secondary.withOpacity(0.15), AppTheme.primary.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Text('🚀', style: TextStyle(fontSize: 32)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Em desenvolvimento',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'O +Físio +Saúde está crescendo! Em breve mais funcionalidades estarão disponíveis.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Seção de acesso rápido
                  const Text(
                    'Acesso Rápido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),

                  // Grid de cards
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: isProfissional
                        ? _profissionalCards()
                        : _pacienteCards(),
                  ),
                  const SizedBox(height: 28),

                  // Seção informativa
                  const Text(
                    'Sobre o App',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),

                  _InfoCard(
                    icon: Icons.health_and_safety_rounded,
                    color: AppTheme.primary,
                    title: '+Físio +Saúde',
                    description: 'Plataforma digital que conecta pacientes e fisioterapeutas para uma reabilitação mais eficiente.',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.lock_outline,
                    color: AppTheme.secondary,
                    title: 'Dados seguros',
                    description: 'Suas informações são protegidas com criptografia bcrypt e tokens JWT.',
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

  List<Widget> _pacienteCards() => [
    _QuickCard(icon: Icons.search_rounded, label: 'Buscar Fisio', color: AppTheme.primary, comingSoon: true),
    _QuickCard(icon: Icons.calendar_month_rounded, label: 'Agendamentos', color: AppTheme.secondary, comingSoon: true),
    _QuickCard(icon: Icons.favorite_rounded, label: 'Minha Saúde', color: Color(0xFFE91E63), comingSoon: true),
    _QuickCard(icon: Icons.person_rounded, label: 'Meu Perfil', color: AppTheme.accent, comingSoon: true),
  ];

  List<Widget> _profissionalCards() => [
    _QuickCard(icon: Icons.people_rounded, label: 'Pacientes', color: AppTheme.primary, comingSoon: true),
    _QuickCard(icon: Icons.calendar_month_rounded, label: 'Agenda', color: AppTheme.secondary, comingSoon: true),
    _QuickCard(icon: Icons.bar_chart_rounded, label: 'Relatórios', color: Color(0xFF9C27B0), comingSoon: true),
    _QuickCard(icon: Icons.person_rounded, label: 'Meu Perfil', color: AppTheme.accent, comingSoon: true),
  ];

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool comingSoon;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.color,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
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
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        if (comingSoon)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Em breve', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
