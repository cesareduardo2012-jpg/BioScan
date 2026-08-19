class ClientesTable {
  static const String tableName = 'clientes';

  static const String columnId = 'id';
  static const String columnNombre = 'nombre';
  static const String columnEmpresa = 'empresa';
  static const String columnTelefono = 'telefono';
  static const String columnCorreo = 'correo';
  static const String columnFechaRegistro = 'fecha_registro';
  static const String columnActivo = 'activo';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnNombre TEXT NOT NULL,
      $columnEmpresa TEXT NOT NULL,
      $columnTelefono TEXT NOT NULL,
      $columnCorreo TEXT NOT NULL,
      $columnFechaRegistro TEXT NOT NULL,
      $columnActivo INTEGER NOT NULL DEFAULT 1
    )
  ''';
}
