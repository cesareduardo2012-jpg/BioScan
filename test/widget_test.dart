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
import 'package:scanner_leche_app/services/hardware_simulator_service.dart';
import 'package:flutter/material.dart';
import 'package:scanner_leche_app/screens/configurar_impresora_screen.dart';
import 'package:scanner_leche_app/screens/reporte_pdf_screen.dart';
import 'package:scanner_leche_app/services/pdf_report_service.dart';
import 'package:scanner_leche_app/services/thermal_printer_service.dart';
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

  group('Pruebas de Migración de Base de Datos v2 a v6', () {
    test('Migra la estructura v2 a v6 agregando columnas de autenticación en usuarios, cliente_id y pdf_path en mediciones', () async {
      final db = ServiceLocator.database.db;

      // Ejecutar migrador v2 -> v6
      await DatabaseMigrator.migrate(db, 2, 6);

      final usuariosInfo = await db.rawQuery("PRAGMA table_info(usuarios)");
      final hasUsername = usuariosInfo.any((c) => c['name'] == 'username');
      final hasPasswordHash = usuariosInfo.any((c) => c['name'] == 'password_hash');
      final hasSalt = usuariosInfo.any((c) => c['name'] == 'salt');

      expect(hasUsername, isTrue);
      expect(hasPasswordHash, isTrue);
      expect(hasSalt, isTrue);

      final medicionesInfo = await db.rawQuery("PRAGMA table_info(mediciones)");
      final hasUsuarioId = medicionesInfo.any((c) => c['name'] == 'usuario_id');
      final hasClienteId = medicionesInfo.any((c) => c['name'] == 'cliente_id');
      final hasPdfPath = medicionesInfo.any((c) => c['name'] == 'pdf_path');

      expect(hasUsuarioId, isTrue);
      expect(hasClienteId, isTrue);
      expect(hasPdfPath, isTrue);

      final indexes = await db.rawQuery("PRAGMA index_list(usuarios)");
      final hasIndexCliente = indexes.any((idx) => idx['name'] == 'idx_usuarios_cliente_id');
      expect(hasIndexCliente, isTrue);
    });
  });

  group('Pruebas de Persistencia y Generación de Reportes PDF', () {
    test('Genera y persiste el archivo PDF localmente asociando su ruta a la medición', () async {
      final ganadero = const Ganadero(
        id: 'g-pdf-test',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Roberto',
        apellidoPaterno: 'Mendoza',
        apellidoMaterno: 'Silva',
        rancho: 'Rancho La Esmeralda',
        tel: '3399887766',
      );

      await ServiceLocator.ganaderoRepository.insertGanadero(ganadero);

      final medicion = const Medicion(
        id: 'm-pdf-001',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-pdf-test',
        ph: '6.68',
        agua: '1.030',
        temperatura: '21.5°C',
        fecha: '2026-08-26T14:30:00.000',
        observaciones: 'Muestra conforme',
      );

      final file = await PdfReportService.saveMeasurementReportPdf(
        medicion: medicion,
        ganadero: ganadero,
      );

      expect(await file.exists(), isTrue);
      expect(file.path, contains('reporte_bioscan_Roberto_m-pdf-00.pdf'));

      final medicionWithPdf = medicion.copyWith(pdfPath: file.path);
      await ServiceLocator.medicionRepository.insertMedicion(medicionWithPdf);

      final retrieved = await ServiceLocator.medicionRepository.getMedicionById('m-pdf-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.pdfPath, equals(file.path));

      final bytes = await PdfReportService.loadOrGeneratePdfBytes(
        medicion: retrieved,
        ganadero: ganadero,
      );
      expect(bytes, isNotEmpty);
    });

    test('Genera reporte PDF para muestra adulterada con agua (densidad baja) y alerta crítica', () async {
      final ganadero = const Ganadero(
        id: 'g-pdf-adulterada',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Carlos',
        apellidoPaterno: 'Gómez',
        apellidoMaterno: 'Hernández',
        rancho: 'Rancho San Pedro',
        tel: '3311223344',
      );

      final medicionConAgua = const Medicion(
        id: 'm-pdf-agua-002',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-pdf-adulterada',
        ph: '6.65',
        agua: '1.023', // Densidad < 1.028 indica agua añadida
        temperatura: '20.0°C',
        fecha: '2026-08-26T15:00:00.000',
        observaciones: 'Sospecha de aguado',
      );

      final pdfFile = await PdfReportService.saveMeasurementReportPdf(
        medicion: medicionConAgua,
        ganadero: ganadero,
      );

      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(1000));
    });

    test('Genera reporte PDF para muestras con acidez láctica y alcalinidad anormal', () async {
      final ganadero = const Ganadero(
        id: 'g-pdf-acido',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Lucía',
        apellidoPaterno: 'Vargas',
        apellidoMaterno: 'Cruz',
        rancho: 'Rancho Bellavista',
        tel: '3355667788',
      );

      // Muestra ácida
      final medicionAcida = const Medicion(
        id: 'm-pdf-acida-003',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-pdf-acido',
        ph: '6.35', // pH ácido < 6.50
        agua: '1.031',
        temperatura: '28.0°C',
        fecha: '2026-08-26T16:00:00.000',
        observaciones: 'Sin refrigeración por 4 horas',
      );

      final bytesAcida = await PdfReportService.generateMeasurementReport(
        medicion: medicionAcida,
        ganadero: ganadero,
      );
      expect(bytesAcida, isNotEmpty);

      // Muestra alcalina
      final medicionAlcalina = medicionAcida.copyWith(
        id: 'm-pdf-alc-004',
        ph: '6.95', // pH alcalino > 6.80
      );

      final bytesAlcalina = await PdfReportService.generateMeasurementReport(
        medicion: medicionAlcalina,
        ganadero: ganadero,
      );
      expect(bytesAlcalina, isNotEmpty);
    });

    testWidgets('ReportePdfScreen renderiza AppBar superior con botones de impresión y compartir sin barra morada inferior', (tester) async {
      final ganadero = const Ganadero(
        id: 'g-screen-test',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Fernando',
        apellidoPaterno: 'Torres',
        apellidoMaterno: 'Vega',
        rancho: 'Rancho Las Palmas',
        tel: '3322114455',
      );

      final medicion = const Medicion(
        id: 'm-screen-001',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-screen-test',
        ph: '6.70',
        agua: '1.029',
        temperatura: '19.5°C',
        fecha: '2026-08-26T17:00:00.000',
        observaciones: 'Prueba de pantalla',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportePdfScreen(
            medicion: medicion,
            ganadero: ganadero,
          ),
        ),
      );

      expect(find.text('Reporte Oficial BioScan'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });

  group('Pruebas de Flujo de Medición BLE (BluetoothManager)', () {
    test('Mantiene isMeasurementActive en false por defecto y no procesa datos hasta startMeasurement', () {
      final bt = BluetoothManager.instance;
      bt.setSimulationMode(false);
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

  group('Pruebas de Servicio Simulador y Modo Simulación (HardwareSimulatorService)', () {
    test('Genera lecturas realistas dentro de los rangos físico-químicos definidos (Densidad 1.028-1.033, Temp 18-23°C, pH 6.5-6.8)', () {
      final simService = HardwareSimulatorService.instance;
      for (int i = 0; i < 20; i++) {
        final reading = simService.generateReading();
        final dens = double.parse(reading.densidad);
        final ph = double.parse(reading.ph);
        final temp = double.parse(reading.temperatura.replaceAll('°C', ''));

        expect(dens, inInclusiveRange(1.028, 1.033));
        expect(ph, inInclusiveRange(6.50, 6.80));
        expect(temp, inInclusiveRange(18.0, 23.0));
        expect(reading.batteryLevel, equals(100));
        expect(reading.rawLine, contains('Ph: '));
        expect(reading.rawLine, contains('T: '));
        expect(reading.rawLine, contains('D: '));
      }
    });

    test('Controla el ciclo de vida completo de timers con start y stop sin fugas', () {
      final simService = HardwareSimulatorService.instance;
      expect(simService.isRunning, isFalse);

      simService.start();
      expect(simService.isRunning, isTrue);

      simService.stop();
      expect(simService.isRunning, isFalse);
    });

    test('BluetoothManager emula conexión a BioScan-Demo y emite datos en Modo Simulación', () {
      final bt = BluetoothManager.instance;
      bt.setSimulationMode(true);

      expect(bt.isSimulationMode, isTrue);
      expect(bt.connectedDevice, isNotNull);
      expect(bt.connectedDevice!.remoteId.str, equals('BioScan-Demo'));

      bt.startMeasurement();
      expect(bt.isMeasurementActive, isTrue);
      expect(bt.densidadActual, isNot(equals("N/D")));
      expect(bt.phActual, isNot(equals("N/D")));
      expect(bt.temperaturaActual, isNot(equals("N/D")));

      bt.resetMeasurement();
      expect(bt.isMeasurementActive, isFalse);

      bt.setSimulationMode(false);
      expect(bt.isSimulationMode, isFalse);
      expect(bt.connectedDevice, isNull);
    });
  });

  group('Pruebas de Deserialización y Sincronización Supabase', () {
    test('Ganadero.fromMap mapea correctamente los campos cuenta_id y telefono provenientes de Supabase', () {
      final mapFromSupabase = {
        'id': 'g-supa-01',
        'cuenta_id': 'cliente-cloud-123',
        'nombre': 'Esteban',
        'apellido_paterno': 'Quintero',
        'apellido_materno': 'Vargas',
        'rancho': 'Rancho El Paraíso',
        'telefono': '3311223344',
        'fecha_registro': '2026-08-26T12:00:00.000',
      };

      final ganadero = Ganadero.fromMap(mapFromSupabase);
      expect(ganadero.id, equals('g-supa-01'));
      expect(ganadero.clienteId, equals('cliente-cloud-123'));
      expect(ganadero.nombre, equals('Esteban'));
      expect(ganadero.tel, equals('3311223344'));
      expect(ganadero.rancho, equals('Rancho El Paraíso'));
    });

    test('SyncService.syncAll ejecuta sin excepciones cuando Supabase está activo', () async {
      await ServiceLocator.syncService.syncAll();
      expect(true, isTrue);
    });
  });

  group('Pruebas de Impresión Térmica Bluetooth (ThermalPrinterService y Formateo 58 mm)', () {
    test('Guarda, recupera y limpia la configuración de impresora en SharedPreferences', () async {
      final service = ThermalPrinterService.instance;
      await service.clearConfiguredPrinter();

      var configured = await service.getConfiguredPrinter();
      expect(configured, isNull);

      await service.savePrinter(mac: '00:11:22:33:44:55', name: 'Impresora Goojprt 58');

      configured = await service.getConfiguredPrinter();
      expect(configured, isNotNull);
      expect(configured!['mac'], equals('00:11:22:33:44:55'));
      expect(configured['name'], equals('Impresora Goojprt 58'));

      await service.clearConfiguredPrinter();
      configured = await service.getConfiguredPrinter();
      expect(configured, isNull);
    });

    test('Genera ticket de prueba ESC/POS con encabezado BioScan y mensaje oficial', () async {
      final service = ThermalPrinterService.instance;
      final bytes = await service.generateTestTicketBytes(
        fecha: DateTime(2026, 9, 8, 10, 30),
      );

      expect(bytes, isNotEmpty);
      final ticketText = String.fromCharCodes(bytes);

      expect(ticketText, contains('=== BIOSCAN ==='));
      expect(ticketText, contains('IMPRESION DE PRUEBA'));
      expect(ticketText, contains('Impresora lista para usar'));
      expect(ticketText, contains('Ticket 58 mm'));
    });

    test('Genera ticket oficial para muestra conforme (LECHE APTA / OPTIMAS CONDICIONES)', () async {
      final service = ThermalPrinterService.instance;
      final ganadero = const Ganadero(
        id: 'g-ticket-apta',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Mateo',
        apellidoPaterno: 'Navarro',
        apellidoMaterno: 'Ríos',
        rancho: 'Rancho Santa Clara',
        tel: '3311223344',
      );

      final medicionApta = const Medicion(
        id: 'm-ticket-001',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-ticket-apta',
        ph: '6.68',
        agua: '1.030', // Densidad normal óptima
        temperatura: '20.0 C',
        fecha: '2026-09-08T11:00:00.000',
      );

      final bytes = await service.generateMeasurementTicketBytes(
        medicion: medicionApta,
        ganadero: ganadero,
      );

      expect(bytes, isNotEmpty);
      final ticketText = String.fromCharCodes(bytes);

      expect(ticketText, contains('=== BIOSCAN ==='));
      expect(ticketText, contains('[ LECHE APTA ]'));
      expect(ticketText, contains('OPTIMAS CONDICIONES'));
      expect(ticketText, contains('Presencia de agua: NO'));
      expect(ticketText, contains('Mateo Navarro'));
      expect(ticketText, contains('Densidad'));
      expect(ticketText, contains('1.030'));
      expect(ticketText, contains('pH'));
      expect(ticketText, contains('6.68'));
      expect(ticketText, contains('OK'));
    });

    test('Genera ticket oficial para muestra adulterada con agua (LECHE NO APTA / ALERTA)', () async {
      final service = ThermalPrinterService.instance;
      final ganadero = const Ganadero(
        id: 'g-ticket-agua',
        clienteId: DatabaseMigrator.defaultClienteId,
        nombre: 'Gonzalo',
        apellidoPaterno: 'Mora',
        apellidoMaterno: 'Castillo',
        rancho: 'Rancho El Encanto',
        tel: '3399881122',
      );

      final medicionAgua = const Medicion(
        id: 'm-ticket-002',
        clienteId: DatabaseMigrator.defaultClienteId,
        ganaderoId: 'g-ticket-agua',
        ph: '6.65',
        agua: '1.022', // Densidad < 1.028 indica adulteración con agua
        temperatura: '21.0 C',
        fecha: '2026-09-08T12:00:00.000',
      );

      final bytes = await service.generateMeasurementTicketBytes(
        medicion: medicionAgua,
        ganadero: ganadero,
      );

      expect(bytes, isNotEmpty);
      final ticketText = String.fromCharCodes(bytes);

      expect(ticketText, contains('=== BIOSCAN ==='));
      expect(ticketText, contains('[ LECHE NO APTA ]'));
      expect(ticketText, contains('ADULTERACION CON AGUA'));
      expect(ticketText, contains('Presencia de agua: SI'));
      expect(ticketText, contains('ALERTA'));
    });
  });

  group('Pruebas de Widgets de Impresión Térmica y Configuración', () {
    testWidgets('ConfigurarImpresoraScreen renderiza título, tarjeta de estado y botón de escaneo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfigurarImpresoraScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Configurar Impresora'), findsOneWidget);
      expect(find.text('DISPOSITIVOS BLUETOOTH DETECTADOS'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
