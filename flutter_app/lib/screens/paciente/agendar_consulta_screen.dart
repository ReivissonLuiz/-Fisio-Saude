/// agendar_consulta_screen.dart
/// Fluxo de agendamento de consulta para o paciente.
/// Passos: 1) Especialidade → 2) Data → 3) Horário → 4) Profissional → 5) Confirmação
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
  int _passo = 0; // 0=Especialidade, 1=Data, 2=Horário, 3=Profissional, 4=Confirmação

  // Seleções
  String? _especialidade;
  DateTime? _data;
  String? _horario;
  Map<String, dynamic>? _profissional;

  // Dados carregados
  List<String> _especialidades = [];
  List<String> _horarios = [];
  List<Map<String, dynamic>> _profissionais = [];

  bool _loading = false;
  bool _confirmando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarEspecialidades();
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

  Future<void> _carregarHorarios() async {
    if (_profissional == null || _data == null) return;
    setState(() { _loading = true; _horarios = []; _horario = null; });
    final res = await _api.getHorariosDisponiveis(
      profissionalId: _profissional!['id'] as String,
      data: _data!,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _horarios = (res['data'] as List).cast<String>();
      }
    });
  }

  Future<void> _carregarProfissionais() async {
    if (_data == null || _horario == null) return;
    setState(() { _loading = true; _profissionais = []; });
    final esp = (_especialidade == null || _especialidade == 'Todas as especialidades')
        ? null : _especialidade;
    final res = await _api.getProfissionaisDisponiveis(
      especialidade: esp,
      data: _data!,
      horario: _horario!,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _profissionais = (res['data'] as List).cast<Map<String, dynamic>>();
      }
    });
  }

  Future<void> _confirmar() async {
    if (_profissional == null || _data == null || _horario == null) return;
    setState(() => _confirmando = true);
    final h = _horario!.split(':');
    final dataHora = DateTime(_data!.year, _data!.month, _data!.day,
        int.parse(h[0]), int.parse(h[1]));
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 56),
            ),
            const SizedBox(height: 16),
            const Text('Consulta Agendada!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Sua consulta com ${_profissional!['nome']} foi confirmada.\nVocê receberá uma notificação.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('Ótimo!'),
            ),
          ),
        ],
      ),
    );
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
          onPressed: () {
            if (_passo > 0) setState(() => _passo--);
            else Navigator.of(context).pop();
          },
        ),
        title: Text(
          ['Especialidade', 'Data', 'Horário', 'Profissional', 'Confirmação'][_passo],
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_passo + 1) / 5,
            backgroundColor: AppTheme.divider,
            color: AppTheme.primary,
          ),
        ),
      ),
      body: _buildPasso(),
    );
  }

  Widget _buildPasso() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_passo) {
      case 0: return _passoEspecialidade();
      case 1: return _passoData();
      case 2: return _passoHorario();
      case 3: return _passoProfissional();
      case 4: return _passoConfirmacao();
      default: return const SizedBox();
    }
  }

  // ─── Passo 0: Especialidade ───────────────────────────────────────────────

  Widget _passoEspecialidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(titulo: 'Qual especialidade você precisa?', sub: 'Selecione para filtrar profissionais'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _especialidades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final esp = _especialidades[i];
              final selecionado = _especialidade == esp;
              return _OpcaoCard(
                titulo: esp,
                icone: esp == 'Todas as especialidades'
                    ? Icons.medical_services_rounded
                    : Icons.self_improvement_rounded,
                selecionado: selecionado,
                onTap: () {
                  setState(() {
                    _especialidade = esp == 'Todas as especialidades' ? null : esp;
                    _passo = 1;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Passo 1: Data ────────────────────────────────────────────────────────

  Widget _passoData() {
    return Column(
      children: [
        _Header(titulo: 'Escolha a data', sub: 'Selecione um dia disponível'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _data ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    onDateChanged: (d) {
                      setState(() {
                        _data = d;
                        _horario = null;
                        _profissional = null;
                        _passo = 2;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Passo 2: Horário ─────────────────────────────────────────────────────

  Widget _passoHorario() {
    // Carrega horários com base em todos os profissionais da especialidade
    // Aqui listamos horários "populares" e ao selecionar buscamos profissionais disponíveis
    final horariosPadrao = [
      '07:00','08:00','09:00','10:00','11:00',
      '13:00','14:00','15:00','16:00','17:00','18:00','19:00'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(titulo: 'Qual horário prefere?', sub: 'Horários para ${_data != null ? _formatarData(_data!) : ""}'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: horariosPadrao.length,
              itemBuilder: (_, i) {
                final h = horariosPadrao[i];
                final sel = _horario == h;
                return GestureDetector(
                  onTap: () async {
                    setState(() { _horario = h; _profissional = null; });
                    await _carregarProfissionais();
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
                    child: Center(
                      child: Text(h,
                          style: TextStyle(
                              color: sel ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── Passo 3: Profissional ────────────────────────────────────────────────

  Widget _passoProfissional() {
    if (_profissionais.isEmpty) {
      return Column(
        children: [
          _Header(titulo: 'Profissionais Disponíveis', sub: '$_horario · ${_data != null ? _formatarData(_data!) : ""}'),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_busy_rounded, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  const Text('Nenhum profissional disponível\nneste horário.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _passo = 2),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Escolher outro horário'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: cor.withValues(alpha: 0.15),
                        child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                            style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(esp, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          if (crefito.isNotEmpty)
                            Text('CREFITO: $crefito', style: const TextStyle(color: AppTheme.primary, fontSize: 11)),
                        ]),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textHint),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Passo 4: Confirmação ─────────────────────────────────────────────────

  Widget _passoConfirmacao() {
    final nome = _profissional?['nome'] as String? ?? '';
    final esp = _profissional?['especialidade'] as String? ?? '';
    return Column(
      children: [
        _Header(titulo: 'Confirmar Agendamento', sub: 'Revise os dados antes de confirmar'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppTheme.primary.withValues(alpha: 0.08),
                      AppTheme.secondary.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 48),
                      const SizedBox(height: 16),
                      _InfoRow(icone: Icons.person_rounded, label: 'Profissional', valor: nome),
                      const SizedBox(height: 10),
                      _InfoRow(icone: Icons.medical_services_rounded, label: 'Especialidade', valor: esp),
                      const SizedBox(height: 10),
                      _InfoRow(icone: Icons.event_rounded, label: 'Data',
                          valor: _data != null ? _formatarData(_data!) : '-'),
                      const SizedBox(height: 10),
                      _InfoRow(icone: Icons.access_time_rounded, label: 'Horário', valor: _horario ?? '-'),
                    ],
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_erro!, style: const TextStyle(color: AppTheme.error))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmando ? null : _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _confirmando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirmar Agendamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() { _passo = 3; _erro = null; }),
                  child: const Text('Voltar e escolher outro profissional'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Widgets Auxiliares ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String titulo;
  final String sub;
  const _Header({required this.titulo, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
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
