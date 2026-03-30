/// supabase_service.dart  (antigo api_service.dart)
/// ServiÃ§o de comunicaÃ§Ã£o com o Supabase â€” +FÃ­sio +SaÃºde
///
/// Substitui completamente a camada Node.js (localhost:3000).
/// Usa o Supabase Auth SDK para login, registro e recuperaÃ§Ã£o de senha.
/// Os dados de paciente/profissional sÃ£o gravados diretamente nas tabelas.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Acesso global ao cliente Supabase (apÃ³s Supabase.initialize)
SupabaseClient get _sb => Supabase.instance.client;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // â”€â”€â”€ SessÃ£o atual â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Retorna o usuÃ¡rio autenticado atual, ou null se nÃ£o logado.
  User? get currentUser => _sb.auth.currentUser;

  /// Stream que emite eventos de mudanÃ§a de autenticaÃ§Ã£o.
  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;

  // â”€â”€â”€ Auth: Login â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        return {'success': false, 'message': 'Credenciais invÃ¡lidas.'};
      }

      // Busca o tipo de usuÃ¡rio na tabela login
      final loginData = await _sb
          .from('login')
          .select(
              'tipo_usuario, id_paciente, id_profissional, id_administrador')
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
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Registro de Paciente â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Registra paciente no Supabase Auth e grava dados na tabela `paciente`.
  Future<Map<String, dynamic>> registerPatient(
      Map<String, dynamic> data) async {
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
        return {'success': false, 'message': 'NÃ£o foi possÃ­vel criar a conta.'};
      }

      // 2. Gravar dados na tabela paciente
      final pacienteResp = await _sb
          .from('paciente')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'rg': (data['rg'] as String).trim(),
            'data_nasc': (data['dataNascimento'] as String).split('/').reversed.join('-'),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': data['genero'],
            'ativo': true,
          })
          .select()
          .single();

      // 3. Criar vÃ­nculo na tabela login
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
        return {'success': false, 'message': 'E-mail ou CPF jÃ¡ cadastrado.'};
      }
      return {
        'success': false,
        'message': 'Erro ao salvar dados. Tente novamente.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Registro de Profissional â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Registra profissional no Auth e grava dados na tabela `profissional`.
  /// O profissional Ã© ativado imediatamente (sem aprovaÃ§Ã£o de administrador).
  Future<Map<String, dynamic>> registerProfessional(
      Map<String, dynamic> data) async {
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
        return {'success': false, 'message': 'NÃ£o foi possÃ­vel criar a conta.'};
      }

      // 2. Gravar dados na tabela profissional (ativo imediatamente)
      final profResp = await _sb
          .from('profissional')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'crefito': (data['crefito'] as String).trim(),
            'especialidade': (data['especializacao'] as String).trim(),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'ativo': true, // Ativado automaticamente â€” sem aprovaÃ§Ã£o
          })
          .select()
          .single();

      // 3. Criar vÃ­nculo na tabela login
      await _sb.from('login').insert({
        'supabase_user_id': user.id,
        'email': email,
        'tipo_usuario': 'Profissional',
        'id_profissional': profResp['id'],
      });

      return {
        'success': true,
        'message': 'Cadastro realizado com sucesso! VocÃª jÃ¡ pode fazer login.',
        'profissional_id': profResp['id'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return {'success': false, 'message': 'E-mail ou CPF jÃ¡ cadastrado.'};
      }
      return {
        'success': false,
        'message': 'Erro ao salvar dados. Tente novamente.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Esqueci Minha Senha â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Envia e-mail real de recuperaÃ§Ã£o de senha via Supabase.
  /// O link no e-mail redireciona para a tela de redefiniÃ§Ã£o de senha do app.
  Future<Map<String, dynamic>> forgotPassword(String email,
      {String? redirectTo}) async {
    try {
      await _sb.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: redirectTo,
      );
      return {
        'success': true,
        'message':
            'Se este e-mail estiver cadastrado, vocÃª receberÃ¡ as instruÃ§Ãµes em breve.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Verificar CÃ³digo OTP (Passo 2) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Verifica o token OTP enviado por e-mail pelo Supabase.
  Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    try {
      final response = await _sb.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.recovery,
      );
      if (response.user != null) {
        return {'success': true, 'message': 'CÃ³digo verificado com sucesso!'};
      }
      return {'success': false, 'message': 'CÃ³digo invÃ¡lido ou expirado.'};
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Redefinir Senha (Passo 3) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Atualiza a senha do usuÃ¡rio apÃ³s OTP verificado.
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String novaSenha,
    required String confirmarSenha,
  }) async {
    if (novaSenha != confirmarSenha) {
      return {'success': false, 'message': 'As senhas nÃ£o coincidem.'};
    }
    if (novaSenha.length < 6) {
      return {
        'success': false,
        'message': 'A senha deve ter no mÃ­nimo 6 caracteres.'
      };
    }
    try {
      final response = await _sb.auth.updateUser(
        UserAttributes(password: novaSenha),
      );
      if (response.user != null) {
        return {'success': true, 'message': 'Senha redefinida com sucesso!'};
      }
      return {
        'success': false,
        'message': 'NÃ£o foi possÃ­vel redefinir a senha.'
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexÃ£o. Verifique sua internet.'
      };
    }
  }

  // â”€â”€â”€ Auth: Logout â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> logout() async {
    await _sb.auth.signOut();
  }

  // â”€â”€â”€ Paciente: Perfil â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Busca os dados completos do paciente pelo ID.
  Future<Map<String, dynamic>> getPaciente(String pacienteId) async {
    try {
      final data = await _sb
          .from('paciente')
          .select()
          .eq('id', pacienteId)
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  /// Atualiza os dados editÃ¡veis do paciente.
  Future<Map<String, dynamic>> updatePaciente(
      String pacienteId, Map<String, dynamic> dados) async {
    try {
      final data = await _sb
          .from('paciente')
          .update(dados)
          .eq('id', pacienteId)
          .select()
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  // â”€â”€â”€ Paciente: Sintomas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Registra um novo sintoma do paciente.
  Future<Map<String, dynamic>> registrarSintoma(
      Map<String, dynamic> dados) async {
    try {
      final data = await _sb
          .from('registro_sintomas')
          .insert(dados)
          .select()
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  /// Busca o histÃ³rico de sintomas de um paciente, do mais recente ao mais antigo.
  Future<Map<String, dynamic>> getSintomas(String pacienteId) async {
    try {
      final data = await _sb
          .from('registro_sintomas')
          .select()
          .eq('id_paciente', pacienteId)
          .order('data_hora', ascending: false)
          .limit(50);
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  // â”€â”€â”€ Profissionais: Busca â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Lista todos os profissionais ativos para busca pelo paciente.
  Future<Map<String, dynamic>> getProfissionais({String? termoBusca}) async {
    try {
      var query = _sb
          .from('profissional')
          .select('id, nome, especialidade, crefito, telefone')
          .eq('ativo', true)
          .order('nome');

      final data = await query;

      // Filtro local por termo (nome ou especialidade)
      if (termoBusca != null && termoBusca.trim().isNotEmpty) {
        final termo = termoBusca.trim().toLowerCase();
        final filtrado = (data as List).where((p) {
          final nome = (p['nome'] as String? ?? '').toLowerCase();
          final esp = (p['especialidade'] as String? ?? '').toLowerCase();
          return nome.contains(termo) || esp.contains(termo);
        }).toList();
        return {'success': true, 'data': filtrado};
      }

      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  // â”€â”€â”€ Paciente: Consultas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Busca as consultas do paciente com dados do profissional.
  Future<Map<String, dynamic>> getConsultas(String pacienteId) async {
    try {
      final data = await _sb
          .from('consulta')
          .select('*, profissional(nome, especialidade)')
          .eq('id_paciente', pacienteId)
          .order('data_hora', ascending: false)
          .limit(20);
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexÃ£o.'};
    }
  }

  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Traduz mensagens de erro do Supabase Auth para portuguÃªs.
  String _traduzirErroAuth(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Confirme seu e-mail antes de fazer login.';
    }
    if (message.contains('User already registered')) {
      return 'Este e-mail jÃ¡ estÃ¡ cadastrado.';
    }
    if (message.contains('Password should be at least')) {
      return 'A senha deve ter no mÃ­nimo 6 caracteres.';
    }
    if (message.contains('rate limit') ||
        message.contains('only request this after')) {
      // Extrai o nÃºmero de segundos da mensagem se disponÃ­vel
      final match = RegExp(r'after (\d+) seconds').firstMatch(message);
      if (match != null) {
        return 'Por seguranÃ§a, aguarde ${match.group(1)} segundos antes de tentar novamente.';
      }
      return 'Muitas tentativas. Aguarde um momento e tente novamente.';
    }
    if (message.contains('Token has expired')) {
      return 'CÃ³digo expirado. Solicite um novo.';
    }
    if (message.contains('otp_expired') || message.contains('invalid')) {
      return 'CÃ³digo invÃ¡lido ou expirado.';
    }
    return 'Erro: $message';
  }
}
