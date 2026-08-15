class Dispositivo {
  final String id;
  final String clienteId;
  final String numeroSerie;
  final String nombre;
  final String modelo;
  final String fechaRegistro;
  final String? fechaAsignacion;
  final bool activo;

  const Dispositivo({
    required this.id,
    required this.clienteId,
    required this.numeroSerie,
    required this.nombre,
    required this.modelo,
    required this.fechaRegistro,
    this.fechaAsignacion,
    bool? activo,
  }) : activo = activo ?? true;

  Dispositivo copyWith({
    String? id,
    String? clienteId,
    String? numeroSerie,
    String? nombre,
    String? modelo,
    String? fechaRegistro,
    String? fechaAsignacion,
    bool? activo,
  }) {
    return Dispositivo(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      nombre: nombre ?? this.nombre,
      modelo: modelo ?? this.modelo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'numero_serie': numeroSerie,
        'nombre': nombre,
        'modelo': modelo,
        'fecha_registro': fechaRegistro,
        'fecha_asignacion': fechaAsignacion,
        'activo': activo ? 1 : 0,
      };

  factory Dispositivo.fromMap(Map<String, dynamic> map) {
    return Dispositivo(
      id: map['id']?.toString() ?? '',
      clienteId: (map['cliente_id'] ?? map['clienteId'])?.toString() ?? '',
      numeroSerie: (map['numero_serie'] ?? map['numeroSerie'])?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      modelo: map['modelo']?.toString() ?? '',
      fechaRegistro: (map['fecha_registro'] ?? map['fechaRegistro'])?.toString() ?? DateTime.now().toIso8601String(),
      fechaAsignacion: (map['fecha_asignacion'] ?? map['fechaAsignacion'])?.toString(),
      activo: map['activo'] == 1 || map['activo'] == true,
    );
  }
}
