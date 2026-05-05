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

  static const _diasNomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _diaParaBanco = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null).then((_) {
      if (mounted) _carregarPadrao();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
              ],
            ),
          ),
          Expanded(child: _buildTabPadrao()),
        ],
      ),
    );
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
}
