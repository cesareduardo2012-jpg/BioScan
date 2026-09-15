class UsuariosTable {
  static const String tableName = 'usuarios';

  static const String columnId = 'id';
  static const String columnClienteId = 'cliente_id';
  static const String columnUsername = 'username';
  static const String columnNombre = 'nombre';
  static const String columnCorreo = 'correo';
  static const String columnPasswordHash = 'password_hash';
  static const String columnSalt = 'salt';
  static const String columnRol = 'rol';
  static const String columnFechaRegistro = 'fecha_registro';
  static const String columnUltimoAcceso = 'ultimo_acceso';
  static const String columnActivo = 'activo';
  static const String columnSincronizado = 'sincronizado';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnClienteId TEXT NOT NULL,
      $columnUsername TEXT NOT NULL,
      $columnNombre TEXT NOT NULL,
      $columnCorreo TEXT NOT NULL,
      $columnPasswordHash TEXT NOT NULL,
      $columnSalt TEXT NOT NULL,
      $columnRol TEXT NOT NULL,
      $columnFechaRegistro TEXT NOT NULL,
      $columnUltimoAcceso TEXT,
      $columnActivo INTEGER NOT NULL DEFAULT 1,
      $columnSincronizado INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY ($columnClienteId) REFERENCES clientes (id) ON DELETE CASCADE
    )
  ''';
}
