/// forgot_step1_screen.dart
/// Passo 1 da recuperação de senha: o usuário informa o e-mail.

import 'package:flutter/material.dart';
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
  String? _successMsg;

  final _api = ApiService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; _successMsg = null; });

    final result = await _api.forgotPassword(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() {
        _successMsg = result['message'] ?? 'Código enviado!';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/forgot-step2',
        arguments: {
          'email': _emailCtrl.text.trim(),
          'devCode': result['_devCode'],
        },
      );
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepIndicator(current: 1),
                const SizedBox(height: 32),

                const Text(
                  'Informe seu e-mail',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enviaremos um código de 6 dígitos para recuperar sua senha.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                      return 'E-mail inválido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (_errorMsg != null) ErrorBox(message: _errorMsg!),
                if (_successMsg != null) SuccessBox(message: _successMsg!),

                PrimaryButton(
                  label: 'Enviar código de recuperação',
                  onPressed: _sendCode,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets públicos compartilhados entre as telas de recuperação ─────────────

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
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
                    color: isDone || isActive ? AppTheme.primary : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isActive || isDone ? AppTheme.primary : AppTheme.divider,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '$step',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppTheme.textSecondary,
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
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
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
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.accent, fontSize: 13))),
        ],
      ),
    );
  }
}
