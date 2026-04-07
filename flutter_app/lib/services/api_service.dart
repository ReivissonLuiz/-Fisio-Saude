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

      // Se loginData for null (possível bloqueio RLS ou registro faltando),
      // tenta identificar o tipo pelo email nas tabelas correspondentes.
      String tipo = loginData?['tipo_usuario'] ?? '';
      String? idPaciente = loginData?['id_paciente']?.toString();
      String? idProfissional = loginData?['id_profissional']?.toString();
      String? idAdministrador = loginData?['id_administrador']?.toString();
      String nome = user.userMetadata?['nome'] as String? ?? '';

      if (tipo.isEmpty) {
        // Fallback: verifica a tabela administrador primeiro
        final admRow = await _sb
            .from('administrador')
            .select('id, nome')
            .eq('email', user.email!)
            .maybeSingle();
        if (admRow != null) {
          tipo = 'Administrador';
          idAdministrador = admRow['id']?.toString();
          nome = admRow['nome'] as String? ?? nome;
        } else {
          // Verifica profissional
          final profRow = await _sb
              .from('profissional')
              .select('id, nome')
              .eq('email', user.email!)
              .maybeSingle();
          if (profRow != null) {
            tipo = 'Profissional';
            idProfissional = profRow['id']?.toString();
            nome = profRow['nome'] as String? ?? nome;
            // Verifica se tem paciente vinculado
            final pacRow = await _sb
                .from('paciente')
                .select('id')
                .eq('email', user.email!)
                .maybeSingle();
            idPaciente = pacRow?['id']?.toString();
          } else {
            // Verifica paciente
            final pacRow = await _sb
                .from('paciente')
                .select('id, nome')
                .eq('email', user.email!)
                .maybeSingle();
            tipo = 'Paciente';
            idPaciente = pacRow?['id']?.toString();
            nome = pacRow?['nome'] as String? ?? nome;
          }
        }
      } else {
        // loginData existe — busca o nome da tabela correspondente
        if (tipo == 'Administrador' && idAdministrador != null) {
          final admRow = await _sb
              .from('administrador')
              .select('nome')
              .eq('id', idAdministrador)
              .maybeSingle();
          nome = admRow?['nome'] as String? ?? nome;
        } else if (tipo == 'Profissional' && idProfissional != null) {
          final profRow = await _sb
              .from('profissional')
              .select('nome')
              .eq('id', idProfissional)
              .maybeSingle();
          nome = profRow?['nome'] as String? ?? nome;
        } else if (idPaciente != null) {
          final pacRow = await _sb
              .from('paciente')
              .select('nome')
              .eq('id', idPaciente)
              .maybeSingle();
          nome = pacRow?['nome'] as String? ?? nome;
        }
      }

      return {
        'success': true,
        'message': 'Login realizado com sucesso!',
        'token': session?.accessToken,
        'user': {
          'id': user.id,
          'email': user.email,
          'nome': nome,
          'tipo': tipo.isEmpty ? 'Paciente' : tipo,
          'id_paciente': idPaciente,
          'id_profissional': idProfissional,
          'id_administrador': idAdministrador,
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
        emailRedirectTo: 'https://reivissonluiz.github.io/-Fisio-Saude/',
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
        emailRedirectTo: 'https://reivissonluiz.github.io/-Fisio-Saude/',
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
      // Usa dados_nasc e genero coletados no formulário
      final String dataNascRaw = data['dataNascimento'] as String? ?? '';
      String dataNascFormatted = '1990-01-01';
      if (dataNascRaw.length == 10 && dataNascRaw.contains('/')) {
        dataNascFormatted = dataNascRaw.split('/').reversed.join('-');
      } else if (dataNascRaw.length == 10 && dataNascRaw.contains('-')) {
        dataNascFormatted = dataNascRaw;
      }

      final pacienteResp = await _sb
          .from('paciente')
          .insert({
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String).replaceAll(RegExp(r'\D'), ''),
            'data_nasc': dataNascFormatted,
            'telefone': (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': (data['genero'] as String?)?.isNotEmpty == true
                ? data['genero']
                : 'Não informado',
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
    if (pacienteId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
    if (pacienteId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
    if (pacienteId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
    if (profissionalId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
    if (profissionalId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
    if (profissionalId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
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
  Future<Map<String, dynamic>> getAllPacientes({bool filterAtivo = true}) async {
    try {
      var query = _sb.from('paciente').select();
      if (filterAtivo) {
         query = query.eq('ativo', true);
      }
      final res = await query.order('nome');
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar pacientes.'};
    }
  }

  /// Busca todos os profissionais para o painel ADM.
  Future<Map<String, dynamic>> getAllProfissionais({bool filterAtivo = true}) async {
    try {
      var query = _sb.from('profissional').select();
      if (filterAtivo) {
        query = query.eq('ativo', true);
      }
      final res = await query.order('nome');
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

  // --- Gestão de Papéis (Roles) -------------------------------------------

  /// Adiciona o papel de Paciente a um usuário existente (ADM ou Profissional).
  /// Cria registro na tabela `paciente` e atualiza `login` com o id_paciente.
  Future<Map<String, dynamic>> addPacienteRole({
    required String supabaseUserId,
    required String nome,
    required String email,
    required String cpf,
    required String dataNascimento,
    required String genero,
    String? telefone,
  }) async {
    try {
      // Verifica se já existe
      final existing = await _sb
          .from('paciente')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (existing != null) {
        // Já existe — apenas vincula
        await _sb
            .from('login')
            .update({'id_paciente': existing['id']})
            .eq('supabase_user_id', supabaseUserId);
        return {'success': true, 'id_paciente': existing['id'].toString()};
      }

      String dataNascFormatted = dataNascimento;
      if (dataNascimento.contains('/')) {
        dataNascFormatted = dataNascimento.split('/').reversed.join('-');
      }

      final pacResp = await _sb
          .from('paciente')
          .insert({
            'nome': nome.trim(),
            'email': email,
            'cpf': cpf.replaceAll(RegExp(r'\D'), ''),
            'data_nasc': dataNascFormatted,
            'telefone': telefone?.replaceAll(RegExp(r'\D'), ''),
            'genero': genero.isNotEmpty ? genero : 'Não informado',
            'ativo': true,
          })
          .select()
          .single();

      await _sb
          .from('login')
          .update({'id_paciente': pacResp['id']})
          .eq('supabase_user_id', supabaseUserId);

      return {'success': true, 'id_paciente': pacResp['id'].toString()};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao adicionar papel de Paciente.'};
    }
  }

  /// Adiciona o papel de Profissional a um Administrador existente.
  /// Cria registro na tabela `profissional` e atualiza `login` com o id_profissional.
  Future<Map<String, dynamic>> addProfissionalRole({
    required String supabaseUserId,
    required String nome,
    required String email,
    required String cpf,
    required String crefito,
    required String especialidade,
    String? telefone,
  }) async {
    try {
      // Verifica se já existe
      final existing = await _sb
          .from('profissional')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (existing != null) {
        await _sb
            .from('login')
            .update({'id_profissional': existing['id']})
            .eq('supabase_user_id', supabaseUserId);
        return {'success': true, 'id_profissional': existing['id'].toString()};
      }

      final profResp = await _sb
          .from('profissional')
          .insert({
            'nome': nome.trim(),
            'email': email,
            'cpf': cpf.replaceAll(RegExp(r'\D'), ''),
            'crefito': crefito.trim(),
            'especialidade': especialidade.trim(),
            'telefone': telefone?.replaceAll(RegExp(r'\D'), ''),
            'ativo': true,
          })
          .select()
          .single();

      await _sb
          .from('login')
          .update({
            'id_profissional': profResp['id'],
            'tipo_usuario': 'Administrador', // mantém tipo original
          })
          .eq('supabase_user_id', supabaseUserId);

      return {'success': true, 'id_profissional': profResp['id'].toString()};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao adicionar papel de Profissional.'};
    }
  }

  // -------------------------------------------------------------------------

  /// Remove (ou desativa) um registro de qualquer tabela.
  /// Implementamos soft-delete para evitar conflitos de Foreign Keys (400 Bad Request).
  Future<Map<String, dynamic>> deleteRecord(String table, String id, {bool forceHardDelete = false}) async {
    try {
      if (forceHardDelete || table == 'consulta' || table == 'registro_sintomas') {
        await _sb.from(table).delete().eq('id', id).select().single();
      } else {
        await _sb.from(table).update({'ativo': false}).eq('id', id).select().single();
      }
      return {'success': true};
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return {'success': false, 'message': 'Operação recusada pelo banco (Verifique as políticas RLS).'};
      }
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao desativar registro.'};
    }
  }

  /// Desativa um paciente ou profissional: marca ativo = false.
  /// O registro permanece no banco visível apenas para ADMs.
  Future<Map<String, dynamic>> deactivateRecord(String table, String id) async {
    try {
      await _sb.from(table).update({'ativo': false}).eq('id', id).select().single();
      return {'success': true};
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return {'success': false, 'message': 'Operação recusada pelo banco (verifique as políticas RLS).'};
      }
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao desativar registro.'};
    }
  }

  /// Reativa um paciente ou profissional: marca ativo = true.
  Future<Map<String, dynamic>> reactivateRecord(String table, String id) async {
    try {
      await _sb.from(table).update({'ativo': true}).eq('id', id).select().single();
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao reativar registro.'};
    }
  }

  /// Exclusão permanente: remove da tabela `login`, da tabela principal e do Supabase Auth.
  /// A remoção do Auth é feita via Edge Function `delete-auth-user` (usa service_role key).
  Future<Map<String, dynamic>> permanentDeleteRecord(String table, String id) async {
    try {
      final loginField = table == 'paciente' ? 'id_paciente' : 'id_profissional';

      // 1. Busca o supabase_user_id ANTES de deletar (precisamos para excluir do Auth)
      final loginData = await _sb
          .from('login')
          .select('supabase_user_id')
          .eq(loginField, id)
          .maybeSingle();

      final supabaseUserId = loginData?['supabase_user_id'] as String?;

      // 2. Remove vínculo na tabela login
      await _sb.from('login').delete().eq(loginField, id);

      // 3. Remove o registro principal
      await _sb.from(table).delete().eq('id', id);

      // 4. Remove do Supabase Auth via Edge Function (service_role key no servidor)
      if (supabaseUserId != null && supabaseUserId.isNotEmpty) {
        try {
          await _sb.functions.invoke(
            'delete-auth-user',
            body: {'user_id': supabaseUserId},
          );
        } catch (_) {
          // Auth cleanup falhou, mas dados do banco já foram removidos.
          // Retorna sucesso parcial para não bloquear o fluxo do ADM.
        }
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao excluir registro permanentemente.'};
    }
  }

  /// Traduz mensagens de erro do Supabase Auth para português.
  String _traduzirErroAuth(String message) {
    final m = message.toLowerCase();

    if (m.contains('invalid login credentials') ||
        m.contains('invalid_credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de fazer login.';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (m.contains('password should be at least') ||
        m.contains('password is too short')) {
      return 'A senha deve ter no mínimo 6 caracteres.';
    }
    if (m.contains('weak_password')) {
      return 'Senha fraca. Use letras, números e símbolos.';
    }
    if (m.contains('invalid email') || m.contains('unable to validate email')) {
      return 'E-mail inválido. Verifique o endereço informado.';
    }
    if (m.contains('email address not authorized') ||
        m.contains('not authorized')) {
      return 'E-mail não autorizado para cadastro.';
    }
    if (m.contains('signup is disabled')) {
      return 'Cadastro temporariamente desativado.';
    }
    if (m.contains('rate limit') || m.contains('only request this after')) {
      final match = RegExp(r'after (\d+) seconds').firstMatch(m);
      if (match != null) {
        return 'Por segurança, aguarde ${match.group(1)} segundos antes de tentar novamente.';
      }
      return 'Muitas tentativas. Aguarde um momento e tente novamente.';
    }
    if (m.contains('token has expired') || m.contains('token_expired')) {
      return 'Código expirado. Solicite um novo.';
    }
    // OTP específicos (recuperação de senha, verificação)
    if (m.contains('otp_expired') ||
        (m.contains('invalid') &&
            (m.contains('otp') || m.contains('token') || m.contains('code')))) {
      return 'Código inválido ou expirado.';
    }
    // Fallback com a mensagem original
    return 'Erro ao processar solicitação. Tente novamente.';
  }
}




