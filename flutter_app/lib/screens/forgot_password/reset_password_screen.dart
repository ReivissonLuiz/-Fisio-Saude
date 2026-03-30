/// reset_password_screen.dart
/// Tela de redefiniÃ§Ã£o de senha acessada via link do e-mail do Supabase.
///
/// O Supabase envia um e-mail com um link do tipo:
///   https://SEU_PROJETO.supabase.co/auth/v1/verify?token=...&type=recovery&redirect_to=...
///
/// O supabase_flutter intercepta a URL de redirect e emite um evento
/// AuthChangeEvent.passwordRecovery no stream onAuthStateChange.
/// Esta tela detecta esse evento e apresenta o formulÃ¡rio de nova senha.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/password_strength_indicator.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  bool _obscureNova = true;
  bool _obscureConfirmar = true;
  bool _isLoading = false;
  bool _sessionReady = false;
  String? _errorMsg;

  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Verifica se jÃ¡ hÃ¡ uma sessÃ£o de recovery ativa (usuÃ¡rio jÃ¡ clicou no link)
    final currentSession = Supabase.instance.client.auth.currentSession;
    if (currentSession != null) {
      setState(() => _sessionReady = true);
    } else {
      // Aguarda o evento de recovery emitido quando o link Ã© processado
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery ||
            data.event == AuthChangeEvent.signedIn) {
          if (mounted) setState(() => _sessionReady = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _novaSenhaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _redefinirSenha() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _novaSenhaCtrl.text),
      );

      if (!mounted) return;

      if (response.user != null) {
        // Faz logout para forÃ§ar novo login com a nova senha
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('âœ… Senha redefinida com sucesso! FaÃ§a login.'),
            backgroundColor: AppTheme.accent,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = 'NÃ£o foi possÃ­vel redefinir a senha. Tente novamente.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = _traduzirErro(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Erro inesperado. Verifique sua conexÃ£o.';
      });
    }
  }

  String _traduzirErro(String msg) {
    if (msg.contains('Password should be at least')) {
      return 'A senha deve ter no mÃ­nimo 6 caracteres.';
    }
    if (msg.contains('same password')) {
      return 'A nova senha nÃ£o pode ser igual Ã  anterior.';
    }
    return 'Erro: $msg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar nova senha'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _sessionReady ? _buildFormulario() : _buildAguardando(),
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Aguardando processamento do link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildAguardando() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        const Text(
          'Verificando seu linkâ€¦',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aguarde um instante enquanto validamos sua sessÃ£o de recuperaÃ§Ã£o.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false),
          child: const Text('Voltar ao login',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    );
  }

  // â”€â”€ FormulÃ¡rio de nova senha â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
          const SizedBox(height: 24),
          const Text(
            'Crie uma nova senha',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Escolha uma senha forte com pelo menos 6 caracteres.',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Campo nova senha
          CustomTextField(
            label: 'Nova senha',
            hint: 'â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢',
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
              onPressed: () => setState(() => _obscureNova = !_obscureNova),
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe a nova senha.';
              if (v.length < 6) return 'MÃ­nimo de 6 caracteres.';
              return null;
            },
          ),
          PasswordStrengthIndicator(password: _novaSenhaCtrl.text),
          const SizedBox(height: 16),

          // Campo confirmar
          CustomTextField(
            label: 'Confirmar nova senha',
            hint: 'â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢',
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
              onPressed: () =>
                  setState(() => _obscureConfirmar = !_obscureConfirmar),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirme a nova senha.';
              if (v != _novaSenhaCtrl.text) return 'As senhas nÃ£o coincidem.';
              return null;
            },
          ),
          const SizedBox(height: 24),

          if (_errorMsg != null)
            Container(
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
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13))),
                ],
              ),
            ),

          PrimaryButton(
            label: 'Redefinir senha',
            onPressed: _isLoading ? null : _redefinirSenha,
            isLoading: _isLoading,
            backgroundColor: AppTheme.secondary,
          ),
        ],
      ),
    );
  }
}
