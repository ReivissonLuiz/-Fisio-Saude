import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _pacientes = [];
  List<dynamic> _profissionais = [];
  String _searchQuery = '';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getAllPacientes(filterAtivo: false),
      _api.getAllProfissionais(filterAtivo: false),
    ]);
    if (mounted) {
      setState(() {
        _pacientes      = results[0]['success'] ? results[0]['data'] : [];
        _profissionais  = results[1]['success'] ? results[1]['data'] : [];
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredPacientes => _pacientes
      .where((p) => p['nome'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  List<dynamic> get _filteredProfissionais => _profissionais
      .where((p) => p['nome'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  // ── Editar usuário ─────────────────────────────────────────────────────────
  Future<void> _showEditDialog(Map<String, dynamic> usuario) async {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl    = TextEditingController(text: usuario['nome']?.toString() ?? '');
    final emailCtrl   = TextEditingController(text: usuario['email']?.toString() ?? '');
    final telCtrl     = TextEditingController(text: usuario['telefone']?.toString() ?? '');
    final cepCtrl     = TextEditingController(text: usuario['cep']?.toString() ?? '');
    final logCtrl     = TextEditingController(text: usuario['logradouro']?.toString() ?? '');
    final numCtrl     = TextEditingController(text: usuario['numero']?.toString() ?? '');
    final bairroCtrl  = TextEditingController(text: usuario['bairro']?.toString() ?? '');
    final cidadeCtrl  = TextEditingController(text: usuario['cidade']?.toString() ?? '');
    final ufCtrl      = TextEditingController(text: usuario['uf']?.toString() ?? '');
    final crefitoCtrl = TextEditingController(text: usuario['crefito']?.toString() ?? '');
    final espCtrl     = TextEditingController(text: usuario['especialidade']?.toString() ?? '');

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.purple, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Editar Usuário',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              usuario['nome']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 20),

                  // Campos em scroll
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _EditSection(title: 'Dados Pessoais', children: [
                            _editField('Nome completo', nomeCtrl, icon: Icons.person_outline, required: true),
                            _editField('E-mail', emailCtrl, icon: Icons.email_outlined, required: true,
                                keyboardType: TextInputType.emailAddress),
                            _editField('Telefone', telCtrl, icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone),
                          ]),
                          if ((usuario['id_permissao'] as int?) == 2) ...[
                            const SizedBox(height: 12),
                            _EditSection(title: 'Dados Profissionais', children: [
                              _editField('CREFITO', crefitoCtrl, icon: Icons.workspace_premium_outlined),
                              _editField('Especialidade', espCtrl, icon: Icons.category_outlined),
                            ]),
                          ],
                          const SizedBox(height: 12),
                          _EditSection(title: 'Endereço', children: [
                            _editField('CEP', cepCtrl, icon: Icons.location_on_outlined,
                                keyboardType: TextInputType.number),
                            _editField('Logradouro', logCtrl, icon: Icons.home_outlined),
                            Row(
                              children: [
                                Expanded(child: _editField('Número', numCtrl, icon: Icons.tag_outlined)),
                                const SizedBox(width: 8),
                                SizedBox(width: 80, child: _editField('UF', ufCtrl, icon: Icons.map_outlined)),
                              ],
                            ),
                            _editField('Bairro', bairroCtrl, icon: Icons.holiday_village_outlined),
                            _editField('Cidade', cidadeCtrl, icon: Icons.location_city_outlined),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          onPressed: isSaving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setD(() => isSaving = true);

                            final dados = <String, dynamic>{
                              'nome'       : nomeCtrl.text.trim(),
                              'email'      : emailCtrl.text.trim().toLowerCase(),
                              'telefone'   : telCtrl.text.trim(),
                              'cep'        : cepCtrl.text.trim(),
                              'logradouro' : logCtrl.text.trim(),
                              'numero'     : numCtrl.text.trim(),
                              'bairro'     : bairroCtrl.text.trim(),
                              'cidade'     : cidadeCtrl.text.trim(),
                              'uf'         : ufCtrl.text.trim().toUpperCase(),
                            };
                            if ((usuario['id_permissao'] as int?) == 2) {
                              dados['crefito']     = crefitoCtrl.text.trim();
                              dados['especialidade'] = espCtrl.text.trim();
                            }

                            final res = await _api.updateUsuario(
                                usuario['id'].toString(), dados);
                            setD(() => isSaving = false);

                            if (!ctx.mounted) return;
                            if (res['success'] == true) {
                              Navigator.pop(ctx);
                              await _loadData();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Dados atualizados com sucesso!'),
                                backgroundColor: AppTheme.accent,
                              ));
                            } else {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(res['message'] ?? 'Erro ao salvar.'),
                                backgroundColor: AppTheme.error,
                              ));
                            }
                          },
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded),
                          label: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    for (final c in [nomeCtrl, emailCtrl, telCtrl, cepCtrl, logCtrl, numCtrl, bairroCtrl, cidadeCtrl, ufCtrl, crefitoCtrl, espCtrl]) {
      c.dispose();
    }
  }

  Widget _editField(String label, TextEditingController ctrl, {
    IconData? icon, bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          filled: true,
          fillColor: AppTheme.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
            : null,
      ),
    );
  }

  // ── Toggle / Delete ────────────────────────────────────────────────────────
  Future<void> _confirmToggleAtivo(String id, String nome, bool isAtivo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isAtivo ? 'Desativar conta' : 'Reativar conta'),
        content: Text(isAtivo
            ? 'Desativar "$nome"? O usuário não conseguirá fazer login.'
            : 'Reativar "$nome"? O usuário voltará a ter acesso normal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: isAtivo ? Colors.orange : AppTheme.accent),
            child: Text(isAtivo ? 'Desativar' : 'Reativar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final res = isAtivo
        ? await _api.deactivateRecord('usuario', id)
        : await _api.reactivateRecord('usuario', id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success']
          ? (isAtivo ? '"$nome" desativado.' : '"$nome" reativado.')
          : (res['message'] ?? 'Falha na operação')),
      backgroundColor: res['success']
          ? (isAtivo ? Colors.orange : AppTheme.accent)
          : AppTheme.error,
    ));
    if (res['success']) _loadData();
  }

  Future<void> _confirmPermanentDelete(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⚠️ Excluir permanentemente'),
        content: Text('Tem certeza que deseja EXCLUIR "$nome"?\n\nEsta ação é IRREVERSÍVEL.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final res = await _api.permanentDeleteUsuario(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] ? '"$nome" excluído permanentemente.' : (res['message'] ?? 'Falha ao excluir')),
      backgroundColor: res['success'] ? AppTheme.error : AppTheme.error,
    ));
    if (res['success']) _loadData();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gestão de Usuários', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
                        : null,
                  ),
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.purple,
                labelColor: Colors.purple,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(text: 'Fisioterapeutas (${_filteredProfissionais.length})'),
                  Tab(text: 'Pacientes (${_filteredPacientes.length})'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.purple), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _UserList(
                  users: _filteredProfissionais,
                  emptyText: 'Nenhum fisioterapeuta encontrado.',
                  accentColor: AppTheme.secondary,
                  onEdit: _showEditDialog,
                  onToggleAtivo: (p) => _confirmToggleAtivo(p['id'].toString(), p['nome'], p['ativo'] as bool? ?? true),
                  onDelete: (p) => _confirmPermanentDelete(p['id'].toString(), p['nome']),
                ),
                _UserList(
                  users: _filteredPacientes,
                  emptyText: 'Nenhum paciente encontrado.',
                  accentColor: AppTheme.primary,
                  onEdit: _showEditDialog,
                  onToggleAtivo: (p) => _confirmToggleAtivo(p['id'].toString(), p['nome'], p['ativo'] as bool? ?? true),
                  onDelete: (p) => _confirmPermanentDelete(p['id'].toString(), p['nome']),
                ),
              ],
            ),
    );
  }
}

// ── User List ─────────────────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final List<dynamic> users;
  final String emptyText;
  final Color accentColor;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onToggleAtivo;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const _UserList({
    required this.users, required this.emptyText, required this.accentColor,
    required this.onEdit, required this.onToggleAtivo, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: AppTheme.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i] as Map<String, dynamic>;
        final isAtivo = u['ativo'] as bool? ?? true;
        final nome = u['nome']?.toString() ?? 'Sem nome';
        final email = u['email']?.toString() ?? '';
        final sub = u['especialidade']?.toString() ?? u['telefone']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isAtivo ? AppTheme.divider : Colors.orange.shade200),
          ),
          child: Opacity(
            opacity: isAtivo ? 1.0 : 0.7,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  leading: CircleAvatar(
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      if (!isAtivo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
                          child: const Text('INATIVO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppTheme.divider),
                Row(
                  children: [
                    // Editar
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => onEdit(u),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Editar', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.purple),
                      ),
                    ),
                    Container(width: 1, height: 36, color: AppTheme.divider),
                    // Ativar/Desativar
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => onToggleAtivo(u),
                        icon: Icon(isAtivo ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 16),
                        label: Text(isAtivo ? 'Desativar' : 'Reativar', style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: isAtivo ? Colors.orange : AppTheme.accent),
                      ),
                    ),
                    Container(width: 1, height: 36, color: AppTheme.divider),
                    // Excluir
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => onDelete(u),
                        icon: const Icon(Icons.delete_forever_rounded, size: 16),
                        label: const Text('Excluir', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Edit Section ──────────────────────────────────────────────────────────────
class _EditSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
