import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanner_leche_app/database/dao/usuario_dao.dart';
import 'package:scanner_leche_app/database/migrations/database_migrator.dart';
import 'package:scanner_leche_app/models/cliente.dart';
import 'package:scanner_leche_app/models/dispositivo.dart';
import 'package:scanner_leche_app/models/ganadero.dart';
import 'package:scanner_leche_app/models/medicion.dart';
import 'package:scanner_leche_app/models/usuario.dart';
import 'package:scanner_leche_app/services/auth_service.dart';
import 'package:scanner_leche_app/services/bluetooth_manager.dart';
import 'package:scanner_leche_app/utils/password_hasher.dart';
import 'package:scanner_leche_app/utils/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    await ServiceLocator.init();
    final db = ServiceLocator.database.db;
    await db.delete('mediciones');
    await db.delete('ganaderos');
    await db.delete('dispositivos');
    await db.delete('usuarios');
    await db.delete('clientes');

    // Re-insert default client for standard tests
    await ServiceLocator.clienteRepository.insertCliente(
      const Cliente(
        id: DatabaseMigrator.defaultClienteId,
        nombre: 'Cliente Predeterminado',
        empresa: 'Organización Inicial',
        telefono: '0000000000',
        correo: 'contacto@bioscan.com',
        fechaRegistro: '2026-01-01T00:00:00.000',
      ),
    );

    // Provision default initial admin for tests
    await ServiceLocator.authService.ensureDefaultAdmin();
  });

  group('Pruebas de Criptografía y Hasher de Contraseñas', () {
    test('Genera salts únicos y valida contraseñas hasheadas correctamente', () {
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();
      expect(salt1, isNot(equals(salt2)));

      final hash = PasswordHasher.hashPassword('miClave123', salt1);
      expect(PasswordHasher.verifyPassword('miClave123', salt1, hash), isTrue);
      expect(PasswordHasher.verifyPassword('claveIncorrecta', salt1, hash), isFalse);
    });
  });

  group('Pruebas del Parser BLE ESP32 (BluetoothManager)', () {
    test('Parsea correctamente Ph, T y D extrayendo siempre la última lectura recibida', () {
      final bt = BluetoothManager.instance;
      bt.parseIncomingData('Ph: 6.50, T: 20.0°C, D: 1.020\nPh: 6.72, T: 24.5°C, D: 1.031');

      expect(bt.phActual, '6.72');
      expect(bt.temperaturaActual, '24.5°C');
      expect(bt.densidadActual, '1.031');
    });
  });

  group('Pruebas de Autenticación y Servicio de Sesión (AuthService)', () {
    test('Inicia sesión correctamente con Administrador por defecto', () async {
      final user = await ServiceLocator.authService.login('admin', 'admin123');
      expect(user, isNotNull);
      expect(user.username, 'admin');
      expect(user.isAdmin, isTrue);
      expect(ServiceLocator.authService.isLoggedIn, isTrue);
    });

    test('Rechaza login con contraseña incorrecta', () async {
      expect(
        () => ServiceLocator.authService.login('admin', 'passwordErroneo'),
        throwsA(isA<AuthException>()),
      );
    });

    test('Rechaza login con usuario inexistente', () async {
      expect(
        () => ServiceLocator.authService.login('noexiste', 'admin123'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('Pruebas de Restricción Máximo 1 Operador por Cuenta', () {
    test('Permite crear el primer operador pero rechaza la creación de un segundo operador', () async {
      // Iniciar sesión como Administrador
      await ServiceLocator.authService.login('admin', 'admin123');

      // 1. Crear el primer operador
      final op1 = await ServiceLocator.authService.createOperator(
        username: 'operador01',
        nombre: 'Juan Operador',
        password: 'password123',
      );

      expect(op1, isNotNull);
      expect(op1.username, 'operador01');
      expect(op1.isOperador, isTrue);

      // 2. Intentar crear un segundo operador debe lanzar OperatorLimitExceededException
      expect(
        () => ServiceLocator.authService.createOperator(
          username: 'operador02',
          nombre: 'Pedro Operador',
          password: 'password456',
        ),
        throwsA(isA<OperatorLimitExceededException>()),
      );

      // 3. Permitir actualizar el nombre de usuario del operador
      await ServiceLocator.authService.updateOperator(
        operatorId: op1.id,
        username: 'operador_modificado',
        nombre: 'Juan Operador Editado',
      );

      final updatedOp = await ServiceLocator.usuarioRepository.getUsuarioById(op1.id);
      expect(updatedOp, isNotNull);
      expect(updatedOp!.username, 'operador_modificado');
      expect(updatedOp.nombre, 'Juan Operador Editado');
    });
  });

  group('Pruebas de Clientes', () {
    test('Crear, consultar, actualizar y desactivar cliente', () async {
      final cliente = const Cliente(
        id: 'cliente-100',
        nombre: 'Quesería Los Alpes',
        empresa: 'Los Alpes S.A.',
        telefono: '3311223344',
        correo: 'alpes@quesos.com',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );

      await ServiceLocator.clienteRepository.insertCliente(cliente);

      final fetched = await ServiceLocator.clienteRepository.getClienteById('cliente-100');
      expect(fetched, isNotNull);
      expect(fetched!.nombre, 'Quesería Los Alpes');
      expect(fetched.activo, isTrue);

      final updated = fetched.copyWith(nombre: 'Quesería Los Alpes Premium', activo: false);
      await ServiceLocator.clienteRepository.updateCliente(updated);

      final fetchedUpdated = await ServiceLocator.clienteRepository.getClienteById('cliente-100');
      expect(fetchedUpdated!.nombre, 'Quesería Los Alpes Premium');
      expect(fetchedUpdated.activo, isFalse);
    });
  });

  group('Pruebas de Usuarios', () {
    test('Crear y consultar usuarios por cliente', () async {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword('test1234', salt);

      final usuario = Usuario(
        id: 'user-1',
        clienteId: DatabaseMigrator.defaultClienteId,
        username: 'juanperez',
        nombre: 'Juan Pérez',
        correo: 'juan@bioscan.com',
        passwordHash: hash,
        salt: salt,
        rol: 'ADMINISTRADOR',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );

      await ServiceLocator.usuarioRepository.insertUsuario(usuario);

      final usuarios = await ServiceLocator.usuarioRepository.getUsuariosByCliente(DatabaseMigrator.defaultClienteId);
      expect(usuarios.any((u) => u.username == 'juanperez'), isTrue);
    });
  });

  group('Pruebas de Dispositivos', () {
    test('Crear y consultar dispositivos asignados a un cliente', () async {
      final dispositivo = const Dispositivo(
        id: 'disp-1',
        clienteId: DatabaseMigrator.defaultClienteId,
        numeroSerie: 'BS-990011',
        nombre: 'BioScan Pro Alpha',
        modelo: 'BS-2026',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );

      await ServiceLocator.dispositivoRepository.insertDispositivo(dispositivo);

      final dispositivos = await ServiceLocator.dispositivoRepository.getDispositivosByCliente(DatabaseMigrator.defaultClienteId);
      expect(dispositivos, hasLength(1));
      expect(dispositivos.first.numeroSerie, 'BS-990011');
      expect(dispositivos.first.modelo, 'BS-2026');
    });
  });

  group('Pruebas de Ganaderos y Mediciones con Dispositivo y Usuario', () {
    test('permite agregar y eliminar ganaderos y asociar mediciones a usuario y dispositivo', () async {
      final ganadero = const Ganadero(
        id: 'g-1',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Carlos',
        apellidoPaterno: 'García',
        apellidoMaterno: 'López',
        rancho: 'Rancho San José',
        tel: '3411234567',
      );

      final dispositivo = const Dispositivo(
        id: 'disp-1',
        clienteId: DatabaseMigrator.defaultClienteId,
        numeroSerie: 'BS-990011',
        nombre: 'BioScan Pro Alpha',
        modelo: 'BS-2026',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );
      await ServiceLocator.dispositivoRepository.insertDispositivo(dispositivo);

      await ServiceLocator.ganaderoRepository.insertGanadero(ganadero);

      final saved = await ServiceLocator.ganaderoRepository.getGanaderosByCliente(DatabaseMigrator.defaultClienteId);
      expect(saved, hasLength(1));
      expect(saved.first.nombreCompleto, 'Carlos García López');
      expect(saved.first.rancho, 'Rancho San José');

      final medicion = const Medicion(
        id: 'm-1',
        ganaderoId: 'g-1',
        dispositivoId: 'disp-1',
        usuarioId: DatabaseMigrator.defaultAdminId,
        ph: '6.65',
        agua: '0.0%',
        temperatura: '23.5°C',
        fecha: '2026-08-12T10:00:00.000',
      );

      await ServiceLocator.medicionRepository.insertMedicion(medicion);

      final mediciones = await ServiceLocator.medicionRepository.getMedicionesByCliente(DatabaseMigrator.defaultClienteId);
      expect(mediciones, hasLength(1));
      expect(mediciones.first.ph, '6.65');
      expect(mediciones.first.dispositivoId, 'disp-1');
      expect(mediciones.first.usuarioId, DatabaseMigrator.defaultAdminId);

      await ServiceLocator.ganaderoRepository.deleteGanadero(saved.first.id);

      final afterDelete = await ServiceLocator.ganaderoRepository.getGanaderosByCliente(DatabaseMigrator.defaultClienteId);
      expect(afterDelete, isEmpty);

      // ON DELETE CASCADE borra las mediciones asociadas
      final medicionesAfterDelete = await ServiceLocator.medicionRepository.getMedicionesByCliente(DatabaseMigrator.defaultClienteId);
      expect(medicionesAfterDelete, isEmpty);
    });
  });

  group('Pruebas de Aislamiento Multi-Cliente (Cliente A vs Cliente B)', () {
    test('Garantiza que Cliente A no accede a datos de Cliente B', () async {
      final clienteA = const Cliente(
        id: 'cliente-a',
        nombre: 'Cliente Alpha',
        empresa: 'Alpha Corp',
        telefono: '111',
        correo: 'a@alpha.com',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );

      final clienteB = const Cliente(
        id: 'cliente-b',
        nombre: 'Cliente Beta',
        empresa: 'Beta Ltd',
        telefono: '222',
        correo: 'b@beta.com',
        fechaRegistro: '2026-08-12T00:00:00.000',
      );

      await ServiceLocator.clienteRepository.insertCliente(clienteA);
      await ServiceLocator.clienteRepository.insertCliente(clienteB);

      final ganaderoA = const Ganadero(
        id: 'g-alpha',
        clienteId: 'cliente-a',
        nombre: 'Ganadero Alpha',
        apellidoPaterno: 'Pérez',
        apellidoMaterno: 'Gómez',
        rancho: 'Rancho Alpha',
        tel: '111111',
      );

      final ganaderoB = const Ganadero(
        id: 'g-beta',
        clienteId: 'cliente-b',
        nombre: 'Ganadero Beta',
        apellidoPaterno: 'Rodríguez',
        apellidoMaterno: 'Martínez',
        rancho: 'Rancho Beta',
        tel: '222222',
      );

      await ServiceLocator.ganaderoRepository.insertGanadero(ganaderoA);
      await ServiceLocator.ganaderoRepository.insertGanadero(ganaderoB);

      await ServiceLocator.medicionRepository.insertMedicion(
        const Medicion(
          id: 'm-alpha',
          ganaderoId: 'g-alpha',
          ph: '6.7',
          agua: '0.0%',
          temperatura: '24°C',
          fecha: '2026-08-12T10:00:00.000',
        ),
      );

      await ServiceLocator.medicionRepository.insertMedicion(
        const Medicion(
          id: 'm-beta',
          ganaderoId: 'g-beta',
          ph: '6.8',
          agua: '0.1%',
          temperatura: '25°C',
          fecha: '2026-08-12T11:00:00.000',
        ),
      );

      final ganaderosClienteA = await ServiceLocator.ganaderoRepository.getGanaderosByCliente('cliente-a');
      final ganaderosClienteB = await ServiceLocator.ganaderoRepository.getGanaderosByCliente('cliente-b');

      expect(ganaderosClienteA, hasLength(1));
      expect(ganaderosClienteA.first.nombre, 'Ganadero Alpha');

      expect(ganaderosClienteB, hasLength(1));
      expect(ganaderosClienteB.first.nombre, 'Ganadero Beta');

      final medicionesClienteA = await ServiceLocator.medicionRepository.getMedicionesByCliente('cliente-a');
      final medicionesClienteB = await ServiceLocator.medicionRepository.getMedicionesByCliente('cliente-b');

      expect(medicionesClienteA, hasLength(1));
      expect(medicionesClienteA.first.ph, '6.7');

      expect(medicionesClienteB, hasLength(1));
      expect(medicionesClienteB.first.ph, '6.8');
    });
  });

  group('Pruebas de Migración de Base de Datos v2 a v4', () {
    test('Migra la estructura v2 a v4 agregando columnas de autenticación en usuarios e índices B-Tree de rendimiento', () async {
      final db = ServiceLocator.database.db;

      // Ejecutar migrador v2 -> v4
      await DatabaseMigrator.migrate(db, 2, 4);

      final usuariosInfo = await db.rawQuery("PRAGMA table_info(usuarios)");
      final hasUsername = usuariosInfo.any((c) => c['name'] == 'username');
      final hasPasswordHash = usuariosInfo.any((c) => c['name'] == 'password_hash');
      final hasSalt = usuariosInfo.any((c) => c['name'] == 'salt');

      expect(hasUsername, isTrue);
      expect(hasPasswordHash, isTrue);
      expect(hasSalt, isTrue);

      final medicionesInfo = await db.rawQuery("PRAGMA table_info(mediciones)");
      final hasUsuarioId = medicionesInfo.any((c) => c['name'] == 'usuario_id');
      expect(hasUsuarioId, isTrue);

      final indexes = await db.rawQuery("PRAGMA index_list(usuarios)");
      final hasIndexCliente = indexes.any((idx) => idx['name'] == 'idx_usuarios_cliente_id');
      expect(hasIndexCliente, isTrue);
    });
  });

  group('Pruebas de Flujo de Medición BLE (BluetoothManager)', () {
    test('Mantiene isMeasurementActive en false por defecto y no procesa datos hasta startMeasurement', () {
      final bt = BluetoothManager.instance;
      bt.resetMeasurement();

      expect(bt.isMeasurementActive, isFalse);
      expect(bt.phActual, equals("N/D"));
      expect(bt.temperaturaActual, equals("N/D"));
      expect(bt.densidadActual, equals("N/D"));

      // Iniciar medición y parsear datos de prueba
      bt.startMeasurement();
      expect(bt.isMeasurementActive, isTrue);

      bt.parseIncomingData("PH: 6.75, T: 22.3, P: -0.3, D: 1.028");
      expect(bt.phActual, equals("6.75"));
      expect(bt.temperaturaActual, equals("22.3"));
      expect(bt.densidadActual, equals("1.028"));

      // Reiniciar medición limpia los valores proyectados
      bt.resetMeasurement();
      expect(bt.isMeasurementActive, isFalse);
      expect(bt.phActual, equals("N/D"));
      expect(bt.temperaturaActual, equals("N/D"));
      expect(bt.densidadActual, equals("N/D"));
    });
  });
}
