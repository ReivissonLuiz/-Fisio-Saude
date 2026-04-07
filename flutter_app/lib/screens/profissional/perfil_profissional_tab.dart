import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class PerfilProfissionalTab extends StatefulWidget {
  final String profissionalId;
  final String nome;
  final String email;
  final Future<void> Function() onLogout;

  // Parâmetros opcionais para suporte a múltiplos papéis
  final String? pacienteId;
  final String? adminId;
  final String? supabaseUserId;
  final bool isAdmin;
  final void Function(String newPacienteId)? onPacienteRoleAdded;
  final void Function(String newProfissionalId)? onProfissionalRoleAdded;

  const PerfilProfissionalTab({
    super.key,
    required this.profissionalId,
    required this.nome,
    required this.email,
    required this.onLogout,
    this.pacienteId,
    this.adminId,
    this.supabaseUserId,
    this.isAdmin = false,
    this.onPacienteRoleAdded,
    this.onProfissionalRoleAdded,
  });

  @override
  State<PerfilProfissionalTab> createState() => _PerfilProfissionalTabState();
}

class _PerfilProfissionalTabState extends State<PerfilProfissionalTab> {
  final _api = ApiService();
  bool _isLoading = true;
  bool _isAddingRole = false;
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
        final res = await _api.getProfissional(widget.profissionalId);
        if (mounted) {
          setState(() {
            _perfilData = res['success'] ? res['data'] : null;
            _isLoading = false;
          });
        }
      } else if (widget.adminId != null && widget.adminId!.isNotEmpty) {
        // Administrador sem papel profissional ainda — mostra dados básicos
        if (mounted) setState(() => _isLoading = false);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Abre o diálogo para adicionar papel de Paciente
  Future<void> _showAddPacienteRoleDialog() async {
    final formKey = GlobalKey<FormState>();
    final cpfCtrl = TextEditingController();
    final nascCtrl = TextEditingController();
    String? generoSelecionado;

    final cpfMask = MaskTextInputFormatter(
        mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
    final nascMask = MaskTextInputFormatter(
        mask: '##/##/####', filter: {'#': RegExp(r'\d')});

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('Ativar como Paciente',
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Preencha os dados para criar o seu perfil de paciente. '
                        'Isso permitirá que você acesse a área de saúde do app.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'CPF *',
                      hint: '000.000.000-00',
                      inputFormatters: [cpfMask],
                      controller: cpfCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) =>
                          cpfMask.getUnmaskedText().length != 11
                              ? 'CPF inválido.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Data de Nascimento *',
                      hint: 'DD/MM/AAAA',
                      inputFormatters: [nascMask],
                      controller: nascCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.cake_outlined),
                      validator: (v) =>
                          (v == null || v.length != 10) ? 'Data inválida.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: generoSelecionado,
                      decoration: InputDecoration(
                        labelText: 'Gênero *',
                        prefixIcon: const Icon(Icons.people_outline),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                        DropdownMenuItem(value: 'Feminino', child: Text('Feminino')),
                        DropdownMenuItem(value: 'Não-Binário', child: Text('Não-Binário')),
                        DropdownMenuItem(value: 'Desejo não Informar', child: Text('Desejo não Informar')),
                      ],
                      onChanged: (v) => setStateDialog(() => generoSelecionado = v),
                      validator: (v) => v == null ? 'Selecione.' : null,
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
              onPressed: _isAddingRole
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      // Fecha o diálogo ANTES de chamar setState do pai
                      Navigator.pop(ctx);
                      setState(() => _isAddingRole = true);
                      final uid = widget.supabaseUserId ??
                          _api.currentUser?.id ?? '';
                      final res = await _api.addPacienteRole(
                        supabaseUserId: uid,
                        nome: widget.nome,
                        email: widget.email,
                        cpf: cpfCtrl.text,
                        dataNascimento: nascCtrl.text,
                        genero: generoSelecionado ?? '',
                      );
                      if (!mounted) return;
                      setState(() => _isAddingRole = false);
                      if (res['success'] == true) {
                        widget.onPacienteRoleAdded
                            ?.call(res['id_paciente'] as String);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perfil de Paciente ativado com sucesso! Reinicie o app para ver as abas.'),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Erro ao ativar papel.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ativar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );

    cpfCtrl.dispose();
    nascCtrl.dispose();
  }

  /// Abre o diálogo para adicionar papel de Profissional (apenas ADM)
  Future<void> _showAddProfissionalRoleDialog() async {
    final formKey = GlobalKey<FormState>();
    final cpfCtrl = TextEditingController();
    final crefitoCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String? especializacaoSelecionada;

    final cpfMask = MaskTextInputFormatter(
        mask: '###.###.###-##', filter: {'#': RegExp(r'\d')});
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
      'Outra',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.medical_services_rounded, color: AppTheme.secondary),
              SizedBox(width: 10),
              Text('Ativar como Profissional',
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Preencha os dados profissionais para ativar a visão de Fisioterapeuta.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'CPF *',
                      hint: '000.000.000-00',
                      controller: cpfCtrl,
                      inputFormatters: [cpfMask],
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) =>
                          cpfMask.getUnmaskedText().length != 11
                              ? 'CPF inválido.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'CREFITO *',
                      hint: 'Ex: 3-12345-F',
                      controller: crefitoCtrl,
                      prefixIcon: const Icon(Icons.workspace_premium_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o CREFITO.' : null,
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
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (v) => setStateDialog(() => especializacaoSelecionada = v),
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                setState(() => _isAddingRole = true);
                final uid = widget.supabaseUserId ?? _api.currentUser?.id ?? '';
                final res = await _api.addProfissionalRole(
                  supabaseUserId: uid,
                  nome: widget.nome,
                  email: widget.email,
                  cpf: cpfCtrl.text,           // CPF do formulário, não de _perfilData
                  crefito: crefitoCtrl.text,
                  especialidade: especializacaoSelecionada ?? '',
                  telefone: telCtrl.text,
                );
                if (!mounted) return;
                setState(() => _isAddingRole = false);
                if (res['success'] == true) {
                  widget.onProfissionalRoleAdded
                      ?.call(res['id_profissional'] as String);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Papel de Profissional ativado! Reinicie o app para ver as abas.'),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Erro ao ativar papel.'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ativar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            ),
          ],
        ),
      ),
    );

    cpfCtrl.dispose();
    crefitoCtrl.dispose();
    telCtrl.dispose();
  }

  /// Abre o diálogo para editar dados do perfil profissional (CREFITO, especialidade, telefone)
  Future<void> _showEditarPerfilDialog() async {
    final formKey = GlobalKey<FormState>();
    final crefitoCtrl = TextEditingController(text: _perfilData?['crefito'] as String? ?? '');
    final telCtrl = TextEditingController(text: _perfilData?['telefone'] as String? ?? '');

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
      'Outra',
    ];

    String? especializacaoSelecionada = _perfilData?['especialidade'] as String?;
    // Garante que o valor salvo existe na lista; se não, deixa null
    if (especializacaoSelecionada != null &&
        !especializacoes.contains(especializacaoSelecionada)) {
      especializacaoSelecionada = null;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primary),
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
                    CustomTextField(
                      label: 'CREFITO *',
                      hint: 'Ex: 3-12345-F',
                      controller: crefitoCtrl,
                      prefixIcon: const Icon(Icons.workspace_premium_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o CREFITO.' : null,
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
              onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);
                      setState(() => _isAddingRole = true);
                      final res = await _api.updateProfissional(
                        widget.profissionalId,
                        {
                          'crefito': crefitoCtrl.text.trim(),
                          'especialidade': especializacaoSelecionada ?? '',
                          'telefone': telCtrl.text,
                        },
                      );
                      if (!mounted) return;
                      setState(() => _isAddingRole = false);
                      if (res['success'] == true) {
                        // Recarrega perfil para refletir dados atualizados
                        await _loadPerfil();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Perfil atualizado com sucesso!'),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Erro ao salvar.'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Salvar'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );

    crefitoCtrl.dispose();
    telCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool temPapelProfissional = widget.profissionalId.isNotEmpty;
    final bool temPapelPaciente = widget.pacienteId != null && widget.pacienteId!.isNotEmpty;

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
                  backgroundColor: widget.isAdmin
                      ? Colors.purple
                      : AppTheme.primary,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: widget.isAdmin
                            ? const LinearGradient(
                                colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : AppTheme.primaryGradient,
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
                              widget.isAdmin
                                  ? 'Administrador'
                                  : (_perfilData?['especialidade'] ?? 'Fisioterapeuta'),
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

                      // --- Seção: Meus Papéis -----------------------------------
                      _buildSection('Meus Papéis', [
                        _buildRoleTile(
                          icon: widget.isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.medical_services_rounded,
                          label: widget.isAdmin ? 'Administrador' : 'Fisioterapeuta',
                          active: true,
                          color: widget.isAdmin ? Colors.purple : AppTheme.secondary,
                        ),
                        if (widget.isAdmin) ...[
                          const Divider(height: 1, color: AppTheme.divider, indent: 56),
                          _buildRoleTile(
                            icon: Icons.medical_services_outlined,
                            label: 'Fisioterapeuta',
                            active: temPapelProfissional,
                            color: AppTheme.secondary,
                            onActivate: temPapelProfissional
                                ? null
                                : () => _showAddProfissionalRoleDialog(),
                          ),
                        ],
                        const Divider(height: 1, color: AppTheme.divider, indent: 56),
                        _buildRoleTile(
                          icon: Icons.person_rounded,
                          label: 'Paciente',
                          active: temPapelPaciente,
                          color: AppTheme.primary,
                          onActivate: temPapelPaciente
                              ? null
                              : () => _showAddPacienteRoleDialog(),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // --- Seção: Informações Pessoais -------------------------
                      if (temPapelProfissional || widget.isAdmin)
                        _buildSection('Informações Pessoais', [
                          if (temPapelProfissional) ...[
                            _buildInfoTile(Icons.assignment_ind_rounded, 'CREFITO', _perfilData?['crefito'] ?? '-'),
                            _buildInfoTile(Icons.work_outline_rounded, 'Especialidade', _perfilData?['especialidade'] ?? 'Fisioterapia'),
                          ],
                          _buildInfoTile(Icons.email_outlined, 'E-mail', widget.email),
                          _buildInfoTile(Icons.phone_outlined, 'Telefone', _perfilData?['telefone'] ?? 'Não informado'),
                        ]),
                      const SizedBox(height: 16),

                      // --- Seção: Configurações --------------------------------
                      _buildSection('Configurações', [
                        _buildMenuTile(Icons.edit_note_rounded, 'Editar Perfil',
                            temPapelProfissional ? _showEditarPerfilDialog : () {}),
                        _buildMenuTile(Icons.notifications_none_rounded, 'Notificações', () {}),
                        _buildMenuTile(Icons.help_outline_rounded, 'Ajuda e Suporte', () {}),
                      ]),
                      const SizedBox(height: 32),

                      // --- Botão Sair ------------------------------------------
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
                          label: const Text('Sair da Conta', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildRoleTile({
    required IconData icon,
    required String label,
    required bool active,
    required Color color,
    VoidCallback? onActivate,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: active ? color : Colors.grey, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: active ? AppTheme.textPrimary : Colors.grey)),
      trailing: active
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Ativo',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : TextButton.icon(
              onPressed: onActivate,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Ativar'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              return e.value;
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja encerrar sua Sessão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
