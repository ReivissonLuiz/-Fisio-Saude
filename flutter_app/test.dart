// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';
void main() async {
  final supabase = SupabaseClient('https://nkicptibdnuygxxnoaof.supabase.co', 'sb_publishable_h4snGK2lw-KyNdizGFBakA_WgL7xtl_');
  final msg = await supabase.from('mensagem').select('id_destinatario, id_remetente, conteudo').limit(5).order('created_at', ascending: false);
  print(msg);
  if (msg.isNotEmpty) {
      final rem = msg.first['id_remetente'];
      final des = msg.first['id_destinatario'];
      final u1 = await supabase.from('usuario').select('id, nome').eq('id', rem);
      final u2 = await supabase.from('usuario').select('id, nome').eq('id', des);
      print('Remetente (usuario): $u1');
      print('Destinatario (usuario): $u2');
  }
}
