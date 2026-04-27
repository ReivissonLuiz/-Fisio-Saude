/// minha_disponibilidade_tab.dart
/// Aba de gerenciamento de horários disponíveis — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MinhaDisponibilidadeTab extends StatefulWidget {
  final String profissionalId;
  const MinhaDisponibilidadeTab({super.key, required this.profissionalId});

  @override
  State<MinhaDisponibilidadeTab> createState() =>
      _MinhaDisponibilidadeTabState();
}

class _MinhaDisponibilidadeTabState extends State<MinhaDisponibilidadeTab> {
  final _api = ApiService();
  List<dynamic> _slots = [];
  bool _loading = true;
  DateTime _mesAtual = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      if (mounted) _carregar();
    });
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final res = await _api.getDisponibilidades(widget.profissionalId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _slots = (res['data'] as List? ?? [])
          ..sort((a, b) {
            final d = (a['data'] as String).compareTo(b['data'] as String);
            if (d != 0) return d;
            return (a['hora_inicio'] as String)
                .compareTo(b['hora_inicio'] as String);
          });
      }
    });
  }

  Future<void> _deletar(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover horário'),
        content: const Text('Deseja remover este horário da sua agenda?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remover',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await _api.deletarDisponibilidade(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['success'] == true
            ? 'Horário removido.'
            : res['message'] ?? 'Erro'),
        backgroundColor:
            res['success'] == true ? AppTheme.accent : AppTheme.error,
      ));
      if (res['success'] == true) _carregar();
    }
  }

  void _abrirAdicionarSlot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdicionarSlotSheet(
        profissionalId: widget.profissionalId,
        onSalvo: _carregar,
      ),
    );
  }

  // Slots agrupados por data para o mês atual
  Map<String, List<dynamic>> get _slotsPorData {
    final map = <String, List<dynamic>>{};
    for (final s in _slots) {
      final data = s['data'] as String;
      map.putIfAbsent(data, () => []).add(s);
    }
    return map;
  }

  List<String> get _datasDoMes {
    return _slotsPorData.keys
        .where((d) {
          final dt = DateTime.parse(d);
          return dt.year == _mesAtual.year && dt.month == _mesAtual.month;
        })
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    final datasDoMes = _datasDoMes;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Minha Disponibilidade',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('Gerencie seus horários de atendimento',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                // Navegação de mês
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white),
                      onPressed: () => setState(() => _mesAtual =
                          DateTime(_mesAtual.year, _mesAtual.month - 1)),
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white),
                      onPressed: () => setState(() => _mesAtual =
                          DateTime(_mesAtual.year, _mesAtual.month + 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de slots
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : datasDoMes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available_rounded,
                                size: 54,
                                color: AppTheme.textHint
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text('Nenhum horário cadastrado\nneste mês.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 15)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _abrirAdicionarSlot,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Adicionar horário'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: datasDoMes.length,
                          itemBuilder: (_, i) {
                            final dataStr = datasDoMes[i];
                            final dt = DateTime.parse(dataStr);
                            final horarios =
                                _slotsPorData[dataStr] ?? [];
                            final dtLabel = DateFormat(
                                    "EEEE, dd 'de' MMMM", 'pt_BR')
                                .format(dt);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 8, top: 4),
                                  child: Text(dtLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textSecondary)),
                                ),
                                ...horarios.map((h) {
                                  final hora =
                                      h['hora_inicio'] as String? ?? '';
                                  final horaFim =
                                      h['hora_fim'] as String?;
                                  final disponivel =
                                      h['disponivel'] as bool? ?? true;
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: disponivel
                                              ? AppTheme.primary
                                                  .withValues(alpha: 0.2)
                                              : AppTheme.divider),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 20,
                                          color: disponivel
                                              ? AppTheme.primary
                                              : AppTheme.textHint,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                horaFim != null
                                                    ? '$hora — $horaFim'
                                                    : hora,
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                    color: disponivel
                                                        ? AppTheme
                                                            .textPrimary
                                                        : AppTheme
                                                            .textHint),
                                              ),
                                              if (!disponivel)
                                                const Text('Reservado',
                                                    style: TextStyle(
                                                        color:
                                                            AppTheme.error,
                                                        fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        if (disponivel)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: AppTheme.error,
                                                size: 20),
                                            onPressed: () =>
                                                _deletar(h['id'] as String),
                                            tooltip: 'Remover',
                                          ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarSlot,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar horário'),
      ),
    );
  }
}

// ── Bottom sheet para adicionar slot ─────────────────────────────────────────

class _AdicionarSlotSheet extends StatefulWidget {
  final String profissionalId;
  final VoidCallback onSalvo;
  const _AdicionarSlotSheet(
      {required this.profissionalId, required this.onSalvo});

  @override
  State<_AdicionarSlotSheet> createState() => _AdicionarSlotSheetState();
}

class _AdicionarSlotSheetState extends State<_AdicionarSlotSheet> {
  final _api = ApiService();
  DateTime? _dataSelecionada;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;
  bool _saving = false;
  // Repetir em múltiplos dias
  bool _repetir = false;
  int _repetirDias = 1;

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _salvar() async {
    if (_dataSelecionada == null || _horaInicio == null) return;
    setState(() => _saving = true);

    final diasParaSalvar = _repetir ? _repetirDias : 1;
    bool sucesso = true;
    String? erroMsg;

    for (int i = 0; i < diasParaSalvar; i++) {
      final data = _dataSelecionada!.add(Duration(days: i * 7));
      final dataStr = DateFormat('yyyy-MM-dd').format(data);
      final res = await _api.criarDisponibilidade(
        idProfissional: widget.profissionalId,
        data: dataStr,
        horaInicio: _fmtTime(_horaInicio!),
        horaFim: _horaFim != null ? _fmtTime(_horaFim!) : null,
      );
      if (res['success'] != true) {
        sucesso = false;
        erroMsg = res['message'] as String?;
        break;
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sucesso ? 'Horário(s) adicionado(s)!' : erroMsg ?? 'Erro'),
      backgroundColor: sucesso ? AppTheme.accent : AppTheme.error,
    ));

    if (sucesso) {
      widget.onSalvo();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Colors.white,
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_rounded, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Text('Adicionar Horário',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Conteúdo
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Data
                      const Text('Data',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('pt', 'BR'),
                          );
                          if (picked != null) {
                            setState(() => _dataSelecionada = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  color: AppTheme.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _dataSelecionada != null
                                    ? DateFormat("dd/MM/yyyy (EEEE)", 'pt_BR')
                                        .format(_dataSelecionada!)
                                    : 'Selecionar data',
                                style: TextStyle(
                                    color: _dataSelecionada != null
                                        ? AppTheme.textPrimary
                                        : AppTheme.textHint,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Horários
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Início',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: const TimeOfDay(
                                          hour: 8, minute: 0),
                                      builder: (ctx, child) =>
                                          MediaQuery(
                                            data: MediaQuery.of(ctx)
                                                .copyWith(
                                                    alwaysUse24HourFormat:
                                                        true),
                                            child: child!,
                                          ),
                                    );
                                    if (picked != null) {
                                      setState(() => _horaInicio = picked);
                                    }
                                  },
                                  child: _timeButton(_horaInicio),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Término (opcional)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _horaInicio ??
                                          const TimeOfDay(hour: 9, minute: 0),
                                      builder: (ctx, child) =>
                                          MediaQuery(
                                            data: MediaQuery.of(ctx)
                                                .copyWith(
                                                    alwaysUse24HourFormat:
                                                        true),
                                            child: child!,
                                          ),
                                    );
                                    if (picked != null) {
                                      setState(() => _horaFim = picked);
                                    }
                                  },
                                  child: _timeButton(_horaFim),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Repetir semanalmente
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: _repetir,
                                  onChanged: (v) =>
                                      setState(() => _repetir = v),
                                  activeColor: AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Repetir semanalmente',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            if (_repetir) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Por quantas semanas?',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppTheme.primary),
                                    onPressed: _repetirDias > 1
                                        ? () => setState(
                                            () => _repetirDias--)
                                        : null,
                                  ),
                                  Text('$_repetirDias',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: AppTheme.primary),
                                    onPressed: _repetirDias < 12
                                        ? () => setState(
                                            () => _repetirDias++)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Botão salvar
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_dataSelecionada != null &&
                            _horaInicio != null &&
                            !_saving)
                        ? _salvar
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Salvar horário',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeButton(TimeOfDay? time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            time != null ? _fmtTime(time) : 'Selecionar',
            style: TextStyle(
                color: time != null ? AppTheme.textPrimary : AppTheme.textHint,
                fontSize: 14,
                fontWeight:
                    time != null ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
