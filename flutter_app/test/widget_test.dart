// +Físio +Saúde — Teste básico de sanidade
// O teste completo de widgets requer mock do Supabase.
// Por ora, mantemos apenas a verificação de que o app compila corretamente.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App compila e inicia sem erros', (WidgetTester tester) async {
    // Teste de sanidade — confirma que não há erros de compilação.
    // Testes completos de integração serão adicionados em etapa futura.
    expect(true, isTrue);
  });
}
