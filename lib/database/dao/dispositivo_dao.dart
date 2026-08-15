import 'package:sqflite/sqflite.dart';
import '../../models/dispositivo.dart';
import '../app_database.dart';
import '../tables/dispositivos_table.dart';

class DispositivoDao {
  final AppDatabase _database;

  DispositivoDao(this._database);

  Future<List<Dispositivo>> getAll() async {
    final maps = await _database.db.query(DispositivosTable.tableName);
    return maps.map((map) => Dispositivo.fromMap(map)).toList();
  }

  Future<List<Dispositivo>> getByClienteId(String clienteId) async {
    final maps = await _database.db.query(
      DispositivosTable.tableName,
      where: '${DispositivosTable.columnClienteId} = ?',
      whereArgs: [clienteId],
    );
    return maps.map((map) => Dispositivo.fromMap(map)).toList();
  }

  Future<void> insert(Dispositivo dispositivo) async {
    await _database.db.insert(
      DispositivosTable.tableName,
      dispositivo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Dispositivo dispositivo) async {
    await _database.db.update(
      DispositivosTable.tableName,
      dispositivo.toMap(),
      where: '${DispositivosTable.columnId} = ?',
      whereArgs: [dispositivo.id],
    );
  }

  Future<void> delete(String id) async {
    await _database.db.delete(
      DispositivosTable.tableName,
      where: '${DispositivosTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
