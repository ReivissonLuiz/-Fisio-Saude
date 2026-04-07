import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';

/// Aba de perfil exclusiva para Administradores.
/// Mostra todas as visões disponíveis (ADM, Fisioterapeuta, Paciente),
/// permitindo ativação ou troca de papel diretamente desta tela.
class AdminPerfilTab extends StatefulWidget {
  final String nome;
  final String email;
  final String? supabaseUserId;
  final String activeView;
  final bool hasProfissional;
  final bool hasPaciente;
  final Future<void> Function() onLogout;
  final void Function(String) onSwitchView;
  final void Function(String newProfissionalId)? onProfissionalRoleAdded;
  final void Function(String newPacienteId)? onPacienteRoleAdded;

  const AdminPerfilTab({
    super.key,
    required this.nome,
    required this.email,
    this.supabaseUserId,
    required this.activeView,
    required this.hasProfissional,
    required this.hasPaciente,
    required this.onLogout,
    required this.onSwitchView,
    this.onProfissionalRoleAdded,
    this.onPacienteRoleAdded,
  });

  @override
  State<AdminPerfilTab> createState() => _AdminPerfilTabState();
}

class _AdminPerfilTabState extends State<AdminPerfilTab> {
  final _api = ApiService();
  bool _isActivating = false;

  // ── Activar Fisioterapeuta ─────────────────────────────────────────────────
  Future<void> _showAddProfissionalDialog() async {
    final formKey = GlobalKey<FormState>();
    final cpfCtrl = TextEditingController();
    final crefitoCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    String? especializacao;

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
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.medical_services_rounded, color: AppTheme.secondary),
            SizedBox(width: 10),
            Expanded(
              child: Text('Ativar como Fisioterapeuta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _infoBanner(
                      'Preencha os dados profissionais para ativar a visão de Fisioterapeuta.',
                      AppTheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'CPF *',
                      hint: '000.000.000-00',
                      controller: cpfCtrl,
                      inputFormatters: [cpfMask],
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) => cpfMask.getUnmaskedText().length != 11
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
                      value: especializacao,
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
                      onChanged: (v) => setD(() => especializacao = v),
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
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                setState(() => _isActivating = true);
                final uid = widget.supabaseUserId ?? _api.currentUser?.id ?? '';
                final res = await _api.addProfissionalRole(
                  supabaseUserId: uid,
                  nome: widget.nome,
                  email: widget.email,
                  cpf: cpfCtrl.text,
                  crefito: crefitoCtrl.text,
                  especialidade: especializacao ?? '',
                  telefone: telCtrl.text,
                );
                if (!mounted) return;
                setState(() => _isActivating = false);
                if (res['success'] == true) {
                  widget.onProfissionalRoleAdded?.call(res['id_profissional'] as String);
                  _showSnack('Papel de Fisioterapeuta ativado com sucesso!', success: true);
                } else {
                  _showSnack(res['message'] ?? 'Erro ao ativar papel.', success: false);
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

  // ── Activar Paciente ───────────────────────────────────────────────────────
  Future<void> _showAddPacienteDialog() async {
    final formKey = GlobalKey<FormState>();
    final cpfCtrl = TextEditingController();
    final nascCtrl = TextEditingController();
    String? genero;

    final Map<String, RegExp> filter = {"#": RegExp(r'[0-9]')};
    final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##', filter: filter);
    final nascMask = MaskTextInputFormatter(mask: '##/##/####', filter: filter);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.person_add_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Ativar como Paciente',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _infoBanner(
                      'Preencha os dados para criar o seu perfil de paciente.',
                      AppTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'CPF *',
                      hint: '000.000.000-00',
                      inputFormatters: <TextInputFormatter>[cpfMask],
                      controller: cpfCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) {
                        final val = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                        return val.length != 11 ? 'CPF inválido.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Data de Nascimento *',
                      hint: 'DD/MM/AAAA',
                      inputFormatters: <TextInputFormatter>[nascMask],
                      controller: nascCtrl,
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.cake_outlined),
                      validator: (v) =>
                          (v == null || v.length != 10) ? 'Data inválida.' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: genero,
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
                        DropdownMenuItem(
                            value: 'Não-Binário', child: Text('Não-Binário')),
                        DropdownMenuItem(
                            value: 'Desejo não Informar',
                            child: Text('Desejo não Informar')),
                      ],
                      onChanged: (v) => setD(() => genero = v),
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
                child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                setState(() => _isActivating = true);
                final uid = widget.supabaseUserId ?? _api.currentUser?.id ?? '';
                final res = await _api.addPacienteRole(
                  supabaseUserId: uid,
                  nome: widget.nome,
                  email: widget.email,
                  cpf: cpfCtrl.text,
                  dataNascimento: nascCtrl.text,
                  genero: genero ?? '',
                );
                if (!mounted) return;
                setState(() => _isActivating = false);
                if (res['success'] == true) {
                  widget.onPacienteRoleAdded?.call(res['id_paciente'] as String);
                  _showSnack('Perfil de Paciente ativado com sucesso!', success: true);
                } else {
                  _showSnack(res['message'] ?? 'Erro ao ativar papel.', success: false);
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

  void _showSnack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? AppTheme.accent : AppTheme.error,
    ));
  }

  Widget _infoBanner(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isActivating
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.purple,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
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
                                widget.nome.isNotEmpty
                                    ? widget.nome[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(widget.nome,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              _viewLabel(),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Conteúdo ─────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Seção: Meus Papéis ──────────────────────────
                      const Text('Meus Papéis',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      const Text(
                        'Como administrador, você pode alternar ou ativar diferentes perfis de acesso.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                            // ADM — sempre ativo
                            _roleTile(
                              icon: Icons.admin_panel_settings_rounded,
                              color: Colors.purple,
                              label: 'Administrador',
                              description: 'Dashboard e gestão do sistema',
                              viewKey: 'admin',
                              isActivated: true,
                              isFirst: true,
                              isLast: false,
                            ),
                            const Divider(
                                height: 1, color: AppTheme.divider, indent: 56),
                            // Fisioterapeuta
                            _roleTile(
                              icon: Icons.medical_services_rounded,
                              color: AppTheme.secondary,
                              label: 'Fisioterapeuta',
                              description: 'Agenda de consultas e pacientes',
                              viewKey: 'profissional',
                              isActivated: widget.hasProfissional,
                              isFirst: false,
                              isLast: false,
                              onActivate: _showAddProfissionalDialog,
                            ),
                            const Divider(
                                height: 1, color: AppTheme.divider, indent: 56),
                            // Paciente
                            _roleTile(
                              icon: Icons.person_rounded,
                              color: AppTheme.primary,
                              label: 'Paciente',
                              description: 'Buscar fisios, saúde e consultas',
                              viewKey: 'paciente',
                              isActivated: widget.hasPaciente,
                              isFirst: false,
                              isLast: true,
                              onActivate: _showAddPacienteDialog,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Seção: Informações da Conta ─────────────────
                      const Text('Informações da Conta',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            _infoTile(Icons.badge_outlined, 'Função',
                                'Administrador'),
                            const Divider(
                                height: 1, color: AppTheme.divider, indent: 56),
                            _infoTile(Icons.email_outlined, 'E-mail',
                                widget.email),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Seção: Configurações ────────────────────────
                      const Text('Configurações',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            _menuTile(Icons.notifications_none_rounded,
                                'Notificações', () {}),
                            const Divider(
                                height: 1, color: AppTheme.divider, indent: 56),
                            _menuTile(Icons.help_outline_rounded,
                                'Ajuda e Suporte', () {}),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Botão Sair ──────────────────────────────────
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
                          icon:
                              const Icon(Icons.logout_rounded, size: 20),
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

  String _viewLabel() {
    switch (widget.activeView) {
      case 'profissional':
        return 'Visão: Fisioterapeuta';
      case 'paciente':
        return 'Visão: Paciente';
      default:
        return 'Administrador';
    }
  }

  /// Tile de papel: se ativado mostra badge "Ativo" + botão de troca;
  /// se não ativado mostra botão "Ativar".
  Widget _roleTile({
    required IconData icon,
    required Color color,
    required String label,
    required String description,
    required String viewKey,
    required bool isActivated,
    required bool isFirst,
    required bool isLast,
    VoidCallback? onActivate,
  }) {
    final bool isCurrentView = widget.activeView == viewKey;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: isActivated && !isCurrentView
            ? () => widget.onSwitchView(viewKey)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isActivated
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: isActivated ? color : Colors.grey.shade400, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isActivated
                            ? AppTheme.textPrimary
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (!isActivated)
                // Botão para ativar o papel
                TextButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                  label: const Text('Ativar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else if (isCurrentView)
                // Badge "Ativo"
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Ativo',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                )
              else
                // Botão para mudar para esse papel
                TextButton(
                  onPressed: () => widget.onSwitchView(viewKey),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Usar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textSecondary, size: 20),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
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
