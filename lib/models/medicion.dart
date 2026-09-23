class Medicion {
  final String id;
  final String clienteId;
  final String ganaderoId;
  final String? dispositivoId;
  final String? usuarioId;
  final String ph;
  final String densidad;
  final String temperatura;
  final String fecha;
  final String observaciones;
  final bool sincronizado;
  final String? fechaSincronizacion;
  final String? pdfPath;
  final bool isSimulado;

  const Medicion({
    required this.id,
    String? clienteId,
    required this.ganaderoId,
    this.dispositivoId,
    this.usuarioId,
    required this.ph,
    required String agua,
    required this.temperatura,
    required this.fecha,
    String? observaciones,
    bool? sincronizado,
    this.fechaSincronizacion,
    this.pdfPath,
    bool? isSimulado,
  })  : clienteId = clienteId ?? '',
        densidad = agua,
        observaciones = observaciones ?? '',
        sincronizado = sincronizado ?? false,
        isSimulado = isSimulado ?? false;

  // Getter for backward compatibility with existing UI code
  String get agua => densidad;

  Medicion copyWith({
    String? id,
    String? clienteId,
    String? ganaderoId,
    String? dispositivoId,
    String? usuarioId,
    String? ph,
    String? agua,
    String? densidad,
    String? temperatura,
    String? fecha,
    String? observaciones,
    bool? sincronizado,
    String? fechaSincronizacion,
    String? pdfPath,
    bool? isSimulado,
  }) {
    return Medicion(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      ganaderoId: ganaderoId ?? this.ganaderoId,
      dispositivoId: dispositivoId ?? this.dispositivoId,
      usuarioId: usuarioId ?? this.usuarioId,
      ph: ph ?? this.ph,
      agua: agua ?? densidad ?? this.densidad,
      temperatura: temperatura ?? this.temperatura,
      fecha: fecha ?? this.fecha,
      observaciones: observaciones ?? this.observaciones,
      sincronizado: sincronizado ?? this.sincronizado,
      fechaSincronizacion: fechaSincronizacion ?? this.fechaSincronizacion,
      pdfPath: pdfPath ?? this.pdfPath,
      isSimulado: isSimulado ?? this.isSimulado,
    );
  }

  factory Medicion.fromMap(Map<String, dynamic> map) {
    return Medicion(
      id: map['id']?.toString() ?? '',
      clienteId: (map['cliente_id'] ?? map['cuenta_id'] ?? map['clienteId'])?.toString() ?? '',
      ganaderoId: (map['ganadero_id'] ?? map['ganaderoId'])?.toString() ?? '',
      dispositivoId: (map['dispositivo_id'] ?? map['dispositivoId'])?.toString(),
      usuarioId: (map['usuario_id'] ?? map['usuarioId'])?.toString(),
      ph: map['ph']?.toString() ?? '',
      agua: (map['densidad'] ?? map['agua'])?.toString() ?? '',
      temperatura: map['temperatura']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
      observaciones: map['observaciones']?.toString() ?? '',
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
      fechaSincronizacion: (map['fecha_sincronizacion'] ?? map['fechaSincronizacion'])?.toString(),
      pdfPath: (map['pdf_path'] ?? map['pdfPath'])?.toString(),
      isSimulado: map['es_simulado'] == 1 || map['es_simulado'] == true || map['isSimulado'] == 1 || map['isSimulado'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    double parseSensorNumber(String val) {
      final text = val.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (text.isEmpty) return 0.0;
      return double.tryParse(text) ?? 0.0;
    }

    return {
      'id': id,
      'cliente_id': clienteId,
      'ganadero_id': ganaderoId,
      'dispositivo_id': dispositivoId,
      'usuario_id': usuarioId,
      'ph': parseSensorNumber(ph),
      'densidad': parseSensorNumber(densidad),
      'temperatura': parseSensorNumber(temperatura),
      'fecha': fecha,
      'observaciones': observaciones.replaceAll('\x00', ''),
      'sincronizado': sincronizado ? 1 : 0,
      'fecha_sincronizacion': fechaSincronizacion,
      'pdf_path': pdfPath,
      'es_simulado': isSimulado ? 1 : 0,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    double? parseSensorNumber(String val) {
      final text = val.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    bool isValidUuid(String uuid) {
      return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', caseSensitive: false).hasMatch(uuid);
    }

    // Las columnas numericas de Supabase son NOT NULL con CHECK de rango, asi
    // que una lectura imposible no cabe y hay que ajustarla para que el upsert
    // no falle. Pero ese ajuste NO puede ser silencioso: un valor recortado se
    // ve igual que uno medido, y asi 4 de 19 mediciones acabaron con densidad
    // 0.9000 sin que nadie lo notara. Se registra cada ajuste para mandar
    // lectura_valida = false junto con el texto crudo del sensor.
    var lecturaValida = true;

    // ph numeric NOT NULL CHECK (ph >= 0.00 AND ph <= 14.00)
    final phVal = parseSensorNumber(ph);
    final safePh = (phVal ?? 7.0).clamp(0.0, 14.0);
    if (phVal == null || phVal != safePh) lecturaValida = false;

    // densidad numeric NOT NULL CHECK (densidad >= 0.9000 AND densidad <= 1.2000)
    final densVal = parseSensorNumber(densidad);
    final safeDens = (densVal ?? 1.0).clamp(0.9, 1.2);
    if (densVal == null || densVal != safeDens) lecturaValida = false;

    // temperatura numeric NOT NULL CHECK (temperatura >= -20.00 AND temperatura <= 120.00)
    final tempVal = parseSensorNumber(temperatura);
    final safeTemp = (tempVal ?? 20.0).clamp(-20.0, 120.0);
    if (tempVal == null || tempVal != safeTemp) lecturaValida = false;

    final fechaUtc = DateTime.tryParse(fecha)?.toUtc().toIso8601String() ?? DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': id,
      'cuenta_id': clienteId,
      'ganadero_id': ganaderoId,
      'ph': safePh,
      'densidad': safeDens,
      'temperatura': safeTemp,
      'fecha': fechaUtc,
      'observaciones': observaciones.replaceAll('\x00', ''), // Limpiar null bytes heredados de registros viejos
      // Lo que realmente mando el sensor, antes de convertir y recortar. Si
      // lectura_valida es false, estas columnas son el unico registro del
      // valor medido: las numericas traen el ajustado.
      'lectura_valida': lecturaValida,
      'ph_raw': ph,
      'densidad_raw': densidad,
      'temperatura_raw': temperatura,
    };

    if (dispositivoId != null && isValidUuid(dispositivoId!)) {
      payload['dispositivo_id'] = dispositivoId;
    }
    if (usuarioId != null && isValidUuid(usuarioId!)) {
      payload['usuario_id'] = usuarioId;
    }
    if (pdfPath != null && pdfPath!.isNotEmpty) payload['pdf_path'] = pdfPath;

    // es_simulado se omite a proposito por decision del equipo (23/09/2026).
    // La columna SI existe -- la agrego la migracion
    // 20260914_add_es_simulado_column.sql, verificada en el proyecto real --
    // pero por ahora no se distingue el origen de la lectura en la nube.
    // Consecuencia a tener presente: al no mandarse, la columna toma su valor
    // por defecto (false), asi que las mediciones del Modo Simulacion quedan
    // registradas como si fueran lecturas reales del sensor.

    return payload;
  }
}
