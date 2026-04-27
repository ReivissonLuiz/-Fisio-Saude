import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ReagendarScreen extends StatefulWidget {
  final String consultaId;
  final String pacienteId;
  final String profissionalId;
  final ApiService api;
  final bool iniciadoPorProfissional;

  const ReagendarScreen({
    super.key,
    required this.consultaId,
    required this.pacienteId,
    required this.profissionalId,
    required this.api,
    this.iniciadoPorProfissional = false,
  });

  @override
  State<ReagendarScreen> createState() => _ReagendarScreenState();
}

class _ReagendarScreenState extends State<ReagendarScreen> {
  DateTime? _data;
  String? _horario;
  List<String> _horarios = [];
  bool _loading = false;
  bool _salvando = false;

  Future<void> _carregarHorarios(DateTime data) async {
    setState(() {
      _loading = true;
      _horarios = [];
      _horario = null;
    });
    final res = await widget.api.getHorariosDisponiveis(
      profissionalId: widget.profissionalId,
      data: data,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['success'] == true) {
        _horarios = (res['data'] as List).cast<String>();
      }
    });
  }

  Future<void> _confirmar() async {
    if (_data == null || _horario == null) return;
    setState(() => _salvando = true);
    final h = _horario!.split(':');
    final novaDataHora = DateTime(
      _data!.year,
      _data!.month,
      _data!.day,
      int.parse(h[0]),
      int.parse(h[1]),
    );
    
    final res = await widget.api.reagendarConsulta(
      consultaId: widget.consultaId,
      pacienteId: widget.pacienteId,
      profissionalId: widget.profissionalId,
      novaDataHora: novaDataHora,
      iniciadoPorProfissional: widget.iniciadoPorProfissional,
    );
    
    if (!mounted) return;
    setState(() => _salvando = false);
    
    if (res['success'] == true) {
      final msg = widget.iniciadoPorProfissional
          ? 'Consulta reagendada! O paciente será notificado.'
          : 'Consulta reagendada! O profissional será notificado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] as String? ?? 'Erro ao reagendar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reagendar Consulta',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha a nova data:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  });
                  _carregarHorarios(d);
                },
              ),
            ),
            if (_data != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Escolha o horário:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_horarios.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.event_busy_rounded, color: AppTheme.warning),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nenhum horário disponível nesta data.',
                          style: TextStyle(color: AppTheme.warning),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _horarios.map((h) {
                    final sel = _horario == h;
                    return GestureDetector(
                      onTap: () => setState(() => _horario = h),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          h,
                          style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
            const SizedBox(height: 32),
            if (_data != null && _horario != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirmar Reagendamento',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
