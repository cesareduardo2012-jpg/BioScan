import 'package:sqflite/sqflite.dart';
import '../../models/cliente.dart';
import '../app_database.dart';
import '../tables/clientes_table.dart';

class ClienteDao {
  final AppDatabase _database;

  ClienteDao(this._database);

  Future<List<Cliente>> getAll() async {
    final maps = await _database.db.query(ClientesTable.tableName);
    return maps.map((map) => Cliente.fromMap(map)).toList();
  }

  Future<Cliente?> getById(String id) async {
    final maps = await _database.db.query(
      ClientesTable.tableName,
      where: '${ClientesTable.columnId} = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Cliente.fromMap(maps.first);
  }

  Future<void> insert(Cliente cliente) async {
    await _database.db.insert(
      ClientesTable.tableName,
      cliente.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Cliente cliente) async {
    await _database.db.update(
      ClientesTable.tableName,
      cliente.toMap(),
      where: '${ClientesTable.columnId} = ?',
      whereArgs: [cliente.id],
    );
  }

  Future<void> delete(String id) async {
    await _database.db.delete(
      ClientesTable.tableName,
      where: '${ClientesTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
