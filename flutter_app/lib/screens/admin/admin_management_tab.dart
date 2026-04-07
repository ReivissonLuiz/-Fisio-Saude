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

  Future<void> _confirmDelete(String table, String id, String nome, {bool forceHardDelete = false}) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(forceHardDelete ? 'Exclusão Permanente' : 'Confirmar Desativação'),
        content: Text(forceHardDelete 
          ? 'Deseja excluir "$nome" DEFINITIVAMENTE do banco de dados? Esta ação destruirá o registro e não pode ser desfeita.'
          : 'Deseja desativar o registro de "$nome"? (O registro não aparecerá em buscas padrão, mas continuará salvo no sistema).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(forceHardDelete ? 'Excluir Permanente' : 'Desativar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await _api.deleteRecord(table, id, forceHardDelete: forceHardDelete);
      if (res['success'] && mounted) {
        final txt = forceHardDelete ? 'removido permanentemente' : 'desativado';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$nome" $txt.'), backgroundColor: AppTheme.primary));
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Falha ao processar operação'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredPacientes = _pacientes.where((p) => p['nome'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final filteredProfissionais = _profissionais.where((p) => p['nome'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gestão de Dados', style: TextStyle(fontWeight: FontWeight.bold)),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                _SectionHeader(title: 'Fisioterapeutas (${filteredProfissionais.length})', icon: Icons.medical_services_rounded, color: AppTheme.secondary),
                ...filteredProfissionais.map((p) => _ManagementTile(
                  id: p['id'].toString(),
                  title: p['nome'],
                  subtitle: p['ativo'] == false ? 'INATIVO - CREFITO: ${p['crefito']}' : 'CREFITO: ${p['crefito']}',
                  isAtivo: p['ativo'] == true,
                  onDeactivate: () => _confirmDelete('profissional', p['id'].toString(), p['nome'], forceHardDelete: false),
                  onHardDelete: () => _confirmDelete('profissional', p['id'].toString(), p['nome'], forceHardDelete: true),
                )),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Pacientes (${filteredPacientes.length})', icon: Icons.people_rounded, color: AppTheme.primary),
                ...filteredPacientes.map((p) => _ManagementTile(
                  id: p['id'].toString(),
                  title: p['nome'],
                  subtitle: p['ativo'] == false ? 'INATIVO - ${p['email']}' : p['email'],
                  isAtivo: p['ativo'] == true,
                  onDeactivate: () => _confirmDelete('paciente', p['id'].toString(), p['nome'], forceHardDelete: false),
                  onHardDelete: () => _confirmDelete('paciente', p['id'].toString(), p['nome'], forceHardDelete: true),
                )),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
  final VoidCallback onDeactivate;
  final VoidCallback onHardDelete;

  const _ManagementTile({required this.id, required this.title, required this.subtitle, required this.isAtivo, required this.onDeactivate, required this.onHardDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: isAtivo ? Colors.white : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isAtivo ? AppTheme.textPrimary : Colors.grey)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isAtivo ? AppTheme.textSecondary : Colors.grey, fontStyle: isAtivo ? FontStyle.normal : FontStyle.italic)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAtivo)
              IconButton(
                icon: const Icon(Icons.person_off_rounded, color: Colors.orange),
                tooltip: 'Desativar Registro',
                onPressed: onDeactivate,
              ),
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error),
              tooltip: 'Excluir Definitivamente',
              onPressed: onHardDelete,
            ),
          ],
        ),
      ),
    );
  }
}

