/// forgot_step2_screen.dart
/// Passo 2: O usuÃ¡rio insere o cÃ³digo de 6 dÃ­gitos recebido por e-mail.
/// Inclui cooldown de 60s para reenvio e validaÃ§Ã£o de cÃ³digo invÃ¡lido/expirado.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/primary_button.dart';
import 'forgot_step1_screen.dart' show StepIndicator, ErrorBox;

class ForgotStep2Screen extends StatefulWidget {
  const ForgotStep2Screen({super.key});

  @override
  State<ForgotStep2Screen> createState() => _ForgotStep2ScreenState();
}

class _ForgotStep2ScreenState extends State<ForgotStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  // Cooldown para reenvio
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  final _api = ApiService();

  late String _email;
  late String? _devCode;
  bool _argsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _email = args['email'] as String;
      _devCode = args['devCode'] as String?;
      _argsInitialized = true;
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
      }
      setState(() => _resendCooldown = (_resendCooldown - 1).clamp(0, 60));
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final result = await _api.verifyCode(_email, _codeCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushNamed(
        context,
        '/forgot-step3',
        arguments: {'email': _email, 'code': _codeCtrl.text.trim()},
      );
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;
    final result = await _api.forgotPassword(_email);
    if (!mounted) return;
    if (result['success'] == true) {
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('CÃ³digo reenviado!'),
            backgroundColor: AppTheme.accent),
      );
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
                    const StepIndicator(current: 2),
                    const SizedBox(height: 32),
                    const Text(
                      'Verifique seu e-mail',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enviamos um cÃ³digo de 6 dÃ­gitos para $_email.',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    // Em desenvolvimento, mostra o cÃ³digo gerado
                    if (_devCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.warning.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'ðŸ›  Modo Dev â€” CÃ³digo: $_devCode',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Campo cÃ³digo
                    TextFormField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: const TextStyle(
                            color: AppTheme.textHint,
                            letterSpacing: 12,
                            fontSize: 28),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length != 6) {
                          return 'Digite o cÃ³digo de 6 dÃ­gitos.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() => _errorMsg = null),
                    ),
                    const SizedBox(height: 16),

                    if (_errorMsg != null) ErrorBox(message: _errorMsg!),

                    PrimaryButton(
                        label: 'Verificar cÃ³digo',
                        onPressed: _verifyCode,
                        isLoading: _isLoading),
                    const SizedBox(height: 24),

                    // Link reenviar
                    Center(
                      child: TextButton(
                        onPressed: _resendCooldown > 0 ? null : _resendCode,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Reenviar cÃ³digo em ${_resendCooldown}s'
                              : 'Reenviar cÃ³digo',
                          style: TextStyle(
                            color: _resendCooldown > 0
                                ? AppTheme.textHint
                                : AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
