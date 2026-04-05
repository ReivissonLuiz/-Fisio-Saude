/// register_success_screen.dart
/// Tela exibida apÃ³s o cadastro ser criado com sucesso.
/// Informa ao usuÃ¡rio que um e-mail de confirmaÃ§Ã£o foi enviado.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class RegisterSuccessScreen extends StatelessWidget {
  final String tipoConta; // 'Paciente' ou 'Profissional'

  const RegisterSuccessScreen({super.key, required this.tipoConta});

  @override
  Widget build(BuildContext context) {
    final isPaciente = tipoConta == 'Paciente';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // â”€â”€ Ãcone animado â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.4), width: 2),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 52,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // â”€â”€ TÃ­tulo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Text(
                    'Conta criada!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // â”€â”€ Mensagem principal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  const Text(
                    'Enviamos um e-mail de confirmaÃ§Ã£o para vocÃª.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    isPaciente
                        ? 'Acesse sua caixa de entrada e clique no link para ativar sua conta de Paciente antes de fazer login.'
                        : 'Acesse sua caixa de entrada e clique no link para ativar sua conta de Fisioterapeuta antes de fazer login.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // â”€â”€ Aviso sobre spam â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.primary.withValues(alpha: 0.7), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'NÃ£o encontrou o e-mail? Verifique a pasta de Spam ou Lixo EletrÃ´nico.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // â”€â”€ BotÃ£o ir para login â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (r) => false),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'Ir para o Login',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
