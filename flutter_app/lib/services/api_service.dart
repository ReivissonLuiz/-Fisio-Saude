/// supabase_service.dart  (antigo api_service.dart)
/// Serviço de comunicação com o Supabase — +Fisio +Saúde
///
/// Substitui completamente a camada Node.js (localhost:3000).
/// Usa o Supabase Auth SDK para login, registro e recuperação de senha.
/// Os dados de paciente/profissional são gravados diretamente nas tabelas.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Acesso global ao cliente Supabase (após Supabase.initialize)
SupabaseClient get _sb => Supabase.instance.client;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- Sessão atual ---------------------------------------------------------

  /// Retorna o usuário autenticado atual, ou null se Não logado.
  User? get currentUser => _sb.auth.currentUser;

  /// Stream que emite eventos de mudança de autenticação.
  Stream<AuthState> get authStateChanges => _sb.auth.onAuthStateChange;

  // --- Auth: Login ----------------------------------------------------------

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
          'id_administrador': loginData?['id_administrador'],
        },
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Registro de Paciente -------------------------------------------

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
        return {'success': false, 'message': 'Não foi possível criar a conta.'};
      }

      // 2. Gravar dados na tabela paciente
      final pacienteResp = await _sb
          .from('paciente')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'data_nasc': (data['dataNascimento'] as String).split('/').reversed.join('-'),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': data['genero'],
            'ativo': true,
          })
          .select()
          .single();

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
      return {
        'success': false,
        'message': 'Erro ao salvar dados. Tente novamente.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Registro de Profissional ---------------------------------------

  /// Registra profissional no Auth e grava dados na tabela `profissional`.
  /// O profissional é ativado imediatamente (sem aprovação de administrador).
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
        return {'success': false, 'message': 'Não foi possível criar a conta.'};
      }

      // 2. Gravar dados na tabela profissional
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
            'ativo': true,
          })
          .select()
          .single();

      // 3. Profissional também é Paciente: Criar registro na tabela paciente
      // Usamos dados padrão ou fornecidos (se adicionarmos campos na tela)
      final pacienteResp = await _sb
          .from('paciente')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'data_nasc': data['dataNasc'] ?? '1990-01-01', // Valor padrão
            'telefone': (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': data['genero'] ?? 'Não informado',
            'ativo': true,
          })
          .select()
          .single();

      // 4. Criar vínculo na tabela login (conectando ambos os IDs)
      await _sb.from('login').insert({
        'supabase_user_id': user.id,
        'email': email,
        'tipo_usuario': 'Profissional',
        'id_profissional': profResp['id'],
        'id_paciente': pacienteResp['id'],
      });

      return {
        'success': true,
        'message': 'Cadastro realizado com sucesso! Você já pode fazer login.',
        'profissional_id': profResp['id'],
        'paciente_id': pacienteResp['id'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return {'success': false, 'message': 'E-mail ou CPF já cadastrado.'};
      }
      return {
        'success': false,
        'message': 'Erro ao salvar dados. Tente novamente.'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Registro de Administrador -------------------------------------

  /// Registra administrador no Auth e grava dados na tabela `administrador`.
  Future<Map<String, dynamic>> registerAdmin(Map<String, dynamic> data) async {
    try {
      final email = (data['email'] as String).trim().toLowerCase();
      final senha = data['senha'] as String;

      // 1. Criar conta no Auth
      final response = await _sb.auth.signUp(
        email: email,
        password: senha,
        data: {'nome': data['nome'], 'tipo': 'Administrador'},
      );

      final user = response.user;
      if (user == null) {
        return {'success': false, 'message': 'Não foi possível criar a conta.'};
      }

      // 2. Gravar dados na tabela administrador
      final admResp = await _sb
          .from('administrador')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'cargo': data['cargo'] ?? 'Diretor',
            'ativo': true,
          })
          .select()
          .single();

      // 3. Criar vínculo na tabela login
      await _sb.from('login').insert({
        'supabase_user_id': user.id,
        'email': email,
        'tipo_usuario': 'Administrador',
        'id_administrador': admResp['id'],
      });

      return {
        'success': true,
        'message': 'Administrador cadastrado com sucesso!',
        'id_administrador': admResp['id'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return {'success': false, 'message': 'E-mail ou CPF já cadastrado.'};
      }
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // --- Auth: Esqueci Minha Senha --------------------------------------------

  /// Envia e-mail real de recuperação de senha via Supabase.
  /// O link no e-mail redireciona para a tela de redefinição de senha do app.
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
            'Se este e-mail estiver cadastrado, você receberá as instruções em breve.',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Verificar Código OTP (Passo 2) ---------------------------------

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
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Redefinir Senha (Passo 3) --------------------------------------

  /// Atualiza a senha do usuário após OTP verificado.
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String novaSenha,
    required String confirmarSenha,
  }) async {
    if (novaSenha != confirmarSenha) {
      return {'success': false, 'message': 'As senhas Não coincidem.'};
    }
    if (novaSenha.length < 6) {
      return {
        'success': false,
        'message': 'A senha deve ter no mínimo 6 caracteres.'
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
        'message': 'Não foi possível redefinir a senha.'
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Logout ---------------------------------------------------------

  Future<void> logout() async {
    await _sb.auth.signOut();
  }

  // --- Paciente: Perfil -----------------------------------------------------

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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Atualiza os dados editáveis do paciente.
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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Paciente: Sintomas ---------------------------------------------------

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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Busca o histórico de sintomas de um paciente, do mais recente ao mais antigo.
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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Profissionais: Busca -------------------------------------------------

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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Paciente: Consultas --------------------------------------------------

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
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Profissional: Perfil --------------------------------------------------

  /// Busca os dados completos do profissional pelo ID.
  Future<Map<String, dynamic>> getProfissional(String profissionalId) async {
    try {
      final data = await _sb
          .from('profissional')
          .select()
          .eq('id', profissionalId)
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Atualiza os dados editáveis do profissional.
  Future<Map<String, dynamic>> updateProfissional(
      String profissionalId, Map<String, dynamic> dados) async {
    try {
      final data = await _sb
          .from('profissional')
          .update(dados)
          .eq('id', profissionalId)
          .select()
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Profissional: Consultas e Pacientes -----------------------------------

  /// Busca as consultas do profissional com dados do paciente.
  Future<Map<String, dynamic>> getConsultasProfissional(String profissionalId) async {
    try {
      final data = await _sb
          .from('consulta')
          .select('*, paciente(nome, email, telefone, data_nasc, genero)')
          .eq('id_profissional', profissionalId)
          .order('data_hora', ascending: true);
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Busca a lista única de pacientes que já tiveram consulta com este profissional.
  Future<Map<String, dynamic>> getPacientesDoProfissional(String profissionalId) async {
    try {
      // 1. Busca todas as consultas do profissional
      final consultas = await _sb
          .from('consulta')
          .select('id_paciente, paciente(id, nome, email, telefone, cpf, data_nasc)')
          .eq('id_profissional', profissionalId);
      
      // 2. Filtra para obter pacientes únicos
      final Map<String, dynamic> pacientesUnicos = {};
      for (var item in (consultas as List)) {
        final pac = item['paciente'];
        if (pac != null && !pacientesUnicos.containsKey(pac['id'])) {
          pacientesUnicos[pac['id']] = pac;
        }
      }

      return {'success': true, 'data': pacientesUnicos.values.toList()};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Administrador: Gestão --------------------------------------------------

  /// Busca todos os pacientes para o painel ADM.
  Future<Map<String, dynamic>> getAllPacientes() async {
    try {
      final res = await _sb.from('paciente').select().eq('ativo', true).order('nome');
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar pacientes.'};
    }
  }

  /// Busca todos os profissionais para o painel ADM.
  Future<Map<String, dynamic>> getAllProfissionais() async {
    try {
      final res = await _sb.from('profissional').select().eq('ativo', true).order('nome');
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar profissionais.'};
    }
  }

  /// Busca todas as consultas para o painel ADM.
  Future<Map<String, dynamic>> getAllConsultas() async {
    try {
      final res = await _sb.from('consulta').select().order('data_hora');
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar consultas globais.'};
    }
  }

  /// Busca todos os sintomas globais para BI ADM.
  Future<Map<String, dynamic>> getAllSintomasGlobais() async {
    try {
      final res = await _sb.from('registro_sintomas').select().order('data_hora', ascending: false);
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar sintomas globais.'};
    }
  }

  /// Remove (ou desativa) um registro de qualquer tabela.
  /// Implementamos soft-delete para evitar conflitos de Foreign Keys (400 Bad Request).
  Future<Map<String, dynamic>> deleteRecord(String table, String id) async {
    try {
      await _sb.from(table).update({'ativo': false}).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao desativar registro.'};
    }
  }

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
    if (message.contains('rate limit') ||
        message.contains('only request this after')) {
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




