import 'package:sqflite/sqflite.dart';
import '../../models/medicion.dart';
import '../app_database.dart';
import '../tables/mediciones_table.dart';

import '../tables/ganaderos_table.dart';

class MedicionDao {
  final AppDatabase _database;

  MedicionDao(this._database);

  Future<List<Medicion>> getAll() async {
    final maps = await _database.db.query(
      MedicionesTable.tableName,
      orderBy: '${MedicionesTable.columnFecha} DESC',
    );
    return maps.map((map) => Medicion.fromMap(map)).toList();
  }

  Future<List<Medicion>> getByGanaderoId(String ganaderoId) async {
    final maps = await _database.db.query(
      MedicionesTable.tableName,
      where: '${MedicionesTable.columnGanaderoId} = ?',
      whereArgs: [ganaderoId],
      orderBy: '${MedicionesTable.columnFecha} DESC',
    );
    return maps.map((map) => Medicion.fromMap(map)).toList();
  }

  Future<List<Medicion>> getByClienteId(String clienteId) async {
    final maps = await _database.db.rawQuery('''
      SELECT m.* FROM ${MedicionesTable.tableName} m
      INNER JOIN ${GanaderosTable.tableName} g ON m.${MedicionesTable.columnGanaderoId} = g.${GanaderosTable.columnId}
      WHERE g.${GanaderosTable.columnClienteId} = ?
      ORDER BY m.${MedicionesTable.columnFecha} DESC
    ''', [clienteId]);
    return maps.map((map) => Medicion.fromMap(map)).toList();
  }

  Future<List<Medicion>> getByDispositivoId(String dispositivoId) async {
    final maps = await _database.db.query(
      MedicionesTable.tableName,
      where: '${MedicionesTable.columnDispositivoId} = ?',
      whereArgs: [dispositivoId],
      orderBy: '${MedicionesTable.columnFecha} DESC',
    );
    return maps.map((map) => Medicion.fromMap(map)).toList();
  }

  Future<void> insert(Medicion medicion) async {
    await _database.db.insert(
      MedicionesTable.tableName,
      medicion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Medicion medicion) async {
    await _database.db.update(
      MedicionesTable.tableName,
      medicion.toMap(),
      where: '${MedicionesTable.columnId} = ?',
      whereArgs: [medicion.id],
    );
  }

  Future<void> delete(String id) async {
    await _database.db.delete(
      MedicionesTable.tableName,
      where: '${MedicionesTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
