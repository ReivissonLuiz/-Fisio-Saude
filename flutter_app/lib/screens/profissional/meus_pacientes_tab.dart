import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MeusPacientesTab extends StatefulWidget {
  final String profissionalId;

  const MeusPacientesTab({super.key, required this.profissionalId});

  @override
  State<MeusPacientesTab> createState() => _MeusPacientesTabState();
}

class _MeusPacientesTabState extends State<MeusPacientesTab> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _pacientes = [];
  List<dynamic> _pacientesFiltrados = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPacientes();
    _searchController.addListener(_filtrarPacientes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPacientes() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getPacientesDoProfissional(widget.profissionalId);
      if (mounted) {
        setState(() {
          _pacientes = res['success'] ? (res['data'] as List) : [];
          _pacientesFiltrados = _pacientes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filtrarPacientes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _pacientesFiltrados = _pacientes.where((p) {
        final nome = (p['nome'] as String? ?? '').toLowerCase();
        final email = (p['email'] as String? ?? '').toLowerCase();
        return nome.contains(query) || email.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Meus Pacientes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou e-mail',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pacientesFiltrados.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _pacientesFiltrados.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final p = _pacientesFiltrados[index];
                          return _PacienteTile(paciente: p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'VocÃª ainda nÃ£o tem pacientes vinculados.'
                : 'Nenhum paciente encontrado.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PacienteTile extends StatelessWidget {
  final dynamic paciente;

  const _PacienteTile({required this.paciente});

  @override
  Widget build(BuildContext context) {
    final nome = paciente['nome'] ?? 'Nome nÃ£o cadastrado';
    final email = paciente['email'] ?? 'E-mail nÃ£o informado';
    final telefone = paciente['telefone'] ?? 'Sem telefone';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
          child: Text(
            nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
            style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(telefone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        onTap: () {
          // Navegar para detalhes do paciente
        },
      ),
    );
  }
}
