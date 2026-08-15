import 'package:sqflite/sqflite.dart';
import '../tables/clientes_table.dart';
import '../tables/dispositivos_table.dart';
import '../tables/ganaderos_table.dart';
import '../tables/mediciones_table.dart';
import '../tables/usuarios_table.dart';

class DatabaseMigrator {
  DatabaseMigrator._();

  static const String defaultClienteId = 'default-cliente-001';

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
  }
}
