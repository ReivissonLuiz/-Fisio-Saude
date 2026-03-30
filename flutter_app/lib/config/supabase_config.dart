/// supabase_config.dart
/// ConfiguraÃ§Ãµes de conexÃ£o com o Supabase â€” +FÃ­sio +SaÃºde
///
/// âœ… SEGURO para commitar: contÃ©m apenas a `anonKey` (chave pÃºblica).
/// A seguranÃ§a dos dados Ã© garantida pelas polÃ­ticas RLS no Supabase.
/// A `service_role` key NUNCA deve aparecer aqui.
library;

class SupabaseConfig {
  /// URL do projeto Supabase
  static const String url = 'https://nkicptibdnuygxxnoaof.supabase.co';

  /// Chave pÃºblica (anon) â€” segura para uso no frontend
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5raWNwdGliZG51eWd4eG5vYW9mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzY0NzEsImV4cCI6MjA5MDA1MjQ3MX0'
      '.Q-pe9YZyLcxBruH4iwfD41Xix48u0fk-NvaMKb97xIk';
}
