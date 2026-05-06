/// chat_screen.dart
/// Tela de chat entre profissional e paciente — +Físio +Saúde
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String meuId;
  final String meuNome;
  final String? meuAvatar;
  final String outroId;
  final String outroNome;
  final String? outroAvatar;

  const ChatScreen({
    super.key,
    required this.meuId,
    required this.meuNome,
    this.meuAvatar,
    required this.outroId,
    required this.outroNome,
    this.outroAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> _mensagens = [];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregarMensagens();
    _assinarRealtime();
  }

  Future<void> _carregarMensagens() async {
    final res = await _api.getMensagens(
      usuarioAId: widget.meuId,
      usuarioBId: widget.outroId,
    );
    if (res['success'] == true && mounted) {
      setState(() {
        _mensagens = List<Map<String, dynamic>>.from(res['data'] as List);
      });
      _scrollToBottom();
    }
    // Marcar mensagens do outro como lidas
    await _api.marcarMensagensLidas(
      remetenteId: widget.outroId,
      destinatarioId: widget.meuId,
    );
  }

  void _assinarRealtime() {
    _sub = _api
        .streamMensagens(
          usuarioAId: widget.meuId,
          usuarioBId: widget.outroId,
        )
        .listen((msgs) {
      if (mounted) {
        setState(() => _mensagens = msgs);
        _scrollToBottom();
        // Marcar como lidas
        _api.marcarMensagensLidas(
          remetenteId: widget.outroId,
          destinatarioId: widget.meuId,
        );
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _ctrl.clear();

    final result = await _api.enviarMensagem(
      remetenteId: widget.meuId,
      destinatarioId: widget.outroId,
      conteudo: texto,
    );

    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _mensagens.add(result['data'] as Map<String, dynamic>);
        });
        _scrollToBottom();
      }
      setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 40,
        title: Row(
          children: [
            UserAvatar(
              nome: widget.outroNome,
              avatarUrl: widget.outroAvatar,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Text(
              widget.outroNome,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _mensagens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: AppTheme.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Inicie uma conversa com\n${widget.outroNome}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    itemCount: _mensagens.length,
                    itemBuilder: (_, i) {
                      final msg = _mensagens[i];
                      final ehMeu = msg['id_remetente'] == widget.meuId;
                      return _BubbleMensagem(
                        conteudo: msg['conteudo'] as String? ?? '',
                        ehMeu: ehMeu,
                        hora: msg['created_at'] as String? ?? '',
                        meuNome: widget.meuNome,
                        outroNome: widget.outroNome,
                        meuAvatar: widget.meuAvatar,
                        outroAvatar: widget.outroAvatar,
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _ctrl,
            enviando: _enviando,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

// ─── Bolha de mensagem ────────────────────────────────────────────────────────

class _BubbleMensagem extends StatelessWidget {
  final String conteudo;
  final bool ehMeu;
  final String hora;
  final String meuNome;
  final String outroNome;
  final String? meuAvatar;
  final String? outroAvatar;

  const _BubbleMensagem({
    required this.conteudo,
    required this.ehMeu,
    required this.hora,
    required this.meuNome,
    required this.outroNome,
    this.meuAvatar,
    this.outroAvatar,
  });

  String _formatarHora(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            ehMeu ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!ehMeu) ...[
            UserAvatar(
              nome: outroNome,
              avatarUrl: outroAvatar,
              radius: 14,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ehMeu ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      ehMeu ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      ehMeu ? Radius.zero : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
                border: ehMeu
                    ? null
                    : Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    conteudo,
                    style: TextStyle(
                      color: ehMeu ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatarHora(hora),
                    style: TextStyle(
                      fontSize: 10,
                      color: ehMeu
                          ? Colors.white60
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ehMeu) ...[
            const SizedBox(width: 6),
            UserAvatar(
              nome: meuNome,
              avatarUrl: meuAvatar,
              radius: 14,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Barra de input ───────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onEnviar;

  const _InputBar({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onEnviar(),
              decoration: InputDecoration(
                hintText: 'Digite uma mensagem...',
                hintStyle:
                    const TextStyle(color: AppTheme.textHint, fontSize: 14),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton.small(
              onPressed: enviando ? null : onEnviar,
              backgroundColor:
                  enviando ? AppTheme.textHint : AppTheme.primary,
              elevation: 0,
              child: enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
