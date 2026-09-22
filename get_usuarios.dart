// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://dgdtfxzlrpjqqyqxloyp.supabase.co', 'sb_publishable_Nm-428Sy_kwdTUK_adweBg__y3id053');
  try {
    final response = await client.from('usuarios').select('username, correo, rol');
    print('Usuarios en la BD:');
    for (var u in response) {
      print('  - Username: ${u['username']} | Correo: ${u['correo']} | Rol: ${u['rol']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
