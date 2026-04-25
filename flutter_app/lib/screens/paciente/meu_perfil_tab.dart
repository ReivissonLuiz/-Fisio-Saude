/// meu_perfil_tab.dart
/// Aba "Meu Perfil" — visualização e edição dos dados do paciente — +Fisio +Saúde
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/edit_perfil_dialog.dart';

class MeuPerfilTab extends StatefulWidget {
  final String pacienteId;
  final String nome;
  final String email;
  final VoidCallback onLogout;

  const MeuPerfilTab({
    super.key,
    required this.pacienteId,
    required this.nome,
    required this.email,
    required this.onLogout,
  });

  @override
  State<MeuPerfilTab> createState() => _MeuPerfilTabState();
}

class _MeuPerfilTabState extends State<MeuPerfilTab> {
  final _api = ApiService();

  Map<String, dynamic>? _paciente;
  bool _loading = true;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    setState(() => _loading = true);
    final result = await _api.getPaciente(widget.pacienteId);
    if (!mounted) return;
    setState(() {
      _paciente = result['success'] == true ? result['data'] as Map<String, dynamic> : null;
      _loading = false;
    });
  }

  Future<void> _abrirEdicao() async {
    if (_paciente == null) return;
    final saved = await showEditPerfilDialog(
      context: context,
      usuarioId: widget.pacienteId,
      perfilData: _paciente!,
      accentColor: AppTheme.primary,
    );
    if (saved && mounted) {
      setState(() => _successMsg = 'Perfil atualizado com sucesso!');
      await _carregarPerfil();
    }
  }

  void _confirmarLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sair', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () { Navigator.pop(ctx); widget.onLogout(); },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final nome = _paciente?['nome'] as String? ?? widget.nome;
    final email = _paciente?['email'] as String? ?? widget.email;
    final dataNasc = _paciente?['data_nasc'] as String?;
    final cpf = _paciente?['cpf'] as String?;

    return RefreshIndicator(
      onRefresh: _carregarPerfil,
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Avatar e nome -----------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(nome,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Paciente',
                        style:
                            TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Feedbacks ---------------------------------------------------
            if (_successMsg != null)
              _FeedbackBanner(message: _successMsg!, isError: false),

            // --- Dados Não editáveis -----------------------------------------
            _SectionCard(
              title: 'Informações da Conta',
              icon: Icons.lock_outline,
              children: [
                _InfoRow(label: 'E-mail', value: email,
                    icon: Icons.email_outlined),
                if (cpf != null && cpf.isNotEmpty)
                  _InfoRow(
                      label: 'CPF',
                      value: _formatarCpf(cpf),
                      icon: Icons.badge_outlined),
                if (dataNasc != null && dataNasc.isNotEmpty)
                  _InfoRow(
                      label: 'Data de nascimento',
                      value: _formatarData(dataNasc),
                      icon: Icons.cake_outlined),
              ],
            ),
            const SizedBox(height: 14),

            // --- Dados editáveis ---------------------------------------------
            _SectionCard(
              title: 'Dados Pessoais',
              icon: Icons.person_outline,
              trailing: TextButton.icon(
                onPressed: _abrirEdicao,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
              children: [
                _InfoRow(label: 'Nome completo', value: nome, icon: Icons.person_outline),
                _InfoRow(
                    label: 'Telefone',
                    value: (_paciente?['telefone'] as String?)?.isNotEmpty == true
                        ? _paciente!['telefone'] as String
                        : 'Não informado',
                    icon: Icons.phone_outlined),
                _InfoRow(
                    label: 'Gênero',
                    value: (_paciente?['genero'] as String?) ?? 'Não informado',
                    icon: Icons.people_outline),
              ],
            ),
            const SizedBox(height: 14),

            // --- Endereço ---------------------------------------------------
            if ((_paciente?['logradouro'] as String?)?.isNotEmpty == true ||
                (_paciente?['cidade'] as String?)?.isNotEmpty == true)
              _SectionCard(
                title: 'Endereço',
                icon: Icons.location_on_outlined,
                children: [
                  if ((_paciente?['logradouro'] as String?)?.isNotEmpty == true)
                    _InfoRow(
                        label: 'Logradouro',
                        value: '${_paciente!['logradouro']}${(_paciente?['numero'] as String?)?.isNotEmpty == true ? ', ${_paciente!['numero']}' : ''}',
                        icon: Icons.home_outlined),
                  if ((_paciente?['bairro'] as String?)?.isNotEmpty == true)
                    _InfoRow(label: 'Bairro', value: _paciente!['bairro'] as String, icon: Icons.holiday_village_outlined),
                  if ((_paciente?['cidade'] as String?)?.isNotEmpty == true)
                    _InfoRow(
                        label: 'Cidade / UF',
                        value: '${_paciente!['cidade']}${(_paciente?['uf'] as String?)?.isNotEmpty == true ? ' - ${_paciente!['uf']}' : ''}',
                        icon: Icons.location_city_outlined),
                ],
              ),
            const SizedBox(height: 24),

            // --- Botão Sair --------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.error),
                  foregroundColor: AppTheme.error,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _confirmarLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatarCpf(String cpf) {
    if (cpf.length != 11) return cpf;
    return '${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9)}';
  }

  String _formatarData(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// --- Widgets auxiliares -----------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.accent;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}


