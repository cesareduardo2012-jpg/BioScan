class DispositivosTable {
  static const String tableName = 'dispositivos';

  static const String columnId = 'id';
  static const String columnClienteId = 'cliente_id';
  static const String columnNumeroSerie = 'numero_serie';
  static const String columnNombre = 'nombre';
  static const String columnModelo = 'modelo';
  static const String columnFechaRegistro = 'fecha_registro';
  static const String columnFechaAsignacion = 'fecha_asignacion';
  static const String columnActivo = 'activo';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnClienteId TEXT NOT NULL,
      $columnNumeroSerie TEXT NOT NULL,
      $columnNombre TEXT NOT NULL,
      $columnModelo TEXT NOT NULL,
      $columnFechaRegistro TEXT NOT NULL,
      $columnFechaAsignacion TEXT,
      $columnActivo INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY ($columnClienteId) REFERENCES clientes (id) ON DELETE CASCADE
    )
  ''';
}
