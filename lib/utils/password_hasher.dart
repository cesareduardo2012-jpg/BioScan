import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  /// Generates a random salt string of the given length.
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Hashes a plain password with the given salt using SHA-256.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain password matches a stored hash and salt.
  static bool verifyPassword(String password, String salt, String expectedHash) {
    final hash = hashPassword(password, salt);
    return hash == expectedHash;
  }
}
