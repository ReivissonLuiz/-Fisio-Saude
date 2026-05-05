/// minha_saude_tab.dart
/// Aba "Minha Saúde" — registro e histórico de sintomas + exercícios — +Fisio +Saúde
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MinhaSaudeTab extends StatefulWidget {
  final String pacienteId;
  const MinhaSaudeTab({super.key, required this.pacienteId});

  @override
  State<MinhaSaudeTab> createState() => _MinhaSaudeTabState();
}

class _MinhaSaudeTabState extends State<MinhaSaudeTab>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<dynamic> _sintomas = [];
  List<dynamic> _recomendacoes = [];
  bool _loading = true;
  bool _loadingRec = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarSintomas();
    _carregarRecomendacoes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _carregarRecomendacoes() async {
    setState(() => _loadingRec = true);
    final result = await _api.getRecomendacoesVideos(widget.pacienteId);
    if (!mounted) return;
    setState(() {
      _loadingRec = false;
      if (result['success'] == true) {
        _recomendacoes = result['data'] as List? ?? [];
      }
    });
    // Marca todas como lidas ao abrir a aba
    for (final rec in _recomendacoes) {
      if (rec['lida'] == false) {
        _api.marcarRecomendacaoLida(rec['id'] as String);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _abrirFormulario,
              backgroundColor: const Color(0xFFE91E63),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Registrar Sintoma',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                const Text('Sintomas, dores e exercícios recomendados',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(
                        label: 'Sintomas',
                        value: '${_sintomas.length}',
                        icon: Icons.list_alt_rounded),
                    const SizedBox(width: 10),
                    _MiniStat(
                        label: 'Este mês',
                        value: '${_sintomasestesMes()}',
                        icon: Icons.calendar_today_rounded),
                    const SizedBox(width: 10),
                    _MiniStat(
                        label: 'Exercícios',
                        value: '${_recomendacoes.fold<int>(0, (sum, r) => sum + ((r['videos'] as List?)?.length ?? 0))}',
                        icon: Icons.fitness_center_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                // TabBar dentro do header
                TabBar(
                  controller: _tabController,
                  onTap: (_) => setState(() {}),
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    const Tab(text: 'Meus Sintomas'),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Exercícios'),
                          if (_recomendacoes.any((r) => r['lida'] == false)) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.yellow,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Conteúdo das tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Sintomas
                _loading
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
                                    'Use o botão abaixo para registrar\ncomo você está se sentindo.',
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              itemCount: _sintomas.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) =>
                                  _SintomaCard(sintoma: _sintomas[index]),
                            ),
                          ),

                // Tab 2: Exercícios Recomendados
                _loadingRec
                    ? const Center(child: CircularProgressIndicator())
                    : _recomendacoes.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fitness_center_rounded,
                                    color: AppTheme.textHint, size: 60),
                                SizedBox(height: 14),
                                Text('Nenhum exercício recomendado',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                                SizedBox(height: 6),
                                Text(
                                    'Após uma consulta, seu fisioterapeuta\npode enviar exercícios personalizados.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppTheme.textHint, fontSize: 13)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _carregarRecomendacoes,
                            color: const Color(0xFFE91E63),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              itemCount: _recomendacoes.length,
                              itemBuilder: (_, idx) =>
                                  _RecomendacaoCard(
                                      recomendacao: _recomendacoes[idx]),
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

class _SintomaCard extends StatelessWidget {
  final Map<String, dynamic> sintoma;
  const _SintomaCard({required this.sintoma});

  @override
  Widget build(BuildContext context) {
    final nivel = sintoma['intensidade'] as int? ?? 0;
    final descricao = sintoma['descricao'] as String? ?? '';
    final regiao = sintoma['categoria'] as String?;
    final dt = DateTime.tryParse(sintoma['data_hora'] as String? ?? '');
    final dtFmt = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
    final cor = nivel <= 3
        ? AppTheme.accent
        : nivel <= 6
            ? AppTheme.warning
            : AppTheme.error;

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
                  const Icon(Icons.sentiment_neutral_rounded, size: 18, color: AppTheme.textSecondary),
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
    'Braço / cotovelo', 'Punho / mão', 'Outra Região',
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
      'intensidade': _nivelDor.round(),
      'categoria': _regiaoSelecionada,
    });
    if (!mounted) return;
    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sintoma registrado!'),
        backgroundColor: AppTheme.accent,
      ));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Erro ao registrar.'),
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
                        hintText: 'Selecione a Região',
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




// ─────────────────────────────────────────────────────────────────────────────
// Card de Recomendação de Exercícios (Tab Exercícios)
// ─────────────────────────────────────────────────────────────────────────────

class _RecomendacaoCard extends StatefulWidget {
  final Map<String, dynamic> recomendacao;
  const _RecomendacaoCard({required this.recomendacao});

  @override
  State<_RecomendacaoCard> createState() => _RecomendacaoCardState();
}

class _RecomendacaoCardState extends State<_RecomendacaoCard> {
  bool _expandido = false;

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

  Future<void> _abrirVideo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profissional = widget.recomendacao['profissional'];
    final nomeProfissional =
        profissional?['nome'] as String? ?? 'Seu fisioterapeuta';
    final videos = (widget.recomendacao['videos'] as List?) ?? [];
    final mensagem = widget.recomendacao['mensagem'] as String?;
    final dt = DateTime.tryParse(
        widget.recomendacao['created_at'] as String? ?? '');
    final dtFmt = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header do card
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercícios de $nomeProfissional',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text('${videos.length} exercício(s)',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                          if (dtFmt.isNotEmpty) ...[ 
                            const SizedBox(width: 8),
                            const Icon(Icons.calendar_today_outlined,
                                size: 11, color: AppTheme.textHint),
                            const SizedBox(width: 2),
                            Text(dtFmt,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textHint)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Badge "Recomendado por IA"
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_rounded,
                          size: 11, color: Colors.purple.shade700),
                      const SizedBox(width: 3),
                      Text('ML',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mensagem personalizada do profissional
          if (mensagem != null && mensagem.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message_outlined,
                      size: 15, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensagem,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppTheme.divider),

          // Lista de exercícios (expansível)
          if (videos.isNotEmpty) ...[
            // Mostrar primeiros 2 sempre, resto ao expandir
            ...videos.take(_expandido ? videos.length : 2).map((video) {
              final nome = video['nome_pt'] as String? ?? '';
              final regiao = video['regiao_display'] as String? ?? '';
              final nivel = video['nivel_dificuldade'] as String? ?? '';
              final duracao = video['duracao_min'] as int? ?? 0;
              final url = video['url_video'] as String? ?? '';
              final corNivel = _corNivel(nivel);

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: corNivel.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.play_circle_rounded,
                          color: corNivel, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nome,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: corNivel.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(nivel,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: corNivel,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: AppTheme.textSecondary),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(regiao,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.timer_outlined,
                                  size: 11, color: AppTheme.textHint),
                              Text(' ${duracao}min',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textHint)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botão de abrir vídeo
                    if (url.isNotEmpty && url != 'https://drive.google.com/')
                      IconButton(
                        onPressed: () => _abrirVideo(url),
                        icon: const Icon(Icons.open_in_new_rounded),
                        color: AppTheme.primary,
                        iconSize: 20,
                        tooltip: 'Abrir vídeo',
                      ),
                  ],
                ),
              );
            }),

            // Botão expandir/recolher
            if (videos.length > 2)
              TextButton.icon(
                onPressed: () => setState(() => _expandido = !_expandido),
                icon: Icon(
                  _expandido
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _expandido
                      ? 'Ver menos'
                      : 'Ver mais ${videos.length - 2} exercício(s)',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary),
              ),
          ],
        ],
      ),
    );
  }
}
