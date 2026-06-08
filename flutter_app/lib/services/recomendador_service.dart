/// recomendador_service.dart
/// Motor de Recomendação ML — +Físio +Saúde
///
/// Porta Dart do algoritmo Python (recomendador.py).
/// Implementa Content-Based Filtering com TF-IDF + Cosine Similarity
/// 100% localmente, sem servidor externo, sem internet.
///
/// Uso:
///   final rec = RecomendadorService();
///   await rec.inicializar();
///   final exercicios = rec.recomendar(sintomas: [...], topN: 5);
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mapeamento: regiões do app → termos do catálogo
// Espelho exato do MAPA_REGIOES do recomendador.py
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _mapaRegioes = {
  'cervical (pescoco)': 'cervical pescoco coluna isometrico',
  'cervical': 'cervical pescoco coluna isometrico',
  'pescoco': 'cervical pescoco coluna isometrico',
  'ombro direito': 'ombro direito manguito abducao flexao braco',
  'ombro esquerdo': 'ombro esquerdo manguito abducao flexao braco',
  'ombro': 'ombro manguito abducao flexao braco',
  'coluna lombar': 'coluna lombar inclinacao lateral isometrico',
  'coluna toracica': 'coluna toracica postura isometrico lateral',
  'coluna': 'coluna lombar postura isometrico',
  'quadril': 'quadril coluna lombar mobilidade fortalecimento',
  'joelho direito': 'joelho direito reabilitacao fortalecimento',
  'joelho esquerdo': 'joelho esquerdo reabilitacao fortalecimento',
  'joelho': 'joelho reabilitacao fortalecimento',
  'tornozelo / pe': 'tornozelo pe flexao plantar panturrilha bilateral',
  'tornozelo': 'tornozelo pe flexao plantar panturrilha bilateral',
  'pe': 'tornozelo pe flexao plantar panturrilha bilateral',
  'braco / cotovelo': 'braco cotovelo ombro circunducao',
  'braco': 'braco ombro cotovelo circunducao',
  'cotovelo': 'braco cotovelo punho epicondilite',
  'punho / mao': 'punho mao antebraco extensao bola preensao',
  'punho': 'punho mao antebraco extensao bola preensao',
  'mao': 'mao punho antebraco bola preensao dedos',
  'outra regiao': 'mobilidade fortalecimento reabilitacao',
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de texto
// ─────────────────────────────────────────────────────────────────────────────

/// Remove acentos e converte para minúsculas — espelho de _normalizar_texto().
String _normalizar(String texto) {
  // Decomposição Unicode manual para os caracteres comuns do PT-BR
  const acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a',
    'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
    'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i',
    'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
    'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u',
    'Ç': 'c', 'Ñ': 'n',
  };
  final buf = StringBuffer();
  for (final ch in texto.split('')) {
    buf.write(acentos[ch] ?? ch.toLowerCase());
  }
  return buf.toString().trim();
}

/// Tokeniza um texto normalizado em palavras únicas (sem stop-words de ruído).
List<String> _tokenizar(String texto) {
  return texto
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// TF-IDF implementado em Dart puro
// ─────────────────────────────────────────────────────────────────────────────

class _TfidfVectorizer {
  final int ngramMax; // 1=unigramas, 2=bigramas
  final bool sublinearTf;

  late List<String> _vocabulario; // lista ordenada de termos
  late Map<String, int> _termIndex; // termo → índice no vetor
  late Map<String, double> _idf; // termo → valor IDF

  _TfidfVectorizer({this.ngramMax = 2, this.sublinearTf = true});

  /// Extrai n-gramas de uma lista de tokens.
  List<String> _ngrams(List<String> tokens) {
    final result = <String>[...tokens]; // unigramas sempre incluídos
    if (ngramMax >= 2) {
      for (var i = 0; i < tokens.length - 1; i++) {
        result.add('${tokens[i]} ${tokens[i + 1]}');
      }
    }
    return result;
  }

  /// Treina o vectorizer com uma lista de documentos (textos normalizados).
  void fit(List<String> documentos) {
    final n = documentos.length;
    // df: quantos documentos contêm cada termo
    final df = <String, int>{};

    for (final doc in documentos) {
      final tokens = _tokenizar(doc);
      final termos = _ngrams(tokens).toSet();
      for (final t in termos) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }

    // IDF = log((1 + n) / (1 + df)) + 1  (fórmula scikit-learn smooth_idf)
    _idf = {};
    for (final entry in df.entries) {
      _idf[entry.key] = math.log((1 + n) / (1 + entry.value)) + 1.0;
    }

    _vocabulario = _idf.keys.toList()..sort();
    _termIndex = {for (var i = 0; i < _vocabulario.length; i++) _vocabulario[i]: i};
  }

  /// Transforma um documento em vetor TF-IDF normalizado (L2).
  List<double> transform(String documento) {
    final tokens = _tokenizar(documento);
    final termos = _ngrams(tokens);

    // Contagem de termos
    final tf = <String, int>{};
    for (final t in termos) {
      if (_termIndex.containsKey(t)) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
    }

    // Monta vetor esparso como lista densa
    final vetor = List<double>.filled(_vocabulario.length, 0.0);
    for (final entry in tf.entries) {
      final idx = _termIndex[entry.key];
      if (idx == null) continue;
      final tfVal = sublinearTf
          ? 1.0 + math.log(entry.value.toDouble())
          : entry.value.toDouble();
      vetor[idx] = tfVal * (_idf[entry.key] ?? 0.0);
    }

    // Normalização L2
    final norma = math.sqrt(vetor.fold(0.0, (s, v) => s + v * v));
    if (norma > 0) {
      for (var i = 0; i < vetor.length; i++) {
        vetor[i] /= norma;
      }
    }

    return vetor;
  }

  /// Transforma múltiplos documentos.
  List<List<double>> transformAll(List<String> documentos) =>
      documentos.map(transform).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Cosine Similarity
// ─────────────────────────────────────────────────────────────────────────────

/// Calcula a similaridade de cosseno entre dois vetores normalizados (L2).
/// Como ambos já são normalizados, é apenas o produto escalar.
double _cosineSimilarity(List<double> a, List<double> b) {
  assert(a.length == b.length, 'Vetores de tamanho diferente');
  var dot = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviço principal
// ─────────────────────────────────────────────────────────────────────────────

class RecomendadorService {
  static final RecomendadorService _instance = RecomendadorService._internal();
  factory RecomendadorService() => _instance;
  RecomendadorService._internal();

  // ── IDs de exercícios com vídeos problemáticos (erro de processamento
  //    no Google Drive). Adicione aqui os IDs conforme forem identificados.
  static const Set<String> _idsBloqueados = {
    // Exemplo: 'shoulder_abduction_left',
    // Adicione os IDs dos vídeos com erro de processamento aqui:
  };

  List<Map<String, dynamic>> _catalogo = [];
  late _TfidfVectorizer _vectorizer;
  late List<List<double>> _matrizTfidf; // um vetor por exercício
  late List<String> _textosTfidf;       // texto gerado para cada exercício
  bool _inicializado = false;

  bool get inicializado => _inicializado;

  /// Carrega o catálogo e treina o modelo. Deve ser chamado uma única vez.
  Future<void> inicializar() async {
    if (_inicializado) return;

    final jsonStr =
        await rootBundle.loadString('assets/catalogo_exercicios.json');
    final lista = jsonDecode(jsonStr) as List;

    // Carrega o catálogo excluindo exercícios com vídeos problemáticos
    _catalogo = lista
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => !_idsBloqueados.contains(e['id'] as String? ?? ''))
        .toList();

    // Monta texto TF-IDF para cada exercício (espelho de _montar_texto_tfidf)
    _textosTfidf = _catalogo.map(_montarTextoExercicio).toList();

    _vectorizer = _TfidfVectorizer(ngramMax: 2, sublinearTf: true);
    _vectorizer.fit(_textosTfidf);
    _matrizTfidf = _vectorizer.transformAll(_textosTfidf);

    _inicializado = true;
  }

  // ── Textos e perfil ───────────────────────────────────────────────────────

  /// Constrói texto TF-IDF de um exercício — espelho de _montar_texto_tfidf().
  String _montarTextoExercicio(Map<String, dynamic> ex) {
    final nomePt = ex['nome_pt'] as String? ?? '';
    final regiao = ex['regiao_corporal'] as String? ?? '';
    final descricao = ex['descricao'] as String? ?? '';
    final palavras = ex['palavras_chave'] as String? ?? '';
    final lateralidade = ex['lateralidade'] as String? ?? '';
    final nivel = ex['nivel_dificuldade'] as String? ?? '';
    final indicacoes =
        (ex['indicacoes'] as List?)?.map((e) => e.toString()).join(' ') ?? '';

    final partes = [
      '$nomePt $nomePt $nomePt',       // peso 3×
      '$regiao $regiao $regiao',        // peso 3×
      '$descricao $descricao',          // peso 2×
      '$palavras $palavras',            // peso 2×
      lateralidade,
      nivel,
      indicacoes,
    ];
    return _normalizar(partes.join(' '));
  }

  /// Constrói perfil textual do paciente — espelho de _montar_perfil_paciente().
  String _montarPerfilPaciente(List<Map<String, dynamic>> sintomas) {
    final partes = <String>[];

    for (final s in sintomas) {
      final descricao = s['descricao'] as String? ?? '';
      final categoria = s['categoria'] as String? ?? '';
      final intensidade = (s['intensidade'] as num?)?.toInt() ?? 5;

      final catNorm = _normalizar(categoria);
      final termosRegiao = _mapaRegioes[catNorm] ?? catNorm;

      // Peso proporcional à intensidade (espelho de peso_intensidade = max(1, int//3))
      final pesoIntensidade = math.max(1, intensidade ~/ 3);
      final descNorm = _normalizar(descricao);

      partes.add('$termosRegiao $termosRegiao $termosRegiao'); // região: 3×
      for (var i = 0; i < pesoIntensidade; i++) {
        partes.add(descNorm); // descrição proporcional à dor
      }
      partes.add(descNorm); // adiciona uma vez extra
    }

    return _normalizar(partes.join(' '));
  }

  // ── API pública ───────────────────────────────────────────────────────────

  /// Retorna os [topN] exercícios mais adequados para o paciente.
  ///
  /// [sintomas] é uma lista de maps com chaves: descricao, categoria, intensidade.
  /// [filtrarRegiao] aplica boost de 80% para exercícios da região indicada.
  List<Map<String, dynamic>> recomendar({
    required List<Map<String, dynamic>> sintomas,
    int topN = 5,
    String? filtrarRegiao,
  }) {
    assert(_inicializado, 'Chame inicializar() antes de recomendar()');
    if (sintomas.isEmpty) return [];

    // Vetoriza o perfil do paciente
    final perfilTexto = _montarPerfilPaciente(sintomas);
    final vetorPerfil = _vectorizer.transform(perfilTexto);

    // Calcula scores de similaridade para cada exercício
    final scores = List<double>.generate(
      _catalogo.length,
      (i) => _cosineSimilarity(vetorPerfil, _matrizTfidf[i]),
    );

    // Aplica boost de 80% para exercícios da região predominante
    if (filtrarRegiao != null && filtrarRegiao.isNotEmpty) {
      final regiaoNorm = _normalizar(filtrarRegiao);
      final palavrasRegiao = regiaoNorm.split(' ').where((w) => w.isNotEmpty).toList();

      for (var i = 0; i < _catalogo.length; i++) {
        final ex = _catalogo[i];
        final regiaoEx = _normalizar(ex['regiao_corporal'] as String? ?? '');
        final regiaoDisplay = _normalizar(ex['regiao_display'] as String? ?? '');

        final match = regiaoNorm.isEmpty ||
            regiaoEx.contains(regiaoNorm) ||
            regiaoDisplay.contains(regiaoNorm) ||
            palavrasRegiao.any((w) => regiaoEx.contains(w));

        if (match) scores[i] *= 1.8;
      }
    }

    // Ordena por score e pega os top-N
    final indices = List<int>.generate(_catalogo.length, (i) => i);
    indices.sort((a, b) => scores[b].compareTo(scores[a]));
    final topIndices = indices.take(topN).toList();

    return topIndices.map((i) {
      final ex = _catalogo[i];
      return {
        'id': ex['id'],
        'pasta_kaggle': ex['pasta_kaggle'],
        'nome_pt': ex['nome_pt'],
        'nome_en': ex['nome_en'],
        'regiao_display': ex['regiao_display'],
        'descricao': ex['descricao'],
        'nivel_dificuldade': ex['nivel_dificuldade'],
        'duracao_min': (ex['duracao_min'] as num).toInt(),
        'url_video': ex['url_video'], // apenas 1 URL — url_videos removido
        'lateralidade': ex['lateralidade'],
        'score_similaridade': double.parse(scores[i].toStringAsFixed(4)),
        'indicacoes': ex['indicacoes'] ?? [],
      };
    }).toList();
  }

  /// Retorna o catálogo completo de exercícios.
  List<Map<String, dynamic>> listarCatalogo() => List.unmodifiable(_catalogo);

  /// Busca um exercício específico pelo ID.
  Map<String, dynamic>? buscarPorId(String id) {
    try {
      return _catalogo.firstWhere((ex) => ex['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
