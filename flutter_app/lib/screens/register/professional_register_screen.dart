/// professional_register_screen.dart
/// Tela de cadastro de Fisioterapeuta com todos os campos obrigatórios,
/// incluindo CREFITO e especialização, com aceite de termos LGPD.
library;

import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/password_strength_indicator.dart';
import 'patient_register_screen.dart'
    show SectionLabel, TermsCheckbox, FeedbackBox;

class ProfessionalRegisterScreen extends StatefulWidget {
  const ProfessionalRegisterScreen({super.key});

  @override
  State<ProfessionalRegisterScreen> createState() =>
      _ProfessionalRegisterScreenState();
}

class _ProfessionalRegisterScreenState
    extends State<ProfessionalRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _crefitoCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  String? _especializacaoSelecionada;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _aceitaTermos = false;
  bool _isLoading = false;
  String? _errorMsg;
  String? _successMsg;

  // Máscaras
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
  final _telMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});
  final _cepMask =
      MaskTextInputFormatter(mask: '#####-###', filter: {'#': RegExp(r'\d')});

  final _api = ApiService();

  static const List<String> _especializacoes = [
    'Fisioterapia Ortopédica e Traumatológica',
    'Fisioterapia Neurológica',
    'Fisioterapia Esportiva',
    'Fisioterapia Cardiorrespiratória',
    'Fisioterapia em Saúde da Mulher',
    'Fisioterapia Pediátrica',
    'Fisioterapia Geriátrica',
    'Fisioterapia Aquática',
    'Fisioterapia Dermato-Funcional',
    'RPG — Reeducação Postural Global',
    'Outra',
  ];

  @override
  void dispose() {
    for (var c in [
      _nomeCtrl,
      _emailCtrl,
      _cpfCtrl,
      _crefitoCtrl,
      _telCtrl,
      _cepCtrl,
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
      setState(() => _errorMsg =
          'Você deve aceitar os Termos de Uso e Política de Privacidade.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _successMsg = null;
    });

    final result = await _api.registerProfessional({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'crefito': _crefitoCtrl.text.trim(),
      'especializacao': _especializacaoSelecionada ?? '',
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
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      setState(() => _errorMsg = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Cadastro — Fisioterapeuta'),
          leading: const BackButton()),
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
                            color: AppTheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.medical_services_rounded,
                              color: AppTheme.secondary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Registrar-se como',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary)),
                            Text('Fisioterapeuta',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),

                    // Banner informativo: cadastro imediato
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppTheme.accent, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Seu cadastro é ativado imediatamente. Você já pode fazer login após o registro.',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Dados Pessoais ─────────────────────────────────────
                    const SectionLabel('Dados Pessoais'),
                    const SizedBox(height: 12),

                    CustomTextField(
                      label: 'Nome completo *',
                      hint: 'Dra. Maria Oliveira',
                      controller: _nomeCtrl,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Informe o nome completo.'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      label: 'E-mail *',
                      hint: 'maria@clinic.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe um e-mail.';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v))
                          return 'E-mail inválido.';
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
                      validator: (v) =>
                          (v == null || _cpfMask.getUnmaskedText().length != 11)
                              ? 'CPF inválido.'
                              : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      label: 'Telefone *',
                      hint: '(11) 99999-9999',
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_telMask],
                      prefixIcon: const Icon(Icons.phone_outlined),
                      validator: (v) =>
                          (v == null || _telMask.getUnmaskedText().length < 10)
                              ? 'Telefone inválido.'
                              : null,
                    ),
                    const SizedBox(height: 20),

                    // ─── Dados Profissionais ────────────────────────────────
                    const SectionLabel('Dados Profissionais'),
                    const SizedBox(height: 12),

                    CustomTextField(
                      label: 'CREFITO *',
                      hint: 'Ex: 3-12345-F',
                      controller: _crefitoCtrl,
                      prefixIcon: const Icon(Icons.workspace_premium_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu CREFITO.'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Dropdown de especialização
                    DropdownButtonFormField<String>(
                      value: _especializacaoSelecionada,
                      decoration: InputDecoration(
                        labelText: 'Especialização / Área de atuação *',
                        prefixIcon: const Icon(Icons.category_outlined),
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
                      items: _especializacoes
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e,
                                  style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _especializacaoSelecionada = v),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Selecione uma especialização.'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ─── Endereço ───────────────────────────────────────────
                    const SectionLabel('Endereço'),
                    const SizedBox(height: 12),

                    CustomTextField(
                      label: 'CEP *',
                      hint: '00000-000',
                      controller: _cepCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_cepMask],
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      validator: (v) =>
                          (v == null || _cepMask.getUnmaskedText().length != 8)
                              ? 'CEP inválido.'
                              : null,
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
                        icon: Icon(
                            _obscureSenha
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary),
                        onPressed: () =>
                            setState(() => _obscureSenha = !_obscureSenha),
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
                        icon: Icon(
                            _obscureConfirmar
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary),
                        onPressed: () => setState(
                            () => _obscureConfirmar = !_obscureConfirmar),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Confirme sua senha.';
                        if (v != _senhaCtrl.text)
                          return 'As senhas não coincidem.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ─── Aceite de termos (LGPD) ────────────────────────────
                    TermsCheckbox(
                      value: _aceitaTermos,
                      onChanged: (v) => setState(() {
                        _aceitaTermos = v!;
                        _errorMsg = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMsg != null)
                      FeedbackBox(message: _errorMsg!, isError: true),
                    if (_successMsg != null)
                      FeedbackBox(message: _successMsg!, isError: false),

                    PrimaryButton(
                      label: 'Criar conta',
                      onPressed: _register,
                      isLoading: _isLoading,
                      backgroundColor: AppTheme.secondary,
                    ),
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
