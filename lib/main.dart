import 'package:flutter/material.dart';
import 'app/app.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La inicialización pesada (ServiceLocator, DB, Supabase) se movió 
  // a SplashScreen para no bloquear el primer frame.
  runApp(const BioScanApp());
}
