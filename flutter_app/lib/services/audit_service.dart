/// audit_service.dart
/// Serviço centralizado de auditoria do +Físio +Saúde.
/// Em conformidade com a LGPD e boas práticas de segurança cibernética.
library;

import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get _sb => Supabase.instance.client;

// ── Tipos de evento (Namespaced Dot-Notation) ──────────────────────────────
class TipoEvento {
  // Autenticação
  static const String loginSucesso        = 'auth.login_sucesso';
  static const String loginFalha          = 'auth.login_falha';
  static const String logout              = 'auth.logout';

  // Navegação
  static const String navegacaoAba        = 'usuario.navegacao_aba';

  // Gestão de Contas e Perfis
  static const String criarConta          = 'usuario.criar';
  static const String desativarConta         = 'usuario.desativar';
  static const String ativarConta            = 'usuario.ativar';
  static const String excluirConta           = 'usuario.excluir';
  static const String alteracaoPermissao     = 'usuario.permissao';
  static const String updatePerfil        = 'usuario.update_perfil';
  static const String updateSenha         = 'usuario.update_senha';

  // Clínico e Consultas
  static const String agendamento         = 'consulta.agendar';
  static const String cancelamento        = 'consulta.cancelar';
  static const String reagendamento       = 'consulta.reagendar';
  static const String confirmacaoConsulta = 'consulta.confirmar';
  static const String checkout            = 'consulta.checkout';
  static const String recomendacaoEnviada = 'clinico.recomendar_exercicio';
  static const String visualizarProntuario = 'clinico.visualizar_prontuario';
}

// ── Serviço ──────────────────────────────────────────────────────────────────
class AuditService {
  static final AuditService instance = AuditService._();
  AuditService._();

  String? _usuarioId;

  // Session ID único gerado a cada inicialização da aplicação (tempo de execução do app)
  final String _sessionId =
      'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';

  /// Define o ID do usuário logado.
  void setUsuario(String? id) => _usuarioId = id;

  /// Retorna o ID do usuário atualmente configurado.
  String? get usuarioId => _usuarioId;

  /// Registra um evento de auditoria completo na tabela `log_auditoria` do Supabase.
  Future<void> log({
    required String tipoEvento,
    required String descricao,
    String? idUsuarioAlvo,
    String severidade = 'INFO',
    String? entidadeAfetada,
    String? idEntidadeAfetada,
    Map<String, dynamic>? estadoAnterior,
    Map<String, dynamic>? estadoPosterior,
    Map<String, dynamic>? dadosExtras,
  }) async {
    final idParaLog = idUsuarioAlvo ?? _usuarioId;

    try {
      await _sb.from('log_auditoria').insert({
        if (idParaLog != null) 'id_usuario': idParaLog,
        'tipo_evento': tipoEvento,
        'descricao': descricao,
        'session_id': _sessionId,
        'severidade': severidade,
        if (entidadeAfetada != null) 'entidade_afetada': entidadeAfetada,
        if (idEntidadeAfetada != null) 'id_entidade_afetada': idEntidadeAfetada,
        if (estadoAnterior != null) 'estado_anterior': estadoAnterior,
        if (estadoPosterior != null) 'estado_posterior': estadoPosterior,
        if (dadosExtras != null) 'dados_extras': dadosExtras,
      });
    } catch (e) {
      // Falha no log nunca bloqueia o fluxo principal, mas imprime em debug
      debugPrint('Erro ao registrar log de auditoria: $e');
    }
  }

  // ── Atalhos e Helpers (Anonimizados e em Conformidade com LGPD) ──────────────

  Future<void> logLogin({
    required String email,
    required bool sucesso,
    String? mensagemErro,
    String? idUsuarioAlvo,
  }) =>
      log(
        tipoEvento: sucesso ? TipoEvento.loginSucesso : TipoEvento.loginFalha,
        descricao: sucesso ? 'Login bem-sucedido' : 'Tentativa de login falhou',
        idUsuarioAlvo: idUsuarioAlvo,
        severidade: sucesso ? 'INFO' : 'WARN',
        entidadeAfetada: 'usuario',
        dadosExtras: {
          'email_mascarado': _mascararEmail(email),
          if (!sucesso && mensagemErro != null) 'erro': mensagemErro,
        },
      );

  Future<void> logLogout() => log(
        tipoEvento: TipoEvento.logout,
        descricao: 'Sessão de usuário encerrada',
        severidade: 'INFO',
      );

  Future<void> logNavegacaoAba({
    required String nomeAba,
    required String perfil,
  }) =>
      log(
        tipoEvento: TipoEvento.navegacaoAba,
        descricao: 'Acesso à aba do sistema',
        severidade: 'INFO',
        dadosExtras: {'aba': nomeAba, 'perfil': perfil},
      );

  Future<void> logCreateConta({
    required String tipo,
    required String email,
    String? idUsuarioAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.criarConta,
        descricao: 'Criação de nova conta de usuário',
        idUsuarioAlvo: idUsuarioAlvo,
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idUsuarioAlvo,
        severidade: 'INFO',
        dadosExtras: {
          'tipo_perfil': tipo,
          'email_mascarado': _mascararEmail(email),
        },
      );

  Future<void> logDesativarConta({
    required String idAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.desativarConta,
        descricao: 'Conta de usuário desativada',
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idAlvo,
        severidade: 'WARN',
        dadosExtras: {'id_alvo': idAlvo},
      );

  Future<void> logAtivarConta({
    required String idAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.ativarConta,
        descricao: 'Conta de usuário reativada',
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idAlvo,
        severidade: 'INFO',
        dadosExtras: {'id_alvo': idAlvo},
      );

  Future<void> logExcluirConta({
    required String idAlvo,
    required String emailAlvo,
  }) =>
      log(
        tipoEvento: TipoEvento.excluirConta,
        descricao: 'Conta de usuário excluída permanentemente',
        severidade: 'CRITICAL',
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idAlvo,
        dadosExtras: {
          'id_alvo': idAlvo,
          'email_mascarado': _mascararEmail(emailAlvo),
        },
      );

  Future<void> logAlteracaoPermissao({
    required String idAlvo,
    required int permissaoAnterior,
    required int novaPermissao,
  }) =>
      log(
        tipoEvento: TipoEvento.alteracaoPermissao,
        descricao: 'Nível de permissão de acesso do usuário alterado',
        severidade: 'WARN',
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idAlvo,
        estadoAnterior: {'id_permissao': permissaoAnterior},
        estadoPosterior: {'id_permissao': novaPermissao},
      );

  Future<void> logUpdatePerfil({
    required String idUsuarioAlvo,
    required List<String> camposAlterados,
    Map<String, dynamic>? valoresAnteriores,
    Map<String, dynamic>? valoresPosteriores,
  }) =>
      log(
        tipoEvento: TipoEvento.updatePerfil,
        descricao: 'Perfil de usuário atualizado',
        idUsuarioAlvo: idUsuarioAlvo,
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idUsuarioAlvo,
        severidade: 'INFO',
        estadoAnterior: valoresAnteriores,
        estadoPosterior: valoresPosteriores,
        dadosExtras: {'campos_alterados': camposAlterados},
      );

  Future<void> logUpdateSenha({required String idUsuarioAlvo}) => log(
        tipoEvento: TipoEvento.updateSenha,
        descricao: 'Senha do usuário alterada com sucesso',
        idUsuarioAlvo: idUsuarioAlvo,
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: idUsuarioAlvo,
        severidade: 'WARN',
      );

  Future<void> logAgendamento({
    required String consultaId,
    required String pacienteId,
    required String profissionalId,
    required String dataHora,
    String? iniciadoPor,
  }) =>
      log(
        tipoEvento: TipoEvento.agendamento,
        descricao: 'Nova consulta médica agendada',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'INFO',
        dadosExtras: {
          'consulta_id': consultaId,
          'paciente_id': pacienteId,
          'profissional_id': profissionalId,
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
        descricao: 'Consulta clínica cancelada',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'WARN',
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
        descricao: 'Consulta clínica reagendada',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'INFO',
        dadosExtras: {
          'consulta_id': consultaId,
          'nova_data_hora': novaDataHora,
          if (iniciadoPor != null) 'iniciado_por': iniciadoPor,
        },
      );

  Future<void> logConfirmacaoConsulta({required String consultaId}) => log(
        tipoEvento: TipoEvento.confirmacaoConsulta,
        descricao: 'Presença em consulta confirmada pelo profissional',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'INFO',
      );

  Future<void> logCheckout({required String consultaId}) => log(
        tipoEvento: TipoEvento.checkout,
        descricao: 'Checkout de atendimento clínico finalizado',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'INFO',
      );

  Future<void> logRecomendacaoEnviada({
    required String pacienteId,
    required int qtdExercicios,
    required String consultaId,
  }) =>
      log(
        tipoEvento: TipoEvento.recomendacaoEnviada,
        descricao: 'Recomendação terapêutica enviada ao paciente',
        entidadeAfetada: 'consulta',
        idEntidadeAfetada: consultaId,
        severidade: 'INFO',
        dadosExtras: {
          'paciente_id': pacienteId,
          'qtd_exercicios': qtdExercicios,
          'consulta_id': consultaId,
        },
      );

  /// Registra acesso e leitura de prontuário de saúde (Exigência crítica LGPD).
  Future<void> logVisualizarProntuario({
    required String pacienteId,
  }) =>
      log(
        tipoEvento: TipoEvento.visualizarProntuario,
        descricao: 'Visualização de ficha/prontuário clínico',
        entidadeAfetada: 'usuario',
        idEntidadeAfetada: pacienteId,
        severidade: 'INFO',
        dadosExtras: {'paciente_id': pacienteId},
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
        'ID,Data/Hora,Severidade,Tipo Evento,Descrição,Usuário,Email,Entidade,ID Entidade,Session ID,IP Address,User Agent,Dados Extras');

    for (final log in logs) {
      final id = log['id'] ?? '';
      final dt = log['created_at'] != null
          ? _formatarData(log['created_at'] as String)
          : '';
      final severidade = _escapeCsv(log['severidade'] ?? 'INFO');
      final tipo = _escapeCsv(log['tipo_evento'] ?? '');
      final desc = _escapeCsv(log['descricao'] ?? '');
      final usuario = log['usuario'];
      final nomeUsuario = _escapeCsv(usuario?['nome'] ?? 'Sistema');
      final emailUsuario = _escapeCsv(usuario?['email'] ?? '');
      final entidade = _escapeCsv(log['entidade_afetada'] ?? '');
      final idEntidade = _escapeCsv(log['id_entidade_afetada'] ?? '');
      final session = _escapeCsv(log['session_id'] ?? '');
      final ip = _escapeCsv(log['ip_address'] ?? '');
      final ua = _escapeCsv(log['user_agent'] ?? '');
      final extras = _escapeCsv(
          log['dados_extras'] != null ? log['dados_extras'].toString() : '');

      buffer.writeln(
          '"$id","$dt","$severidade","$tipo","$desc","$nomeUsuario","$emailUsuario","$entidade","$idEntidade","$session","$ip","$ua","$extras"');
    }

    return buffer.toString();
  }

  static String _escapeCsv(String s) => s.replaceAll('"', '""');

  static String _formatarData(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  /// Mascara o e-mail para não expor dados pessoais desnecessariamente nos logs
  /// Exemplo: willyrobertv.21@gmail.com -> wi**********21@gmail.com
  static String _mascararEmail(String email) {
    try {
      final partes = email.split('@');
      if (partes.length != 2) return email;
      final local = partes[0];
      final dominio = partes[1];
      if (local.length <= 2) return '${local[0]}*@$dominio';
      return '${local[0]}${local[1]}'
          '${'*' * (local.length - 4)}'
          '${local[local.length - 2]}${local[local.length - 1]}@$dominio';
    } catch (_) {
      return email;
    }
  }
}
