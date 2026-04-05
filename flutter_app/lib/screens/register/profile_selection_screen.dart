/// profile_selection_screen.dart
/// Tela de seleção de perfil: o usuário escolhe entre Paciente ou Fisioterapeuta.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Criar Conta'), leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Qual é o seu perfil?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecione como você quer usar o +Físio +Saúde.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // Card Paciente
              _ProfileCard(
                icon: Icons.person_2_rounded,
                title: 'Paciente',
                description:
                    'Busque fisioterapeutas, agende sessões e acompanhe sua recuperação.',
                color: AppTheme.primary,
                onTap: () => Navigator.pushNamed(context, '/register-patient'),
              ),
              const SizedBox(height: 20),

              // Card Fisioterapeuta
              _ProfileCard(
                icon: Icons.medical_services_rounded,
                title: 'Fisioterapeuta',
                description:
                    'Gerencie seus pacientes, consultas e evolução clínica.',
                color: AppTheme.secondary,
                onTap: () =>
                    Navigator.pushNamed(context, '/register-professional'),
              ),
              const SizedBox(height: 20),

              // Card Administrador
              _ProfileCard(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Administrador (ADM)',
                description:
                    'Gerencie a base de dados, profissionais, pacientes e veja BI.',
                color: Colors.purple,
                onTap: () => Navigator.pushNamed(context, '/register-admin'),
              ),

              const SizedBox(height: 40),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Já tem conta? ',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      child: const Text(
                        'Entrar',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Ícone
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
