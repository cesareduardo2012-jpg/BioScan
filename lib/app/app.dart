import 'package:flutter/material.dart';
import 'navigation.dart';

class BioScanApp extends StatelessWidget {
  const BioScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const MainNavigation(),
    );
  }
}
