class Ganadero {
  const Ganadero({
    required this.id,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.rancho,
    required this.tel,
  });

  final String id;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String rancho;
  final String tel;

  String get nombreCompleto {
    final parts = [nombre, apellidoPaterno, apellidoMaterno].where((value) => value.trim().isNotEmpty).toList();
    return parts.join(' ').trim();
  }

  Ganadero copyWith({
    String? id,
    String? nombre,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? rancho,
    String? tel,
  }) {
    return Ganadero(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      rancho: rancho ?? this.rancho,
      tel: tel ?? this.tel,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'apellidoPaterno': apellidoPaterno,
        'apellidoMaterno': apellidoMaterno,
        'rancho': rancho,
        'tel': tel,
      };

  factory Ganadero.fromMap(Map<String, dynamic> map) {
    return Ganadero(
      id: map['id'].toString(),
      nombre: map['nombre']?.toString() ?? '',
      apellidoPaterno: map['apellidoPaterno']?.toString() ?? '',
      apellidoMaterno: map['apellidoMaterno']?.toString() ?? '',
      rancho: map['rancho']?.toString() ?? '',
      tel: map['tel']?.toString() ?? '',
    );
  }
}
