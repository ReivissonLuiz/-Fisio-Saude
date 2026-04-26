/// buscar_fisio_tab.dart
/// Aba "Buscar Fisio" — lista e pesquisa de profissionais ativos — +Fisio +Saúde
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/agendamento_dialog.dart';

class BuscarFisioTab extends StatefulWidget {
  final String pacienteId;
  final String pacienteNome;

  const BuscarFisioTab({
    super.key,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<BuscarFisioTab> createState() => _BuscarFisioTabState();
}

class _BuscarFisioTabState extends State<BuscarFisioTab> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<dynamic> _profissionais = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregar();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getProfissionais();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _profissionais = result['data'] as List? ?? [];
        _filtered = List.from(_profissionais);
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  void _filtrar() {
    final termo = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (termo.isEmpty) {
        _filtered = List.from(_profissionais);
      } else {
        _filtered = _profissionais.where((p) {
          final nome = (p['nome'] as String? ?? '').toLowerCase();
          final esp = (p['especialidade'] as String? ?? '').toLowerCase();
          return nome.contains(termo) || esp.contains(termo);
        }).toList();
      }
    });
  }

  void _abrirAgendamento(Map<String, dynamic> profissional) {
    showDialog(
      context: context,
      builder: (_) => AgendamentoDialog(
        profissional: profissional,
        pacienteId: widget.pacienteId,
        pacienteNome: widget.pacienteNome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- Header + busca ----------------------------------------------
        Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buscar Fisioterapeuta',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Encontre um profissional para você',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou especialidade...',
                  hintStyle:
                      const TextStyle(color: AppTheme.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textSecondary),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filtrar();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- Lista -------------------------------------------------------
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: AppTheme.textHint, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _carregar,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_search_rounded,
                                  color: AppTheme.textHint, size: 54),
                              const SizedBox(height: 12),
                              Text(
                                _searchCtrl.text.isEmpty
                                    ? 'Nenhum profissional cadastrado.'
                                    : 'Nenhum resultado para "${_searchCtrl.text}".',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _carregar,
                          color: AppTheme.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = _filtered[index];
                              return _ProfissionalCard(
                                profissional: p,
                                onAgendar: () => _abrirAgendamento(
                                    Map<String, dynamic>.from(p)),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _ProfissionalCard extends StatelessWidget {
  final Map<String, dynamic> profissional;
  final VoidCallback onAgendar;
  const _ProfissionalCard({required this.profissional, required this.onAgendar});

  @override
  Widget build(BuildContext context) {
    final nome = profissional['nome'] as String? ?? 'Profissional';
    final especialidade =
        profissional['especialidade'] as String? ?? 'Fisioterapia';
    final crefito = profissional['crefito'] as String? ?? '';
    final telefone = profissional['telefone'] as String?;

    // Cor do avatar baseada na inicial do nome
    final cores = [
      AppTheme.primary,
      AppTheme.secondary,
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      AppTheme.accent,
    ];
    final corAvatar = cores[nome.codeUnitAt(0) % cores.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: corAvatar.withValues(alpha: 0.15),
              child: Text(
                nome[0].toUpperCase(),
                style: TextStyle(
                    color: corAvatar,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(especialidade,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('CREFITO: $crefito',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (telefone != null && telefone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded,
                        color: AppTheme.secondary, size: 22),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Telefone: $telefone')),
                      );
                    },
                    tooltip: 'Ligar',
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.primary, size: 22),
                  onPressed: onAgendar,
                  tooltip: 'Agendar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
