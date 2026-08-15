class MedicionesTable {
  static const String tableName = 'mediciones';

  static const String columnId = 'id';
  static const String columnGanaderoId = 'ganadero_id';
  static const String columnDispositivoId = 'dispositivo_id';
  static const String columnUsuarioId = 'usuario_id';
  static const String columnPh = 'ph';
  static const String columnDensidad = 'densidad';
  static const String columnTemperatura = 'temperatura';
  static const String columnFecha = 'fecha';
  static const String columnObservaciones = 'observaciones';
  static const String columnSincronizado = 'sincronizado';
  static const String columnFechaSincronizacion = 'fecha_sincronizacion';

  static const String createTableQuery = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnGanaderoId TEXT NOT NULL,
      $columnDispositivoId TEXT,
      $columnUsuarioId TEXT,
      $columnPh TEXT NOT NULL,
      $columnDensidad TEXT NOT NULL,
      $columnTemperatura TEXT NOT NULL,
      $columnFecha TEXT NOT NULL,
      $columnObservaciones TEXT NOT NULL,
      $columnSincronizado INTEGER NOT NULL DEFAULT 0,
      $columnFechaSincronizacion TEXT,
      FOREIGN KEY ($columnGanaderoId) REFERENCES ganaderos (id) ON DELETE CASCADE,
      FOREIGN KEY ($columnDispositivoId) REFERENCES dispositivos (id) ON DELETE SET NULL,
      FOREIGN KEY ($columnUsuarioId) REFERENCES usuarios (id) ON DELETE SET NULL
    )
  ''';
}
