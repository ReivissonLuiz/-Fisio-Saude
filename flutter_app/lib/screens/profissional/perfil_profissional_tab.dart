/// perfil_profissional_tab.dart
/// Aba de perfil para Fisioterapeutas
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PerfilProfissionalTab extends StatefulWidget {
  final String profissionalId;
  final String nome;
  final String email;
  final String? supabaseUserId;
  final Future<void> Function() onLogout;

  const PerfilProfissionalTab({
    super.key,
    required this.profissionalId,
    required this.nome,
    required this.email,
    this.supabaseUserId,
    required this.onLogout,
  });

  @override
  State<PerfilProfissionalTab> createState() => _PerfilProfissionalTabState();
}

class _PerfilProfissionalTabState extends State<PerfilProfissionalTab> {
  final _api = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _perfilData;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    setState(() => _isLoading = true);
    try {
      if (widget.profissionalId.isNotEmpty) {
        final res = await _api.getUsuario(widget.profissionalId);
        if (mounted) {
          setState(() {
            _perfilData = res['success'] ? res['data'] : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Abre o diálogo para editar dados do perfil profissional
  Future<void> _showEditarPerfilDialog() async {
    final formKey = GlobalKey<FormState>();

    // Extrai o número e tipo do CREFITO existente
    final crefitoAtual = _perfilData?['crefito'] as String? ?? '';
    String tipoCrefito = 'F';
    String crefitoNumeros = '';
    if (crefitoAtual.contains('-TO')) {
      tipoCrefito = 'TO';
      crefitoNumeros = crefitoAtual.replaceAll('-TO', '');
    } else if (crefitoAtual.contains('-F')) {
      tipoCrefito = 'F';
      crefitoNumeros = crefitoAtual.replaceAll('-F', '');
    } else {
      crefitoNumeros = crefitoAtual.replaceAll(RegExp(r'[^\d]'), '');
    }

    final crefitoNumCtrl = TextEditingController(text: crefitoNumeros);
    final telCtrl = TextEditingController(text: _perfilData?['telefone'] as String? ?? '');

    final crefitoNumMask = MaskTextInputFormatter(
        mask: '#######', filter: {'#': RegExp(r'\d')});
    final telMask = MaskTextInputFormatter(
        mask: '(##) #####-####', filter: {'#': RegExp(r'\d')});

    const especializacoes = [
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

    String? especializacaoSelecionada = _perfilData?['especialidade'] as String?;
    // Garante que o valor salvo existe na lista; se não, deixa null
    if (especializacaoSelecionada != null &&
        !especializacoes.contains(especializacaoSelecionada)) {
      especializacaoSelecionada = null;
    }

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.secondary),
              SizedBox(width: 10),
              Text('Editar Perfil Profissional',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Seletor de categoria (F ou TO)
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
                          const Text('Categoria Profissional',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setStateDialog(() => tipoCrefito = 'F'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tipoCrefito == 'F'
                                          ? AppTheme.secondary
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Fisioterapeuta',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: tipoCrefito == 'F'
                                                    ? Colors.white
                                                    : AppTheme.textSecondary),
                                            textAlign: TextAlign.center),
                                        Text('-F',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: tipoCrefito == 'F'
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
                                  onTap: () => setStateDialog(() => tipoCrefito = 'TO'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: tipoCrefito == 'TO'
                                          ? AppTheme.primary
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('Ter. Ocupacional',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: tipoCrefito == 'TO'
                                                    ? Colors.white
                                                    : AppTheme.textSecondary),
                                            textAlign: TextAlign.center),
                                        Text('-TO',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: tipoCrefito == 'TO'
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
                    const SizedBox(height: 12),
                    // Número do CREFITO + badge do sufixo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'CREFITO Número *',
                            hint: '0123456',
                            controller: crefitoNumCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [crefitoNumMask],
                            prefixIcon: const Icon(Icons.workspace_premium_outlined),
                            validator: (_) {
                              final nums = crefitoNumMask.getUnmaskedText();
                              return Validators.crefito('$nums-$tipoCrefito');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatefulBuilder(
                          builder: (_, __) => Container(
                            height: 60,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: tipoCrefito == 'F'
                                  ? AppTheme.secondary.withValues(alpha: 0.1)
                                  : AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: tipoCrefito == 'F'
                                      ? AppTheme.secondary.withValues(alpha: 0.4)
                                      : AppTheme.primary.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '-$tipoCrefito',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: tipoCrefito == 'F'
                                      ? AppTheme.secondary
                                      : AppTheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: especializacaoSelecionada,
                      decoration: InputDecoration(
                        labelText: 'Especialização *',
                        prefixIcon: const Icon(Icons.category_outlined),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: especializacoes
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => especializacaoSelecionada = v),
                      validator: (v) => v == null ? 'Selecione.' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Telefone',
                      hint: '(11) 99999-9999',
                      controller: telCtrl,
                      inputFormatters: [telMask],
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setStateDialog(() => isSaving = true);
                
                final crefitoFinal = '${crefitoNumMask.getUnmaskedText()}-$tipoCrefito';
                final res = await _api.updateUsuario(
                  widget.profissionalId,
                  {
                    'crefito': crefitoFinal,
                    'especialidade': especializacaoSelecionada ?? '',
                    'telefone': telCtrl.text,
                  },
                );
                
                setStateDialog(() => isSaving = false);
                if (!ctx.mounted) return;
                
                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  await _loadPerfil();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Perfil atualizado com sucesso!'),
                      backgroundColor: AppTheme.accent,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Erro ao salvar.'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              },
              icon: isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            ),
          ],
        ),
      ),
    );

    crefitoNumCtrl.dispose();
    telCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: AppTheme.secondary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.secondary, Color(0xFF00ACC1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              child: Text(
                                widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.nome,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _perfilData?['especialidade'] as String? ?? 'Fisioterapeuta',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // --- Seção: Informações Pessoais -------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Informações Profissionais',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary)),
                          TextButton.icon(
                            onPressed: _showEditarPerfilDialog,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Editar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            _buildInfoTile(
                              Icons.email_outlined,
                              'E-mail',
                              widget.email,
                            ),
                            const Divider(height: 1, color: AppTheme.divider, indent: 56),
                            if (_perfilData?['telefone'] != null && _perfilData!['telefone'].toString().isNotEmpty) ...[
                              _buildInfoTile(
                                Icons.phone_outlined,
                                'Telefone',
                                _formatarTelefone(_perfilData!['telefone']),
                              ),
                              const Divider(height: 1, color: AppTheme.divider, indent: 56),
                            ],
                            _buildInfoTile(
                              Icons.workspace_premium_outlined,
                              'CREFITO',
                              _perfilData?['crefito'] ?? 'Não informado',
                            ),
                            const Divider(height: 1, color: AppTheme.divider, indent: 56),
                            _buildInfoTile(
                              Icons.category_outlined,
                              'Especialidade',
                              _perfilData?['especialidade'] ?? 'Não informada',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Seção: Permissão -------------------------------------
                      const Text('Nível de Acesso',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.secondary.withValues(alpha: 0.08),
                              AppTheme.secondary.withValues(alpha: 0.04)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.secondary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.medical_services_rounded,
                                  color: AppTheme.secondary,
                                  size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Profissional',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.secondary)),
                                  SizedBox(height: 2),
                                  Text(
                                      'Acesso à agenda, pacientes e consultas',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Ativo',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Botão Sair --------------------------------------------
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmLogout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.error,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.divider),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text('Sair da Conta',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppTheme.secondary.withValues(alpha: 0.7)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarTelefone(String? tel) {
    if (tel == null || tel.isEmpty) return 'Não informado';
    final digits = tel.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return tel;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.onLogout();
    }
  }
}
