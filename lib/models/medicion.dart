class Medicion {
  const Medicion({
    required this.id,
    required this.ganaderoId,
    required this.ph,
    required this.agua,
    required this.temperatura,
    required this.fecha,
  });

  final String id;
  final String ganaderoId;
  final String ph;
  final String agua;
  final String temperatura;
  final String fecha;

  factory Medicion.fromMap(Map<String, dynamic> map) {
    return Medicion(
      id: map['id'].toString(),
      ganaderoId: map['ganaderoId'].toString(),
      ph: map['ph']?.toString() ?? '',
      agua: map['agua']?.toString() ?? '',
      temperatura: map['temperatura']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
    );
  }
}
