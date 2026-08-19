import 'package:sqflite/sqflite.dart';
import '../../models/usuario.dart';
import '../app_database.dart';
import '../tables/usuarios_table.dart';

class OperatorLimitExceededException implements Exception {
  final String message;
  OperatorLimitExceededException([this.message = 'Una cuenta BioScan solamente puede tener 1 usuario Administrador + 1 usuario Operador.']);

  @override
  String toString() => message;
}

class UsuarioDao {
  final AppDatabase _database;

  UsuarioDao(this._database);

  Future<List<Usuario>> getAll() async {
    final maps = await _database.db.query(UsuariosTable.tableName);
    return maps.map((map) => Usuario.fromMap(map)).toList();
  }

  Future<List<Usuario>> getByClienteId(String clienteId) async {
    final maps = await _database.db.query(
      UsuariosTable.tableName,
      where: '${UsuariosTable.columnClienteId} = ?',
      whereArgs: [clienteId],
    );
    return maps.map((map) => Usuario.fromMap(map)).toList();
  }

  Future<Usuario?> getById(String id) async {
    final maps = await _database.db.query(
      UsuariosTable.tableName,
      where: '${UsuariosTable.columnId} = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<Usuario?> getByUsername(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    final maps = await _database.db.query(
      UsuariosTable.tableName,
      where: 'LOWER(${UsuariosTable.columnUsername}) = ? OR LOWER(${UsuariosTable.columnCorreo}) = ?',
      whereArgs: [cleanUsername, cleanUsername],
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<Usuario?> getOperatorByClienteId(String clienteId) async {
    final maps = await _database.db.query(
      UsuariosTable.tableName,
      where: '${UsuariosTable.columnClienteId} = ? AND (${UsuariosTable.columnRol} = ? OR ${UsuariosTable.columnRol} = ? OR ${UsuariosTable.columnRol} = ?)',
      whereArgs: [clienteId, 'OPERADOR', 'tecnico', 'supervisor'],
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<Usuario?> getAdminByClienteId(String clienteId) async {
    final maps = await _database.db.query(
      UsuariosTable.tableName,
      where: '${UsuariosTable.columnClienteId} = ? AND (${UsuariosTable.columnRol} = ? OR ${UsuariosTable.columnRol} = ?)',
      whereArgs: [clienteId, 'ADMINISTRADOR', 'admin'],
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  Future<void> insert(Usuario usuario) async {
    if (usuario.isOperador) {
      final existingOperator = await getOperatorByClienteId(usuario.clienteId);
      if (existingOperator != null && existingOperator.id != usuario.id) {
        throw OperatorLimitExceededException();
      }
    }

    await _database.db.insert(
      UsuariosTable.tableName,
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Usuario usuario) async {
    if (usuario.isOperador) {
      final existingOperator = await getOperatorByClienteId(usuario.clienteId);
      if (existingOperator != null && existingOperator.id != usuario.id) {
        throw OperatorLimitExceededException();
      }
    }

    await _database.db.update(
      UsuariosTable.tableName,
      usuario.toMap(),
      where: '${UsuariosTable.columnId} = ?',
      whereArgs: [usuario.id],
    );
  }

  Future<void> delete(String id) async {
    // Realiza desactivación (soft delete) por trazabilidad
    await _database.db.update(
      UsuariosTable.tableName,
      {UsuariosTable.columnActivo: 0},
      where: '${UsuariosTable.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDelete(String id) async {
    await _database.db.delete(
      UsuariosTable.tableName,
      where: '${UsuariosTable.columnId} = ?',
      whereArgs: [id],
    );
  }
}
