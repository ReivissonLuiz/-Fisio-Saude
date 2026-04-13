/// forgot_step3_screen.dart
/// Passo 3: O usuário define uma nova senha com indicador de força.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/password_strength_indicator.dart';
import 'forgot_step1_screen.dart' show StepIndicator, ErrorBox;

class ForgotStep3Screen extends StatefulWidget {
  const ForgotStep3Screen({super.key});

  @override
  State<ForgotStep3Screen> createState() => _ForgotStep3ScreenState();
}

class _ForgotStep3ScreenState extends State<ForgotStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  bool _obscureNova = true;
  bool _obscureConfirmar = true;
  bool _isLoading = false;
  String? _errorMsg;

  late String _email;
  late String _code;
  bool _argsInitialized = false;

  final _api = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _email = args['email'] as String;
      _code = args['code'] as String;
      _argsInitialized = true;
    }
  }

  @override
  void dispose() {
    _novaSenhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final result = await _api.resetPassword(
      email: _email,
      code: _code,
      novaSenha: _novaSenhaCtrl.text,
      confirmarSenha: _confirmarCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida com sucesso! Faça login.'),
          backgroundColor: AppTheme.accent,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Recuperar Senha'), leading: const BackButton()),
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
                    const StepIndicator(current: 3),
                    const SizedBox(height: 32),
                    const Text(
                      'Crie uma nova senha',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sua nova senha deve ter pelo menos 8 caracteres, letra maiúscula, minúscula, número e caractere especial.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Campo nova senha
                    CustomTextField(
                      label: 'Nova senha',
                      hint: '••••••••',
                      controller: _novaSenhaCtrl,
                      obscureText: _obscureNova,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNova
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNova = !_obscureNova),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: Validators.senha,
                    ),

                    // Indicador de força
                    PasswordStrengthIndicator(password: _novaSenhaCtrl.text),
                    const SizedBox(height: 16),

                    // Campo confirmar senha
                    CustomTextField(
                      label: 'Confirmar nova senha',
                      hint: '••••••••',
                      controller: _confirmarCtrl,
                      obscureText: _obscureConfirmar,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmar
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirmar = !_obscureConfirmar),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirme a nova senha.';
                        }
                        if (v != _novaSenhaCtrl.text) {
                          return 'As senhas Não coincidem.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    if (_errorMsg != null) ErrorBox(message: _errorMsg!),

                    PrimaryButton(
                      label: 'Redefinir senha',
                      onPressed: _resetPassword,
                      isLoading: _isLoading,
                      backgroundColor: AppTheme.secondary,
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


