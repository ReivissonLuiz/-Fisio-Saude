import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
                            onConfirmar: () => _confirmar(c),
                            onCheckout: () => _checkout(c),
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

  // URL base da API de ML (Rodando localmente)
  static const String _mlApiUrl = 'http://localhost:8000';

  Future<void> _checkout(dynamic c) async {
    final status = (c['status'] as String?)?.toLowerCase();
    if (status == 'cancelada') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consulta cancelada.')));
      return;
    }

    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkout da Consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Insira o relatório da consulta (máx 300 caracteres):', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 300,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Descreva a evolução do paciente...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final res = await _api.finalizarConsulta(
        consultaId: c['id'] as String,
        relatorio: result,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consulta finalizada! Carregando recomendações de exercícios...')),
        );
        _loadAgenda();
        // Abre o modal de recomendação ML após checkout bem-sucedido
        await _abrirModalRecomendacao(c);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Erro ao finalizar consulta.')),
        );
      }
    }
  }

  /// Busca sintomas do paciente e chama a API ML para recomendações.
  Future<void> _abrirModalRecomendacao(dynamic consulta) async {
    if (!mounted) return;

    final pacienteId = consulta['id_paciente'] as String? ?? '';
    final consultaId = consulta['id'] as String? ?? '';

    // Busca sintomas recentes do paciente para alimentar o ML
    final sintomasRes = await _api.getSintomas(pacienteId);
    final sintomas = sintomasRes['success'] == true
        ? (sintomasRes['data'] as List).take(5).toList()
        : [];

    if (!mounted) return;

    // Chama a API de ML em background
    List<Map<String, dynamic>> recomendacoesML = [];
    bool mlDisponivel = true;

    try {
      final payload = {
        'sintomas': sintomas.map((s) => {
          'descricao': s['descricao'] ?? '',
          'categoria': s['categoria'] ?? 'Outra Região',
          'intensidade': s['intensidade'] ?? 5,
        }).toList(),
        'top_n': 5,
        'paciente_id': pacienteId,
        'profissional_id': widget.profissionalId,
      };

      final response = await http.post(
        Uri.parse('$_mlApiUrl/recomendar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        recomendacoesML = List<Map<String, dynamic>>.from(data['exercicios'] ?? []);
      } else {
        mlDisponivel = false;
      }
    } catch (_) {
      mlDisponivel = false;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecomendacaoMLModal(
        consulta: consulta,
        consultaId: consultaId,
        pacienteId: pacienteId,
        profissionalId: widget.profissionalId,
        recomendacoes: recomendacoesML,
        mlDisponivel: mlDisponivel,
        api: _api,
      ),
    );
  }

  Future<void> _confirmar(dynamic c) async {
    final pacienteId = c['id_paciente'] as String? ?? '';
    final res = await _api.confirmarConsulta(
      consultaId: c['id'] as String,
      pacienteId: pacienteId,
      profissionalId: widget.profissionalId,
      iniciadoPorProfissional: true,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presença confirmada! O paciente foi notificado.')),
      );
      _loadAgenda();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao confirmar.')),
      );
    }
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
  final VoidCallback onConfirmar;
  final VoidCallback onCheckout;
  final VoidCallback onDetalhes;

  const _ConsultaAgendaTile({
    required this.consulta,
    required this.onReagendar,
    required this.onCancelar,
    required this.onConfirmar,
    required this.onCheckout,
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
          if (!isPassada && (consulta['status'] as String?)?.toLowerCase() == 'agendada' && hoje.isAfter(dataHora.subtract(const Duration(hours: 24))))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Confirmar Presença (Check-in)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onConfirmar,
                ),
              ),
            ),
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
                if ((consulta['status'] as String?)?.toLowerCase() != 'cancelada' && (consulta['status'] as String?)?.toLowerCase() != 'finalizada') ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    ),
                    child: const Text('Checkout', style: TextStyle(fontSize: 12)),
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
                    if (widget.consulta['observacoes'] != null && (widget.consulta['observacoes'] as String).isNotEmpty) ...[
                      const Text('Relato do Paciente no Agendamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
                        child: Text(widget.consulta['observacoes'] as String, style: const TextStyle(color: AppTheme.textPrimary)),
                      ),
                      const SizedBox(height: 24),
                    ],

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
                        final nivel = s['intensidade'] as int? ?? 0;
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
                                    if (s['categoria'] != null && (s['categoria'] as String).isNotEmpty) 
                                      Text('Região: ${s['categoria']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal de Recomendação ML (pós-checkout)
// ─────────────────────────────────────────────────────────────────────────────

class _RecomendacaoMLModal extends StatefulWidget {
  final dynamic consulta;
  final String consultaId;
  final String pacienteId;
  final String profissionalId;
  final List<Map<String, dynamic>> recomendacoes;
  final bool mlDisponivel;
  final ApiService api;

  const _RecomendacaoMLModal({
    required this.consulta,
    required this.consultaId,
    required this.pacienteId,
    required this.profissionalId,
    required this.recomendacoes,
    required this.mlDisponivel,
    required this.api,
  });

  @override
  State<_RecomendacaoMLModal> createState() => _RecomendacaoMLModalState();
}

class _RecomendacaoMLModalState extends State<_RecomendacaoMLModal> {
  final Set<String> _selecionados = {};
  final _msgCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    // Pré-seleciona o exercício com maior score de similaridade
    if (widget.recomendacoes.isNotEmpty) {
      _selecionados.add(widget.recomendacoes.first['id'] as String);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Color _corNivel(String nivel) {
    switch (nivel.toLowerCase()) {
      case 'iniciante':
        return Colors.green;
      case 'intermediario':
        return Colors.orange;
      case 'avancado':
        return AppTheme.error;
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconRegiao(String regiao) {
    final r = regiao.toLowerCase();
    if (r.contains('ombro') || r.contains('braco')) return Icons.sports_gymnastics_rounded;
    if (r.contains('pescoco') || r.contains('cervical')) return Icons.self_improvement_rounded;
    if (r.contains('tornozelo') || r.contains('pe')) return Icons.directions_walk_rounded;
    if (r.contains('punho') || r.contains('mao')) return Icons.back_hand_rounded;
    return Icons.fitness_center_rounded;
  }

  Future<void> _enviarRecomendacoes() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um exercício para enviar.')),
      );
      return;
    }

    setState(() => _enviando = true);

    final videosSelecionados = widget.recomendacoes
        .where((r) => _selecionados.contains(r['id'] as String))
        .toList();

    final res = await widget.api.enviarRecomendacaoVideos(
      pacienteId: widget.pacienteId,
      profissionalId: widget.profissionalId,
      consultaId: widget.consultaId,
      videos: videosSelecionados,
      mensagem: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (res['success'] == true) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${videosSelecionados.length} exercício(s) enviado(s) com sucesso! O paciente foi notificado.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] as String? ?? 'Erro ao enviar recomendações.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pacienteNome = (widget.consulta['paciente']?['nome'] as String?) ?? 'o paciente';

    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exercícios Recomendados por IA',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.mlDisponivel
                            ? 'Selecionados com base nos sintomas de ${pacienteNome.split(' ').first}'
                            : 'Catálogo completo de exercícios',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Badge do algoritmo
          if (widget.mlDisponivel)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.psychology_rounded, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'TF-IDF + Cosine Similarity · Ordenados por score de relevância',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'API ML indisponível — exibindo catálogo completo',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),

          // Lista de exercícios
          Expanded(
            child: widget.recomendacoes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 56, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        const Text('Nenhum exercício disponível.', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        const Text(
                          'Configure a API ML para habilitar as recomendações.',
                          style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    children: [
                      Text(
                        'Selecione os exercícios para enviar (${_selecionados.length} selecionado(s)):',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ...widget.recomendacoes.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ex = entry.value;
                        final id = ex['id'] as String;
                        final selecionado = _selecionados.contains(id);
                        final score = ex['score_similaridade'] as double? ?? 0.0;
                        final nivel = ex['nivel_dificuldade'] as String? ?? '';
                        final corNivel = _corNivel(nivel);
                        final regiao = ex['regiao_display'] as String? ?? '';

                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selecionado) {
                              _selecionados.remove(id);
                            } else {
                              _selecionados.add(id);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? AppTheme.primary.withValues(alpha: 0.06)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selecionado ? AppTheme.primary : AppTheme.divider,
                                width: selecionado ? 1.5 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Posição + ícone
                                  Column(
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: selecionado
                                              ? AppTheme.primary
                                              : AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: selecionado
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                            : Center(
                                                child: Text(
                                                  '${idx + 1}',
                                                  style: TextStyle(
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 6),
                                      Icon(_iconRegiao(regiao), size: 20, color: AppTheme.textSecondary),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                ex['nome_pt'] as String? ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                            // Score badge
                                            if (widget.mlDisponivel)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.green.shade200),
                                                ),
                                                child: Text(
                                                  '${(score * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(regiao, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: corNivel.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                nivel,
                                                style: TextStyle(fontSize: 10, color: corNivel, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.timer_outlined, size: 12, color: AppTheme.textHint),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${ex['duracao_min']}min',
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ex['descricao'] as String? ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Campo de mensagem personalizada
                      const SizedBox(height: 8),
                      const Text(
                        'Mensagem para o paciente (opcional):',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _msgCtrl,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText: 'Ex: Realize esses exercícios 2x ao dia por 2 semanas...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),

          // Botão enviar
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.divider)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Pular', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (_enviando || _selecionados.isEmpty) ? null : _enviarRecomendacoes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _enviando
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _enviando
                          ? 'Enviando...'
                          : 'Enviar ${_selecionados.length > 0 ? "(${_selecionados.length})" : ""} Exercícios',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
