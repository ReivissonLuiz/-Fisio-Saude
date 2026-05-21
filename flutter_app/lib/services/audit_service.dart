/// audit_service.dart
/// Serviço centralizado de auditoria do +Físio +Saúde.
/// Registra todos os eventos críticos na tabela `log_auditoria` do Supabase.
/// Cobertura: login, navegação, perfil, consultas, contas.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _sb => Supabase.instance.client;

// ── Tipos de evento ──────────────────────────────────────────────────────────
class TipoEvento {
  // Autenticação
  static const String loginSucesso        = 'login_sucesso';
  static const String loginFalha          = 'login_falha';
  static const String logout              = 'logout';
  static const String redefinicaoSenha    = 'redefinicao_senha';

  // Navegação
  static const String navegacaoAba        = 'navegacao_aba';
  static const String navegacaoTela       = 'navegacao_tela';

  // Contas
  static const String createContaPaciente    = 'create_conta_paciente';
  static const String createContaProfissional = 'create_conta_profissional';
  static const String createContaAdmin       = 'create_conta_admin';
  static const String desativarConta         = 'desativar_conta';
  static const String ativarConta            = 'ativar_conta';
  static const String excluirConta           = 'excluir_conta';
  static const String alteracaoPermissao     = 'alteracao_permissao';

  // Perfil
  static const String updatePerfil        = 'update_perfil';
  static const String updateSenha         = 'update_senha';

  // Consultas
  static const String agendamento         = 'agendamento';
  static const String cancelamento        = 'cancelamento';
  static const String reagendamento       = 'reagendamento';
  static const String confirmacaoConsulta = 'confirmacao_consulta';
  static const String checkout            = 'checkout';
  static const String avaliacao           = 'avaliacao_consulta';

  // Saúde
  static const String registroSintoma     = 'registro_sintoma';
  static const String recomendacaoEnviada = 'recomendacao_enviada';
}

// ── Serviço ──────────────────────────────────────────────────────────────────
class AuditService {
  static final AuditService instance = AuditService._();
  AuditService._();

  String? _usuarioId;

  /// Define o ID do usuário logado. Chamar após login bem-sucedido.
  void setUsuario(String? id) => _usuarioId = id;

  /// Retorna o ID do usuário atualmente configurado.
  String? get usuarioId => _usuarioId;

  /// Registra um evento de auditoria na tabela `log_auditoria`.
  /// [idUsuarioAlvo] permite registrar eventos sobre outro usuário
  /// (ex: admin desativando uma conta).
  Future<void> log({
    required String tipoEvento,
    required String descricao,
    String? idUsuarioAlvo,
    Map<String, dynamic>? dadosExtras,
  }) async {
    // Usa o alvo se informado, senão usa o usuário logado
    final idParaLog = idUsuarioAlvo ?? _usuarioId;

    try {
      await _sb.from('log_auditoria').insert({
        if (idParaLog != null) 'id_usuario': idParaLog,
        'tipo_evento': tipoEvento,
        'descricao': descricao,
        if (dadosExtras != null) 'dados_extras': dadosExtras,
      });
    } catch (_) {
      // Falha no log nunca bloqueia o fluxo principal
    }
  }

  // ── Atalhos para eventos comuns ──────────────────────────────────────────

  Future<void> logLogin({
    required String email,
    required bool sucesso,
    String? mensagemErro,
    String? idUsuarioAlvo,
  }) =>
      log(
        tipoEvento: sucesso ? TipoEvento.loginSucesso : TipoEvento.loginFalha,
        descricao: sucesso
            ? 'Login bem-sucedido para $email'
            : 'Tentativa de login falhou para $email',
        idUsuarioAlvo: idUsuarioAlvo,
        dadosExtras: {
          'email': email,
          if (!sucesso && mensagemErro != null) 'erro': mensagemErro,
        },
      );

  Future<void> logLogout() =>
      log(tipoEvento: TipoEvento.logout, descricao: 'Usuário realizou logout');

  Future<void> logNavegacaoAba({
    required String nomeAba,
    required String perfil,
  }) =>
      log(
        tipoEvento: TipoEvento.navegacaoAba,
        descricao: 'Acessou a aba "$nomeAba" (perfil: $perfil)',
        dadosExtras: {'aba': nomeAba, 'perfil': perfil},
      );

  Future<void> logNavegacaoTela(String nomeTela, {String? acao}) =>
      log(
        tipoEvento: TipoEvento.navegacaoTela,
        descricao: acao != null
            ? '$acao para "$nomeTela"'
            : 'Acessou "$nomeTela"',
        dadosExtras: {'tela': nomeTela, if (acao != null) 'acao': acao},
      );

  Future<void> logCreateConta({
    required String tipo,
    required String nome,
    required String email,
    String? idUsuarioAlvo,
  }) =>
      log(
        tipoEvento: tipo == 'paciente'
            ? TipoEvento.createContaPaciente
            : tipo == 'profissional'
                ? TipoEvento.createContaProfissional
                : TipoEvento.createContaAdmin,
        descricao: 'Conta criada: $nome ($email) — perfil: $tipo',
        idUsuarioAlvo: idUsuarioAlvo,
        dadosExtras: {'nome': nome, 'email': email, 'tipo': tipo},
      );

  Future<void> logDesativarConta({
    required String idAlvo,
    required String nomeAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.desativarConta,
        descricao: 'Conta desativada: $nomeAlvo',
        idUsuarioAlvo: idAlvo,
        dadosExtras: {'id_alvo': idAlvo, 'nome_alvo': nomeAlvo},
      );

  Future<void> logAtivarConta({
    required String idAlvo,
    required String nomeAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.ativarConta,
        descricao: 'Conta reativada: $nomeAlvo',
        idUsuarioAlvo: idAlvo,
        dadosExtras: {'id_alvo': idAlvo, 'nome_alvo': nomeAlvo},
      );

  Future<void> logExcluirConta({
    required String idAlvo,
    required String nomeAlvo,
    required String emailAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.excluirConta,
        descricao: 'Conta excluída permanentemente: $nomeAlvo ($emailAlvo)',
        dadosExtras: {
          'id_alvo': idAlvo,
          'nome_alvo': nomeAlvo,
          'email_alvo': emailAlvo,
        },
      );

  Future<void> logAlteracaoPermissao({
    required String idAlvo,
    required String nomeAlvo,
    required int novaPermissao,
  }) =>
      log(
        tipoEvento: TipoEvento.alteracaoPermissao,
        descricao: 'Permissão alterada para $nomeAlvo → nível $novaPermissao',
        idUsuarioAlvo: idAlvo,
        dadosExtras: {
          'id_alvo': idAlvo,
          'nome_alvo': nomeAlvo,
          'nova_permissao': novaPermissao,
        },
      );

  Future<void> logUpdatePerfil({required List<String> camposAlterados}) =>
      log(
        tipoEvento: TipoEvento.updatePerfil,
        descricao: 'Perfil atualizado. Campos: ${camposAlterados.join(', ')}',
        dadosExtras: {'campos': camposAlterados},
      );

  Future<void> logUpdateSenha() =>
      log(
        tipoEvento: TipoEvento.updateSenha,
        descricao: 'Senha alterada com sucesso',
      );

  Future<void> logAgendamento({
    required String consultaId,
    required String pacienteNome,
    required String profissionalNome,
    required String dataHora,
    String? iniciadoPor,
  }) =>
      log(
        tipoEvento: TipoEvento.agendamento,
        descricao:
            'Consulta agendada: $pacienteNome com $profissionalNome em $dataHora',
        dadosExtras: {
          'consulta_id': consultaId,
          'paciente': pacienteNome,
          'profissional': profissionalNome,
          'data_hora': dataHora,
          if (iniciadoPor != null) 'iniciado_por': iniciadoPor,
        },
      );

  Future<void> logCancelamento({
    required String consultaId,
    String? motivo,
    String? iniciadoPor,
  }) =>
      log(
        tipoEvento: TipoEvento.cancelamento,
        descricao: 'Consulta cancelada. ID: $consultaId'
            '${motivo != null ? '. Motivo: $motivo' : ''}',
        dadosExtras: {
          'consulta_id': consultaId,
          if (motivo != null) 'motivo': motivo,
          if (iniciadoPor != null) 'iniciado_por': iniciadoPor,
        },
      );

  Future<void> logReagendamento({
    required String consultaId,
    required String novaDataHora,
    String? iniciadoPor,
  }) =>
      log(
        tipoEvento: TipoEvento.reagendamento,
        descricao: 'Consulta reagendada para $novaDataHora. ID: $consultaId',
        dadosExtras: {
          'consulta_id': consultaId,
          'nova_data_hora': novaDataHora,
          if (iniciadoPor != null) 'iniciado_por': iniciadoPor,
        },
      );

  Future<void> logConfirmacaoConsulta({required String consultaId}) =>
      log(
        tipoEvento: TipoEvento.confirmacaoConsulta,
        descricao: 'Presença confirmada na consulta. ID: $consultaId',
        dadosExtras: {'consulta_id': consultaId},
      );

  Future<void> logCheckout({
    required String consultaId,
    required String pacienteNome,
  }) =>
      log(
        tipoEvento: TipoEvento.checkout,
        descricao: 'Checkout realizado para $pacienteNome. ID: $consultaId',
        dadosExtras: {'consulta_id': consultaId, 'paciente': pacienteNome},
      );

  Future<void> logRecomendacaoEnviada({
    required String pacienteId,
    required int qtdExercicios,
    required String consultaId,
  }) =>
      log(
        tipoEvento: TipoEvento.recomendacaoEnviada,
        descricao:
            '$qtdExercicios exercício(s) recomendado(s) ao paciente. Consulta: $consultaId',
        dadosExtras: {
          'paciente_id': pacienteId,
          'qtd_exercicios': qtdExercicios,
          'consulta_id': consultaId,
        },
      );

  // ── Leitura para o admin ─────────────────────────────────────────────────

  /// Busca logs de auditoria com filtros opcionais.
  /// Retorna até [limite] registros, paginados por [offset].
  Future<Map<String, dynamic>> getLogs({
    String? idUsuario,
    String? tipoEvento,
    DateTime? dataInicio,
    DateTime? dataFim,
    int limite = 100,
    int offset = 0,
  }) async {
    try {
      var query = _sb
          .from('log_auditoria')
          .select('*, usuario:id_usuario(nome, email, id_permissao)');

      if (idUsuario != null && idUsuario.isNotEmpty) {
        query = query.eq('id_usuario', idUsuario);
      }
      if (tipoEvento != null && tipoEvento.isNotEmpty) {
        query = query.eq('tipo_evento', tipoEvento);
      }
      if (dataInicio != null) {
        query = query.gte('created_at', dataInicio.toIso8601String());
      }
      if (dataFim != null) {
        query = query.lte('created_at', dataFim.toIso8601String());
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limite - 1);

      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao buscar logs: $e'};
    }
  }

  /// Converte os logs em formato CSV para exportação.
  static String paraCSV(List<dynamic> logs) {
    final buffer = StringBuffer();
    // Cabeçalho
    buffer.writeln(
        'ID,Data/Hora,Tipo Evento,Descrição,Usuário,Email,Dados Extras');

    for (final log in logs) {
      final id = log['id'] ?? '';
      final dt = log['created_at'] != null
          ? _formatarData(log['created_at'] as String)
          : '';
      final tipo = _escapeCsv(log['tipo_evento'] ?? '');
      final desc = _escapeCsv(log['descricao'] ?? '');
      final usuario = log['usuario'];
      final nomeUsuario = _escapeCsv(usuario?['nome'] ?? 'Sistema');
      final emailUsuario = _escapeCsv(usuario?['email'] ?? '');
      final extras = _escapeCsv(
          log['dados_extras'] != null ? log['dados_extras'].toString() : '');

      buffer.writeln(
          '"$id","$dt","$tipo","$desc","$nomeUsuario","$emailUsuario","$extras"');
    }

    return buffer.toString();
  }

  static String _escapeCsv(String s) =>
      s.replaceAll('"', '""');

  static String _formatarData(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
