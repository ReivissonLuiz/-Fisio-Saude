/// admin_audit_tab.dart
/// Tela de auditoria do painel administrativo do +Físio +Saúde.
/// Exibe todos os eventos do log_auditoria com filtros e exportação CSV.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/audit_service.dart';

class AdminAuditTab extends StatefulWidget {
  const AdminAuditTab({super.key});

  @override
  State<AdminAuditTab> createState() => _AdminAuditTabState();
}

class _AdminAuditTabState extends State<AdminAuditTab> {
  final _audit = AuditService.instance;

  bool _isLoading = false;
  bool _isExporting = false;
  List<dynamic> _logs = [];

  // Filtros
  String? _filtroTipo;
  DateTime? _filtroInicio;
  DateTime? _filtroFim;
  final _searchController = TextEditingController();
  String _termoBusca = '';

  // Paginação
  static const int _porPagina = 50;
  int _pagina = 0;

  // Tipos disponíveis para filtro (atualizado com os namespaces LGPD)
  static const _tiposEvento = <String, String>{
    '': 'Todos os eventos',
    'auth.login_sucesso': '✅ Login bem-sucedido',
    'auth.login_falha': '❌ Falha de login',
    'auth.logout': '🚪 Logout',
    'auth.alterar_senha': '🔑 Alteração de senha',
    'conta.criar': '👤 Criação de conta',
    'conta.ativar': '🔓 Reativação de conta',
    'conta.desativar': '🔒 Desativação de conta',
    'conta.excluir': '🗑️ Exclusão de conta',
    'conta.alterar_permissao': '🔄 Alteração de permissão',
    'conta.atualizar_perfil': '✏️ Atualização de perfil',
    'clinico.agendar': '📅 Agendamento de consulta',
    'clinico.cancelar': '🚫 Cancelamento de consulta',
    'clinico.reagendar': '🔁 Reagendamento de consulta',
    'clinico.checkout': '🏁 Checkout (finalização)',
    'clinico.visualizar_prontuario': '👁️ Acesso a Prontuário',
  };

  @override
  void initState() {
    super.initState();
    _carregarLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarLogs({bool resetPagina = true}) async {
    if (resetPagina) _pagina = 0;
    setState(() => _isLoading = true);

    final resultado = await _audit.getLogs(
      tipoEvento: _filtroTipo?.isEmpty == true ? null : _filtroTipo,
      dataInicio: _filtroInicio,
      dataFim: _filtroFim?.add(const Duration(days: 1)),
      limite: _porPagina,
      offset: _pagina * _porPagina,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (resultado['success'] == true) {
          final data = resultado['data'] as List;
          _logs = data;
        } else {
          _logs = [];
        }
      });
    }
  }

  Future<void> _exportarCSV() async {
    setState(() => _isExporting = true);

    try {
      // Busca todos os logs (sem paginação) para exportar
      final resultado = await _audit.getLogs(
        tipoEvento: _filtroTipo?.isEmpty == true ? null : _filtroTipo,
        dataInicio: _filtroInicio,
        dataFim: _filtroFim?.add(const Duration(days: 1)),
        limite: 10000,
        offset: 0,
      );

      if (resultado['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao exportar logs.')),
          );
        }
        return;
      }

      final dados = resultado['data'] as List;
      final csv = AuditService.paraCSV(dados);

      if (kIsWeb) {
        // Na versão Web o export via browser é feito pelo JS nativo.
        // Como estamos compilando para Android aqui, este bloco nunca executa,
        // mas mantemos o guard por clareza.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exportação disponível na versão web do sistema.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // --- Android / Desktop: copia o CSV para o clipboard ---
      await Clipboard.setData(ClipboardData(text: csv));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${dados.length} registros copiados para a área de transferência!\n'
              'Cole em um editor de texto e salve como .csv',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _selecionarData(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (inicio ? _filtroInicio : _filtroFim) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        if (inicio) {
          _filtroInicio = picked;
        } else {
          _filtroFim = picked;
        }
      });
      _carregarLogs();
    }
  }

  void _limparFiltros() {
    setState(() {
      _filtroTipo = null;
      _filtroInicio = null;
      _filtroFim = null;
      _termoBusca = '';
      _searchController.clear();
    });
    _carregarLogs();
  }

  // Filtragem local por termo de busca (nome/email/descrição)
  List<dynamic> get _logsFiltrados {
    if (_termoBusca.isEmpty) return _logs;
    final t = _termoBusca.toLowerCase();
    return _logs.where((log) {
      final desc = (log['descricao'] ?? '').toString().toLowerCase();
      final usuario = log['usuario'];
      final nome = (usuario?['nome'] ?? '').toString().toLowerCase();
      final email = (usuario?['email'] ?? '').toString().toLowerCase();
      return desc.contains(t) || nome.contains(t) || email.contains(t);
    }).toList();
  }

  Color _corEvento(String tipo) {
    if (tipo.contains('login_sucesso') || tipo.endsWith('.ativar') || tipo.endsWith('.checkout')) {
      return Colors.green;
    }
    if (tipo.contains('login_falha') || tipo.endsWith('.cancelar') || tipo.endsWith('.excluir')) {
      return Colors.red;
    }
    if (tipo.endsWith('.desativar') || tipo.contains('senha') || tipo.contains('permissao')) {
      return Colors.orange;
    }
    if (tipo.endsWith('.agendar') || tipo.endsWith('.reagendar')) {
      return Colors.blue;
    }
    if (tipo.contains('prontuario')) {
      return Colors.cyan;
    }
    if (tipo.contains('criar') || tipo.contains('perfil') || tipo.contains('atualizar_perfil')) {
      return Colors.teal;
    }
    return Colors.purple;
  }

  IconData _iconeEvento(String tipo) {
    if (tipo.contains('login_sucesso')) return Icons.login_rounded;
    if (tipo.contains('login_falha')) return Icons.no_accounts_rounded;
    if (tipo.contains('logout')) return Icons.logout_rounded;
    if (tipo.contains('criar')) return Icons.person_add_rounded;
    if (tipo.endsWith('.desativar')) return Icons.lock_rounded;
    if (tipo.endsWith('.ativar')) return Icons.lock_open_rounded;
    if (tipo.endsWith('.excluir')) return Icons.delete_forever_rounded;
    if (tipo.contains('permissao')) return Icons.manage_accounts_rounded;
    if (tipo.contains('perfil') || tipo.contains('atualizar_perfil')) return Icons.edit_rounded;
    if (tipo.contains('senha')) return Icons.key_rounded;
    if (tipo.endsWith('.agendar')) return Icons.event_available_rounded;
    if (tipo.endsWith('.cancelar')) return Icons.event_busy_rounded;
    if (tipo.endsWith('.reagendar')) return Icons.event_repeat_rounded;
    if (tipo.endsWith('.checkout')) return Icons.flag_rounded;
    if (tipo.contains('prontuario')) return Icons.assignment_ind_rounded;
    return Icons.info_rounded;
  }

  String _formatarJson(dynamic json) {
    if (json == null) return '-';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (_) {
      return json.toString();
    }
  }

  String _formatarData(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsFiltrados = _logsFiltrados;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF4A148C),
            actions: [
              if (_isExporting)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  tooltip: 'Exportar CSV',
                  onPressed: _exportarCSV,
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _carregarLogs,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text('Log de Auditoria',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${logsFiltrados.length} evento(s) · clique em exportar para baixar CSV',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Filtros ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Busca por texto
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por usuário, e-mail ou descrição...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _termoBusca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _termoBusca = '';
                                  _searchController.clear();
                                });
                              })
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.divider)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.divider)),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                    onChanged: (v) => setState(() => _termoBusca = v),
                  ),
                  const SizedBox(height: 10),
                  // Filtros em linha
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Tipo de evento
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.divider),
                            borderRadius: BorderRadius.circular(8),
                            color: AppTheme.background,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filtroTipo ?? '',
                              hint: const Text('Tipo de evento',
                                  style: TextStyle(fontSize: 12)),
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textPrimary),
                              isDense: true,
                              onChanged: (v) {
                                setState(() => _filtroTipo = v);
                                _carregarLogs();
                              },
                              items: _tiposEvento.entries
                                  .map((e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Data início
                        _FiltroDataChip(
                          label: _filtroInicio != null
                              ? '${_filtroInicio!.day.toString().padLeft(2, '0')}/${_filtroInicio!.month.toString().padLeft(2, '0')}/${_filtroInicio!.year}'
                              : 'Data início',
                          icon: Icons.calendar_today_rounded,
                          onTap: () => _selecionarData(true),
                          selecionado: _filtroInicio != null,
                        ),
                        const SizedBox(width: 8),
                        // Data fim
                        _FiltroDataChip(
                          label: _filtroFim != null
                              ? '${_filtroFim!.day.toString().padLeft(2, '0')}/${_filtroFim!.month.toString().padLeft(2, '0')}/${_filtroFim!.year}'
                              : 'Data fim',
                          icon: Icons.calendar_today_rounded,
                          onTap: () => _selecionarData(false),
                          selecionado: _filtroFim != null,
                        ),
                        if (_filtroTipo != null ||
                            _filtroInicio != null ||
                            _filtroFim != null) ...[
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _limparFiltros,
                            icon: const Icon(Icons.filter_list_off_rounded,
                                size: 14),
                            label: const Text('Limpar',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lista de logs ────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF7B1FA2))),
            )
          else if (logsFiltrados.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 48,
                        color: AppTheme.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('Nenhum evento encontrado.',
                        style: TextStyle(
                            color: AppTheme.textHint, fontSize: 14)),
                    if (_filtroTipo != null ||
                        _filtroInicio != null ||
                        _filtroFim != null)
                      TextButton(
                          onPressed: _limparFiltros,
                          child: const Text('Limpar filtros')),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= logsFiltrados.length) return null;
                    final log = logsFiltrados[index];
                    final tipo =
                        (log['tipo_evento'] as String? ?? '').toLowerCase();
                    final desc = log['descricao'] as String? ?? '';
                    final createdAt = log['created_at'] as String?;
                    final usuario = log['usuario'];
                    final nomeUsuario =
                        usuario?['nome'] as String? ?? 'Sistema';
                    final emailUsuario = usuario?['email'] as String? ?? '';
                    final cor = _corEvento(tipo);
                    final icone = _iconeEvento(tipo);
                    final extras = log['dados_extras'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: cor.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: ExpansionTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icone, color: cor, size: 18),
                        ),
                        title: Text(
                          desc,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3, right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _tiposEvento[tipo] ?? tipo,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: cor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatarData(createdAt),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 12),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(
                              height: 1, color: AppTheme.divider),
                          const SizedBox(height: 10),
                          _DetalheRow(label: 'Usuário', value: nomeUsuario),
                          if (emailUsuario.isNotEmpty)
                            _DetalheRow(label: 'E-mail', value: emailUsuario),
                          _DetalheRow(label: 'Data/Hora', value: _formatarData(createdAt)),
                          _DetalheRow(label: 'Tipo', value: tipo),
                          _DetalheRow(label: 'Severidade', value: log['severidade'] ?? 'INFO'),
                          if (log['ip_address'] != null)
                            _DetalheRow(label: 'IP', value: log['ip_address'] as String),
                          if (log['user_agent'] != null)
                            _DetalheRow(label: 'Dispositivo/Browser', value: log['user_agent'] as String),
                          if (log['session_id'] != null)
                            _DetalheRow(label: 'ID da Sessão', value: log['session_id'] as String),
                          if (log['entidade_afetada'] != null)
                            _DetalheRow(
                              label: 'Entidade Afetada', 
                              value: '${log['entidade_afetada']} (ID: ${log['id_entidade_afetada'] ?? '-'})'
                            ),
                          if (extras != null && extras.toString() != '{}')
                            _DetalheRow(label: 'Dados extras', value: _formatarJson(extras)),
                          if (log['estado_anterior'] != null && log['estado_anterior'].toString() != '{}')
                            _DetalheRow(label: 'Estado Anterior', value: _formatarJson(log['estado_anterior'])),
                          if (log['estado_posterior'] != null && log['estado_posterior'].toString() != '{}')
                            _DetalheRow(label: 'Estado Posterior', value: _formatarJson(log['estado_posterior'])),
                          if (log['hash_assinatura'] != null)
                            _DetalheRow(
                              label: 'Assinatura (Imutável)', 
                              value: log['hash_assinatura'] as String,
                              isCode: true,
                            ),
                        ],
                      ),
                    );
                  },
                  childCount: logsFiltrados.length,
                ),
              ),
            ),

          // ── Paginação ────────────────────────────────────────────────────
          if (!_isLoading && _logs.length == _porPagina)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _pagina++);
                    _carregarLogs(resetPagina: false);
                  },
                  icon: const Icon(Icons.expand_more_rounded),
                  label: const Text('Carregar mais eventos'),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _FiltroDataChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selecionado;

  const _FiltroDataChip({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.selecionado,
  });

  @override
  Widget build(BuildContext context) {
    const cor = Color(0xFF7B1FA2);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? cor.withValues(alpha: 0.08) : AppTheme.background,
          border: Border.all(
              color: selecionado ? cor : AppTheme.divider,
              width: selecionado ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: selecionado ? cor : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: selecionado ? cor : AppTheme.textSecondary,
                  fontWeight:
                      selecionado ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetalheRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;

  const _DetalheRow({required this.label, required this.value, this.isCode = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 11, 
                  color: isCode ? Colors.grey[700] : AppTheme.textPrimary,
                  fontFamily: isCode ? 'Courier' : null,
                  fontWeight: isCode ? FontWeight.bold : null),
            ),
          ),
        ],
      ),
    );
  }
}
