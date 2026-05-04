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

class _MinhaDisponibilidadeTabState extends State<MinhaDisponibilidadeTab>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  // --- Slots específicos ---
  List<dynamic> _slots = [];
  bool _loading = true;
  DateTime _mesAtual = DateTime.now();
  // --- Horário Padrão ---
  late TabController _tabController;
  // dia_semana(1-7) -> {inicio, fim} ; 1=Seg...7=Dom
  final Map<int, TimeOfDay> _padInicio = {};
  final Map<int, TimeOfDay> _padFim = {};
  final Set<int> _padAtivos = {};
  bool _loadingPadrao = true;
  bool _salvandoPadrao = false;

  static const _diasNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  // dia da semana no banco: 0=Dom..6=Sáb → mapeamos 1=Seg..7=Dom internamente
  static const _diaParaBanco = [1, 2, 3, 4, 5, 6, 0]; // índice 0=Seg → banco 1

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    initializeDateFormatting('pt_BR', null).then((_) {
      if (mounted) {
        _carregar();
        _carregarPadrao();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarPadrao() async {
    setState(() => _loadingPadrao = true);
    final res = await _api.getHorarioPadrao(widget.profissionalId);
    if (!mounted) return;
    final lista = res['success'] == true ? (res['data'] as List? ?? []) : [];
    _padAtivos.clear();
    _padInicio.clear();
    _padFim.clear();
    for (final item in lista) {
      final bancoIdx = item['dia_semana'] as int; // 0=Dom..6=Sáb
      // converte para índice interno 0=Seg..6=Dom
      final interno = _diaParaBanco.indexOf(bancoIdx);
      if (interno < 0) continue;
      _padAtivos.add(interno);
      final ini = (item['hora_inicio'] as String).substring(0, 5).split(':');
      final fim = (item['hora_fim'] as String).substring(0, 5).split(':');
      _padInicio[interno] = TimeOfDay(hour: int.parse(ini[0]), minute: int.parse(ini[1]));
      _padFim[interno]    = TimeOfDay(hour: int.parse(fim[0]), minute: int.parse(fim[1]));
    }
    setState(() => _loadingPadrao = false);
  }

  Future<void> _salvarPadrao() async {
    setState(() => _salvandoPadrao = true);
    final entradas = _padAtivos.map((interno) {
      final bancoIdx = _diaParaBanco[interno];
      final ini = _padInicio[interno] ?? const TimeOfDay(hour: 7, minute: 0);
      final fim = _padFim[interno]    ?? const TimeOfDay(hour: 19, minute: 0);
      return {
        'dia_semana': bancoIdx,
        'hora_inicio': '${ini.hour.toString().padLeft(2,'0')}:${ini.minute.toString().padLeft(2,'0')}',
        'hora_fim':    '${fim.hour.toString().padLeft(2,'0')}:${fim.minute.toString().padLeft(2,'0')}',
      };
    }).toList();
    final res = await _api.salvarHorarioPadrao(
      profissionalId: widget.profissionalId,
      entradas: entradas,
    );
    if (!mounted) return;
    setState(() => _salvandoPadrao = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true ? 'Horário padrão salvo!' : res['message'] ?? 'Erro'),
      backgroundColor: res['success'] == true ? Colors.green : AppTheme.error,
    ));
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<TimeOfDay?> _pickTime(BuildContext ctx, TimeOfDay initial) =>
      showTimePicker(
        context: ctx,
        initialTime: initial,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );


  Future<void> _carregar() async {
    setState(() => _loading = true);
    final res = await _api.getDisponibilidade(widget.profissionalId);
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
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _abrirAdicionarSlot,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar slot'),
            )
          : null,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('Gerencie seu horário de atendimento',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Horário Padrão'),
                    Tab(text: 'Slots Específicos'),
                  ],
                ),
              ],
            ),
          ),
          // ── Conteúdo das abas ────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabPadrao(),
                _buildTabSlots(datasDoMes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Horário Padrão ────────────────────────────────────────────────
  Widget _buildTabPadrao() {
    if (_loadingPadrao) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Banner informativo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quando não houver slot específico, seu horário padrão será exibido. '
                  'Sem configuração: padrão 07:00–19:00 (Seg–Sex).',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Dias de atendimento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        // Chips de dias da semana
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(7, (i) {
            final ativo = _padAtivos.contains(i);
            return FilterChip(
              label: Text(_diasNomes[i]),
              selected: ativo,
              onSelected: (v) => setState(() {
                if (v) {
                  _padAtivos.add(i);
                  _padInicio.putIfAbsent(i, () => const TimeOfDay(hour: 7, minute: 0));
                  _padFim.putIfAbsent(i, () => const TimeOfDay(hour: 19, minute: 0));
                } else {
                  _padAtivos.remove(i);
                }
              }),
              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: ativo ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        // Horários por dia ativo
        if (_padAtivos.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Selecione pelo menos um dia acima.',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            ),
          )
        else
          ..._padAtivos.toList()..sort()
            ..map((i) => _buildDiaPadrao(i)).toList(),
        const SizedBox(height: 20),
        // Botão salvar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _salvandoPadrao ? null : _salvarPadrao,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _salvandoPadrao
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_salvandoPadrao ? 'Salvando...' : 'Salvar Horário Padrão',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildDiaPadrao(int i) {
    final ini = _padInicio[i] ?? const TimeOfDay(hour: 7, minute: 0);
    final fim = _padFim[i]    ?? const TimeOfDay(hour: 19, minute: 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(_diasNomes[i],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                // Início
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final t = await _pickTime(context, ini);
                      if (t != null) setState(() => _padInicio[i] = t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(_fmtTime(ini), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('→', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                // Fim
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final t = await _pickTime(context, fim);
                      if (t != null) setState(() => _padFim[i] = t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Row(children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(_fmtTime(fim), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
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

  // ── Tab 2: Slots Específicos (lógica existente preservada) ──────────────
  Widget _buildTabSlots(List<String> datasDoMes) {
    // Navegação de mês no topo
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primary),
                onPressed: () => setState(() => _mesAtual = DateTime(_mesAtual.year, _mesAtual.month - 1)),
              ),
              Text(DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                onPressed: () => setState(() => _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + 1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : datasDoMes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available_rounded, size: 54, color: AppTheme.textHint.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text('Nenhum slot específico\nneste mês.', textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _abrirAdicionarSlot,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Adicionar slot'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: datasDoMes.length,
                        itemBuilder: (_, i) {
                          final dataStr = datasDoMes[i];
                          final dt = DateTime.parse(dataStr);
                          final horarios = _slotsPorData[dataStr] ?? [];
                          final dtLabel = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(dt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text(dtLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary)),
                              ),
                              ...horarios.map((h) {
                                final hora = h['hora_inicio'] as String? ?? '';
                                final horaFim = h['hora_fim'] as String?;
                                final disponivel = h['disponivel'] as bool? ?? true;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: disponivel ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.divider),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.access_time_rounded, size: 20, color: disponivel ? AppTheme.primary : AppTheme.textHint),
                                    const SizedBox(width: 10),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(horaFim != null ? '$hora — $horaFim' : hora,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                                              color: disponivel ? AppTheme.textPrimary : AppTheme.textHint)),
                                      if (!disponivel) const Text('Reservado', style: TextStyle(color: AppTheme.error, fontSize: 11)),
                                    ])),
                                    if (disponivel)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                        onPressed: () => _deletar(h['id'] as String),
                                        tooltip: 'Remover',
                                      ),
                                  ]),
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
