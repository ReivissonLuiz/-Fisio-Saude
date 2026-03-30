/// supabase_service.dart  (antigo api_service.dart)
/// Serviço de comunicação com o Supabase — +Físio +Saúde
///
/// Substitui completamente a camada Node.js (localhost:3000).
/// Usa o Supabase Auth SDK para login, registro e recuperação de senha.
/// Os dados de paciente/profissional são gravados diretamente nas tabelas.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Acesso global ao cliente Supabase (após Supabase.initialize)
SupabaseClient get _sb => Supabase.instance.client;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ─── Sessão atual ─────────────────────────────────────────────────────────

  /// Retorna o usuário autenticado atual, ou null se não logado.
  User? get currentUser => _sb.auth.currentUser;

  /// Stream que emite eventos de mudança de autenticação.
  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;

  // ─── Auth: Login ──────────────────────────────────────────────────────────

  /// Realiza login com e-mail e senha via Supabase Auth.
  /// Retorna { success, user, token, tipo, message }
  Future<Map<String, dynamic>> login(String email, String senha) async {
    try {
      final response = await _sb.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: senha,
      );

      final user = response.user;
      final session = response.session;

      if (user == null) {
        return {'success': false, 'message': 'Credenciais inválidas.'};
      }

      // Busca o tipo de usuário na tabela login
      final loginData = await _sb
          .from('login')
          .select('tipo_usuario, id_paciente, id_profissional, id_administrador')
          .eq('supabase_user_id', user.id)
          .maybeSingle();

      return {
        'success': true,
        'message': 'Login realizado com sucesso!',
        'token': session?.accessToken,
        'user': {
          'id': user.id,
          'email': user.email,
          'tipo': loginData?['tipo_usuario'] ?? 'Paciente',
          'id_paciente': loginData?['id_paciente'],
          'id_profissional': loginData?['id_profissional'],
        },
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Registro de Paciente ───────────────────────────────────────────

  /// Registra paciente no Supabase Auth e grava dados na tabela `paciente`.
  Future<Map<String, dynamic>> registerPatient(Map<String, dynamic> data) async {
    try {
      final email = (data['email'] as String).trim().toLowerCase();
      final senha = data['senha'] as String;

      // 1. Criar conta no Supabase Auth
      final response = await _sb.auth.signUp(
        email: email,
        password: senha,
        data: {'nome': data['nome'], 'tipo': 'Paciente'},
      );

      final user = response.user;
      if (user == null) {
        return {'success': false, 'message': 'Não foi possível criar a conta.'};
      }

      // 2. Gravar dados na tabela paciente
      final pacienteResp = await _sb.from('paciente').insert({
        'nome': (data['nome'] as String).trim(),
        'email': email,
        'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
        'data_nasc': data['dataNascimento'],
        'telefone': (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
        'genero': data['genero'],
        'ativo': true,
      }).select().single();

      // 3. Criar vínculo na tabela login
      await _sb.from('login').insert({
        'supabase_user_id': user.id,
        'email': email,
        'tipo_usuario': 'Paciente',
        'id_paciente': pacienteResp['id'],
      });

      return {
        'success': true,
        'message': 'Paciente cadastrado com sucesso!',
        'paciente_id': pacienteResp['id'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return {'success': false, 'message': 'E-mail ou CPF já cadastrado.'};
      }
      return {'success': false, 'message': 'Erro ao salvar dados. Tente novamente.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Registro de Profissional ───────────────────────────────────────

  /// Registra profissional no Auth e grava dados na tabela `profissional`.
  /// O profissional é criado com `ativo: false` — aguarda aprovação do admin.
  Future<Map<String, dynamic>> registerProfessional(Map<String, dynamic> data) async {
    try {
      final email = (data['email'] as String).trim().toLowerCase();
      final senha = data['senha'] as String;

      // 1. Criar conta no Auth
      final response = await _sb.auth.signUp(
        email: email,
        password: senha,
        data: {'nome': data['nome'], 'tipo': 'Profissional'},
      );

      final user = response.user;
      if (user == null) {
        return {'success': false, 'message': 'Não foi possível criar a conta.'};
      }

      // 2. Gravar dados na tabela profissional
      final profResp = await _sb.from('profissional').insert({
        'nome': (data['nome'] as String).trim(),
        'email': email,
        'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
        'crefito': (data['crefito'] as String).trim(),
        'especialidade': (data['especializacao'] as String).trim(),
        'telefone': (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
        'ativo': false, // Aguarda aprovação do administrador
      }).select().single();

      // 3. Criar vínculo na tabela login
      await _sb.from('login').insert({
        'supabase_user_id': user.id,
        'email': email,
        'tipo_usuario': 'Profissional',
        'id_profissional': profResp['id'],
      });

      return {
        'success': true,
        'message': 'Profissional cadastrado! Seu cadastro está em análise e será aprovado em breve.',
        'profissional_id': profResp['id'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return {'success': false, 'message': 'E-mail ou CPF já cadastrado.'};
      }
      return {'success': false, 'message': 'Erro ao salvar dados. Tente novamente.'};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Esqueci Minha Senha ────────────────────────────────────────────

  /// Envia e-mail real de recuperação de senha via Supabase.
  /// Não retorna mais _devCode — o usuário recebe o e-mail automaticamente.
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await _sb.auth.resetPasswordForEmail(email.trim().toLowerCase());
      return {
        'success': true,
        'message': 'Se este e-mail estiver cadastrado, você receberá as instruções em breve.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Verificar Código OTP (Passo 2) ─────────────────────────────────

  /// Verifica o token OTP enviado por e-mail pelo Supabase.
  Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    try {
      final response = await _sb.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.recovery,
      );
      if (response.user != null) {
        return {'success': true, 'message': 'Código verificado com sucesso!'};
      }
      return {'success': false, 'message': 'Código inválido ou expirado.'};
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Redefinir Senha (Passo 3) ──────────────────────────────────────

  /// Atualiza a senha do usuário após OTP verificado.
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String novaSenha,
    required String confirmarSenha,
  }) async {
    if (novaSenha != confirmarSenha) {
      return {'success': false, 'message': 'As senhas não coincidem.'};
    }
    if (novaSenha.length < 6) {
      return {'success': false, 'message': 'A senha deve ter no mínimo 6 caracteres.'};
    }
    try {
      final response = await _sb.auth.updateUser(
        UserAttributes(password: novaSenha),
      );
      if (response.user != null) {
        return {'success': true, 'message': 'Senha redefinida com sucesso!'};
      }
      return {'success': false, 'message': 'Não foi possível redefinir a senha.'};
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão. Verifique sua internet.'};
    }
  }

  // ─── Auth: Logout ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _sb.auth.signOut();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Traduz mensagens de erro do Supabase Auth para português.
  String _traduzirErroAuth(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Confirme seu e-mail antes de fazer login.';
    }
    if (message.contains('User already registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (message.contains('Password should be at least')) {
      return 'A senha deve ter no mínimo 6 caracteres.';
    }
    if (message.contains('rate limit') || message.contains('only request this after')) {
      // Extrai o número de segundos da mensagem se disponível
      final match = RegExp(r'after (\d+) seconds').firstMatch(message);
      if (match != null) {
        return 'Por segurança, aguarde ${match.group(1)} segundos antes de tentar novamente.';
      }
      return 'Muitas tentativas. Aguarde um momento e tente novamente.';
    }
    if (message.contains('Token has expired')) {
      return 'Código expirado. Solicite um novo.';
    }
    if (message.contains('otp_expired') || message.contains('invalid')) {
      return 'Código inválido ou expirado.';
    }
    return 'Erro: $message';
  }
}

