/// minha_disponibilidade_tab.dart
/// Aba de gerenciamento de horários disponíveis — +Físio +Saúde
library;

import 'package:flutter/material.dart';
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
  // --- Horário Padrão ---
  final Map<int, TimeOfDay> _padInicio = {};
  final Map<int, TimeOfDay> _padFim = {};
  final Set<int> _padAtivos = {};
  bool _loadingPadrao = true;
  bool _salvandoPadrao = false;

  // --- Dias Específicos ---
  List<dynamic> _diasEspecificos = [];
  bool _loadingEspecificos = true;

  static const _diasNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _diaParaBanco = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      if (mounted) {
        _carregarPadrao();
        _carregarEspecificos();
      }
    });
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
      final bancoIdx = item['dia_semana'] as int;
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

  Future<void> _carregarEspecificos() async {
    setState(() => _loadingEspecificos = true);
    final res = await _api.getDisponibilidade(widget.profissionalId);
    if (!mounted) return;
    setState(() {
      _loadingEspecificos = false;
      if (res['success'] == true) {
        _diasEspecificos = res['data'] as List? ?? [];
      }
    });
  }

  Future<void> _deletarEspecifico(String id) async {
    setState(() => _loadingEspecificos = true);
    await _api.deletarDisponibilidade(id);
    if (!mounted) return;
    _carregarEspecificos();
  }

  Future<void> _adicionarEspecifico() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d == null || !mounted) return;

    final tIni = await _pickTime(context, const TimeOfDay(hour: 8, minute: 0));
    if (tIni == null || !mounted) return;

    final tFim = await _pickTime(context, TimeOfDay(hour: tIni.hour + 1, minute: tIni.minute));
    if (tFim == null || !mounted) return;

    setState(() => _loadingEspecificos = true);
    final res = await _api.criarDisponibilidade(
      idProfissional: widget.profissionalId,
      data: d.toIso8601String().split('T')[0],
      horaInicio: '${tIni.hour.toString().padLeft(2, '0')}:${tIni.minute.toString().padLeft(2, '0')}:00',
      horaFim: '${tFim.hour.toString().padLeft(2, '0')}:${tFim.minute.toString().padLeft(2, '0')}:00',
    );

    if (!mounted) return;
    if (res['success'] == true) {
      _carregarEspecificos();
    } else {
      setState(() => _loadingEspecificos = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Erro ao adicionar.'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _adicionarEspecifico,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Dia Específico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Column(
          children: [
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minha Disponibilidade',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Gerencie seu horário de atendimento',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 16),
                TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Horário Padrão'),
                    Tab(text: 'Dias Específicos'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTabPadrao(),
                _buildTabEspecificos(),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildTabPadrao() {
    if (_loadingPadrao) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
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
                  'Configure seus dias e horários de atendimento. '
                  'Sem configuração, o padrão é 07:00–19:00 (Seg–Sex).',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Dias de atendimento:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
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
        if (_padAtivos.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Selecione pelo menos um dia acima.',
                  style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
            ),
          )
        else
          ...(_padAtivos.toList()..sort()).map((i) => _buildDiaPadrao(i)),
        const SizedBox(height: 20),
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

  Widget _buildTabEspecificos() {
    if (_loadingEspecificos) return const Center(child: CircularProgressIndicator());
    if (_diasEspecificos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 64, color: AppTheme.textHint),
            SizedBox(height: 16),
            Text('Nenhum dia específico configurado.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            SizedBox(height: 8),
            Text('Use o botão + para adicionar horários excepcionais.',
                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _diasEspecificos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _diasEspecificos[i];
        final dtParts = (item['data'] as String).split('-');
        final dataFmt = '${dtParts[2]}/${dtParts[1]}/${dtParts[0]}';
        final tIni = (item['hora_inicio'] as String).substring(0, 5);
        final tFim = item['hora_fim'] != null ? (item['hora_fim'] as String).substring(0, 5) : '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: AppTheme.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dataFmt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('$tIni ${tFim.isNotEmpty ? '- $tFim' : ''}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () => _deletarEspecifico(item['id'] as String),
              ),
            ],
          ),
        );
      },
    );
  }
}
