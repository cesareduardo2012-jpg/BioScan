import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/ganadero.dart';
import '../app_database.dart';
import '../tables/ganaderos_table.dart';

List<Ganadero> _mapGanaderosList(List<Map<String, Object?>> maps) {
  return maps.map((map) => Ganadero.fromMap(map)).toList();
}

class GanaderoDao {
  final AppDatabase _database;

  GanaderoDao(this._database);

  Future<List<Ganadero>> getAll() async {
    final maps = await _database.db.query(
      GanaderosTable.tableName,
      orderBy: '${GanaderosTable.columnNombre} ASC',
    );
    return compute(_mapGanaderosList, maps);
  }

  Future<List<Ganadero>> getUnsynced() async {
    final maps = await _database.db.query(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnSincronizado} = 0',
    );
    return compute(_mapGanaderosList, maps);
  }

  Future<Ganadero?> getById(String id) async {
    final maps = await _database.db.query(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnId} = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Ganadero.fromMap(maps.first);
  }

  Future<List<Ganadero>> getByClienteId(String clienteId) async {
    debugPrint('[SQLITE DAO] Obteniendo ganaderos para clienteId: $clienteId...');
    final maps = await _database.db.query(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnClienteId} = ?',
      whereArgs: [clienteId],
    );
    debugPrint('[SQLITE DAO] Ganaderos encontrados para cliente $clienteId: ${maps.length}');
    return maps.map((map) => Ganadero.fromMap(map)).toList();
  }

  Future<void> insert(Ganadero ganadero) async {
    final map = ganadero.toMap();
    debugPrint('\n================================================================');
    debugPrint('[SQLITE DAO] Abriendo base de datos SQLite...');
    debugPrint('[SQLITE DAO] Insertando en tabla "${GanaderosTable.tableName}":');
    debugPrint('  Payload: $map');

    try {
      final rowId = await _database.db.insert(
        GanaderosTable.tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[SQLITE DAO] INSERT ejecutado exitosamente. Resultado SQLite RowID/Código: $rowId');

      // VERIFICACIÓN FUNDAMENTAL: SELECT INMEDIATO TRAS EL INSERT
      debugPrint('[SQLITE VERIFY] Ejecutando SELECT * FROM ${GanaderosTable.tableName} WHERE id = "${ganadero.id}"...');
      final verification = await _database.db.query(
        GanaderosTable.tableName,
        where: '${GanaderosTable.columnId} = ?',
        whereArgs: [ganadero.id],
      );

      if (verification.isNotEmpty) {
        debugPrint('[SQLITE VERIFY] ✅ REGISTRO CONFIRMADO EXISTENTE EN SQLITE:');
        debugPrint('  Row: ${verification.first}');
      } else {
        debugPrint('[SQLITE ERROR] ❌ ERROR CRÍTICO: El registro no se encontró en SQLite inmediatamente después del INSERT.');
      }

      await _database.printDatabaseDiagnostics();
    } catch (e, stackTrace) {
      debugPrint('[SQLITE ERROR] Exception al ejecutar INSERT en tabla ganaderos: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> update(Ganadero ganadero) async {
    debugPrint('[SQLITE DAO] Actualizando ganadero ID: ${ganadero.id}...');
    await _database.db.update(
      GanaderosTable.tableName,
      ganadero.toMap(),
      where: '${GanaderosTable.columnId} = ?',
      whereArgs: [ganadero.id],
    );
  }

  Future<void> delete(String id) async {
    debugPrint('[SQLITE DAO] Eliminando ganadero ID: $id...');
    await _database.db.delete(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
