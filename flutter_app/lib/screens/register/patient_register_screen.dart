/// patient_register_screen.dart
/// Tela de cadastro de Paciente com todos os campos obrigatórios e opcionais,
/// máscaras de CPF/telefone/CEP e aceite de termos de uso (LGPD).

import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/password_strength_indicator.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _nascCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _aceitaTermos = false;
  bool _isLoading = false;
  String? _errorMsg;
  String? _successMsg;

  // Máscaras
  final _cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
  final _telMask = MaskTextInputFormatter(mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});
  final _cepMask = MaskTextInputFormatter(mask: '#####-###', filter: {'#': RegExp(r'\d')});
  final _nascMask = MaskTextInputFormatter(mask: '##/##/####', filter: {'#': RegExp(r'\d')});

  final _api = ApiService();

  @override
  void dispose() {
    [_nomeCtrl, _emailCtrl, _cpfCtrl, _nascCtrl, _telCtrl, _senhaCtrl, _confirmarCtrl, _cepCtrl]
        .forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitaTermos) {
      setState(() => _errorMsg = 'Você deve aceitar os Termos de Uso e Política de Privacidade.');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; _successMsg = null; });

    final result = await _api.registerPatient({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'dataNascimento': _nascCtrl.text.trim(),
      'telefone': _telCtrl.text.trim(),
      'cep': _cepCtrl.text.trim(),
      'senha': _senhaCtrl.text,
      'confirmarSenha': _confirmarCtrl.text,
      'aceitaTermos': _aceitaTermos,
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      setState(() => _successMsg = result['message']);
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro — Paciente'), leading: const BackButton()),
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
                // Cabeçalho
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_2_rounded, color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Criar conta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Preencha seus dados pessoais', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ─── Campos obrigatórios ────────────────────────────────
                const SectionLabel('Dados Pessoais'),
                const SizedBox(height: 12),

                CustomTextField(
                  label: 'Nome completo *',
                  hint: 'João da Silva',
                  controller: _nomeCtrl,
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome completo.' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'E-mail *',
                  hint: 'joao@email.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe um e-mail.';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) return 'E-mail inválido.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'CPF *',
                  hint: '000.000.000-00',
                  controller: _cpfCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cpfMask],
                  prefixIcon: const Icon(Icons.badge_outlined),
                  validator: (v) {
                    if (v == null || _cpfMask.getUnmaskedText().length != 11) return 'CPF inválido.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Data de nascimento *',
                  hint: 'DD/MM/AAAA',
                  controller: _nascCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_nascMask],
                  prefixIcon: const Icon(Icons.cake_outlined),
                  validator: (v) => (v == null || v.length != 10) ? 'Data inválida.' : null,
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Telefone *',
                  hint: '(11) 99999-9999',
                  controller: _telCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_telMask],
                  prefixIcon: const Icon(Icons.phone_outlined),
                  validator: (v) => (v == null || _telMask.getUnmaskedText().length < 10) ? 'Telefone inválido.' : null,
                ),
                const SizedBox(height: 20),

                // ─── Campos opcionais ───────────────────────────────────
                const SectionLabel('Endereço (opcional)'),
                const SizedBox(height: 12),

                CustomTextField(
                  label: 'CEP',
                  hint: '00000-000',
                  controller: _cepCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cepMask],
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                const SizedBox(height: 20),

                // ─── Senha ──────────────────────────────────────────────
                const SectionLabel('Senha de acesso'),
                const SizedBox(height: 12),

                CustomTextField(
                  label: 'Senha *',
                  hint: 'Mínimo 6 caracteres',
                  controller: _senhaCtrl,
                  obscureText: _obscureSenha,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscureSenha = !_obscureSenha),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Crie uma senha.';
                    if (v.length < 6) return 'Mínimo 6 caracteres.';
                    return null;
                  },
                ),
                PasswordStrengthIndicator(password: _senhaCtrl.text),
                const SizedBox(height: 14),

                CustomTextField(
                  label: 'Confirmar senha *',
                  hint: 'Repita sua senha',
                  controller: _confirmarCtrl,
                  obscureText: _obscureConfirmar,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmar ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscureConfirmar = !_obscureConfirmar),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme sua senha.';
                    if (v != _senhaCtrl.text) return 'As senhas não coincidem.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ─── Aceite de termos (LGPD) ────────────────────────────
                TermsCheckbox(
                  value: _aceitaTermos,
                  onChanged: (v) => setState(() { _aceitaTermos = v!; _errorMsg = null; }),
                ),
                const SizedBox(height: 20),

                // ─── Mensagens ───────────────────────────────────────────
                if (_errorMsg != null) FeedbackBox(message: _errorMsg!, isError: true),
                if (_successMsg != null) FeedbackBox(message: _successMsg!, isError: false),

                // ─── Botão ───────────────────────────────────────────────
                PrimaryButton(label: 'Criar conta', onPressed: _register, isLoading: _isLoading),
                const SizedBox(height: 32),
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

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String label;
  const SectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5),
    );
  }
}

class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const TermsCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: const Text.rich(
              TextSpan(
                text: 'Li e aceito os ',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                children: [
                  TextSpan(text: 'Termos de Uso', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  TextSpan(text: ' e a '),
                  TextSpan(text: 'Política de Privacidade', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  TextSpan(text: ' (LGPD).'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FeedbackBox extends StatelessWidget {
  final String message;
  final bool isError;
  const FeedbackBox({super.key, required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.accent;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
