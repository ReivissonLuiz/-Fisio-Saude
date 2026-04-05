/// admin_register_screen.dart
/// Tela de cadastro de Administrador com campos obrigatórios e aceite LGPD.
library;

import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/password_strength_indicator.dart';
import 'patient_register_screen.dart' show SectionLabel, TermsCheckbox, FeedbackBox;

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _cargoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _aceitaTermos = false;
  bool _isLoading = false;
  String? _errorMsg;

  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});

  final _api = ApiService();

  @override
  void dispose() {
    for (var c in [
      _nomeCtrl,
      _emailCtrl,
      _cpfCtrl,
      _cargoCtrl,
      _senhaCtrl,
      _confirmarCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitaTermos) {
      setState(() => _errorMsg = 'Você deve aceitar os Termos.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final result = await _api.registerAdmin({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'cargo': _cargoCtrl.text.trim(),
      'senha': _senhaCtrl.text,
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/register-success',
        (r) => false,
        arguments: 'Administrador',
      );
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro — ADM'), leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Registrar-se como', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                            Text('Administrador', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const SectionLabel('Dados de Acesso ADM'),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Nome completo *',
                      controller: _nomeCtrl,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Informe o nome completo.' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'E-mail Corporativo *',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (v) => (v == null || !v.contains('@')) ? 'E-mail inválido.' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'CPF *',
                      controller: _cpfCtrl,
                      inputFormatters: [_cpfMask],
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) => (_cpfMask.getUnmaskedText().length != 11) ? 'CPF inválido.' : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Cargo / Função *',
                      controller: _cargoCtrl,
                      hint: 'Ex: Gerente Técnico',
                      prefixIcon: const Icon(Icons.work_outline),
                      validator: (v) => (v == null || v.isEmpty) ? 'Informe seu cargo.' : null,
                    ),
                    const SizedBox(height: 24),
                    const SectionLabel('Segurança'),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Senha *',
                      controller: _senhaCtrl,
                      obscureText: _obscureSenha,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                      ),
                    ),
                    PasswordStrengthIndicator(password: _senhaCtrl.text),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Confirmar senha *',
                      controller: _confirmarCtrl,
                      obscureText: _obscureConfirmar,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmar ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                      ),
                      validator: (v) => (v != _senhaCtrl.text) ? 'As senhas Não coincidem.' : null,
                    ),
                    const SizedBox(height: 24),
                    TermsCheckbox(
                      value: _aceitaTermos,
                      onChanged: (v) => setState(() => _aceitaTermos = v!),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMsg != null) FeedbackBox(message: _errorMsg!, isError: true),
                    PrimaryButton(
                      label: 'Finalizar Cadastro ADM',
                      onPressed: _register,
                      isLoading: _isLoading,
                      backgroundColor: Colors.purple,
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


