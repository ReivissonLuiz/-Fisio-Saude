/// agendamento_dialog.dart
/// Dialog de agendamento de consulta — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AgendamentoDialog extends StatefulWidget {
  final Map<String, dynamic> profissional;
  final String pacienteId;
  final String pacienteNome;

  const AgendamentoDialog({
    super.key,
    required this.profissional,
    required this.pacienteId,
    required this.pacienteNome,
  });

  @override
  State<AgendamentoDialog> createState() => _AgendamentoDialogState();
}

class _AgendamentoDialogState extends State<AgendamentoDialog> {
  final _api = ApiService();
  final _notif = NotificationService();

  bool _loadingDisp = true;
  bool _loadingClinicas = true;
  bool _submitting = false;

  List<dynamic> _disponibilidades = [];
  List<dynamic> _clinicas = [];

  // Agrupamento por data
  Map<String, List<dynamic>> _dispPorData = {};
  String? _dataSelecionada;
  Map<String, dynamic>? _horarioSelecionado;
  Map<String, dynamic>? _clinicaSelecionada;
  final _obsCtrl = TextEditingController();

  int _step = 0; // 0=data, 1=horário, 2=clínica, 3=confirmar

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final profId = widget.profissional['id'] as String;
    final futures = await Future.wait([
      _api.getDisponibilidades(profId),
      _api.getClinicas(),
    ]);
    if (!mounted) return;
    setState(() {
      _loadingDisp = false;
      _loadingClinicas = false;
      if (futures[0]['success'] == true) {
        _disponibilidades = futures[0]['data'] as List? ?? [];
        _agruparPorData();
      }
      if (futures[1]['success'] == true) {
        _clinicas = futures[1]['data'] as List? ?? [];
      }
    });
  }

  void _agruparPorData() {
    _dispPorData = {};
    for (var d in _disponibilidades) {
      final data = d['data'] as String;
      _dispPorData.putIfAbsent(data, () => []).add(d);
    }
  }

  Future<void> _confirmarAgendamento() async {
    if (_horarioSelecionado == null || _clinicaSelecionada == null) return;
    setState(() => _submitting = true);

    final data = _horarioSelecionado!['data'] as String;
    final hora = _horarioSelecionado!['hora_inicio'] as String;
    final dataHora = '${data}T$hora:00';
    final profId = widget.profissional['id'] as String;
    final profNome = widget.profissional['nome'] as String? ?? 'Profissional';
    final profEmail = widget.profissional['email'] as String?;
    final clinicaNome = _clinicaSelecionada!['nome'] as String? ?? '';

    final result = await _api.criarConsulta(
      idPaciente: widget.pacienteId,
      idProfissional: profId,
      dataHora: dataHora,
      idClinica: _clinicaSelecionada!['id'] as String?,
      observacao: _obsCtrl.text.trim().isNotEmpty ? _obsCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // Notificação in-app
      final dtFmt = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataHora));
      await _notif.criarNotificacao(
        destinatarioId: profId,
        titulo: 'Nova consulta agendada',
        mensagem:
            'Paciente ${widget.pacienteNome} agendou para $dtFmt às $hora.\nLocal: $clinicaNome.',
      );

      // Notificação por e-mail
      if (profEmail != null && profEmail.isNotEmpty) {
        await _notif.enviarEmailNotificacao(
          emailDestino: profEmail,
          assunto: '+Físio +Saúde — Nova Consulta Agendada',
          corpo: '''
<h2>Nova Consulta Agendada</h2>
<p><b>Paciente:</b> ${widget.pacienteNome}</p>
<p><b>Data:</b> $dtFmt</p>
<p><b>Horário:</b> $hora</p>
<p><b>Local:</b> $clinicaNome</p>
${_obsCtrl.text.trim().isNotEmpty ? '<p><b>Obs:</b> ${_obsCtrl.text.trim()}</p>' : ''}
<hr>
<p style="color:#888;font-size:12px">+Físio +Saúde — Plataforma de Fisioterapia</p>
''',
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Consulta agendada com $profNome!'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } else {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erro ao agendar.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profNome = widget.profissional['nome'] as String? ?? 'Profissional';
    final profEsp =
        widget.profissional['especialidade'] as String? ?? 'Fisioterapia';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Agendar Consulta',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('com $profNome',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text(profEsp,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Step indicator
                  _buildStepIndicator(),
                ],
              ),
            ),

            // Body
            Flexible(
              child: _loadingDisp || _loadingClinicas
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildStepContent(),
            ),

            // Footer buttons
            if (!_loadingDisp && !_loadingClinicas) _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(4, (i) {
        final isActive = i == _step;
        final isDone = i < _step;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Colors.white
                      : isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: AppTheme.primary)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? AppTheme.primary
                                  : Colors.white70)),
                ),
              ),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < _step
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              if (i == 3) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildDateStep();
      case 1:
        return _buildTimeStep();
      case 2:
        return _buildClinicStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // Step 0: Selecionar data
  Widget _buildDateStep() {
    if (_dispPorData.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('Nenhuma data disponível',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Este profissional não possui horários disponíveis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
          ],
        ),
      );
    }

    final datas = _dispPorData.keys.toList()..sort();
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: datas.length,
      itemBuilder: (_, i) {
        final dataStr = datas[i];
        final dt = DateTime.parse(dataStr);
        final fmt = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(dt);
        final qtdHorarios = _dispPorData[dataStr]!.length;
        final selected = _dataSelecionada == dataStr;

        return GestureDetector(
          onTap: () => setState(() => _dataSelecionada = dataStr),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('${dt.day}'.padLeft(2, '0'),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary)),
                      Text(
                          DateFormat('MMM', 'pt_BR')
                              .format(dt)
                              .toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmt,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary)),
                      Text('$qtdHorarios horário${qtdHorarios > 1 ? 's' : ''} disponíve${qtdHorarios > 1 ? 'is' : 'l'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  // Step 1: Selecionar horário
  Widget _buildTimeStep() {
    final horarios = _dispPorData[_dataSelecionada] ?? [];
    if (horarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('Nenhum horário disponível para esta data.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat("dd 'de' MMMM, EEEE", 'pt_BR')
                .format(DateTime.parse(_dataSelecionada!)),
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: horarios.map<Widget>((h) {
                final hora = h['hora_inicio'] as String;
                final selected = _horarioSelecionado == h;
                return GestureDetector(
                  onTap: () => setState(() => _horarioSelecionado = h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(hora,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                selected ? Colors.white : AppTheme.primary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Selecionar clínica
  Widget _buildClinicStep() {
    if (_clinicas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('Nenhuma clínica cadastrada.',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: _clinicas.length,
      itemBuilder: (_, i) {
        final c = _clinicas[i];
        final nome = c['nome'] as String? ?? 'Clínica';
        final endereco = _formatarEndereco(c);
        final telefone = c['telefone'] as String?;
        final selected = _clinicaSelecionada == c;

        return GestureDetector(
          onTap: () => setState(() => _clinicaSelecionada = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.secondary.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.secondary : AppTheme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.secondary.withValues(alpha: 0.12)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_hospital_rounded,
                      color: selected
                          ? AppTheme.secondary
                          : AppTheme.textSecondary,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (endereco.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(endereco,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      if (telefone != null && telefone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_rounded,
                                  size: 12, color: AppTheme.textHint),
                              const SizedBox(width: 4),
                              Text(telefone,
                                  style: const TextStyle(
                                      color: AppTheme.textHint,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.secondary, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }

  // Step 3: Confirmar
  Widget _buildConfirmStep() {
    final dt = DateTime.parse(
        '${_horarioSelecionado!['data']}T${_horarioSelecionado!['hora_inicio']}:00');
    final dataFmt = DateFormat("dd/MM/yyyy (EEEE)", 'pt_BR').format(dt);
    final hora = _horarioSelecionado!['hora_inicio'] as String;
    final clinicaNome = _clinicaSelecionada!['nome'] as String? ?? '';
    final clinicaEnd = _formatarEndereco(_clinicaSelecionada!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Confirme os dados do agendamento:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _infoRow(Icons.person_rounded, 'Profissional',
              widget.profissional['nome'] as String? ?? ''),
          _infoRow(Icons.calendar_month_rounded, 'Data', dataFmt),
          _infoRow(Icons.access_time_rounded, 'Horário', hora),
          _infoRow(Icons.local_hospital_rounded, 'Local', clinicaNome),
          if (clinicaEnd.isNotEmpty)
            _infoRow(Icons.location_on_rounded, 'Endereço', clinicaEnd),
          const SizedBox(height: 16),
          TextFormField(
            controller: _obsCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Descreva o motivo da consulta...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 1),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canAdvance = (_step == 0 && _dataSelecionada != null) ||
        (_step == 1 && _horarioSelecionado != null) ||
        (_step == 2 && _clinicaSelecionada != null) ||
        _step == 3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            TextButton.icon(
              onPressed: _submitting ? null : () => setState(() => _step--),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Voltar'),
            ),
          const Spacer(),
          if (_step < 3)
            ElevatedButton(
              onPressed: canAdvance ? () => setState(() => _step++) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Próximo'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          if (_step == 3)
            ElevatedButton(
              onPressed: _submitting ? null : _confirmarAgendamento,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 4),
                        Text('Confirmar'),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  String _formatarEndereco(Map<String, dynamic> c) {
    final partes = <String>[];
    if (c['logradouro'] != null && (c['logradouro'] as String).isNotEmpty) {
      var s = c['logradouro'] as String;
      if (c['numero'] != null && (c['numero'] as String).isNotEmpty) {
        s += ', ${c['numero']}';
      }
      partes.add(s);
    }
    if (c['bairro'] != null && (c['bairro'] as String).isNotEmpty) {
      partes.add(c['bairro'] as String);
    }
    if (c['cidade'] != null && (c['cidade'] as String).isNotEmpty) {
      var s = c['cidade'] as String;
      if (c['uf'] != null && (c['uf'] as String).isNotEmpty) {
        s += ' - ${c['uf']}';
      }
      partes.add(s);
    }
    return partes.join(', ');
  }
}
