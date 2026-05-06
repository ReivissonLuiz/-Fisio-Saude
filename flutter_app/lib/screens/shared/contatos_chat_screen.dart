import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';

class ContatosChatScreen extends StatefulWidget {
  final String usuarioId;
  final String usuarioNome;
  final String? usuarioAvatar;

  const ContatosChatScreen({
    super.key,
    required this.usuarioId,
    required this.usuarioNome,
    this.usuarioAvatar,
  });

  @override
  State<ContatosChatScreen> createState() => _ContatosChatScreenState();
}

class _ContatosChatScreenState extends State<ContatosChatScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _contatos = [];

  @override
  void initState() {
    super.initState();
    _carregarContatos();
  }

  Future<void> _carregarContatos() async {
    setState(() => _isLoading = true);
    final res = await _api.getContatosChat(widget.usuarioId);
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _contatos = res['data'] as List;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mensagens'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contatos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 64, color: AppTheme.textHint),
                      SizedBox(height: 16),
                      Text('Nenhuma conversa encontrada.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregarContatos,
                  child: ListView.builder(
                    itemCount: _contatos.length,
                    itemBuilder: (context, index) {
                      final c = _contatos[index];
                      final nome = c['nome'] ?? 'Usuário';
                      final ultimaMsg = c['ultima_mensagem'] ?? '';
                      final naoLidas = c['nao_lidas'] ?? 0;
                      final dt = c['data_hora'] as DateTime?;
                      final avatarUrl = c['avatar_url'] as String?;
                      
                      String timeStr = '';
                      if (dt != null) {
                        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        if (dt.day != DateTime.now().day) {
                          timeStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
                        }
                      }

                      return ListTile(
                        tileColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(nome.isNotEmpty ? nome[0].toUpperCase() : 'U', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                        subtitle: Text(ultimaMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: naoLidas > 0 ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: naoLidas > 0 ? FontWeight.bold : FontWeight.normal)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                            const SizedBox(height: 6),
                            if (naoLidas > 0)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                                child: Text(naoLidas.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                meuId: widget.usuarioId,
                                meuNome: widget.usuarioNome,
                                meuAvatar: widget.usuarioAvatar,
                                outroId: c['id'],
                                outroNome: nome,
                              ),
                            ),
                          );
                          _carregarContatos();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
