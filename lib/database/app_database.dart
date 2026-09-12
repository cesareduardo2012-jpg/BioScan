import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/ganadero.dart';
import '../models/medicion.dart';
import 'migrations/database_migrator.dart';
import 'tables/clientes_table.dart';
import 'tables/dispositivos_table.dart';
import 'tables/ganaderos_table.dart';
import 'tables/mediciones_table.dart';
import 'tables/usuarios_table.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError('Base de datos no inicializada. Llama a init() primero.');
    }
    return _db!;
  }

  Future<void> init() async {
    if (_db != null) return;

    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _getDatabasePath();
    debugPrint('================================================================');
    debugPrint('[SQLITE INIT] INICIALIZANDO BASE DE DATOS EN:');
    debugPrint('  $dbPath');
    debugPrint('================================================================');

    _db = await openDatabase(
      dbPath,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(ClientesTable.createTableQuery);
        await db.insert(
          ClientesTable.tableName,
          {
            ClientesTable.columnId: DatabaseMigrator.defaultClienteId,
            ClientesTable.columnNombre: 'Cliente Predeterminado',
            ClientesTable.columnEmpresa: 'Organización Inicial',
            ClientesTable.columnTelefono: '0000000000',
            ClientesTable.columnCorreo: 'contacto@bioscan.com',
            ClientesTable.columnFechaRegistro: DateTime.now().toIso8601String(),
            ClientesTable.columnActivo: 1,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.execute(UsuariosTable.createTableQuery);
        await db.execute(DispositivosTable.createTableQuery);
        await db.execute(GanaderosTable.createTableQuery);
        await db.execute(MedicionesTable.createTableQuery);

        // Crear Índices B-Tree de rendimiento
        await db.execute('CREATE INDEX IF NOT EXISTS idx_usuarios_cliente_id ON ${UsuariosTable.tableName}(${UsuariosTable.columnClienteId})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_usuarios_username ON ${UsuariosTable.tableName}(${UsuariosTable.columnUsername})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ganaderos_cliente_id ON ${GanaderosTable.tableName}(${GanaderosTable.columnClienteId})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_cliente_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnClienteId})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_ganadero_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnGanaderoId})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_usuario_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnUsuarioId})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_sincronizado ON ${MedicionesTable.tableName}(${MedicionesTable.columnSincronizado})');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_dispositivos_cliente_id ON ${DispositivosTable.tableName}(${DispositivosTable.columnClienteId})');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DatabaseMigrator.migrate(db, oldVersion, newVersion);
      },
    );

    // Migrar datos legados desde archivos JSON si existen
    await _migrateLegacyJsonData();

    // Imprimir diagnóstico completo de inicio
    await printDatabaseDiagnostics();
  }

  Future<String> _getDatabasePath() async {
    Directory directory;
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
    } else {
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (_) {
        directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
      }
    }
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return p.join(directory.path, 'bioscan.db');
  }

  Future<void> printDatabaseDiagnostics() async {
    final dbPath = await _getDatabasePath();
    debugPrint('\n=================== DIAGNÓSTICO BASE DE DATOS SQLITE ===================');
    debugPrint('[SQLITE RUTA FISICA]: $dbPath');

    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'].toString()).toList();
      debugPrint('[SQLITE TABLAS EXISTENTES]: $tableNames');

      final schema = await db.rawQuery("PRAGMA table_info(${GanaderosTable.tableName})");
      debugPrint('[SQLITE ESQUEMA GANADEROS]:');
      for (var col in schema) {
        debugPrint('  - ${col['name']} (${col['type']}) | NotNull: ${col['notnull']} | Default: ${col['dflt_value']}');
      }

      final countResult = await db.rawQuery("SELECT COUNT(*) as total FROM ${GanaderosTable.tableName}");
      final total = Sqflite.firstIntValue(countResult) ?? 0;
      debugPrint('[SQLITE GANADEROS CANTIDAD REGISTROS]: $total');

      final rows = await db.query(GanaderosTable.tableName);
      debugPrint('[SQLITE CONTENIDO TABLA GANADEROS]:');
      for (var r in rows) {
        debugPrint('  -> $r');
      }
    } catch (e, st) {
      debugPrint('[SQLITE DIAGNOSTICS ERROR]: $e');
      debugPrint(st.toString());
    }
    debugPrint('=======================================================================\n');
  }

  Future<void> _migrateLegacyJsonData() async {
    Directory directory;
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
    } else {
      try {
        directory = await getApplicationDocumentsDirectory();
      } catch (_) {
        directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
      }
    }

    final ganaderosFile = File(p.join(directory.path, 'ganaderos.json'));
    final medicionesFile = File(p.join(directory.path, 'mediciones.json'));

    if (await ganaderosFile.exists()) {
      try {
        final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM ${GanaderosTable.tableName}'),
            ) ??
            0;
        if (count == 0) {
          final raw = await ganaderosFile.readAsString();
          final parsed = jsonDecode(raw) as List<dynamic>;
          final batch = db.batch();
          for (var item in parsed) {
            final ganadero = Ganadero.fromMap(Map<String, dynamic>.from(item as Map));
            batch.insert(
              GanaderosTable.tableName,
              ganadero.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          debugPrint('Migrados ${parsed.length} ganaderos desde JSON a SQLite.');
        }
      } catch (e, stackTrace) {
        debugPrint('Error al migrar ganaderos desde JSON: $e');
        debugPrint(stackTrace.toString());
      }
    }

    if (await medicionesFile.exists()) {
      try {
        final count = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM ${MedicionesTable.tableName}'),
            ) ??
            0;
        if (count == 0) {
          final raw = await medicionesFile.readAsString();
          final parsed = jsonDecode(raw) as List<dynamic>;
          final batch = db.batch();
          for (var item in parsed) {
            final medicion = Medicion.fromMap(Map<String, dynamic>.from(item as Map));
            batch.insert(
              MedicionesTable.tableName,
              medicion.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          debugPrint('Migradas ${parsed.length} mediciones desde JSON a SQLite.');
        }
      } catch (e, stackTrace) {
        debugPrint('Error al migrar mediciones desde JSON: $e');
        debugPrint(stackTrace.toString());
      }
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
