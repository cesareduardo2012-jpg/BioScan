// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final salt = '7_gmHT-s25i_2qh3C69s1w==';
  final password = 'admin123';
  final bytes = utf8.encode('$salt:$password');
  final digest = sha256.convert(bytes);
  print('Hash for $password: $digest');
}
