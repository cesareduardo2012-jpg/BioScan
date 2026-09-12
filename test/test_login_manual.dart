import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scanner_leche_app/database/app_database.dart';
import 'package:scanner_leche_app/utils/service_locator.dart';

void main() {
  test('Test login logic', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    await ServiceLocator.init();

    try {
      final user = await ServiceLocator.authService.login('admin', 'admin123');
      print('LOGIN SUCCESSFUL: ${user.username}');
    } catch (e) {
      print('LOGIN FAILED: $e');
    }
  });
}
