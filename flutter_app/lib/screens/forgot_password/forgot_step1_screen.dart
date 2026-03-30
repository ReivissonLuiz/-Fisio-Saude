/// forgot_step1_screen.dart
/// Passo 1: usuÃ¡rio informa o e-mail e recebe link de recuperaÃ§Ã£o no e-mail.
/// O Supabase envia um e-mail real com link de redefiniÃ§Ã£o de senha.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class ForgotStep1Screen extends StatefulWidget {
  const ForgotStep1Screen({super.key});

  @override
  State<ForgotStep1Screen> createState() => _ForgotStep1ScreenState();
}

class _ForgotStep1ScreenState extends State<ForgotStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;
  bool _enviado = false;

  final _api = ApiService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // Pega a URL em que o aplicativo estÃ¡ rodando atualmente (mesmo se for localhost ou github)
    String? redirectUrl;
    if (kIsWeb) {
      final currentUri = Uri.base;
      // Garante que retorne para a mesma raiz do site atual
      redirectUrl = '${currentUri.origin}${currentUri.path}';
    }

    final result = await _api.forgotPassword(
      _emailCtrl.text.trim(),
      redirectTo: redirectUrl,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _enviado = true);
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _enviado ? _buildConfirmacao() : _buildFormulario(),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Tela de confirmaÃ§Ã£o apÃ³s envio â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildConfirmacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 28),
        const Text(
          'Verifique seu e-mail!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos um link de recuperaÃ§Ã£o para:\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 28),
        // Card com instruÃ§Ãµes
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Como prosseguir:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _InstrucaoItem(
                numero: '1',
                texto: 'Abra o e-mail enviado para ${_emailCtrl.text.trim()}',
              ),
              const _InstrucaoItem(
                numero: '2',
                texto: 'Clique no botÃ£o "Redefinir minha senha"',
              ),
              const _InstrucaoItem(
                numero: '3',
                texto:
                    'VocÃª serÃ¡ redirecionado para criar uma nova senha',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Aviso sobre spam
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NÃ£o encontrou o e-mail? Verifique a pasta de spam ou lixo eletrÃ´nico.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.warning, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // BotÃ£o reenviar
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _enviado = false;
            _emailCtrl.clear();
          }),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Tentar com outro e-mail'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false),
          child: const Text('Voltar ao login',
              style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // â”€â”€ FormulÃ¡rio de e-mail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ãcone
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Recuperar sua senha',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informe seu e-mail cadastrado e enviaremos um link para vocÃª criar uma nova senha.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            label: 'E-mail',
            hint: 'seu@email.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe seu e-mail.';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                return 'E-mail invÃ¡lido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          if (_errorMsg != null) ErrorBox(message: _errorMsg!),
          PrimaryButton(
            label: 'Enviar link de recuperaÃ§Ã£o',
            onPressed: _sendLink,
            isLoading: _isLoading,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Voltar ao login',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Widgets compartilhados entre as telas de recuperaÃ§Ã£o â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InstrucaoItem extends StatelessWidget {
  final String numero;
  final String texto;
  const _InstrucaoItem({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(numero,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final step = i + 1;
        final isActive = step == current;
        final isDone = step < current;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDone || isActive
                        ? AppTheme.primary
                        : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive || isDone
                      ? AppTheme.primary
                      : AppTheme.divider,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '$step',
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }
}

class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: AppTheme.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class SuccessBox extends StatelessWidget {
  final String message;
  const SuccessBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: AppTheme.accent, fontSize: 13))),
        ],
      ),
    );
  }
}
