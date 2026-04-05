/// paciente_detalhes_screen.dart
/// Tela do Profissional para visualizar dados e histórico (sintomas) de um paciente.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class PacienteDetalhesScreen extends StatefulWidget {
  final Map<String, dynamic> pacienteDados; // Vem da lista (nome, email, telefone...)
  final String profissionalId;

  const PacienteDetalhesScreen({
    super.key,
    required this.pacienteDados,
    required this.profissionalId,
  });

  @override
  State<PacienteDetalhesScreen> createState() => _PacienteDetalhesScreenState();
}

class _PacienteDetalhesScreenState extends State<PacienteDetalhesScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _sintomas = [];

  @override
  void initState() {
    super.initState();
    _loadHistorico();
  }

  Future<void> _loadHistorico() async {
    setState(() => _isLoading = true);
    final pacienteId = widget.pacienteDados['id'];
    
    // Busca os sintomas reportados pelo paciente
    final res = await _api.getSintomas(pacienteId);
    
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _sintomas = res['data'] as List;
        }
        _isLoading = false;
      });
    }
  }

  int _sintomasEsteMes() {
    final now = DateTime.now();
    return _sintomas.where((s) {
      final dt = DateTime.tryParse(s['data_hora'] as String? ?? '');
      return dt != null && dt.month == now.month && dt.year == now.year;
    }).length;
  }

  String _dorMedia() {
    if (_sintomas.isEmpty) return '-';
    final niveis = _sintomas.map((s) => s['nivel_dor'] as int? ?? 0).toList();
    final media = niveis.reduce((a, b) => a + b) / niveis.length;
    return media.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final nome = widget.pacienteDados['nome'] ?? 'Nome não cadastrado';
    final email = widget.pacienteDados['email'] ?? 'E-mail não informado';
    final telefone = widget.pacienteDados['telefone'] ?? 'Sem telefone';
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Prontuário do Paciente'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : RefreshIndicator(
              onRefresh: _loadHistorico,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Paciente ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nome, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Text(telefone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- Resumo de Sintomas ---
                    const Text('Métricas Clínicas Recentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatCard(label: 'Total de Registros', value: _sintomas.length.toString(), icon: Icons.history_rounded, color: Colors.blue),
                        const SizedBox(width: 12),
                        _StatCard(label: 'Sintomas neste Mês', value: _sintomasEsteMes().toString(), icon: Icons.date_range_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        _StatCard(label: 'Média de Dor', value: _dorMedia(), icon: Icons.analytics_rounded, color: Colors.red),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // --- Linha do Tempo ---
                    const Text('Histórico de Sintomas (Linha do Tempo)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    if (_sintomas.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              Icon(Icons.monitor_heart_rounded, size: 60, color: AppTheme.textHint.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text('Nenhum sintoma registrado por este paciente.', style: TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _sintomas.length,
                        itemBuilder: (context, index) {
                          return _SintomaViewCard(sintoma: _sintomas[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _SintomaViewCard extends StatelessWidget {
  final Map<String, dynamic> sintoma;
  const _SintomaViewCard({required this.sintoma});

  @override
  Widget build(BuildContext context) {
    final nivel = sintoma['nivel_dor'] as int? ?? 0;
    final descricao = sintoma['descricao'] as String? ?? '';
    final regiao = sintoma['regiao'] as String?;
    final dt = DateTime.tryParse(sintoma['data_hora'] as String? ?? '');
    final dtFmt = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';
        
    final cor = nivel <= 3
        ? AppTheme.accent
        : nivel <= 6
            ? AppTheme.warning
            : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cor.withValues(alpha: 0.3))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$nivel', style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Dor', style: TextStyle(color: cor, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (regiao != null && regiao.isNotEmpty)
                        Text(regiao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                      else
                        const Text('Sintoma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      
                      Text(dtFmt, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (descricao.isNotEmpty)
                    Text(descricao, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
