import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../shared/reagendar_screen.dart';

class AgendaTab extends StatefulWidget {
  final String profissionalId;

  const AgendaTab({super.key, required this.profissionalId});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _consultas = [];
  String _filtroStatus = 'Todas';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      if (mounted) _loadAgenda();
    });
  }

  Future<void> _loadAgenda() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getConsultasProfissional(widget.profissionalId);
      if (mounted) {
        setState(() {
          _consultas = res['success'] ? (res['data'] as List) : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _consultasFiltradas {
    if (_filtroStatus == 'Todas') return _consultas;
    final hoje = DateTime.now();
    if (_filtroStatus == 'Futuras') {
      return _consultas.where((c) => DateTime.parse(c['data_hora']).isAfter(hoje)).toList();
    }
    if (_filtroStatus == 'Passadas') {
      return _consultas.where((c) => DateTime.parse(c['data_hora']).isBefore(hoje)).toList();
    }
    return _consultas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: _loadAgenda,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas',
                    isSelected: _filtroStatus == 'Todas',
                    onTap: () => setState(() => _filtroStatus = 'Todas'),
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Futuras',
                    isSelected: _filtroStatus == 'Futuras',
                    onTap: () => setState(() => _filtroStatus = 'Futuras'),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Passadas',
                    isSelected: _filtroStatus == 'Passadas',
                    onTap: () => setState(() => _filtroStatus = 'Passadas'),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _consultasFiltradas.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        itemCount: _consultasFiltradas.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final c = _consultasFiltradas[index];
                          return _ConsultaAgendaTile(
                            consulta: c,
                            onReagendar: () => _reagendar(c),
                            onCancelar: () => _cancelar(c),
                            onDetalhes: () => _mostrarDetalhes(c),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Future<void> _reagendar(dynamic c) async {
    final pacienteId = c['id_paciente'] as String? ?? '';
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReagendarScreen(
          consultaId: c['id'] as String,
          pacienteId: pacienteId,
          profissionalId: widget.profissionalId,
          api: _api,
          iniciadoPorProfissional: true,
        ),
      ),
    );
    if (result == true && mounted) _loadAgenda();
  }

  Future<void> _cancelar(dynamic c) async {
    final pacienteId = c['id_paciente'] as String? ?? '';
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Cancelar Consulta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tem certeza que deseja cancelar esta consulta?'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Voltar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Cancelar Consulta'),
            ),
          ],
        );
      },
    );

    if (motivo == null || !mounted) return;

    final res = await _api.cancelarConsulta(
      consultaId: c['id'] as String,
      pacienteId: pacienteId,
      profissionalId: widget.profissionalId,
      motivo: motivo.isEmpty ? null : motivo,
      iniciadoPorProfissional: true,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Consulta cancelada. O paciente foi notificado.')),
      );
      _loadAgenda();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] as String? ?? 'Erro ao cancelar.')),
      );
    }
  }

  void _mostrarDetalhes(dynamic c) {
    final paciente = c['paciente'];
    if (paciente == null) return;

    final pacienteId = c['id_paciente'] as String? ?? '';
    
    int idade = 0;
    if (paciente['data_nasc'] != null) {
      final nascimento = DateTime.tryParse(paciente['data_nasc']);
      if (nascimento != null) {
        final hoje = DateTime.now();
        idade = hoje.year - nascimento.year;
        if (hoje.month < nascimento.month || (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
          idade--;
        }
      }
    }
    
    final genero = paciente['genero'] as String? ?? 'Não informado';
    final nome = paciente['nome'] as String? ?? 'Paciente';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DetalhesModal(
          consulta: c,
          pacienteId: pacienteId,
          profissionalId: widget.profissionalId,
          nome: nome,
          idade: idade,
          genero: genero,
          api: _api,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma consulta encontrada.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ConsultaAgendaTile extends StatelessWidget {
  final dynamic consulta;
  final VoidCallback onReagendar;
  final VoidCallback onCancelar;
  final VoidCallback onDetalhes;

  const _ConsultaAgendaTile({
    required this.consulta,
    required this.onReagendar,
    required this.onCancelar,
    required this.onDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    final paciente = consulta['paciente'];
    final dataHora = DateTime.parse(consulta['data_hora']);
    final formatadorData = DateFormat('dd/MM/yyyy');
    final formatadorHora = DateFormat('HH:mm');

    final dataExtenso = formatadorData.format(dataHora);
    final hora = formatadorHora.format(dataHora);
    final hoje = DateTime.now();
    final isPassada = dataHora.isBefore(hoje);

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPassada ? Colors.grey.shade100 : AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(dataExtenso.split('/')[0], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isPassada ? Colors.grey : AppTheme.primary)),
                      Text(DateFormat('MMM', 'pt_BR').format(dataHora).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPassada ? Colors.grey : AppTheme.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paciente?['nome'] ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(hora, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          const Text('Consultório', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isPassada && (consulta['status'] as String?)?.toLowerCase() != 'cancelada') ...[
                  TextButton.icon(
                    onPressed: onCancelar,
                    icon: const Icon(Icons.event_busy_rounded, size: 16),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: onReagendar,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Reagendar'),
                  ),
                  const Spacer(),
                ],
                TextButton(
                  onPressed: onDetalhes,
                  child: const Text('Detalhes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (!isPassada) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    child: const Text('Prontuário', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalhesModal extends StatefulWidget {
  final dynamic consulta;
  final String pacienteId;
  final String profissionalId;
  final String nome;
  final int idade;
  final String genero;
  final ApiService api;

  const _DetalhesModal({
    super.key,
    required this.consulta,
    required this.pacienteId,
    required this.profissionalId,
    required this.nome,
    required this.idade,
    required this.genero,
    required this.api,
  });

  @override
  State<_DetalhesModal> createState() => _DetalhesModalState();
}

class _DetalhesModalState extends State<_DetalhesModal> {
  bool _isLoading = true;
  int _consultasRealizadas = 0;
  List<dynamic> _sintomas = [];

  @override
  void initState() {
    super.initState();
    _loadDados();
  }

  Future<void> _loadDados() async {
    final res = await widget.api.getResumoPacienteParaProfissional(
      pacienteId: widget.pacienteId,
      profissionalId: widget.profissionalId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      setState(() {
        _consultasRealizadas = data['consultas_realizadas'] as int;
        _sintomas = data['sintomas'] as List;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Detalhes do Paciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Resumo Demográfico
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    widget.nome.isNotEmpty ? widget.nome.substring(0, 1).toUpperCase() : 'P',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.idade} anos • ${widget.genero}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Histórico de Consultas
                    const Text('Histórico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _consultasRealizadas <= 1 ? AppTheme.accent.withValues(alpha: 0.1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _consultasRealizadas <= 1 ? AppTheme.accent : AppTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _consultasRealizadas <= 1 ? Icons.star_rounded : Icons.history_rounded,
                            color: _consultasRealizadas <= 1 ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _consultasRealizadas <= 1
                                  ? 'Primeira consulta com você!'
                                  : 'Já realizou $_consultasRealizadas consulta(s) com você.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _consultasRealizadas <= 1 ? AppTheme.accent : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sintomas Registrados
                    const Text('Sintomas Recentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (_sintomas.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                        child: const Text('Nenhum sintoma registrado pelo paciente.', style: TextStyle(color: AppTheme.textHint, fontStyle: FontStyle.italic)),
                      )
                    else
                      ..._sintomas.map((s) {
                        final nivel = s['nivel_dor'] as int? ?? 0;
                        final corNivel = nivel <= 3 ? AppTheme.accent : nivel <= 6 ? AppTheme.warning : AppTheme.error;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: corNivel.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text('$nivel/10', style: TextStyle(fontWeight: FontWeight.bold, color: corNivel))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['descricao'] ?? 'Sem descrição', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (s['regiao'] != null && (s['regiao'] as String).isNotEmpty) 
                                      Text('Região: ${s['regiao']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
