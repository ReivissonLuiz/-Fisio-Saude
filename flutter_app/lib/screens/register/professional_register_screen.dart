/// Tela de cadastro de Fisioterapeuta com todos os campos obrigatórios,
/// incluindo CREFITO com máscara dinâmica (F ou TO) e integração ViaCEP.
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
  final _logradouroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  final _nascCtrl = TextEditingController();

  String? _especializacaoSelecionada;
  String? _generoSelecionado;
  bool _obscureSenha = true;
  bool _obscureConfirmar = true;
  bool _aceitaTermos = false;
  bool _isLoading = false;
  bool _buscandoCep = false;
  bool _cepEncontrado = false;
  String? _errorMsg;
  String? _successMsg;

  // Tipo de CREFITO: 'F' = Fisioterapeuta, 'TO' = Terapeuta Ocupacional
  String _tipoCrefito = 'F';

  // Máscaras
  final _cpfMask = MaskTextInputFormatter(
      mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
  final _telMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});
  final _cepMask =
      MaskTextInputFormatter(mask: '#####-###', filter: {'#': RegExp(r'\d')});
  final _nascMask =
      MaskTextInputFormatter(mask: '##/##/####', filter: {'#': RegExp(r'\d')});
  // Máscara CREFITO: 7 dígitos
  final _crefitoNumMask = MaskTextInputFormatter(
      mask: '#######', filter: {'#': RegExp(r'\d')});

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
    'Terapia Ocupacional',
    'Outra',
  ];

  @override
  void dispose() {
    for (var c in [
      _nomeCtrl, _emailCtrl, _cpfCtrl, _crefitoCtrl, _telCtrl, _cepCtrl,
      _logradouroCtrl, _bairroCtrl, _cidadeCtrl, _ufCtrl, _numeroCtrl,
      _complementoCtrl, _senhaCtrl, _confirmarCtrl, _nascCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Busca o CEP na API ViaCEP e preenche os campos automaticamente.
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

  /// Monta o valor do CREFITO com o sufixo do tipo selecionado.
  String get _crefitoCompletoFormatado {
    final nums = _crefitoNumMask.getUnmaskedText();
    return '$nums-$_tipoCrefito';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceitaTermos) {
      setState(() =>
          _errorMsg = 'Você deve aceitar os Termos de Uso e Política de Privacidade.');
      return;
    }

    // Verificação adicional do CEP via ViaCEP (se ainda não buscou)
    final cepUnmasked = _cepMask.getUnmaskedText();
    if (cepUnmasked.isNotEmpty && !_cepEncontrado) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
        _successMsg = null;
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
        // Se a API estiver indisponível, prossegue
      }
    } else {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
        _successMsg = null;
      });
    }

    final result = await _api.registerProfessional({
      'nome': _nomeCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'cpf': _cpfCtrl.text.trim(),
      'crefito': _crefitoCompletoFormatado,
      'especializacao': _especializacaoSelecionada ?? '',
      'telefone': _telCtrl.text.trim(),
      'dataNascimento': _nascCtrl.text.trim(),
      'genero': _generoSelecionado ?? '',
      'senha': _senhaCtrl.text,
      'confirmarSenha': _confirmarCtrl.text,
      'aceitaTermos': _aceitaTermos,
      'cep': _cepCtrl.text.trim(),
      'logradouro': _logradouroCtrl.text.trim(),
      'numero': _numeroCtrl.text.trim(),
      'complemento': _complementoCtrl.text.trim(),
      'bairro': _bairroCtrl.text.trim(),
      'cidade': _cidadeCtrl.text.trim(),
      'uf': _ufCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/register-success',
        (r) => false,
        arguments: 'Profissional',
      );
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
                            color: AppTheme.secondary.withValues(alpha: 0.1),
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
                            Text('Profissional de Saúde',
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
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.4)),
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

                    // --- Dados Pessoais --------------------------------------------
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
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                          return 'E-mail inválido.';
                        }
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
                      validator: (_) =>
                          Validators.cpf(_cpfMask.getUnmaskedText()),
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

                    // --- Dados Profissionais ---------------------------------------
                    const SectionLabel('Dados Profissionais'),
                    const SizedBox(height: 12),

                    // Selector de tipo de CREFITO
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Categoria Profissional *',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tipoCrefito = 'F'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _tipoCrefito == 'F'
                                          ? AppTheme.secondary
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.medical_services_outlined,
                                            color: _tipoCrefito == 'F'
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                            size: 20),
                                        const SizedBox(height: 4),
                                        Text('Fisioterapeuta',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _tipoCrefito == 'F'
                                                    ? Colors.white
                                                    : AppTheme.textSecondary),
                                            textAlign: TextAlign.center),
                                        Text('sufixo: -F',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _tipoCrefito == 'F'
                                                    ? Colors.white70
                                                    : Colors.grey),
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _tipoCrefito = 'TO'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _tipoCrefito == 'TO'
                                          ? AppTheme.primary
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.accessibility_new_outlined,
                                            color: _tipoCrefito == 'TO'
                                                ? Colors.white
                                                : AppTheme.textSecondary,
                                            size: 20),
                                        const SizedBox(height: 4),
                                        Text('Ter. Ocupacional',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _tipoCrefito == 'TO'
                                                    ? Colors.white
                                                    : AppTheme.textSecondary),
                                            textAlign: TextAlign.center),
                                        Text('sufixo: -TO',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _tipoCrefito == 'TO'
                                                    ? Colors.white70
                                                    : Colors.grey),
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo CREFITO com máscara de 7 dígitos + sufixo automático
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'CREFITO — Número *',
                            hint: '0123456',
                            controller: _crefitoCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_crefitoNumMask],
                            prefixIcon: const Icon(Icons.workspace_premium_outlined),
                            validator: (_) => Validators.crefito(
                                _crefitoCompletoFormatado),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 60,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _tipoCrefito == 'F'
                                ? AppTheme.secondary.withValues(alpha: 0.1)
                                : AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _tipoCrefito == 'F'
                                    ? AppTheme.secondary.withValues(alpha: 0.4)
                                    : AppTheme.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '-$_tipoCrefito',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _tipoCrefito == 'F'
                                    ? AppTheme.secondary
                                    : AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Ex: 0123456-$_tipoCrefito',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
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

                    // --- Endereço --------------------------------------------------
                    const SectionLabel('Endereço'),
                    const SizedBox(height: 12),

                    // CEP com busca automática
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'CEP *',
                            hint: '00000-000',
                            controller: _cepCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_cepMask],
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            onChanged: (v) {
                              if (_cepMask.getUnmaskedText().length == 8) {
                                _buscarCep();
                              } else {
                                setState(() => _cepEncontrado = false);
                              }
                            },
                            validator: (_) => Validators.cepObrigatorio(
                                _cepCtrl.text, _cepMask.getUnmaskedText()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: _buscandoCep ? null : _buscarCep,
                            icon: _buscandoCep
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Icon(
                                    _cepEncontrado
                                        ? Icons.check_circle_outline
                                        : Icons.search,
                                    color: _cepEncontrado
                                        ? AppTheme.accent
                                        : AppTheme.primary),
                            label: Text(
                              _cepEncontrado ? 'Encontrado' : 'Buscar',
                              style: TextStyle(
                                  color: _cepEncontrado
                                      ? AppTheme.accent
                                      : AppTheme.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: _cepEncontrado
                                      ? AppTheme.accent
                                      : AppTheme.primary),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_cepEncontrado) ...[
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Logradouro',
                        controller: _logradouroCtrl,
                        prefixIcon: const Icon(Icons.signpost_outlined),
                        readOnly: true,
                        validator: null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: CustomTextField(
                              label: 'Número *',
                              hint: 'Ex: 123',
                              controller: _numeroCtrl,
                              keyboardType: TextInputType.text,
                              prefixIcon: const Icon(Icons.tag_outlined),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Informe o número.'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              label: 'Complemento',
                              hint: 'Apto, Sala...',
                              controller: _complementoCtrl,
                              prefixIcon: const Icon(Icons.apartment_outlined),
                              validator: null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CustomTextField(
                              label: 'Bairro',
                              controller: _bairroCtrl,
                              prefixIcon: const Icon(Icons.map_outlined),
                              readOnly: true,
                              validator: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: CustomTextField(
                              label: 'Cidade',
                              controller: _cidadeCtrl,
                              prefixIcon: const Icon(Icons.location_city_outlined),
                              readOnly: true,
                              validator: null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: CustomTextField(
                              label: 'UF',
                              controller: _ufCtrl,
                              readOnly: true,
                              validator: null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // --- Senha -----------------------------------------------------
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
                        if (v == null || v.isEmpty) {
                          return 'Confirme sua senha.';
                        }
                        if (v != _senhaCtrl.text) {
                          return 'As senhas não coincidem.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- Aceite de termos (LGPD) -----------------------------------
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
