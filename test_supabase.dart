// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://dgdtfxzlrpjqqyqxloyp.supabase.co', 'sb_publishable_Nm-428Sy_kwdTUK_adweBg__y3id053');
  try {
    print('Intentando iniciar sesión con Supabase...');
    // We don't have the user's password, we just want to see if the client throws a 4xx error or what
    final response = await client.auth.signInWithPassword(
      email: 'nonexistent@example.com',
      password: 'wrongpassword',
    );
    print('Success: ${response.user?.id}');
  } catch (e) {
    print('Supabase Exception: $e');
  }
}
