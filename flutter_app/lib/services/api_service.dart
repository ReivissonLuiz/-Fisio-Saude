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
      await _sb.from('usuario').insert({
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
      });

      return {
        'success': true,
        'message': 'Paciente cadastrado com sucesso!',
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
      await _sb.from('usuario').insert({
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
      });

      return {
        'success': true,
        'message': 'Cadastro realizado com sucesso! Você já pode fazer login.',
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
      await _sb.from('usuario').insert({
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
      });

      return {
        'success': true,
        'message': 'Administrador cadastrado com sucesso!',
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

  // --- Agendamento: Disponibilidade ----------------------------------------

  /// Retorna os slots de disponibilidade de um profissional.
  Future<Map<String, dynamic>> getDisponibilidade(String profissionalId) async {
    try {
      final data = await _sb
          .from('disponibilidade')
          .select()
          .eq('id_profissional', profissionalId)
          .eq('disponivel', true)
          .order('data')
          .order('hora_inicio');
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Retorna as especialidades distintas de profissionais ativos.
  Future<Map<String, dynamic>> getEspecialidades() async {
    try {
      final data = await _sb
          .from('usuario')
          .select('especialidade')
          .eq('id_permissao', Permissao.profissional)
          .eq('ativo', true)
          .not('especialidade', 'is', null);

      final especialidades = (data as List)
          .map((e) => e['especialidade'] as String? ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return {'success': true, 'data': especialidades};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Busca profissionais disponíveis para uma especialidade, data e horário.
  /// Lógica: qualquer profissional ativo pode ser agendado das 08h–19h,
  /// desde que não tenha consulta agendada naquele slot.
  Future<Map<String, dynamic>> getProfissionaisDisponiveis({
    required String? especialidade,
    required DateTime data,
    required String horario,
  }) async {
    try {
      // 1. Busca todos os profissionais ativos (filtrado por especialidade)
      var query = _sb
          .from('usuario')
          .select('id, nome, especialidade, crefito, telefone')
          .eq('id_permissao', Permissao.profissional)
          .eq('ativo', true);

      final todos = await query;

      List<Map<String, dynamic>> profissionais = (todos as List)
          .cast<Map<String, dynamic>>()
          .where((p) {
            if (especialidade != null && especialidade.isNotEmpty) {
              final esp = (p['especialidade'] as String? ?? '').toLowerCase();
              return esp.contains(especialidade.toLowerCase());
            }
            return true;
          })
          .toList();

      // 2. Verifica quais já têm consulta agendada neste slot
      final h = horario.split(':');
      final dataInicio = DateTime(data.year, data.month, data.day, int.parse(h[0]), int.parse(h[1]));
      final dataFim = dataInicio.add(const Duration(hours: 1));

      final consultasExistentes = await _sb
          .from('consulta')
          .select('id_profissional')
          .gte('data_hora', dataInicio.toIso8601String())
          .lt('data_hora', dataFim.toIso8601String())
          .inFilter('status', ['agendada', 'Agendada']);

      final ocupados = (consultasExistentes as List)
          .map((c) => c['id_profissional'] as String)
          .toSet();

      final disponiveis = profissionais.where((p) => !ocupados.contains(p['id'] as String)).toList();

      return {'success': true, 'data': disponiveis};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Retorna slots de 08:00–19:00 para um profissional em uma data,
  /// excluindo horários já agendados e horários passados.
  Future<Map<String, dynamic>> getHorariosDisponiveis({
    required String profissionalId,
    required DateTime data,
  }) async {
    try {
      // Consultas já agendadas neste dia para este profissional
      final inicioDia = DateTime(data.year, data.month, data.day);
      final fimDia = inicioDia.add(const Duration(days: 1));

      final consultasDia = await _sb
          .from('consulta')
          .select('data_hora')
          .eq('id_profissional', profissionalId)
          .gte('data_hora', inicioDia.toIso8601String())
          .lt('data_hora', fimDia.toIso8601String())
          .inFilter('status', ['agendada', 'Agendada']);

      final horariosOcupados = (consultasDia as List).map((c) {
        final dt = DateTime.parse(c['data_hora'] as String).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }).toSet();

      // Gera slots das 08:00 às 19:00 (último início às 18:00)
      final horariosDisponiveis = <String>[];
      for (int h = 8; h < 19; h++) {
        final horario = '${h.toString().padLeft(2, '0')}:00';
        final slotDt = DateTime(data.year, data.month, data.day, h, 0);
        if (!horariosOcupados.contains(horario) && slotDt.isAfter(DateTime.now())) {
          horariosDisponiveis.add(horario);
        }
      }

      return {'success': true, 'data': horariosDisponiveis};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  // --- Agendamento: Consultas -----------------------------------------------

  /// Cria uma nova consulta e envia notificações para ambas as partes.
  Future<Map<String, dynamic>> agendarConsulta({
    required String pacienteId,
    required String profissionalId,
    required DateTime dataHora,
    String? observacoes,
  }) async {
    try {
      // Verificação dupla de disponibilidade
      final horario =
          '${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}';
      final dataFim = dataHora.add(const Duration(hours: 1));

      final conflito = await _sb
          .from('consulta')
          .select('id')
          .eq('id_profissional', profissionalId)
          .gte('data_hora', dataHora.toIso8601String())
          .lt('data_hora', dataFim.toIso8601String())
          .inFilter('status', ['agendada', 'Agendada'])
          .maybeSingle();

      if (conflito != null) {
        return {
          'success': false,
          'message': 'Este horário já foi reservado. Por favor, escolha outro.'
        };
      }

      // Cria a consulta
      final consulta = await _sb
          .from('consulta')
          .insert({
            'id_paciente': pacienteId,
            'id_profissional': profissionalId,
            'data_hora': dataHora.toIso8601String(),
            'status': 'agendada',
            'observacoes': observacoes,
          })
          .select()
          .single();

      final consultaId = consulta['id'] as String;

      // Busca nomes para notificação
      final profData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', profissionalId)
          .single();
      final pacData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', pacienteId)
          .single();

      final nomeProfissional = profData['nome'] as String? ?? 'Profissional';
      final nomePaciente = pacData['nome'] as String? ?? 'Paciente';
      final dataFormatada =
          '${dataHora.day.toString().padLeft(2, '0')}/${dataHora.month.toString().padLeft(2, '0')}/${dataHora.year} às $horario';

      // Notifica paciente
      await _criarNotificacao(
        idDestinatario: pacienteId,
        titulo: 'Consulta Agendada!',
        mensagem: 'Sua consulta com $nomeProfissional foi confirmada para $dataFormatada.',
        tipo: 'agendamento',
      );

      // Notifica profissional
      await _criarNotificacao(
        idDestinatario: profissionalId,
        titulo: 'Nova Consulta Agendada',
        mensagem: '$nomePaciente agendou uma consulta para $dataFormatada.',
        tipo: 'agendamento',
      );

      return {'success': true, 'data': consulta};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao realizar agendamento.'};
    }
  }

  /// Cancela uma consulta agendada e notifica a outra parte.
  Future<Map<String, dynamic>> cancelarConsulta({
    required String consultaId,
    required String pacienteId,
    required String profissionalId,
    String? motivo,
    bool iniciadoPorProfissional = false,
  }) async {
    try {
      await _sb
          .from('consulta')
          .update({'status': 'cancelada', 'observacoes': motivo})
          .eq('id', consultaId);

      final pacData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', pacienteId)
          .maybeSingle();
      final profData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', profissionalId)
          .maybeSingle();
          
      final nomePaciente = pacData?['nome'] as String? ?? 'Paciente';
      final nomeProfissional = profData?['nome'] as String? ?? 'Profissional';

      if (iniciadoPorProfissional) {
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Consulta Cancelada',
          mensagem: 'O profissional $nomeProfissional cancelou a sua consulta.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}',
          tipo: 'cancelamento',
        );
      } else {
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Consulta Cancelada',
          mensagem: '$nomePaciente cancelou a consulta agendada.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}',
          tipo: 'cancelamento',
        );
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao cancelar consulta.'};
    }
  }

  /// Reagenda uma consulta e notifica a outra parte.
  Future<Map<String, dynamic>> reagendarConsulta({
    required String consultaId,
    required String pacienteId,
    required String profissionalId,
    required DateTime novaDataHora,
    bool iniciadoPorProfissional = false,
  }) async {
    try {
      // Verificação de disponibilidade no novo horário
      final dataFim = novaDataHora.add(const Duration(hours: 1));
      final horario =
          '${novaDataHora.hour.toString().padLeft(2, '0')}:${novaDataHora.minute.toString().padLeft(2, '0')}';

      final conflitoList = await _sb
          .from('consulta')
          .select('id')
          .eq('id_profissional', profissionalId)
          .neq('id', consultaId)
          .gte('data_hora', novaDataHora.toIso8601String())
          .lt('data_hora', dataFim.toIso8601String())
          .inFilter('status', ['agendada', 'Agendada'])
          .limit(1);

      if (conflitoList.isNotEmpty) {
        return {
          'success': false,
          'message': 'Este horário já está ocupado. Escolha outro.'
        };
      }

      await _sb
          .from('consulta')
          .update({
            'data_hora': novaDataHora.toIso8601String(),
            'status': 'agendada',
          })
          .eq('id', consultaId);

      final pacData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', pacienteId)
          .maybeSingle();
      final profData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', profissionalId)
          .maybeSingle();
          
      final nomePaciente = pacData?['nome'] as String? ?? 'Paciente';
      final nomeProfissional = profData?['nome'] as String? ?? 'Profissional';
      final dataFormatada =
          '${novaDataHora.day.toString().padLeft(2, '0')}/${novaDataHora.month.toString().padLeft(2, '0')}/${novaDataHora.year} às $horario';

      if (iniciadoPorProfissional) {
        // Notifica paciente
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Consulta Reagendada',
          mensagem: 'O profissional $nomeProfissional reagendou sua consulta para $dataFormatada.',
          tipo: 'reagendamento',
        );
        // Confirma para o profissional
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Reagendamento Confirmado',
          mensagem: 'Você reagendou a consulta de $nomePaciente para $dataFormatada.',
          tipo: 'reagendamento',
        );
      } else {
        // Notifica profissional
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Consulta Reagendada',
          mensagem: '$nomePaciente reagendou a consulta para $dataFormatada.',
          tipo: 'reagendamento',
        );
        // Confirma para o paciente
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Reagendamento Confirmado',
          mensagem: 'Sua consulta foi reagendada para $dataFormatada.',
          tipo: 'reagendamento',
        );
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao reagendar consulta.'};
    }
  }

  // --- Notificações ----------------------------------------------------------

  /// Cria uma notificação interna.
  Future<void> _criarNotificacao({
    required String idDestinatario,
    required String titulo,
    required String mensagem,
    required String tipo,
  }) async {
    try {
      await _sb.from('notificacao').insert({
        'id_destinatario': idDestinatario,
        'titulo': titulo,
        'mensagem': mensagem,
        'tipo': tipo,
      });
    } catch (_) {
      // Falha de notificação não bloqueia o fluxo principal
    }
  }

  /// Busca notificações do usuário atual.
  Future<Map<String, dynamic>> getNotificacoes(String usuarioId) async {
    try {
      final data = await _sb
          .from('notificacao')
          .select()
          .eq('id_destinatario', usuarioId)
          .order('created_at', ascending: false)
          .limit(30);
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Conta notificações não lidas.
  Future<int> getNotificacoesNaoLidas(String usuarioId) async {
    try {
      final data = await _sb
          .from('notificacao')
          .select('id')
          .eq('id_destinatario', usuarioId)
          .eq('lida', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Marca uma notificação como lida.
  Future<void> marcarNotificacaoLida(String notificacaoId) async {
    try {
      await _sb
          .from('notificacao')
          .update({'lida': true})
          .eq('id', notificacaoId);
    } catch (_) {}
  }

  /// Marca todas as notificações do usuário como lidas.
  Future<void> marcarTodasNotificacoesLidas(String usuarioId) async {
    try {
      await _sb
          .from('notificacao')
          .update({'lida': true})
          .eq('id_destinatario', usuarioId)
          .eq('lida', false);
    } catch (_) {}
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
