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
