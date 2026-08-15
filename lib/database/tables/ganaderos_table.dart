class GanaderosTable {
  static const String tableName = 'ganaderos';

  static const String columnId = 'id';
  static const String columnClienteId = 'cliente_id';
  static const String columnNombre = 'nombre';
  static const String columnApellidoPaterno = 'apellido_paterno';
  static const String columnApellidoMaterno = 'apellido_materno';
  static const String columnRancho = 'rancho';
  static const String columnTelefono = 'telefono';
  static const String columnCorreo = 'correo';
  static const String columnFechaRegistro = 'fecha_registro';
  static const String columnSincronizado = 'sincronizado';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnClienteId TEXT NOT NULL,
      $columnNombre TEXT NOT NULL,
      $columnApellidoPaterno TEXT NOT NULL,
      $columnApellidoMaterno TEXT NOT NULL,
      $columnRancho TEXT NOT NULL,
      $columnTelefono TEXT NOT NULL,
      $columnCorreo TEXT NOT NULL,
      $columnFechaRegistro TEXT NOT NULL,
      $columnSincronizado INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY ($columnClienteId) REFERENCES clientes (id) ON DELETE CASCADE
    )
  ''';
}
