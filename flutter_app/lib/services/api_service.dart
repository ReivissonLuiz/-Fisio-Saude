/// api_service.dart
/// Serviço de comunicação com o Supabase — +Físio +Saúde
///
/// Esquema unificado: tabela `usuario` com FK para `permissao`.
/// Permissões: 1=Paciente, 2=Profissional, 3=Administrador.
/// A tabela `login` é usada como log de acessos.
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_service.dart';

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

      // Registrar acesso bem-sucedido e ativar log de navegação
      LogService.instance.setUsuario(usuarioId);
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
      await _registrarLog(email: email, status: 'falha', mensagemErro: _traduzirErroAuth(e.message));
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

  /// Busca o resumo do paciente para exibir na agenda (histórico com o prof e sintomas)
  Future<Map<String, dynamic>> getResumoPacienteParaProfissional({
    required String pacienteId,
    required String profissionalId,
  }) async {
    try {
      // Busca consultas passadas realizadas com este profissional
      final hist = await _sb
          .from('consulta')
          .select('id')
          .eq('id_paciente', pacienteId)
          .eq('id_profissional', profissionalId)
          .eq('status', 'realizada');
      final totalConsultas = (hist as List).length;

      // Busca os últimos sintomas registrados pelo paciente (max 5)
      final sint = await _sb
          .from('registro_sintomas')
          .select('*')
          .eq('id_paciente', pacienteId)
          .order('data_hora', ascending: false)
          .limit(5);

      return {
        'success': true,
        'data': {
          'consultas_realizadas': totalConsultas,
          'sintomas': sint,
        }
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar detalhes.'};
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

  /// Cria um slot de disponibilidade.
  Future<Map<String, dynamic>> criarDisponibilidade({
    required String idProfissional,
    required String data,
    required String horaInicio,
    String? horaFim,
  }) async {
    try {
      final res = await _sb.from('disponibilidade').insert({
        'id_profissional': idProfissional,
        'data': data,
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
        'disponivel': true,
      }).select().single();
      return {'success': true, 'data': res};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao criar disponibilidade.'};
    }
  }

  /// Remove um slot de disponibilidade.
  Future<Map<String, dynamic>> deletarDisponibilidade(String id) async {
    return deleteRecord('disponibilidade', id, forceHardDelete: true);
  }

  // --- Horário Padrão (padrão semanal recorrente) ---------------------------

  /// Retorna o horário padrão configurado pelo profissional.
  /// Se nenhum padrão existir, retorna lista vazia (o app aplica 07:00–19:00).
  Future<Map<String, dynamic>> getHorarioPadrao(String profissionalId) async {
    if (profissionalId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
    try {
      final data = await _sb
          .from('horario_padrao')
          .select()
          .eq('id_profissional', profissionalId)
          .eq('ativo', true)
          .order('dia_semana');
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Salva (upsert) o horário padrão do profissional.
  /// [entradas] é uma lista de maps com: dia_semana, hora_inicio, hora_fim.
  /// Dias não incluídos na lista terão ativo=false (desativados).
  Future<Map<String, dynamic>> salvarHorarioPadrao({
    required String profissionalId,
    required List<Map<String, dynamic>> entradas,
  }) async {
    try {
      // 1. Desativa todos os dias existentes
      await _sb
          .from('horario_padrao')
          .update({'ativo': false})
          .eq('id_profissional', profissionalId);

      // 2. Upsert dos dias ativos
      if (entradas.isNotEmpty) {
        final rows = entradas.map((e) => {
          'id_profissional': profissionalId,
          'dia_semana': e['dia_semana'],
          'hora_inicio': e['hora_inicio'],
          'hora_fim': e['hora_fim'],
          'ativo': true,
        }).toList();

        await _sb
            .from('horario_padrao')
            .upsert(rows, onConflict: 'id_profissional,dia_semana');
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao salvar horário padrão.'};
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

      // Gerar link do Google Meet e URL do Google Calendar
      final meetId = _gerarMeetId();
      final meetUrl = 'https://meet.google.com/$meetId';

      // Busca e-mails e nomes para Calendar e notificação
      final profData = await _sb
          .from('usuario')
          .select('nome, email')
          .eq('id', profissionalId)
          .single();
      final pacData = await _sb
          .from('usuario')
          .select('nome, email')
          .eq('id', pacienteId)
          .single();

      final nomeProfissional = profData['nome'] as String? ?? 'Profissional';
      final nomePaciente = pacData['nome'] as String? ?? 'Paciente';
      final emailProfissional = profData['email'] as String? ?? '';
      final emailPaciente = pacData['email'] as String? ?? '';

      final calendarUrl = _gerarCalendarUrl(
        nomeProfissional: nomeProfissional,
        emailPaciente: emailPaciente,
        emailProfissional: emailProfissional,
        dataHora: dataHora,
        meetUrl: meetUrl,
      );

      // Cria a consulta com links Google
      final consulta = await _sb
          .from('consulta')
          .insert({
            'id_paciente': pacienteId,
            'id_profissional': profissionalId,
            'data_hora': dataHora.toIso8601String(),
            'status': 'agendada',
            'observacoes': observacoes,
            'link_meet': meetUrl,
            'link_calendar': calendarUrl,
          })
          .select()
          .single();

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

      return {
        'success': true,
        'data': consulta,
        'link_meet': meetUrl,
        'link_calendar': calendarUrl,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao realizar agendamento.'};
    }
  }

  /// Finaliza a consulta (checkout) e salva o relatório.
  Future<Map<String, dynamic>> finalizarConsulta({
    required String consultaId,
    required String relatorio,
  }) async {
    try {
      await _sb.from('consulta').update({
        'status': 'finalizada',
        'relatorio': relatorio,
      }).eq('id', consultaId);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao finalizar consulta.'};
    }
  }

  /// Avalia a consulta finalizada.
  Future<Map<String, dynamic>> avaliarConsulta({
    required String consultaId,
    required int nota,
  }) async {
    try {
      await _sb.from('consulta').update({
        'avaliacao': nota,
      }).eq('id', consultaId);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao avaliar consulta.'};
    }
  }

  /// Confirma a consulta (check-in de véspera).
  Future<Map<String, dynamic>> confirmarConsulta({
    required String consultaId,
    required String pacienteId,
    required String profissionalId,
    required bool iniciadoPorProfissional,
  }) async {
    try {
      await _sb
          .from('consulta')
          .update({'status': 'confirmada'})
          .eq('id', consultaId);

      final pacData = await _sb.from('usuario').select('nome').eq('id', pacienteId).maybeSingle();
      final profData = await _sb.from('usuario').select('nome').eq('id', profissionalId).maybeSingle();
      final nomePaciente = pacData?['nome'] as String? ?? 'Paciente';
      final nomeProfissional = profData?['nome'] as String? ?? 'Profissional';

      if (iniciadoPorProfissional) {
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Consulta Confirmada',
          mensagem: 'O profissional $nomeProfissional confirmou a sua consulta.',
          tipo: 'agendamento',
        );
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Confirmação Realizada',
          mensagem: 'Você confirmou a consulta de $nomePaciente.',
          tipo: 'agendamento',
        );
      } else {
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Consulta Confirmada',
          mensagem: 'O paciente $nomePaciente confirmou a presença na consulta.',
          tipo: 'agendamento',
        );
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Confirmação Realizada',
          mensagem: 'Você confirmou sua presença na consulta com $nomeProfissional.',
          tipo: 'agendamento',
        );
      }

      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao confirmar consulta.'};
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
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Cancelamento Confirmado',
          mensagem: 'Você cancelou a consulta de $nomePaciente.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}',
          tipo: 'cancelamento',
        );
      } else {
        await _criarNotificacao(
          idDestinatario: profissionalId,
          titulo: 'Consulta Cancelada',
          mensagem: '$nomePaciente cancelou a consulta agendada.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}',
          tipo: 'cancelamento',
        );
        await _criarNotificacao(
          idDestinatario: pacienteId,
          titulo: 'Cancelamento Confirmado',
          mensagem: 'Você cancelou sua consulta com $nomeProfissional.${motivo != null && motivo.isNotEmpty ? ' Motivo: $motivo' : ''}',
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
    String? acaoId,
  }) async {
    try {
      await _sb.from('notificacao').insert({
        'id_destinatario': idDestinatario,
        'titulo': titulo,
        'corpo': mensagem,
        'tipo': tipo,
        if (acaoId != null) 'acao_id': acaoId,
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

  // --- Recomendações de Vídeos (ML) ----------------------------------------

  /// Envia uma lista de exercícios recomendados pelo profissional ao paciente,
  /// após o encerramento de uma consulta. Salva no Supabase e cria notificação.
  Future<Map<String, dynamic>> enviarRecomendacaoVideos({
    required String pacienteId,
    required String profissionalId,
    required String consultaId,
    required List<Map<String, dynamic>> videos,
    String? mensagem,
  }) async {
    try {
      final rec = await _sb.from('recomendacao_video').insert({
        'id_consulta': consultaId,
        'id_paciente': pacienteId,
        'id_profissional': profissionalId,
        'videos': videos,
        'mensagem': mensagem,
      }).select().single();

      // Busca nome do profissional para a notificação
      final profData = await _sb
          .from('usuario')
          .select('nome')
          .eq('id', profissionalId)
          .maybeSingle();
      final nomeProfissional = profData?['nome'] as String? ?? 'Seu fisioterapeuta';

      // Notifica o paciente
      await _criarNotificacao(
        idDestinatario: pacienteId,
        titulo: '🏃 Novos Exercícios Recomendados!',
        mensagem:
            '$nomeProfissional enviou ${videos.length} exercício(s) personalizado(s) para você. Acesse "Minha Saúde" para ver.',
        tipo: 'recomendacao',
      );

      return {'success': true, 'data': rec};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao enviar recomendação.'};
    }
  }

  /// Busca as recomendações de vídeos recebidas pelo paciente.
  Future<Map<String, dynamic>> getRecomendacoesVideos(String pacienteId) async {
    if (pacienteId.isEmpty) return {'success': false, 'message': 'ID inválido.'};
    try {
      final data = await _sb
          .from('recomendacao_video')
          .select('*, profissional:id_profissional(nome, especialidade)')
          .eq('id_paciente', pacienteId)
          .order('created_at', ascending: false)
          .limit(20);
      return {'success': true, 'data': data};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão.'};
    }
  }

  /// Conta recomendações de vídeos não lidas do paciente.
  Future<int> getRecomendacoesNaoLidas(String pacienteId) async {
    try {
      final data = await _sb
          .from('recomendacao_video')
          .select('id')
          .eq('id_paciente', pacienteId)
          .eq('lida', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Marca uma recomendação de vídeo como lida pelo paciente.
  Future<void> marcarRecomendacaoLida(String recomendacaoId) async {
    try {
      await _sb.from('recomendacao_video').update({
        'lida': true,
        'lida_em': DateTime.now().toIso8601String(),
      }).eq('id', recomendacaoId);
    } catch (_) {}
  }

  // --- Logs ----------------------------------------------------------------

  /// Registra evento de login/tentativa na tabela `login`.
  Future<void> _registrarLog({
    String? supabaseUserId,
    String? usuarioId,
    required String email,
    required String status,
    String? dispositivo,
    String? mensagemErro,
  }) async {
    try {
      await _sb.from('login').insert({
        if (supabaseUserId != null) 'supabase_user_id': supabaseUserId,
        if (usuarioId != null) 'id_usuario': usuarioId,
        'email': email,
        'status': status,
        if (dispositivo != null) 'dispositivo': dispositivo,
        if (mensagemErro != null) 'mensagem_erro': mensagemErro,
      });
    } catch (_) {
      // Falha no log não deve bloquear o fluxo
    }
  }

  // --- Google Meet / Calendar ----------------------------------------------

  /// Gera um ID aleatório no formato xxx-yyyy-zzz para o Google Meet.
  String _gerarMeetId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final rng = Random();
    String seg(int len) =>
        List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${seg(3)}-${seg(4)}-${seg(3)}';
  }

  /// Gera URL do Google Calendar com todos os dados da consulta e link Meet.
  String _gerarCalendarUrl({
    required String nomeProfissional,
    required String emailPaciente,
    required String emailProfissional,
    required DateTime dataHora,
    required String meetUrl,
  }) {
    final inicio = _formatarDataHoraCalendar(dataHora);
    final fim = _formatarDataHoraCalendar(dataHora.add(const Duration(hours: 1)));
    final titulo = Uri.encodeComponent('Consulta com $nomeProfissional - +Físio +Saúde');
    final detalhes = Uri.encodeComponent(
        'Consulta de fisioterapia agendada pelo app +Físio +Saúde.\n\nLink da sala: $meetUrl');
    final convidados = Uri.encodeComponent('$emailPaciente,$emailProfissional');
    return 'https://calendar.google.com/calendar/render?action=TEMPLATE'
        '&text=$titulo&dates=$inicio/$fim&details=$detalhes'
        '&add=$convidados&sf=true&output=xml';
  }

  String _formatarDataHoraCalendar(DateTime dt) {
    final d = dt.toUtc();
    return '${d.year}${_pad(d.month)}${_pad(d.day)}T${_pad(d.hour)}${_pad(d.minute)}00Z';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

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

  // ─── Avatar / Foto de Perfil ──────────────────────────────────────────────

  /// Faz upload de avatar para o Supabase Storage e atualiza avatar_url.

  Future<Map<String, dynamic>> uploadAvatar({
    required String usuarioId,
    required List<int> bytes,
    required String mimeType,
    required String extensao,
  }) async {
    try {
      final path = 'avatars/$usuarioId.$extensao';
      await _sb.storage.from('avatars').uploadBinary(
        path,
        bytes as Uint8List,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );
      final url = _sb.storage.from('avatars').getPublicUrl(path);
      final urlComCache = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      await _sb.from('usuario').update({'avatar_url': urlComCache}).eq('id', usuarioId);
      return {'success': true, 'url': urlComCache};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao enviar foto: $e'};
    }
  }

  Future<String?> getAvatarUrl(String usuarioId) async {
    try {
      final data = await _sb.from('usuario').select('avatar_url').eq('id', usuarioId).maybeSingle();
      return data?['avatar_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Chat (Mensagens) ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> enviarMensagem({
    required String remetenteId,
    required String destinatarioId,
    required String conteudo,
    String? consultaId,
  }) async {
    try {
      final data = await _sb.from('mensagem').insert({
        'id_remetente': remetenteId,
        'id_destinatario': destinatarioId,
        'conteudo': conteudo.trim(),
        if (consultaId != null) 'id_consulta': consultaId,
        'lida': false,
      }).select().single();

      // Buscar nome do remetente
      final remetenteData = await _sb.from('usuario').select('nome').eq('id', remetenteId).maybeSingle();
      final nomeRemetente = remetenteData?['nome'] as String? ?? 'Alguém';

      final corpoMensagem = conteudo.trim().length > 50 ? '${conteudo.trim().substring(0, 50)}...' : conteudo.trim();
      
      await _criarNotificacao(
        idDestinatario: destinatarioId,
        titulo: 'Nova mensagem de $nomeRemetente',
        mensagem: '$corpoMensagem|||$remetenteId',
        tipo: 'chat',
      );

      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao enviar mensagem.'};
    }
  }

  Future<Map<String, dynamic>> getMensagens({
    required String usuarioAId,
    required String usuarioBId,
  }) async {
    try {
      final data = await _sb
          .from('mensagem')
          .select('*')
          .or('and(id_remetente.eq.$usuarioAId,id_destinatario.eq.$usuarioBId),and(id_remetente.eq.$usuarioBId,id_destinatario.eq.$usuarioAId)')
          .order('created_at', ascending: true)
          .limit(200);
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar mensagens.'};
    }
  }

  Future<void> marcarMensagensLidas({required String remetenteId, required String destinatarioId}) async {
    try {
      await _sb.from('mensagem').update({'lida': true})
          .eq('id_remetente', remetenteId)
          .eq('id_destinatario', destinatarioId)
          .eq('lida', false);
    } catch (_) {}
  }

  Future<int> contarMensagensNaoLidas(String usuarioId) async {
    try {
      final data = await _sb.from('mensagem').select('id').eq('id_destinatario', usuarioId).eq('lida', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> streamMensagens({required String usuarioAId, required String usuarioBId}) {
    return _sb.from('mensagem').stream(primaryKey: ['id']).order('created_at', ascending: true).map(
      (rows) => rows.where((r) =>
        (r['id_remetente'] == usuarioAId && r['id_destinatario'] == usuarioBId) ||
        (r['id_remetente'] == usuarioBId && r['id_destinatario'] == usuarioAId)
      ).toList()
    );
  }

  Future<Map<String, dynamic>> getContatosChat(String usuarioId) async {
    try {
      final data = await _sb.from('mensagem')
          .select('id_remetente, id_destinatario, conteudo, created_at, lida')
          .or('id_remetente.eq.$usuarioId,id_destinatario.eq.$usuarioId')
          .order('created_at', ascending: false)
          .limit(100);
      final Map<String, dynamic> contatos = {};
      for (final msg in data as List) {
        final outroId = msg['id_remetente'] == usuarioId ? msg['id_destinatario'] as String : msg['id_remetente'] as String;
        if (!contatos.containsKey(outroId)) { contatos[outroId] = msg; }
      }
      return {'success': true, 'data': contatos.values.toList()};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar contatos.'};
    }
  }
}

