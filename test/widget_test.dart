import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_leche_app/models/ganadero.dart';
import 'package:scanner_leche_app/services/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await DatabaseHelper.instance.init();
    await DatabaseHelper.instance.resetStorage();
  });

  test('permite agregar y eliminar ganaderos desde la base de datos local', () async {
    final ganadero = Ganadero(
      id: '1',
      nombre: 'Carlos',
      apellidoPaterno: 'García',
      apellidoMaterno: 'López',
      rancho: 'Rancho San José',
      tel: '3411234567',
    );

    await DatabaseHelper.instance.insertGanadero(ganadero);

    final saved = await DatabaseHelper.instance.getGanaderos();
    expect(saved, hasLength(1));
    expect(saved.first.nombreCompleto, 'Carlos García López');
    expect(saved.first.rancho, 'Rancho San José');

    await DatabaseHelper.instance.deleteGanadero(saved.first.id);

    final afterDelete = await DatabaseHelper.instance.getGanaderos();
    expect(afterDelete, isEmpty);
  });
}
