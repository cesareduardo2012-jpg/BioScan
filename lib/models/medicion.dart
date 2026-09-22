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

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'ganadero_id': ganaderoId,
        'dispositivo_id': dispositivoId,
        'usuario_id': usuarioId,
        'ph': ph,
        'densidad': densidad,
        'temperatura': temperatura,
        'fecha': fecha,
        'observaciones': observaciones,
        'sincronizado': sincronizado ? 1 : 0,
        'fecha_sincronizacion': fechaSincronizacion,
        'pdf_path': pdfPath,
        'es_simulado': isSimulado ? 1 : 0,
      };

  Map<String, dynamic> toSupabaseMap() {
    double? parseSensorNumber(String val) {
      final text = val.replaceAll(RegExp(r'[^0-9.-]'), '');
      if (text.isEmpty) return null;
      return double.tryParse(text);
    }

    // Default values to satisfy Supabase NOT NULL and CHECK constraints
    // ph numeric NOT NULL CHECK (ph >= 0.00 AND ph <= 14.00)
    final phVal = parseSensorNumber(ph) ?? 7.0; 
    final safePh = phVal.clamp(0.0, 14.0);

    // densidad numeric NOT NULL CHECK (densidad >= 0.9000 AND densidad <= 1.2000)
    final densVal = parseSensorNumber(densidad) ?? 1.0;
    final safeDens = densVal.clamp(0.9, 1.2);

    // temperatura numeric NOT NULL CHECK (temperatura >= -20.00 AND temperatura <= 120.00)
    final tempVal = parseSensorNumber(temperatura) ?? 20.0;
    final safeTemp = tempVal.clamp(-20.0, 120.0);

    final fechaUtc = DateTime.tryParse(fecha)?.toUtc().toIso8601String() ?? DateTime.now().toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'id': id,
      'cuenta_id': clienteId,
      'ganadero_id': ganaderoId,
      'ph': safePh,
      'densidad': safeDens,
      'temperatura': safeTemp,
      'fecha': fechaUtc,
      'observaciones': observaciones,
    };

    if (dispositivoId != null && dispositivoId!.isNotEmpty) payload['dispositivo_id'] = dispositivoId;
    if (usuarioId != null && usuarioId!.isNotEmpty) payload['usuario_id'] = usuarioId;
    if (pdfPath != null && pdfPath!.isNotEmpty) payload['pdf_path'] = pdfPath;
    
    // NOTA: es_simulado no existe en Supabase public.mediciones según el esquema proporcionado.
    // Si la migración lo añadió, se debe agregar aquí, pero para evitar el error de Postgrest,
    // se omite por defecto hasta confirmarlo.

    return payload;
  }
}
