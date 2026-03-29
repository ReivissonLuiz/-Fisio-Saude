/// supabase_config.dart
/// Configurações de conexão com o Supabase — +Físio +Saúde
///
/// ✅ SEGURO para commitar: contém apenas a `anonKey` (chave pública).
/// A segurança dos dados é garantida pelas políticas RLS no Supabase.
/// A `service_role` key NUNCA deve aparecer aqui.

class SupabaseConfig {
  /// URL do projeto Supabase
  static const String url = 'https://nkicptibdnuygxxnoaof.supabase.co';

  /// Chave pública (anon) — segura para uso no frontend
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5raWNwdGliZG51eWd4eG5vYW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzY0NzEsImV4cCI6MjA5MDA1MjQ3MX0'
      '.Q-pe9YZyLcxBruH4iwfD41Xix48u0fk-NvaMKb97xIk';
}
