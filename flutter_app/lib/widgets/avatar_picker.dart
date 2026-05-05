/// avatar_picker.dart
/// Widget de avatar com botão de troca de foto — +Físio +Saúde
library;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class AvatarPicker extends StatefulWidget {
  final String usuarioId;
  final String? avatarUrl;
  final String nome;
  final double radius;
  final Color accentColor;
  final void Function(String newUrl)? onUploaded;

  const AvatarPicker({
    super.key,
    required this.usuarioId,
    required this.nome,
    this.avatarUrl,
    this.radius = 44,
    this.accentColor = AppTheme.primary,
    this.onUploaded,
  });

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  final _api = ApiService();
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _localUrl;

  String? get _urlAtual => _localUrl ?? widget.avatarUrl;

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);

    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

    final res = await _api.uploadAvatar(
      usuarioId: widget.usuarioId,
      bytes: bytes,
      mimeType: mime,
      extensao: ext,
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    if (res['success'] == true) {
      final newUrl = res['url'] as String;
      setState(() => _localUrl = newUrl);
      widget.onUploaded?.call(newUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] as String? ?? 'Erro ao enviar foto.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _urlAtual;
    final inicial = widget.nome.isNotEmpty ? widget.nome[0].toUpperCase() : '?';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Avatar principal
        CircleAvatar(
          radius: widget.radius,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
          child: url == null || url.isEmpty
              ? Text(
                  inicial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.radius * 0.72,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        // Botão de câmera
        GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            width: widget.radius * 0.72,
            height: widget.radius * 0.72,
            decoration: BoxDecoration(
              color: widget.accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _uploading
                ? const Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: widget.radius * 0.38,
                  ),
          ),
        ),
      ],
    );
  }
}
