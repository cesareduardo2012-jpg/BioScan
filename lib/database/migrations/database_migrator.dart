import 'package:sqflite/sqflite.dart';
import '../tables/clientes_table.dart';
import '../tables/dispositivos_table.dart';
import '../tables/ganaderos_table.dart';
import '../tables/mediciones_table.dart';
import '../tables/usuarios_table.dart';

class DatabaseMigrator {
  DatabaseMigrator._();

  static const String defaultClienteId = '00000000-0000-0000-0000-000000000001';
  static const String defaultAdminId = '00000000-0000-0000-0000-000000000002';

  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Crear tabla de clientes si no existe
      await db.execute(ClientesTable.createTableQuery);

      // 2. Crear cliente predeterminado para asociar los datos preexistentes
      await db.insert(
        ClientesTable.tableName,
        {
          ClientesTable.columnId: defaultClienteId,
          ClientesTable.columnNombre: 'Cliente Predeterminado',
          ClientesTable.columnEmpresa: 'Organización Inicial',
          ClientesTable.columnTelefono: '0000000000',
          ClientesTable.columnCorreo: 'contacto@bioscan.com',
          ClientesTable.columnFechaRegistro: DateTime.now().toIso8601String(),
          ClientesTable.columnActivo: 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 3. Crear tabla de usuarios
      await db.execute(UsuariosTable.createTableQuery);

      // 4. Crear tabla de dispositivos
      await db.execute(DispositivosTable.createTableQuery);

      // 5. Agregar columna cliente_id a la tabla ganaderos asignando el cliente por defecto
      final ganaderosInfo = await db.rawQuery("PRAGMA table_info(${GanaderosTable.tableName})");
      final hasClienteId = ganaderosInfo.any((column) => column['name'] == GanaderosTable.columnClienteId);
      if (!hasClienteId) {
        await db.execute(
          'ALTER TABLE ${GanaderosTable.tableName} ADD COLUMN ${GanaderosTable.columnClienteId} TEXT NOT NULL DEFAULT \'$defaultClienteId\'',
        );
      }

      // 6. Agregar columna dispositivo_id a la tabla mediciones
      final medicionesInfo = await db.rawQuery("PRAGMA table_info(${MedicionesTable.tableName})");
      final hasDispositivoId = medicionesInfo.any((column) => column['name'] == MedicionesTable.columnDispositivoId);
      if (!hasDispositivoId) {
        await db.execute(
          'ALTER TABLE ${MedicionesTable.tableName} ADD COLUMN ${MedicionesTable.columnDispositivoId} TEXT',
        );
      }
    }

    if (oldVersion < 3) {
      // Migración v3: agregar columnas de autenticación en usuarios y trazabilidad en mediciones
      final usuariosInfo = await db.rawQuery("PRAGMA table_info(${UsuariosTable.tableName})");

      final hasUsername = usuariosInfo.any((c) => c['name'] == UsuariosTable.columnUsername);
      if (!hasUsername) {
        await db.execute('ALTER TABLE ${UsuariosTable.tableName} ADD COLUMN ${UsuariosTable.columnUsername} TEXT NOT NULL DEFAULT \'\'');
      }

      final hasPasswordHash = usuariosInfo.any((c) => c['name'] == UsuariosTable.columnPasswordHash);
      if (!hasPasswordHash) {
        await db.execute('ALTER TABLE ${UsuariosTable.tableName} ADD COLUMN ${UsuariosTable.columnPasswordHash} TEXT NOT NULL DEFAULT \'\'');
      }

      final hasSalt = usuariosInfo.any((c) => c['name'] == UsuariosTable.columnSalt);
      if (!hasSalt) {
        await db.execute('ALTER TABLE ${UsuariosTable.tableName} ADD COLUMN ${UsuariosTable.columnSalt} TEXT NOT NULL DEFAULT \'\'');
      }

      final hasUltimoAcceso = usuariosInfo.any((c) => c['name'] == UsuariosTable.columnUltimoAcceso);
      if (!hasUltimoAcceso) {
        await db.execute('ALTER TABLE ${UsuariosTable.tableName} ADD COLUMN ${UsuariosTable.columnUltimoAcceso} TEXT');
      }

      final medicionesInfo = await db.rawQuery("PRAGMA table_info(${MedicionesTable.tableName})");
      final hasUsuarioId = medicionesInfo.any((c) => c['name'] == MedicionesTable.columnUsuarioId);
      if (!hasUsuarioId) {
        await db.execute('ALTER TABLE ${MedicionesTable.tableName} ADD COLUMN ${MedicionesTable.columnUsuarioId} TEXT');
      }
    }

    if (oldVersion < 4) {
      // Migración v4: Índices B-Tree de rendimiento para escalabilidad a miles de registros y aislamiento multi-tenant
      await db.execute('CREATE INDEX IF NOT EXISTS idx_usuarios_cliente_id ON ${UsuariosTable.tableName}(${UsuariosTable.columnClienteId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_usuarios_username ON ${UsuariosTable.tableName}(${UsuariosTable.columnUsername})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ganaderos_cliente_id ON ${GanaderosTable.tableName}(${GanaderosTable.columnClienteId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_ganadero_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnGanaderoId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_usuario_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnUsuarioId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_sincronizado ON ${MedicionesTable.tableName}(${MedicionesTable.columnSincronizado})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_dispositivos_cliente_id ON ${DispositivosTable.tableName}(${DispositivosTable.columnClienteId})');
    }

    if (oldVersion < 5) {
      // Migración v5: Agregar columna cliente_id a la tabla mediciones para soporte multi-tenant total
      final medicionesInfo = await db.rawQuery("PRAGMA table_info(${MedicionesTable.tableName})");
      final hasClienteId = medicionesInfo.any((c) => c['name'] == MedicionesTable.columnClienteId);
      if (!hasClienteId) {
        await db.execute(
          'ALTER TABLE ${MedicionesTable.tableName} ADD COLUMN ${MedicionesTable.columnClienteId} TEXT NOT NULL DEFAULT \'$defaultClienteId\'',
        );
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_cliente_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnClienteId})');
    }

    if (oldVersion < 6) {
      // Migración v6: Agregar columna pdf_path a la tabla mediciones para persistencia de reportes PDF locales
      final medicionesInfo = await db.rawQuery("PRAGMA table_info(${MedicionesTable.tableName})");
      final hasPdfPath = medicionesInfo.any((c) => c['name'] == MedicionesTable.columnPdfPath);
      if (!hasPdfPath) {
        await db.execute('ALTER TABLE ${MedicionesTable.tableName} ADD COLUMN ${MedicionesTable.columnPdfPath} TEXT');
      }
    }
    if (oldVersion < 7) {
      // Migración v7: Estandarización de tipos en Mediciones a REAL
      // Creamos una tabla temporal sin claves foráneas temporalmente
      await db.execute('''
        CREATE TABLE mediciones_v7_temp (
          ${MedicionesTable.columnId} TEXT PRIMARY KEY,
          ${MedicionesTable.columnClienteId} TEXT NOT NULL DEFAULT '$defaultClienteId',
          ${MedicionesTable.columnGanaderoId} TEXT NOT NULL,
          ${MedicionesTable.columnDispositivoId} TEXT,
          ${MedicionesTable.columnUsuarioId} TEXT,
          ${MedicionesTable.columnPh} REAL NOT NULL,
          ${MedicionesTable.columnDensidad} REAL NOT NULL,
          ${MedicionesTable.columnTemperatura} REAL NOT NULL,
          ${MedicionesTable.columnFecha} TEXT NOT NULL,
          ${MedicionesTable.columnObservaciones} TEXT NOT NULL,
          ${MedicionesTable.columnSincronizado} INTEGER NOT NULL DEFAULT 0,
          ${MedicionesTable.columnFechaSincronizacion} TEXT,
          ${MedicionesTable.columnPdfPath} TEXT
        )
      ''');

      // Copiamos datos casteando (reemplazando cualquier caracter extraño o cadena no parseable por 0.0)
      await db.execute('''
        INSERT INTO mediciones_v7_temp
        SELECT id, cliente_id, ganadero_id, dispositivo_id, usuario_id,
               CAST(ph AS REAL), CAST(densidad AS REAL), CAST(temperatura AS REAL),
               fecha, observaciones, sincronizado, fecha_sincronizacion, pdf_path
        FROM ${MedicionesTable.tableName}
      ''');

      // Recreamos tabla original y restauramos relaciones y Foreign Keys
      await db.execute('DROP TABLE ${MedicionesTable.tableName}');
      await db.execute(MedicionesTable.createTableQuery); 
      await db.execute('''
        INSERT INTO ${MedicionesTable.tableName}
        SELECT * FROM mediciones_v7_temp
      ''');
      await db.execute('DROP TABLE mediciones_v7_temp');
      
      // Recrear índices B-Tree de rendimiento
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_cliente_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnClienteId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_ganadero_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnGanaderoId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_usuario_id ON ${MedicionesTable.tableName}(${MedicionesTable.columnUsuarioId})');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mediciones_sincronizado ON ${MedicionesTable.tableName}(${MedicionesTable.columnSincronizado})');
    }

    if (oldVersion < 8) {
      // Migración v8: Agregar columna sincronizado a la tabla usuarios
      final usuariosInfo = await db.rawQuery("PRAGMA table_info(${UsuariosTable.tableName})");
      final hasSincronizado = usuariosInfo.any((c) => c['name'] == UsuariosTable.columnSincronizado);
      if (!hasSincronizado) {
        await db.execute('ALTER TABLE ${UsuariosTable.tableName} ADD COLUMN ${UsuariosTable.columnSincronizado} INTEGER NOT NULL DEFAULT 0');
      }
    }
  }
}
