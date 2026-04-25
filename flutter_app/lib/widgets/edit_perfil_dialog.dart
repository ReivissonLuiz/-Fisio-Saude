/// edit_perfil_dialog.dart
/// Dialog de edição de dados pessoais reutilizável por todos os papéis.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Abre o dialog de edição de perfil e aguarda. Retorna `true` se salvou.
Future<bool> showEditPerfilDialog({
  required BuildContext context,
  required String usuarioId,
  required Map<String, dynamic> perfilData,
  List<ExtraField>? camposExtras,
  Color accentColor = AppTheme.primary,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _EditPerfilDialog(
      usuarioId: usuarioId,
      perfilData: perfilData,
      camposExtras: camposExtras ?? [],
      accentColor: accentColor,
    ),
  );
  return result == true;
}

/// Define um campo extra (ex: CREFITO) a ser exibido no dialog.
class ExtraField {
  final String label;
  final String fieldKey;
  final IconData icon;
  final TextInputType keyboardType;

  const ExtraField({
    required this.label,
    required this.fieldKey,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });
}

// ── Dialog ──────────────────────────────────────────────────────────────────

class _EditPerfilDialog extends StatefulWidget {
  final String usuarioId;
  final Map<String, dynamic> perfilData;
  final List<ExtraField> camposExtras;
  final Color accentColor;

  const _EditPerfilDialog({
    required this.usuarioId,
    required this.perfilData,
    required this.camposExtras,
    required this.accentColor,
  });

  @override
  State<_EditPerfilDialog> createState() => _EditPerfilDialogState();
}

class _EditPerfilDialogState extends State<_EditPerfilDialog> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _cepCtrl;
  late final TextEditingController _logCtrl;
  late final TextEditingController _numCtrl;
  late final TextEditingController _complCtrl;
  late final TextEditingController _bairroCtrl;
  late final TextEditingController _cidadeCtrl;
  late final TextEditingController _ufCtrl;

  final Map<String, TextEditingController> _extraCtrls = {};

  final _telMask = MaskTextInputFormatter(
      mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});
  final _cepMask = MaskTextInputFormatter(
      mask: '#####-###', filter: {'#': RegExp(r'\d')});

  bool _isSaving = false;
  bool _isFetchingCep = false;
  String? _errorMsg;

  static const _generos = [
    'Masculino', 'Feminino', 'Não-binário', 'Prefiro não informar', 'Outro'
  ];
  String? _generoSelecionado;

  @override
  void initState() {
    super.initState();
    final p = widget.perfilData;
    _nomeCtrl   = TextEditingController(text: p['nome']?.toString() ?? '');
    _telCtrl    = TextEditingController(text: p['telefone']?.toString() ?? '');
    _cepCtrl    = TextEditingController(text: _formatCep(p['cep']?.toString() ?? ''));
    _logCtrl    = TextEditingController(text: p['logradouro']?.toString() ?? '');
    _numCtrl    = TextEditingController(text: p['numero']?.toString() ?? '');
    _complCtrl  = TextEditingController(text: p['complemento']?.toString() ?? '');
    _bairroCtrl = TextEditingController(text: p['bairro']?.toString() ?? '');
    _cidadeCtrl = TextEditingController(text: p['cidade']?.toString() ?? '');
    _ufCtrl     = TextEditingController(text: p['uf']?.toString() ?? '');
    _generoSelecionado = p['genero']?.toString();

    for (final f in widget.camposExtras) {
      _extraCtrls[f.fieldKey] = TextEditingController(
          text: p[f.fieldKey]?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in [_nomeCtrl, _telCtrl, _cepCtrl, _logCtrl, _numCtrl,
                     _complCtrl, _bairroCtrl, _cidadeCtrl, _ufCtrl]) {
      c.dispose();
    }
    for (final c in _extraCtrls.values) { c.dispose(); }
    super.dispose();
  }

  String _formatCep(String cep) {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) return '${digits.substring(0, 5)}-${digits.substring(5)}';
    return cep;
  }

  Future<void> _fetchCep() async {
    final digits = _cepMask.getUnmaskedText();
    if (digits.length != 8) return;
    setState(() { _isFetchingCep = true; _errorMsg = null; });
    try {
      final res = await http.get(Uri.parse('https://viacep.com.br/ws/$digits/json/'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['erro'] == true) {
          setState(() => _errorMsg = 'CEP não encontrado.');
        } else {
          setState(() {
            _logCtrl.text   = data['logradouro']?.toString() ?? '';
            _bairroCtrl.text = data['bairro']?.toString() ?? '';
            _cidadeCtrl.text = data['localidade']?.toString() ?? '';
            _ufCtrl.text    = data['uf']?.toString() ?? '';
          });
        }
      }
    } catch (_) {
      setState(() => _errorMsg = 'Falha ao buscar CEP. Verifique sua conexão.');
    } finally {
      if (mounted) setState(() => _isFetchingCep = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSaving = true; _errorMsg = null; });

    final telDigits = _telMask.getUnmaskedText();
    final cepDigits = _cepMask.getUnmaskedText();

    final dados = <String, dynamic>{
      'nome'        : _nomeCtrl.text.trim(),
      'telefone'    : telDigits.isNotEmpty ? telDigits : _telCtrl.text.replaceAll(RegExp(r'\D'), ''),
      'cep'         : cepDigits.isNotEmpty ? cepDigits : _cepCtrl.text.replaceAll(RegExp(r'\D'), ''),
      'logradouro'  : _logCtrl.text.trim(),
      'numero'      : _numCtrl.text.trim(),
      'complemento' : _complCtrl.text.trim(),
      'bairro'      : _bairroCtrl.text.trim(),
      'cidade'      : _cidadeCtrl.text.trim(),
      'uf'          : _ufCtrl.text.trim().toUpperCase(),
      if (_generoSelecionado != null) 'genero': _generoSelecionado,
    };

    for (final f in widget.camposExtras) {
      dados[f.fieldKey] = _extraCtrls[f.fieldKey]!.text.trim();
    }

    final res = await _api.updateUsuario(widget.usuarioId, dados);
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (res['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMsg = res['message']?.toString() ?? 'Erro ao salvar.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Editar Dados Pessoais',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 20),

              // ── Erro ─────────────────────────────────────────────────────
              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: AppTheme.error))),
                  ]),
                ),

              // ── Campos em scroll ─────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Dados Pessoais', accent),
                      const SizedBox(height: 8),

                      _field('Nome completo *', _nomeCtrl,
                          icon: Icons.person_outline,
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Nome inválido.' : null),
                      const SizedBox(height: 10),

                      _field('Telefone', _telCtrl,
                          icon: Icons.phone_outlined,
                          mask: _telMask,
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 10),

                      // Gênero (só se o campo existir no perfil)
                      if (widget.perfilData.containsKey('genero')) ...[
                        DropdownButtonFormField<String>(
                          value: _generos.contains(_generoSelecionado) ? _generoSelecionado : null,
                          decoration: InputDecoration(
                            labelText: 'Gênero',
                            prefixIcon: const Icon(Icons.people_outline, size: 20),
                            filled: true,
                            fillColor: AppTheme.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          items: _generos.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _generoSelecionado = v),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Campos extras (ex: CREFITO, especialidade)
                      for (final f in widget.camposExtras) ...[
                        _field(f.label, _extraCtrls[f.fieldKey]!,
                            icon: f.icon, keyboardType: f.keyboardType),
                        const SizedBox(height: 10),
                      ],

                      const SizedBox(height: 6),
                      _sectionLabel('Endereço', accent),
                      const SizedBox(height: 8),

                      // CEP com busca automática
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field('CEP', _cepCtrl,
                                icon: Icons.location_on_outlined,
                                mask: _cepMask,
                                keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isFetchingCep ? null : _fetchCep,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isFetchingCep
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Buscar', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _field('Logradouro', _logCtrl, icon: Icons.home_outlined),
                      const SizedBox(height: 10),

                      Row(children: [
                        Expanded(child: _field('Número', _numCtrl, icon: Icons.tag_outlined)),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: _field('UF', _ufCtrl, icon: Icons.map_outlined)),
                      ]),
                      const SizedBox(height: 10),

                      _field('Complemento', _complCtrl, icon: Icons.add_location_alt_outlined),
                      const SizedBox(height: 10),

                      _field('Bairro', _bairroCtrl, icon: Icons.holiday_village_outlined),
                      const SizedBox(height: 10),

                      _field('Cidade', _cidadeCtrl, icon: Icons.location_city_outlined),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Botões ───────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                      onPressed: _isSaving ? null : _salvar,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Row(children: [
      Container(width: 3, height: 13, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, {
    IconData? icon,
    MaskTextInputFormatter? mask,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: mask != null ? [mask] : null,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }
}
