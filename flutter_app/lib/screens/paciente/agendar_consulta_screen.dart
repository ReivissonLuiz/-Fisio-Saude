/// agendar_consulta_screen.dart
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AgendarConsultaScreen extends StatefulWidget {
  final String pacienteId;
  final String? profissionalIdPreSelecionado;
  const AgendarConsultaScreen({
    super.key,
    required this.pacienteId,
    this.profissionalIdPreSelecionado,
  });

  @override
  State<AgendarConsultaScreen> createState() => _AgendarConsultaScreenState();
}

class _AgendarConsultaScreenState extends State<AgendarConsultaScreen> {
  final _api = ApiService();

  // Quando profissional pré-selecionado, começa no passo 1 (data)
  int _passo = 0;
  bool _profPreSelecionado = false;

  String? _especialidade;
  DateTime? _data;
  String? _horario;
  Map<String, dynamic>? _profissional;

  List<String> _especialidades = [];
  List<String> _horarios = [];
  List<Map<String, dynamic>> _profissionais = [];

  bool _loading = false;
  bool _confirmando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (widget.profissionalIdPreSelecionado != null) {
      _profPreSelecionado = true;
      _passo = 1;
      _carregarProfissional(widget.profissionalIdPreSelecionado!);
    } else {
      _carregarEspecialidades();
    }
  }

  Future<void> _carregarProfissional(String id) async {
    setState(() => _loading = true);
    final res = await _api.getUsuario(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) _profissional = res['data'] as Map<String, dynamic>?;
    });
  }

  Future<void> _carregarEspecialidades() async {
    setState(() => _loading = true);
    final res = await _api.getEspecialidades();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _especialidades = ['Todas as especialidades', ...(res['data'] as List).cast<String>()];
      }
    });
  }

  Future<void> _carregarHorarios(DateTime data) async {
    if (_profissional == null) return;
    setState(() { _loading = true; _horarios = []; _horario = null; });
    final res = await _api.getHorariosDisponiveis(
      profissionalId: _profissional!['id'] as String,
      data: data,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) _horarios = (res['data'] as List).cast<String>();
    });
  }

  Future<void> _carregarProfissionaisDisponiveis() async {
    if (_data == null || _horario == null) return;
    setState(() { _loading = true; _profissionais = []; });
    final esp = (_especialidade == null || _especialidade == 'Todas as especialidades') ? null : _especialidade;
    final res = await _api.getProfissionaisDisponiveis(
      especialidade: esp,
      data: _data!,
      horario: _horario!,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) _profissionais = (res['data'] as List).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _confirmar() async {
    if (_profissional == null || _data == null || _horario == null) return;
    setState(() { _confirmando = true; _erro = null; });
    final h = _horario!.split(':');
    final dataHora = DateTime(_data!.year, _data!.month, _data!.day, int.parse(h[0]), int.parse(h[1]));
    final res = await _api.agendarConsulta(
      pacienteId: widget.pacienteId,
      profissionalId: _profissional!['id'] as String,
      dataHora: dataHora,
    );
    if (!mounted) return;
    setState(() => _confirmando = false);
    if (res['success'] == true) {
      _mostrarSucesso();
    } else {
      setState(() => _erro = res['message'] as String?);
    }
  }

  void _mostrarSucesso() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 56),
          ),
          const SizedBox(height: 16),
          const Text('Consulta Agendada!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Sua consulta com ${_profissional!['nome']} foi confirmada.\nO profissional será informado sobre o agendamento.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(true); },
              child: const Text('Ótimo!'),
            ),
          ),
        ],
      ),
    );
  }

  void _voltar() {
    if (_passo > 0) {
      // Se profissional pré-selecionado, passo mínimo é 1
      final minPasso = _profPreSelecionado ? 1 : 0;
      if (_passo > minPasso) {
        setState(() => _passo--);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  // Títulos dos passos (quando sem profissional pré-selecionado)
  String get _tituloPasso {
    if (_profPreSelecionado) {
      switch (_passo) {
        case 1: return 'Escolha a Data';
        case 2: return 'Escolha o Horário';
        case 4: return 'Confirmar Agendamento';
        default: return 'Agendamento';
      }
    }
    switch (_passo) {
      case 0: return 'Especialidade';
      case 1: return 'Data';
      case 2: return 'Horário';
      case 3: return 'Profissional';
      case 4: return 'Confirmação';
      default: return 'Agendamento';
    }
  }

  double get _progresso {
    if (_profPreSelecionado) {
      // passos 1,2,4 → progress 1/3, 2/3, 3/3
      if (_passo == 1) return 1/3;
      if (_passo == 2) return 2/3;
      return 1.0;
    }
    return (_passo + 1) / 5;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: _voltar,
        ),
        title: Text(_tituloPasso, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: _progresso, backgroundColor: AppTheme.divider, color: AppTheme.primary),
        ),
      ),
      body: _loading && _passo == 1 && _profPreSelecionado
          ? const Center(child: CircularProgressIndicator())
          : _buildPasso(),
    );
  }

  Widget _buildPasso() {
    if (_loading && _passo != 2) return const Center(child: CircularProgressIndicator());
    switch (_passo) {
      case 0: return _passoEspecialidade();
      case 1: return _passoData();
      case 2: return _passoHorario();
      case 3: return _passoProfissional();
      case 4: return _passoConfirmacao();
      default: return const SizedBox();
    }
  }

  // ── Passo 0: Especialidade ────────────────────────────────────────────────
  Widget _passoEspecialidade() {
    return Column(children: [
      _Header(titulo: 'Qual especialidade você precisa?', sub: 'Selecione para filtrar profissionais'),
      Expanded(
        child: _especialidades.isEmpty
            ? const Center(child: Text('Nenhuma especialidade encontrada.\nVerifique se há profissionais cadastrados.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _especialidades.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final esp = _especialidades[i];
                  return _OpcaoCard(
                    titulo: esp,
                    icone: i == 0 ? Icons.medical_services_rounded : Icons.self_improvement_rounded,
                    selecionado: _especialidade == esp,
                    onTap: () => setState(() {
                      _especialidade = esp == 'Todas as especialidades' ? null : esp;
                      _passo = 1;
                    }),
                  );
                },
              ),
      ),
    ]);
  }

  // ── Passo 1: Data ─────────────────────────────────────────────────────────
  Widget _passoData() {
    final nomeProfissional = _profissional?['nome'] as String? ?? '';
    return Column(children: [
      _Header(
        titulo: 'Escolha a data',
        sub: nomeProfissional.isNotEmpty ? 'Disponibilidade de $nomeProfissional' : 'Selecione um dia disponível',
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.divider)),
            child: CalendarDatePicker(
              initialDate: _data ?? DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
              onDateChanged: (d) async {
                setState(() { _data = d; _horario = null; });
                if (_profPreSelecionado && _profissional != null) {
                  await _carregarHorarios(d);
                  if (!mounted) return;
                  setState(() => _passo = 2);
                } else {
                  setState(() => _passo = 2);
                }
              },
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Passo 2: Horário ──────────────────────────────────────────────────────
  Widget _passoHorario() {
    // Se profissional pré-selecionado: usa horários reais da disponibilidade
    if (_profPreSelecionado) {
      return Column(children: [
        _Header(titulo: 'Qual horário prefere?', sub: _data != null ? _formatarData(_data!) : ''),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _horarios.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event_busy_rounded, size: 64, color: AppTheme.textHint),
                      const SizedBox(height: 16),
                      const Text('Sem horários disponíveis\nnesta data.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(onPressed: () => setState(() => _passo = 1), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Escolher outra data')),
                    ]))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                        itemCount: _horarios.length,
                        itemBuilder: (_, i) {
                          final h = _horarios[i];
                          final sel = _horario == h;
                          return GestureDetector(
                            onTap: () => setState(() { _horario = h; _passo = 4; }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: sel ? AppTheme.primary : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider),
                              ),
                              child: Center(child: Text(h, style: TextStyle(color: sel ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]);
    }

    // Sem profissional pré-selecionado: horários padrão
    final horariosPadrao = ['07:00','08:00','09:00','10:00','11:00','13:00','14:00','15:00','16:00','17:00','18:00','19:00'];
    return Column(children: [
      _Header(titulo: 'Qual horário prefere?', sub: _data != null ? _formatarData(_data!) : ''),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: horariosPadrao.length,
            itemBuilder: (_, i) {
              final h = horariosPadrao[i];
              final sel = _horario == h;
              return GestureDetector(
                onTap: () async {
                  setState(() { _horario = h; });
                  await _carregarProfissionaisDisponiveis();
                  if (!mounted) return;
                  setState(() => _passo = 3);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? AppTheme.primary : AppTheme.divider),
                  ),
                  child: Center(child: Text(h, style: TextStyle(color: sel ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15))),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }

  // ── Passo 3: Profissional ─────────────────────────────────────────────────
  Widget _passoProfissional() {
    if (_profissionais.isEmpty) {
      return Column(children: [
        _Header(titulo: 'Profissionais Disponíveis', sub: '$_horario · ${_data != null ? _formatarData(_data!) : ""}'),
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_busy_rounded, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          const Text('Nenhum profissional disponível\nneste horário.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: () => setState(() => _passo = 2), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Outro horário')),
        ]))),
      ]);
    }
    return Column(children: [
      _Header(titulo: 'Escolha o profissional', sub: '${_profissionais.length} disponível(is) em $_horario'),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _profissionais.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final p = _profissionais[i];
            final nome = p['nome'] as String? ?? '';
            final esp = p['especialidade'] as String? ?? 'Fisioterapia';
            final crefito = p['crefito'] as String? ?? '';
            final cores = [AppTheme.primary, AppTheme.secondary, const Color(0xFF9C27B0)];
            final cor = cores[nome.isNotEmpty ? nome.codeUnitAt(0) % cores.length : 0];
            return GestureDetector(
              onTap: () => setState(() { _profissional = p; _passo = 4; }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
                child: Row(children: [
                  CircleAvatar(radius: 26, backgroundColor: cor.withValues(alpha: 0.15), child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?', style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 20))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(esp, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    if (crefito.isNotEmpty) Text('CREFITO: $crefito', style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textHint),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Passo 4: Confirmação ──────────────────────────────────────────────────
  Widget _passoConfirmacao() {
    final nome = _profissional?['nome'] as String? ?? '';
    final esp = _profissional?['especialidade'] as String? ?? 'Fisioterapia';
    return Column(children: [
      _Header(titulo: 'Confirmar Agendamento', sub: 'Revise os dados antes de confirmar'),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.08), AppTheme.secondary.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 48),
                const SizedBox(height: 16),
                _InfoRow(icone: Icons.person_rounded, label: 'Profissional', valor: nome),
                const SizedBox(height: 10),
                _InfoRow(icone: Icons.medical_services_rounded, label: 'Especialidade', valor: esp),
                const SizedBox(height: 10),
                _InfoRow(icone: Icons.event_rounded, label: 'Data', valor: _data != null ? _formatarData(_data!) : '-'),
                const SizedBox(height: 10),
                _InfoRow(icone: Icons.access_time_rounded, label: 'Horário', valor: _horario ?? '-'),
              ]),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_erro!, style: const TextStyle(color: AppTheme.error))),
                ]),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmando ? null : _confirmar,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _confirmando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Agendamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() { _erro = null; _passo = _profPreSelecionado ? 2 : 3; }),
              child: const Text('Voltar e alterar'),
            ),
          ]),
        ),
      ),
    ]);
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String titulo;
  final String sub;
  const _Header({required this.titulo, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

class _OpcaoCard extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final bool selecionado;
  final VoidCallback onTap;
  const _OpcaoCard({required this.titulo, required this.icone, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selecionado ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selecionado ? AppTheme.primary : AppTheme.divider, width: selecionado ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icone, color: selecionado ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, color: selecionado ? AppTheme.primary : AppTheme.textPrimary))),
          if (selecionado) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  const _InfoRow({required this.icone, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icone, size: 18, color: AppTheme.primary),
      const SizedBox(width: 10),
      Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
    ]);
  }
}
