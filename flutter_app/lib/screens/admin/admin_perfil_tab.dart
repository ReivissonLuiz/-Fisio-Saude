import "package:flutter/material.dart";
import "../../theme/app_theme.dart";
import "../../services/api_service.dart";
import "../../widgets/edit_perfil_dialog.dart";

class AdminPerfilTab extends StatefulWidget {
  final String nome;
  final String email;
  final String? supabaseUserId;
  final String? usuarioId;
  final Future<void> Function() onLogout;

  const AdminPerfilTab({
    super.key,
    required this.nome,
    required this.email,
    this.supabaseUserId,
    this.usuarioId,
    required this.onLogout,
  });

  @override
  State<AdminPerfilTab> createState() => _AdminPerfilTabState();
}

class _AdminPerfilTabState extends State<AdminPerfilTab> {
  final _api = ApiService();
  Map<String, dynamic>? _perfilData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerfil();
  }

  Future<void> _loadPerfil() async {
    if (widget.usuarioId == null || widget.usuarioId!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    final res = await _api.getUsuario(widget.usuarioId!);
    if (mounted) {
      setState(() {
        _perfilData = res["success"] == true ? res["data"] as Map<String, dynamic> : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirEdicao() async {
    if (_perfilData == null || widget.usuarioId == null) return;
    final saved = await showEditPerfilDialog(
      context: context,
      usuarioId: widget.usuarioId!,
      perfilData: _perfilData!,
      accentColor: Colors.purple,
      camposExtras: [
        const ExtraField(label: "Cargo", fieldKey: "cargo", icon: Icons.badge_outlined),
      ],
    );
    if (saved && mounted) {
      final sm = ScaffoldMessenger.of(context);
      await _loadPerfil();
      sm.showSnackBar(
        const SnackBar(content: Text("Dados atualizados com sucesso!"), backgroundColor: AppTheme.accent),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sair da conta"),
        content: const Text("Tem certeza que deseja sair?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text("Sair"),
          ),
        ],
      ),
    );
    if (confirm == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.purple,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white.withValues(alpha: 0.25),
                              child: Text(
                                widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : "A",
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(widget.nome, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              _perfilData?["cargo"] as String? ?? "Administrador",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Informacoes da Conta", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          TextButton.icon(
                            onPressed: widget.usuarioId != null ? _abrirEdicao : null,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text("Editar"),
                            style: TextButton.styleFrom(foregroundColor: Colors.purple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
                        child: Column(
                          children: [
                            _infoTile(Icons.admin_panel_settings_outlined, "Funcao", _perfilData?["cargo"] as String? ?? "Administrador"),
                            const Divider(height: 1, color: AppTheme.divider, indent: 56),
                            _infoTile(Icons.email_outlined, "E-mail", widget.email),
                            if ((_perfilData?["telefone"] as String?)?.isNotEmpty == true) ...[
                              const Divider(height: 1, color: AppTheme.divider, indent: 56),
                              _infoTile(Icons.phone_outlined, "Telefone", _perfilData!["telefone"] as String),
                            ],
                            if (_perfilData?["cpf"] != null) ...[
                              const Divider(height: 1, color: AppTheme.divider, indent: 56),
                              _infoTile(Icons.badge_outlined, "CPF", _formatCpf(_perfilData!["cpf"] as String)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if ((_perfilData?["cidade"] as String?)?.isNotEmpty == true ||
                          (_perfilData?["logradouro"] as String?)?.isNotEmpty == true) ...[
                        const Text("Endereco", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.divider)),
                          child: Column(
                            children: [
                              if ((_perfilData?["logradouro"] as String?)?.isNotEmpty == true)
                                _infoTile(Icons.home_outlined, "Logradouro",
                                    "${_perfilData!["logradouro"]}${(_perfilData?["numero"] as String?)?.isNotEmpty == true ? ", ${_perfilData!["numero"]}" : ""}"),
                              if ((_perfilData?["bairro"] as String?)?.isNotEmpty == true) ...[
                                const Divider(height: 1, color: AppTheme.divider, indent: 56),
                                _infoTile(Icons.holiday_village_outlined, "Bairro", _perfilData!["bairro"] as String),
                              ],
                              if ((_perfilData?["cidade"] as String?)?.isNotEmpty == true) ...[
                                const Divider(height: 1, color: AppTheme.divider, indent: 56),
                                _infoTile(Icons.location_city_outlined, "Cidade / UF",
                                    "${_perfilData!["cidade"]}${(_perfilData?["uf"] as String?)?.isNotEmpty == true ? " - ${_perfilData!["uf"]}" : ""}"),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      const Text("Nivel de Acesso", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.purple.withValues(alpha: 0.08), Colors.purple.withValues(alpha: 0.04)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Administrador", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                                  SizedBox(height: 2),
                                  Text("Acesso total: gestao, relatorios e usuarios", style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                              child: const Text("Ativo", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmLogout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.error,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.divider)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text("Sair da Conta", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatCpf(String cpf) {
    if (cpf.length == 11) return "${cpf.substring(0,3)}.${cpf.substring(3,6)}.${cpf.substring(6,9)}-${cpf.substring(9)}";
    return cpf;
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.purple.withValues(alpha: 0.7)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
