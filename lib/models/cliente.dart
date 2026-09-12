class Cliente {
  final String id;
  final String nombre;
  final String empresa;
  final String telefono;
  final String correo;
  final String fechaRegistro;
  final bool activo;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.empresa,
    required this.telefono,
    required this.correo,
    required this.fechaRegistro,
    bool? activo,
  }) : activo = activo ?? true;

  Cliente copyWith({
    String? id,
    String? nombre,
    String? empresa,
    String? telefono,
    String? correo,
    String? fechaRegistro,
    bool? activo,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      empresa: empresa ?? this.empresa,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'empresa': empresa,
        'telefono': telefono,
        'correo': correo,
        'fecha_registro': fechaRegistro,
        'activo': activo ? 1 : 0,
      };

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      empresa: map['empresa']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      fechaRegistro: (map['fecha_registro'] ?? map['created_at'])?.toString() ?? DateTime.now().toIso8601String(),
      activo: map['activo'] == 1 || map['activo'] == true,
    );
  }
}
