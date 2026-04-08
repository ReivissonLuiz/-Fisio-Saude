/// api_service.dart
/// Serviço de comunicação com o Supabase — +Físio +Saúde
///
/// Esquema unificado: tabela `usuario` com FK para `permissao`.
/// Permissões: 1=Paciente, 2=Profissional, 3=Administrador.
/// A tabela `login` é usada como log de acessos.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Acesso global ao cliente Supabase (após Supabase.initialize)
SupabaseClient get _sb => Supabase.instance.client;

/// Níveis de permissão
class Permissao {
  static const int paciente = 1;
  static const int profissional = 2;
  static const int administrador = 3;

  static String nomePorNivel(int nivel) {
    switch (nivel) {
      case 1:
        return 'Paciente';
      case 2:
        return 'Profissional';
      case 3:
        return 'Administrador';
      default:
        return 'Paciente';
    }
  }

  static int nivelPorNome(String nome) {
    switch (nome.toLowerCase()) {
      case 'profissional':
        return 2;
      case 'administrador':
        return 3;
      default:
        return 1;
    }
  }
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- Sessão atual ---------------------------------------------------------

  /// Retorna o usuário autenticado atual, ou null se não logado.
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
        await _registrarLog(email: email, status: 'falha');
        return {'success': false, 'message': 'Credenciais inválidas.'};
      }

      // Busca dados do usuário + permissão via join
      final usuarioData = await _sb
          .from('usuario')
          .select('id, nome, email, id_permissao, ativo, permissao(nome, nivel)')
          .eq('supabase_user_id', user.id)
          .maybeSingle();

      if (usuarioData == null) {
        await _registrarLog(email: email, status: 'falha');
        return {
          'success': false,
          'message': 'Usuário não encontrado no sistema. Contate o suporte.'
        };
      }

      if (usuarioData['ativo'] == false) {
        await _registrarLog(email: email, status: 'falha');
        return {
          'success': false,
          'message': 'Conta desativada. Contate o administrador.'
        };
      }

      final String usuarioId = usuarioData['id'] as String;
      final String nome = usuarioData['nome'] as String? ?? user.email ?? '';
      final int idPermissao = usuarioData['id_permissao'] as int;
      final permissaoData = usuarioData['permissao'] as Map<String, dynamic>?;
      final String tipo = permissaoData?['nome'] as String? ??
          Permissao.nomePorNivel(idPermissao);

      // Registrar acesso bem-sucedido
      await _registrarLog(
        supabaseUserId: user.id,
        usuarioId: usuarioId,
        email: email,
        status: 'sucesso',
      );

      return {
        'success': true,
        'message': 'Login realizado com sucesso!',
        'token': session?.accessToken,
        'user': {
          'id': user.id,
          'id_usuario': usuarioId,
          'email': user.email,
          'nome': nome,
          'tipo': tipo,
          'id_permissao': idPermissao,
        },
      };
    } on AuthException catch (e) {
      await _registrarLog(email: email, status: 'falha');
      return {'success': false, 'message': _traduzirErroAuth(e.message)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique sua internet.'
      };
    }
  }

  // --- Auth: Registro de Paciente -------------------------------------------

  /// Registra paciente no Supabase Auth e grava dados na tabela `usuario`
  /// com id_permissao = 1 (Paciente).
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

      // 2. Gravar dados na tabela usuario com permissao = Paciente
      final usuarioResp = await _sb
          .from('usuario')
          .insert({
            'supabase_user_id': user.id,
            'id_permissao': Permissao.paciente,
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'data_nasc': _formatarData(data['dataNascimento'] as String?),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': data['genero'],
            'cep': (data['cep'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'logradouro': data['logradouro'],
            'numero': data['numero'],
            'complemento': data['complemento'],
            'bairro': data['bairro'],
            'cidade': data['cidade'],
            'uf': data['uf'],
            'ativo': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Paciente cadastrado com sucesso!',
        'id_usuario': usuarioResp['id'],
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

  /// Registra profissional no Auth e grava dados na tabela `usuario`
  /// com id_permissao = 2 (Profissional).
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

      // 2. Gravar dados na tabela usuario com permissao = Profissional
      final usuarioResp = await _sb
          .from('usuario')
          .insert({
            'supabase_user_id': user.id,
            'id_permissao': Permissao.profissional,
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'data_nasc': _formatarData(data['dataNascimento'] as String?),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': (data['genero'] as String?)?.isNotEmpty == true
                ? data['genero']
                : 'Não informado',
            'cep': (data['cep'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'logradouro': data['logradouro'],
            'numero': data['numero'],
            'complemento': data['complemento'],
            'bairro': data['bairro'],
            'cidade': data['cidade'],
            'uf': data['uf'],
            'crefito': (data['crefito'] as String?)?.trim(),
            'especialidade': (data['especializacao'] as String?)?.trim(),
            'ativo': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Cadastro realizado com sucesso! Você já pode fazer login.',
        'id_usuario': usuarioResp['id'],
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

  /// Registra administrador no Auth e grava dados na tabela `usuario`
  /// com id_permissao = 3 (Administrador).
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

      // 2. Gravar dados na tabela usuario com permissao = Administrador
      final usuarioResp = await _sb
          .from('usuario')
          .insert({
            'supabase_user_id': user.id,
            'id_permissao': Permissao.administrador,
            'nome': (data['nome'] as String).trim(),
            'email': email,
            'cpf': (data['cpf'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'data_nasc': _formatarData(data['dataNascimento'] as String?),
            'telefone':
                (data['telefone'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'genero': (data['genero'] as String?)?.isNotEmpty == true
                ? data['genero']
                : 'Não informado',
            'cep': (data['cep'] as String?)?.replaceAll(RegExp(r'\D'), ''),
            'logradouro': data['logradouro'],
            'numero': data['numero'],
            'complemento': data['complemento'],
            'bairro': data['bairro'],
            'cidade': data['cidade'],
            'uf': data['uf'],
            'cargo': data['cargo'] ?? 'Diretor',
            'ativo': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Administrador cadastrado com sucesso!',
        'id_usuario': usuarioResp['id'],
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

  // --- Usuario: Busca por supabase_user_id ----------------------------------

  /// Busca dados completos do usuário logado via supabase_user_id.
  Future<Map<String, dynamic>> getUsuarioLogado() async {
    final user = currentUser;
    if (user == null) return {'success': false, 'message': 'Não autenticado.'};
    return getUsuarioPorSupabaseId(user.id);
  }

  /// Busca dados do usuário pelo supabase_user_id (join com permissao).
  Future<Map<String, dynamic>> getUsuarioPorSupabaseId(
      String supabaseUserId) async {
    try {
      final data = await _sb
          .from('usuario')
          .select('*, permissao(id, nome, nivel)')
          .eq('supabase_user_id', supabaseUserId)
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Busca dados do usuário pelo ID interno (UUID da tabela usuario).
  Future<Map<String, dynamic>> getUsuario(String usuarioId) async {
    if (usuarioId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
    try {
      final data = await _sb
          .from('usuario')
          .select('*, permissao(id, nome, nivel)')
          .eq('id', usuarioId)
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Compat: métodos legados de Paciente → usuario -----------------------

  /// Alias para compatibilidade: busca dados do paciente pelo ID.
  Future<Map<String, dynamic>> getPaciente(String usuarioId) =>
      getUsuario(usuarioId);

  /// Alias para compatibilidade: atualiza dados do paciente.
  Future<Map<String, dynamic>> updatePaciente(
          String usuarioId, Map<String, dynamic> dados) =>
      updateUsuario(usuarioId, dados);

  // --- Compat: métodos legados de Profissional → usuario -------------------

  /// Alias para compatibilidade: busca dados do profissional pelo ID.
  Future<Map<String, dynamic>> getProfissional(String usuarioId) =>
      getUsuario(usuarioId);

  /// Alias para compatibilidade: atualiza dados do profissional.
  Future<Map<String, dynamic>> updateProfissional(
          String usuarioId, Map<String, dynamic> dados) =>
      updateUsuario(usuarioId, dados);

  // --- Usuario: Atualização -------------------------------------------------

  /// Atualiza campos editáveis do usuário.
  Future<Map<String, dynamic>> updateUsuario(
      String usuarioId, Map<String, dynamic> dados) async {
    try {
      final data = await _sb
          .from('usuario')
          .update(dados)
          .eq('id', usuarioId)
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
      final data = await _sb
          .from('usuario')
          .select('id, nome, especialidade, crefito, telefone, cidade, uf')
          .eq('id_permissao', Permissao.profissional)
          .eq('ativo', true)
          .order('nome');

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

  // --- Consultas ------------------------------------------------------------

  /// Busca as consultas do paciente com dados do profissional.
  Future<Map<String, dynamic>> getConsultas(String pacienteId) async {
    if (pacienteId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
    try {
      final data = await _sb
          .from('consulta')
          .select('*, profissional:id_profissional(nome, especialidade)')
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

  /// Busca as consultas do profissional com dados do paciente.
  Future<Map<String, dynamic>> getConsultasProfissional(
      String profissionalId) async {
    if (profissionalId.isEmpty) {
      return {'success': false, 'message': 'ID inválido.'};
    }
    try {
      final data = await _sb
          .from('consulta')
          .select(
              '*, paciente:id_paciente(nome, email, telefone, data_nasc, genero)')
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
  Future<Map<String, dynamic>> getPacientesDoProfissional(
      String profissionalId) async {
    if (profissionalId.isEmpty) {
      return {'success': false, 'message': 'ID inválido.'};
    }
    try {
      final consultas = await _sb
          .from('consulta')
          .select(
              'id_paciente, paciente:id_paciente(id, nome, email, telefone, cpf, data_nasc)')
          .eq('id_profissional', profissionalId);

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

  // --- Administrador: Gestão -----------------------------------------------

  /// Busca todos os usuários de um determinado nível de permissão.
  Future<Map<String, dynamic>> getUsuariosPorPermissao(int idPermissao,
      {bool filterAtivo = true}) async {
    try {
      var query =
          _sb.from('usuario').select('*, permissao(nome, nivel)').eq('id_permissao', idPermissao);
      if (filterAtivo) {
        query = query.eq('ativo', true);
      }
      final res = await query.order('nome');
      return {'success': true, 'data': res};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar usuários.'};
    }
  }

  /// Alias: Lista todos os pacientes para o painel ADM.
  Future<Map<String, dynamic>> getAllPacientes({bool filterAtivo = true}) =>
      getUsuariosPorPermissao(Permissao.paciente, filterAtivo: filterAtivo);

  /// Alias: Lista todos os profissionais para o painel ADM.
  Future<Map<String, dynamic>> getAllProfissionais(
          {bool filterAtivo = true}) =>
      getUsuariosPorPermissao(Permissao.profissional, filterAtivo: filterAtivo);

  /// Busca todos os administradores para o painel ADM.
  Future<Map<String, dynamic>> getAllAdministradores(
          {bool filterAtivo = true}) =>
      getUsuariosPorPermissao(Permissao.administrador, filterAtivo: filterAtivo);

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
      final res = await _sb
          .from('registro_sintomas')
          .select()
          .order('data_hora', ascending: false);
      return {'success': true, 'data': res};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao carregar sintomas globais.'
      };
    }
  }

  // --- Gestão: Alterar Permissão -------------------------------------------

  /// Altera a permissão de um usuário (ex: promover paciente a profissional).
  /// Atualiza também os campos específicos do novo papel.
  Future<Map<String, dynamic>> alterarPermissao({
    required String usuarioId,
    required int novaPermissao,
    Map<String, dynamic>? dadosAdicionais,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'id_permissao': novaPermissao,
        ...?dadosAdicionais,
      };

      final data = await _sb
          .from('usuario')
          .update(updateData)
          .eq('id', usuarioId)
          .select()
          .single();
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao alterar permissão.'};
    }
  }

  // -------------------------------------------------------------------------

  /// Desativa um usuário (soft-delete): marca ativo = false.
  Future<Map<String, dynamic>> deactivateRecord(
      String table, String id) async {
    try {
      await _sb
          .from(table)
          .update({'ativo': false})
          .eq('id', id)
          .select()
          .single();
      return {'success': true};
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return {
          'success': false,
          'message':
              'Operação recusada pelo banco (verifique as políticas RLS).'
        };
      }
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao desativar registro.'};
    }
  }

  /// Reativa um usuário: marca ativo = true.
  Future<Map<String, dynamic>> reactivateRecord(
      String table, String id) async {
    try {
      await _sb
          .from(table)
          .update({'ativo': true})
          .eq('id', id)
          .select()
          .single();
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao reativar registro.'};
    }
  }

  /// Remove um registro de qualquer tabela (hard-delete).
  Future<Map<String, dynamic>> deleteRecord(String table, String id,
      {bool forceHardDelete = false}) async {
    try {
      if (forceHardDelete ||
          table == 'consulta' ||
          table == 'registro_sintomas') {
        await _sb.from(table).delete().eq('id', id).select().single();
      } else {
        await _sb
            .from(table)
            .update({'ativo': false})
            .eq('id', id)
            .select()
            .single();
      }
      return {'success': true};
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return {
          'success': false,
          'message':
              'Operação recusada pelo banco (Verifique as políticas RLS).'
        };
      }
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao deletar registro.'};
    }
  }

  /// Exclusão permanente de usuário: remove da tabela `usuario` e do Supabase Auth.
  Future<Map<String, dynamic>> permanentDeleteUsuario(
      String usuarioId) async {
    try {
      // 1. Busca o supabase_user_id ANTES de deletar
      final usuarioData = await _sb
          .from('usuario')
          .select('supabase_user_id')
          .eq('id', usuarioId)
          .maybeSingle();

      final supabaseUserId =
          usuarioData?['supabase_user_id'] as String?;

      // 2. Remove o registro do usuário (cascata remove consultas e sintomas)
      await _sb.from('usuario').delete().eq('id', usuarioId);

      // 3. Remove do Supabase Auth via Edge Function
      if (supabaseUserId != null && supabaseUserId.isNotEmpty) {
        try {
          await _sb.functions.invoke(
            'delete-auth-user',
            body: {'user_id': supabaseUserId},
          );
        } catch (_) {
          // Auth cleanup falhou, mas dados do banco já foram removidos.
        }
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao excluir usuário permanentemente.'
      };
    }
  }

  // --- Logs ----------------------------------------------------------------

  /// Registra evento de login na tabela `login`.
  Future<void> _registrarLog({
    String? supabaseUserId,
    String? usuarioId,
    required String email,
    required String status,
    String? dispositivo,
  }) async {
    try {
      await _sb.from('login').insert({
        if (supabaseUserId != null) 'supabase_user_id': supabaseUserId,
        if (usuarioId != null) 'id_usuario': usuarioId,
        'email': email,
        'status': status,
        if (dispositivo != null) 'dispositivo': dispositivo,
      });
    } catch (_) {
      // Falha no log não deve bloquear o fluxo
    }
  }

  // --- Helpers -------------------------------------------------------------

  /// Converte data no formato DD/MM/AAAA para AAAA-MM-DD.
  String? _formatarData(String? data) {
    if (data == null || data.isEmpty) return null;
    if (data.contains('/')) {
      return data.split('/').reversed.join('-');
    }
    return data; // Já está em formato ISO
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
    if (m.contains('invalid email') ||
        m.contains('unable to validate email')) {
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
    if (m.contains('otp_expired') ||
        (m.contains('invalid') &&
            (m.contains('otp') ||
                m.contains('token') ||
                m.contains('code')))) {
      return 'Código inválido ou expirado.';
    }
    return 'Erro ao processar solicitação. Tente novamente.';
  }
}
