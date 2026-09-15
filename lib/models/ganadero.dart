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
  final bool activo;
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
    bool? activo,
    bool? sincronizado,
  })  : clienteId = clienteId ?? '',
        telefono = tel,
        correo = correo ?? '',
        fechaRegistro = fechaRegistro ?? '',
        activo = activo ?? true,
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
    bool? activo,
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
      activo: activo ?? this.activo,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  // Mapa para SQLite (Local First)
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
        'activo': activo ? 1 : 0,
        'sincronizado': sincronizado ? 1 : 0,
      };

  // Mapa para Supabase (Remote)
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'cuenta_id': clienteId, // Mapeo explícito de cliente_id -> cuenta_id
      'nombre': nombre,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'rancho': rancho,
      'telefono': telefono,
      'correo': correo,
      'activo': activo,
      // No mandamos 'fecha_registro': la migracion 20260914211000 la elimina
      // de public.ganaderos y se estandariza en created_at. Mandarla rompia
      // el upsert COMPLETO con PostgrestException y ningun ganadero subia.
      // No mandamos 'sincronizado' porque es control local únicamente
    };
  }

  factory Ganadero.fromMap(Map<String, dynamic> map) {
    return Ganadero(
      id: map['id']?.toString() ?? '',
      clienteId: (map['cliente_id'] ?? map['cuenta_id'] ?? map['clienteId'])?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      apellidoPaterno: (map['apellido_paterno'] ?? map['apellidoPaterno'])?.toString() ?? '',
      apellidoMaterno: (map['apellido_materno'] ?? map['apellidoMaterno'])?.toString() ?? '',
      rancho: map['rancho']?.toString() ?? '',
      tel: (map['telefono'] ?? map['tel'])?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      fechaRegistro: (map['fecha_registro'] ?? map['fechaRegistro'])?.toString() ?? DateTime.now().toIso8601String(),
      activo: map['activo'] == 1 || map['activo'] == true || map['activo'] == null,
      sincronizado: map['sincronizado'] == 1 || map['sincronizado'] == true,
    );
  }
}
