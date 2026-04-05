/// minha_saude_tab.dart
/// Aba "Minha Saúde" — registro e histórico de sintomas — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MinhaSaudeTab extends StatefulWidget {
  final String pacienteId;
  const MinhaSaudeTab({super.key, required this.pacienteId});

  @override
  State<MinhaSaudeTab> createState() => _MinhaSaudeTabState();
}

class _MinhaSaudeTabState extends State<MinhaSaudeTab> {
  final _api = ApiService();
  List<dynamic> _sintomas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregarSintomas();
  }

  Future<void> _carregarSintomas() async {
    setState(() => _loading = true);
    final result = await _api.getSintomas(widget.pacienteId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _sintomas = result['data'] as List? ?? [];
      }
    });
  }

  Future<void> _abrirFormulario() async {
    final registrado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegistroSintomaSheet(
          pacienteId: widget.pacienteId, api: _api),
    );
    if (registrado == true) await _carregarSintomas();
  }

  int _sintomasestesMes() {
    final now = DateTime.now();
    return _sintomas.where((s) {
      final dt = DateTime.tryParse(s['data_hora'] as String? ?? '');
      return dt != null && dt.month == now.month && dt.year == now.year;
    }).length;
  }

  String _dorMedia() {
    if (_sintomas.isEmpty) return '—';
    final niveis = _sintomas.map((s) => s['nivel_dor'] as int? ?? 0).toList();
    final media = niveis.reduce((a, b) => a + b) / niveis.length;
    return media.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormulario,
        backgroundColor: const Color(0xFFE91E63),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Registrar Sintoma',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monitor_heart_rounded,
                        color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text('Minha Saúde',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Registro de sintomas e dores',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(
                        label: 'Total',
                        value: '${_sintomas.length}',
                        icon: Icons.list_alt_rounded),
                    const SizedBox(width: 10),
                    _MiniStat(
                        label: 'Este mês',
                        value: '${_sintomasestesMes()}',
                        icon: Icons.calendar_today_rounded),
                    const SizedBox(width: 10),
                    _MiniStat(
                        label: 'Dor média',
                        value: _dorMedia(),
                        icon: Icons.analytics_rounded),
                  ],
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sintomas.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.healing_rounded,
                                color: AppTheme.textHint, size: 60),
                            SizedBox(height: 14),
                            Text('Nenhum sintoma registrado',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 6),
                            Text(
                                'Use o botão abaixo para registrar\ncomo você está sentindo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.textHint, fontSize: 13)),
                            SizedBox(height: 80),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarSintomas,
                        color: const Color(0xFFE91E63),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _sintomas.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _SintomaCard(sintoma: _sintomas[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SintomaCard extends StatelessWidget {
  final Map<String, dynamic> sintoma;
  const _SintomaCard({required this.sintoma});

  @override
  Widget build(BuildContext context) {
    final nivel = sintoma['nivel_dor'] as int? ?? 0;
    final descricao = sintoma['descricao'] as String? ?? '';
    final regiao = sintoma['regiao'] as String?;
    final dt = DateTime.tryParse(sintoma['data_hora'] as String? ?? '');
    final dtFmt = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    final cor = nivel <= 3
        ? AppTheme.accent
        : nivel <= 6
            ? AppTheme.warning
            : AppTheme.error;
    final emoji = nivel <= 3 ? '😊' : nivel <= 6 ? '😐' : '😣';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cor.withValues(alpha: 0.3))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  Text('$nivel/10',
                      style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (descricao.isNotEmpty)
                    Text(descricao,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  if (regiao != null && regiao.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(regiao,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: AppTheme.textHint),
                      const SizedBox(width: 3),
                      Text(dtFmt,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistroSintomaSheet extends StatefulWidget {
  final String pacienteId;
  final ApiService api;
  const _RegistroSintomaSheet({required this.pacienteId, required this.api});

  @override
  State<_RegistroSintomaSheet> createState() => _RegistroSintomaSheetState();
}

class _RegistroSintomaSheetState extends State<_RegistroSintomaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  double _nivelDor = 5;
  String? _regiaoSelecionada;
  bool _loading = false;

  static const _regioes = [
    'Cervical (pescoço)', 'Ombro direito', 'Ombro esquerdo',
    'Coluna lombar', 'Coluna torácica', 'Quadril',
    'Joelho direito', 'Joelho esquerdo', 'Tornozelo / pé',
    'Braço / cotovelo', 'Punho / mão', 'Outra região',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await widget.api.registrarSintoma({
      'id_paciente': widget.pacienteId,
      'data_hora': DateTime.now().toIso8601String(),
      'descricao': _descCtrl.text.trim(),
      'nivel_dor': _nivelDor.round(),
      'regiao': _regiaoSelecionada,
    });
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Sintoma registrado!'),
        backgroundColor: AppTheme.accent,
      ));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ ${result['message'] ?? 'Erro ao registrar.'}'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final nivel = _nivelDor.round();
    final cor = nivel <= 3
        ? AppTheme.accent
        : nivel <= 6
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      height: mq.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    color: Color(0xFFE91E63)),
                const SizedBox(width: 10),
                const Text('Registrar Sintoma',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false)),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nível de dor',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sem dor',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                              Text('$nivel / 10',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: cor)),
                              const Text('Intensa',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
                          Slider(
                            value: _nivelDor,
                            min: 0, max: 10, divisions: 10,
                            activeColor: cor,
                            inactiveColor: cor.withValues(alpha: 0.2),
                            label: '$nivel',
                            onChanged: (v) => setState(() => _nivelDor = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Região do corpo',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _regiaoSelecionada,
                      decoration: InputDecoration(
                        hintText: 'Selecione a região',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _regioes
                          .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r,
                                  style: const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _regiaoSelecionada = v),
                    ),
                    const SizedBox(height: 18),
                    const Text('Descrição',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Descreva como está se sentindo, quando começou…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Descreva o sintoma.'
                              : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: _loading ? null : _salvar,
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Salvar Sintoma',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
