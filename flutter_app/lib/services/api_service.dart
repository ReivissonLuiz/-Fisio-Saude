/// api_service.dart
/// Serviço HTTP centralizado para comunicação com a API Node.js.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Configuração da URL base:
  // - Emulador Android: 10.0.2.2
  // - iOS/Web/Desktop: localhost
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Headers padrão para todas as requisições
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Headers com autenticação JWT
  Map<String, String> headersWithToken(String token) => {
    ..._headers,
    'Authorization': 'Bearer $token',
  };

  // ─── Auth: Login ───────────────────────────────────────────────────────────

  /// Realiza login e retorna { success, token, user, message }
  Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique se o servidor está rodando.'};
    }
  }

  // ─── Auth: Registro de Paciente ────────────────────────────────────────────

  Future<Map<String, dynamic>> registerPatient(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register/patient'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Registro de Profissional ───────────────────────────────────────

  Future<Map<String, dynamic>> registerProfessional(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register/professional'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Esqueci Minha Senha — Passo 1 ──────────────────────────────────

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/forgot-password'),
            headers: _headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Verificar Código — Passo 2 ─────────────────────────────────────

  Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/verify-code'),
            headers: _headers,
            body: jsonEncode({'email': email, 'code': code}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Redefinir Senha — Passo 3 ──────────────────────────────────────

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String novaSenha,
    required String confirmarSenha,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/reset-password'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'code': code,
              'novaSenha': novaSenha,
              'confirmarSenha': confirmarSenha,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
      return {'success': false, 'message': 'Resposta do servidor inválida.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }
}
