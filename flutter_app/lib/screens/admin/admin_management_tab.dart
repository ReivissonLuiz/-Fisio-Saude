import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _pacientes = [];
  List<dynamic> _profissionais = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final resPac = await _api.getAllPacientes(filterAtivo: false);
    final resProf = await _api.getAllProfissionais(filterAtivo: false);

    if (mounted) {
      setState(() {
        _pacientes = resPac['success'] ? resPac['data'] : [];
        _profissionais = resProf['success'] ? resProf['data'] : [];
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmToggleAtivo(
      String table, String id, String nome, bool isAtivo) async {
    final acaoLabel = isAtivo ? 'Desativar' : 'Reativar';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$acaoLabel conta'),
        content: Text(
          isAtivo
              ? 'Deseja desativar "$nome"?\n\nA conta ficará no banco de dados, mas o usuário não conseguirá fazer login.'
              : 'Deseja reativar "$nome"?\n\nO usuário voltará a ter acesso normal ao sistema.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAtivo ? Colors.orange : AppTheme.accent,
            ),
            child: Text(acaoLabel),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = isAtivo
          ? await _api.deactivateRecord('usuario', id)
          : await _api.reactivateRecord('usuario', id);

      if (!mounted) return;
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAtivo
              ? '"$nome" foi desativado.'
              : '"$nome" foi reativado.'),
          backgroundColor: isAtivo ? Colors.orange : AppTheme.accent,
        ));
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Falha na operação'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _confirmPermanentDelete(
      String table, String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Excluir permanentemente'),
        content: Text(
          'Tem certeza que deseja EXCLUIR "$nome" do sistema?\n\n'
          'Esta ação é IRREVERSÍVEL e removerá todos os dados do banco permanentemente.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Excluir permanentemente'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await _api.permanentDeleteUsuario(id);
      if (!mounted) return;
      if (res['success']) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"$nome" foi excluído permanentemente.'),
          backgroundColor: AppTheme.error,
        ));
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Falha ao excluir'),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPacientes = _pacientes
        .where((p) => p['nome']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
    final filteredProfissionais = _profissionais
        .where((p) => p['nome']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gestão de Dados',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: 'Fisioterapeutas (${filteredProfissionais.length})',
                  icon: Icons.medical_services_rounded,
                  color: AppTheme.secondary,
                ),
                ...filteredProfissionais.map((p) => _ManagementTile(
                      id: p['id'].toString(),
                      title: p['nome'],
                      subtitle: 'CREFITO: ${p['crefito']}',
                      isAtivo: p['ativo'] as bool? ?? true,
                      onToggleAtivo: () => _confirmToggleAtivo(
                          'usuario',
                          p['id'].toString(),
                          p['nome'],
                          p['ativo'] as bool? ?? true),
                      onPermanentDelete: () => _confirmPermanentDelete(
                          'usuario', p['id'].toString(), p['nome']),
                    )),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Pacientes (${filteredPacientes.length})',
                  icon: Icons.people_rounded,
                  color: AppTheme.primary,
                ),
                ...filteredPacientes.map((p) => _ManagementTile(
                      id: p['id'].toString(),
                      title: p['nome'],
                      subtitle: p['email'],
                      isAtivo: p['ativo'] as bool? ?? true,
                      onToggleAtivo: () => _confirmToggleAtivo(
                          'usuario',
                          p['id'].toString(),
                          p['nome'],
                          p['ativo'] as bool? ?? true),
                      onPermanentDelete: () => _confirmPermanentDelete(
                          'usuario', p['id'].toString(), p['nome']),
                    )),
              ],
            ),
    );
  }
}

// --- Widgets auxiliares ------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final bool isAtivo;
  final VoidCallback onToggleAtivo;
  final VoidCallback onPermanentDelete;

  const _ManagementTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isAtivo,
    required this.onToggleAtivo,
    required this.onPermanentDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAtivo ? 1.0 : 0.65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAtivo ? AppTheme.divider : Colors.orange.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── Info ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (!isAtivo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'INATIVO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Botão Desativar / Reativar ──────────────────────────
              Tooltip(
                message: isAtivo ? 'Desativar conta' : 'Reativar conta',
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isAtivo
                        ? Colors.orange.withValues(alpha: 0.1)
                        : AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isAtivo
                          ? Icons.block_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isAtivo ? Colors.orange : AppTheme.accent,
                      size: 22,
                    ),
                    onPressed: onToggleAtivo,
                  ),
                ),
              ),
              // ── Botão Excluir permanentemente ───────────────────────
              Tooltip(
                message: 'Excluir permanentemente',
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: AppTheme.error,
                      size: 22,
                    ),
                    onPressed: onPermanentDelete,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
