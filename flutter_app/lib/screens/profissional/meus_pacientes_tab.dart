import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../shared/chat_screen.dart';
import 'paciente_detalhes_screen.dart';

class MeusPacientesTab extends StatefulWidget {
  final String profissionalId;
  final String profissionalNome;
  final String? profissionalAvatar;

  const MeusPacientesTab({
    super.key,
    required this.profissionalId,
    this.profissionalNome = 'Profissional',
    this.profissionalAvatar,
  });

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
                    : RefreshIndicator(
                        onRefresh: _loadPacientes,
                        child: ListView.builder(
                          itemCount: _pacientesFiltrados.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final p = _pacientesFiltrados[index];
                            return _PacienteTile(
                              paciente: p,
                              profissionalId: widget.profissionalId,
                              profissionalNome: widget.profissionalNome,
                              profissionalAvatar: widget.profissionalAvatar,
                            );
                          },
                        ),
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
                ? 'Você ainda não tem pacientes vinculados.'
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
  final String profissionalId;
  final String profissionalNome;
  final String? profissionalAvatar;

  const _PacienteTile({
    required this.paciente,
    required this.profissionalId,
    required this.profissionalNome,
    this.profissionalAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final nome = paciente['nome'] as String? ?? 'Nome não cadastrado';
    final email = paciente['email'] as String? ?? 'E-mail não informado';
    final telefone = paciente['telefone'] as String? ?? 'Sem telefone';
    final pacienteId = paciente['id'] as String? ?? '';
    final avatarUrl = paciente['avatar_url'] as String?;
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            leading: avatarUrl != null && avatarUrl.isNotEmpty
                ? CircleAvatar(radius: 24, backgroundImage: NetworkImage(avatarUrl))
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                    child: Text(inicial, style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
            title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.phone_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(telefone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('Chat', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            meuId: profissionalId,
                            meuNome: profissionalNome,
                            meuAvatar: profissionalAvatar,
                            outroId: pacienteId,
                            outroNome: nome,
                            outroAvatar: avatarUrl,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_outline_rounded, size: 16),
                    label: const Text('Detalhes', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: const BorderSide(color: AppTheme.secondary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PacienteDetalhesScreen(
                            pacienteDados: paciente,
                            profissionalId: profissionalId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
