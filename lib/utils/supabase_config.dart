import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://dgdtfxzlrpjqqyqxloyp.supabase.co';
  static const String anonKey = 'sb_publishable_Nm-428Sy_kwdTUK_adweBg__y3id053';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase inicializado correctamente en: $url');
    } catch (e) {
      debugPrint('Error al inicializar Supabase: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
