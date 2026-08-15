class Medicion {
  final String id;
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

  const Medicion({
    required this.id,
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
  })  : densidad = agua,
        observaciones = observaciones ?? '',
        sincronizado = sincronizado ?? false;

  // Getter for backward compatibility with existing UI code
  String get agua => densidad;

  Medicion copyWith({
    String? id,
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
  }) {
    return Medicion(
      id: id ?? this.id,
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
    );
  }

  factory Medicion.fromMap(Map<String, dynamic> map) {
    return Medicion(
      id: map['id']?.toString() ?? '',
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
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
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
      };
}
