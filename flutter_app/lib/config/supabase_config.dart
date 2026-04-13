/// Configurações de conexão com o Supabase — +Fisio +Saúde
///
/// ✅ SEGURO para commitar: contém apenas a chave pública (publishable).
/// A segurança dos dados é garantida pelas políticas RLS no Supabase.
/// A secret key NUNCA deve aparecer aqui.
library;

class SupabaseConfig {
  /// URL do projeto Supabase
  static const String url = 'https://nkicptibdnuygxxnoaof.supabase.co';

  /// Chave pública (publishable) — segura para uso no frontend
  static const String anonKey =
      'sb_publishable_h4snGK2lw-KyNdizGFBakA_WgL7xtl_';
}
