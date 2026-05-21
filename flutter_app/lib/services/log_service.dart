/// log_service.dart
/// Serviço simplificado de sessão do +Físio +Saúde.
/// Mantém compatibilidade com a inicialização do usuário.
library;

import 'audit_service.dart';

class LogService {
  static final LogService instance = LogService._();
  LogService._();

  String? _usuarioId;

  /// Define o ID do usuário logado. Chamar após login bem-sucedido.
  void setUsuario(String? id) {
    _usuarioId = id;
    AuditService.instance.setUsuario(id);
  }

  String? get usuarioId => _usuarioId;
}
