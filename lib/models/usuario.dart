class Usuario {
  final String id;
  final String clienteId;
  final String username;
  final String nombre;
  final String correo;
  final String passwordHash;
  final String salt;
  final String rol; // ADMINISTRADOR, OPERADOR
  final String fechaRegistro;
  final String? ultimoAcceso;
  final bool activo;

  const Usuario({
    required this.id,
    required this.clienteId,
    required this.username,
    required this.nombre,
    required this.correo,
    required this.passwordHash,
    required this.salt,
    required this.rol,
    required this.fechaRegistro,
    this.ultimoAcceso,
    bool? activo,
  }) : activo = activo ?? true;

  bool get isAdmin => rol.toUpperCase() == 'ADMINISTRADOR' || rol.toLowerCase() == 'admin';
  bool get isOperador => rol.toUpperCase() == 'OPERADOR' || rol.toLowerCase() == 'tecnico' || rol.toLowerCase() == 'operator';

  Usuario copyWith({
    String? id,
    String? clienteId,
    String? username,
    String? nombre,
    String? correo,
    String? passwordHash,
    String? salt,
    String? rol,
    String? fechaRegistro,
    String? ultimoAcceso,
    bool? activo,
  }) {
    return Usuario(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      username: username ?? this.username,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      rol: rol ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
      activo: activo ?? this.activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cliente_id': clienteId,
        'username': username,
        'nombre': nombre,
        'correo': correo,
        'password_hash': passwordHash,
        'salt': salt,
        'rol': rol,
        'fecha_registro': fechaRegistro,
        'ultimo_acceso': ultimoAcceso,
        'activo': activo ? 1 : 0,
      };

  factory Usuario.fromMap(Map<String, dynamic> map) {
    final rawRol = map['rol']?.toString() ?? 'OPERADOR';
    String normalizedRol = rawRol;
    if (rawRol.toLowerCase() == 'admin') {
      normalizedRol = 'ADMINISTRADOR';
    } else if (rawRol.toLowerCase() == 'tecnico' || rawRol.toLowerCase() == 'supervisor') {
      normalizedRol = 'OPERADOR';
    }

    final rawUsername = map['username']?.toString();
    final fallbackUsername = rawUsername != null && rawUsername.isNotEmpty
        ? rawUsername
        : (map['correo']?.toString().split('@').first ?? 'user_${map['id']}');

    return Usuario(
      id: map['id']?.toString() ?? '',
      clienteId: (map['cliente_id'] ?? map['clienteId'])?.toString() ?? '',
      username: fallbackUsername,
      nombre: map['nombre']?.toString() ?? '',
      correo: map['correo']?.toString() ?? '',
      passwordHash: (map['password_hash'] ?? map['passwordHash'])?.toString() ?? '',
      salt: map['salt']?.toString() ?? '',
      rol: normalizedRol,
      fechaRegistro: (map['fecha_registro'] ?? map['fechaRegistro'])?.toString() ?? DateTime.now().toIso8601String(),
      ultimoAcceso: (map['ultimo_acceso'] ?? map['ultimoAcceso'])?.toString(),
      activo: map['activo'] == 1 || map['activo'] == true || map['activo'] == null,
    );
  }
}
