/// admin_register_screen.dart
/// Tela de cadastro de Administrador com todos os campos obrigatórios e opcionais.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
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
  final _nascCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();

  String? _generoSelecionado;

  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _aceitaTermos = false;
  bool _isLoading = false;
  bool _buscandoCep = false;
  bool _cepEncontrado = false;
  String? _errorMsg;

  // Máscaras
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
  final _telMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});
  final _cepMask =
      MaskTextInputFormatter(mask: '#####-###', filter: {'#': RegExp(r'\d')});
  final _nascMask =
      MaskTextInputFormatter(mask: '##/##/####', filter: {'#': RegExp(r'\d')});

  final _api = ApiService();

  @override
  void dispose() {
    for (var c in [
      _nomeCtrl, _emailCtrl, _cpfCtrl, _cargoCtrl, _nascCtrl, _telCtrl,
      _senhaCtrl, _confirmarCtrl, _cepCtrl, _logradouroCtrl,
      _bairroCtrl, _cidadeCtrl, _ufCtrl, _numeroCtrl, _complementoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Busca o CEP na API ViaCEP e preenche os campos de endereço automaticamente.
  Future<void> _buscarCep() async {
    final cepUnmasked = _cepMask.getUnmaskedText();
    if (cepUnmasked.length != 8) return;

    setState(() {
      _buscandoCep = true;
      _cepEncontrado = false;
      _errorMsg = null;
    });

    try {
      final resp = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cepUnmasked/json/'))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data is Map && data['erro'] == true) {
          setState(() {
            _buscandoCep = false;
            _cepEncontrado = false;
            _errorMsg = 'CEP não encontrado. Verifique o número digitado.';
          });
          return;
        }
        setState(() {
          _buscandoCep = false;
          _cepEncontrado = true;
          _logradouroCtrl.text = data['logradouro'] as String? ?? '';
          _bairroCtrl.text = data['bairro'] as String? ?? '';
          _cidadeCtrl.text = data['localidade'] as String? ?? '';
          _ufCtrl.text = data['uf'] as String? ?? '';
        });
      } else {
        setState(() {
          _buscandoCep = false;
          _cepEncontrado = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _buscandoCep = false;
          _cepEncontrado = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitaTermos) {
      setState(() => _errorMsg = 'Você deve aceitar os Termos de Uso e Política de Privacidade.');
      return;
    }
    if (_generoSelecionado == null) {
      setState(() => _errorMsg = 'Por favor, selecione o seu Gênero.');
      return;
    }

    // Se CEP foi preenchido mas não foi encontrado, valida antes de prosseguir
    final cepUnmasked = _cepMask.getUnmaskedText();
    if (cepUnmasked.length == 8 && !_cepEncontrado) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
      try {
        final viaResp = await http
            .get(Uri.parse('https://viacep.com.br/ws/$cepUnmasked/json/'))
            .timeout(const Duration(seconds: 6));
        if (viaResp.statusCode == 200) {
          final data = json.decode(viaResp.body);
          if (data is Map && data['erro'] == true) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'CEP não encontrado. Verifique o número digitado.';
            });
            return;
          }
        }
      } catch (_) {
        // API indisponível — prossegue
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });
    }

    final result = await _api.registerAdmin({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'cargo': _cargoCtrl.text.trim(),
      'genero': _generoSelecionado,
      'dataNascimento': _nascCtrl.text.trim(),
      'telefone': _telCtrl.text.trim(),
      'cep': _cepCtrl.text.trim(),
      'logradouro': _logradouroCtrl.text.trim(),
      'numero': _numeroCtrl.text.trim(),
      'complemento': _complementoCtrl.text.trim(),
      'bairro': _bairroCtrl.text.trim(),
      'cidade': _cidadeCtrl.text.trim(),
      'uf': _ufCtrl.text.trim(),
      'senha': _senhaCtrl.text,
      'confirmarSenha': _confirmarCtrl.text,
      'aceitaTermos': _aceitaTermos,
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
                    
                    // --- Dados Pessoais ---
                    const SectionLabel('Dados Pessoais'),
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
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (_) => Validators.cpf(_cpfMask.getUnmaskedText()),
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      label: 'Data de nascimento *',
                      hint: 'DD/MM/AAAA',
                      controller: _nascCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_nascMask],
                      prefixIcon: const Icon(Icons.cake_outlined),
                      validator: (_) => Validators.dataNascimento(_nascCtrl.text),
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
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: _generoSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Gênero *',
                        prefixIcon: Icon(Icons.people_outline),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                        DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                        DropdownMenuItem(value: 'Não-Binário', child: Text('Não-Binário')),
                        DropdownMenuItem(value: 'Desejo não Informar', child: Text('Desejo não Informar')),
                      ],
                      onChanged: (v) => setState(() => _generoSelecionado = v),
                      validator: (v) => v == null ? 'Selecione um gênero.' : null,
                    ),
                    const SizedBox(height: 20),

                    // --- Perfil ADM ---
                    const SectionLabel('Perfil ADM'),
                    const SizedBox(height: 12),
                    
                    CustomTextField(
                      label: 'Cargo / Função *',
                      controller: _cargoCtrl,
                      hint: 'Ex: Gerente Técnico',
                      prefixIcon: const Icon(Icons.work_outline),
                      validator: (v) => (v == null || v.isEmpty) ? 'Informe seu cargo.' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // --- Endereço viaCEP ---
                    const SectionLabel('Endereço'),
                    const SizedBox(height: 12),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomTextField(
                            label: 'CEP *',
                            hint: '00000-000',
                            controller: _cepCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_cepMask],
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            onChanged: (v) {
                              if (_cepMask.getUnmaskedText().length == 8 && !_buscandoCep) {
                                _buscarCep();
                              }
                            },
                            validator: (_) => (_cepMask.getUnmaskedText().length != 8) ? 'CEP inválido.' : null,
                          ),
                        ),
                        if (_buscandoCep) ...[
                          const SizedBox(width: 12),
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    CustomTextField(
                      label: 'Logradouro *',
                      hint: 'Rua, Avenida, etc.',
                      controller: _logradouroCtrl,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório.' : null,
                    ),
                    const SizedBox(height: 14),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomTextField(
                            label: 'Número *',
                            controller: _numeroCtrl,
                            keyboardType: TextInputType.text,
                            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório.' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: CustomTextField(
                            label: 'Complemento',
                            hint: 'Apto, Sala, etc.',
                            controller: _complementoCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    CustomTextField(
                      label: 'Bairro *',
                      controller: _bairroCtrl,
                      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório.' : null,
                    ),
                    const SizedBox(height: 14),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: CustomTextField(
                            label: 'Cidade *',
                            controller: _cidadeCtrl,
                            validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório.' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 1,
                          child: CustomTextField(
                            label: 'UF *',
                            controller: _ufCtrl,
                            validator: (v) => (v == null || v.length != 2) ? 'Ex: SP' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- Segurança ---
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
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo de 6 caracteres.' : null,
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
