import 'package:sqflite/sqflite.dart';
import '../../models/ganadero.dart';
import '../app_database.dart';
import '../tables/ganaderos_table.dart';

class GanaderoDao {
  final AppDatabase _database;

  GanaderoDao(this._database);

  Future<List<Ganadero>> getAll() async {
    final maps = await _database.db.query(GanaderosTable.tableName);
    return maps.map((map) => Ganadero.fromMap(map)).toList();
  }

  Future<List<Ganadero>> getByClienteId(String clienteId) async {
    final maps = await _database.db.query(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnClienteId} = ?',
      whereArgs: [clienteId],
    );
    return maps.map((map) => Ganadero.fromMap(map)).toList();
  }

  Future<void> insert(Ganadero ganadero) async {
    await _database.db.insert(
      GanaderosTable.tableName,
      ganadero.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Ganadero ganadero) async {
    await _database.db.update(
      GanaderosTable.tableName,
      ganadero.toMap(),
      where: '${GanaderosTable.columnId} = ?',
      whereArgs: [ganadero.id],
    );
  }

  Future<void> delete(String id) async {
    await _database.db.delete(
      GanaderosTable.tableName,
      where: '${GanaderosTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
