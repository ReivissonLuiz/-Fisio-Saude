/// validators.dart — +Físio +Saúde
/// Funções de validação reutilizáveis entre as telas de cadastro.
library;

class Validators {
  Validators._();

  /// Valida CPF usando o algoritmo oficial dos dígitos verificadores.
  /// Retorna null se válido, ou mensagem de erro se inválido.
  static String? cpf(String? value) {
    if (value == null) return 'CPF inválido.';

    final numbers = value.replaceAll(RegExp(r'\D'), '');
    if (numbers.length != 11) return 'CPF inválido.';

    // CPFs com todos os dígitos iguais são inválidos (ex: 111.111.111-11)
    if (RegExp(r'^(\d)\1{10}$').hasMatch(numbers)) return 'CPF inválido.';

    // Calcula o 1º dígito verificador
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(numbers[i]) * (10 - i);
    }
    int remainder = sum % 11;
    final int digit1 = remainder < 2 ? 0 : 11 - remainder;
    if (int.parse(numbers[9]) != digit1) return 'CPF inválido.';

    // Calcula o 2º dígito verificador
    sum = 0;
    for (int i = 0; i < 10; i++) {
      sum += int.parse(numbers[i]) * (11 - i);
    }
    remainder = sum % 11;
    final int digit2 = remainder < 2 ? 0 : 11 - remainder;
    if (int.parse(numbers[10]) != digit2) return 'CPF inválido.';

    return null; // ✅ CPF válido
  }

  /// Valida CREFITO conforme a categoria profissional:
  ///   Fisioterapeuta:        0000000-F   (7 dígitos + -F)
  ///   Terapeuta Ocupacional: 0000000-TO  (7 dígitos + -TO)
  /// Retorna null se válido, ou mensagem de erro se inválido.
  static String? crefito(String? value) {
    if (value == null || value.trim().isEmpty) return 'Informe seu CREFITO.';
    final v = value.trim().toUpperCase();
    final regExp = RegExp(r'^\d{7}-(?:F|TO)$');
    if (!regExp.hasMatch(v)) {
      return 'CREFITO inválido. Ex: 0123456-F ou 0123456-TO';
    }
    return null; // ✅ CREFITO válido
  }

  /// Valida a data de nascimento no formato DD/MM/AAAA.
  ///   - A data deve ser uma data real (ex: 30/02 é inválido)
  ///   - O usuário deve ter entre 1 e 120 anos
  ///   - Não aceita datas futuras
  /// Retorna null se válido, ou mensagem de erro se inválido.
  static String? dataNascimento(String? value) {
    if (value == null || value.length != 10) return 'Data inválida.';
    try {
      final parts = value.split('/');
      if (parts.length != 3) return 'Data inválida.';

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      // Verifica se a data é real (DateTime normaliza datas inválidas como 30/02)
      final dataNasc = DateTime(year, month, day);
      if (dataNasc.day != day || dataNasc.month != month || dataNasc.year != year) {
        return 'Data inválida (dia ou mês inexistente).';
      }

      final hoje = DateTime.now();
      final hojeDate = DateTime(hoje.year, hoje.month, hoje.day);

      // Não aceita datas futuras
      if (dataNasc.isAfter(hojeDate)) {
        return 'Data de nascimento não pode ser futura.';
      }

      // Calcula a idade exata
      int idade = hoje.year - dataNasc.year;
      if (hoje.month < dataNasc.month ||
          (hoje.month == dataNasc.month && hoje.day < dataNasc.day)) {
        idade--;
      }

      if (idade < 1) return 'Idade mínima é 1 ano.';
      if (idade > 120) return 'Idade máxima permitida é 120 anos.';
    } catch (e) {
      return 'Data inválida.';
    }
    return null; // ✅ Data válida
  }

  /// Valida CEP: se preenchido, deve ter exatamente 8 dígitos.
  /// Retorna null se válido ou vazio (campo opcional), erro se preenchido incorretamente.
  static String? cepOpcional(String? value, String unmaskedText) {
    if (unmaskedText.isEmpty) return null; // campo opcional, vazio = ok
    if (unmaskedText.length != 8) return 'CEP inválido.';
    return null;
  }

  /// Valida CEP obrigatório: deve ter exatamente 8 dígitos.
  static String? cepObrigatorio(String? value, String unmaskedText) {
    if (unmaskedText.length != 8) return 'CEP inválido.';
    return null;
  }
}
