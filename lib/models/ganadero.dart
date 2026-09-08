class Ganadero {
  final String id;
  final String clienteId;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String rancho;
  final String telefono;
  final String correo;
  final String fechaRegistro;
  final bool sincronizado;

  const Ganadero({
    required this.id,
    String? clienteId,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.rancho,
    required String tel,
    String? correo,
    String? fechaRegistro,
    bool? sincronizado,
  })  : clienteId = clienteId ?? '00000000-0000-0000-0000-000000000001',
        telefono = tel,
        correo = correo ?? '',
        fechaRegistro = fechaRegistro ?? '',
        sincronizado = sincronizado ?? false;

  // Getter for backward compatibility with existing UI code
  String get tel => telefono;

  String get nombreCompleto {
    final parts = [nombre, apellidoPaterno, apellidoMaterno]
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return parts.join(' ').trim();
  }

  Ganadero copyWith({
    String? id,
    String? clienteId,
    String? nombre,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? rancho,
    String? telefono,
    String? tel,
    String? correo,
    String? fechaRegistro,
    bool? sincronizado,
  }) {
    return Ganadero(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      nombre: nombre ?? this.nombre,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      rancho: rancho ?? this.rancho,
      tel: tel ?? telefono ?? this.telefono,
      correo: correo ?? this.correo,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'nombre': nombre,
        'apellido_paterno': apellidoPaterno,
        'apellido_materno': apellidoMaterno,
        'rancho': rancho,
        'telefono': telefono,
        'correo': correo,
        'fecha_registro': fechaRegistro,
        'sincronizado': sincronizado ? 1 : 0,
      };

  factory Ganadero.fromMap(Map<String, dynamic> map) {
    return Ganadero(
      id: map['id']?.toString() ?? '',
      clienteId: (map['cliente_id'] ?? map['cuenta_id'] ?? map['clienteId'])?.toString() ?? '00000000-0000-0000-0000-000000000001',
      nombre: map['nombre']?.toString() ?? '',
      apellidoPaterno: (map['apellido_paterno'] ?? map['apellidoPaterno'])?.toString() ?? '',
      apellidoMaterno: (map['apellido_materno'] ?? map['apellidoMaterno'])?.toString() ?? '',
      rancho: map['rancho']?.toString() ?? '',
      tel: (map['telefono'] ?? map['tel'])?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      fechaRegistro: (map['fecha_registro'] ?? map['fechaRegistro'])?.toString() ?? DateTime.now().toIso8601String(),
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}
