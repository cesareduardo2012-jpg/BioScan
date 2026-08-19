import 'package:flutter/material.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';

class HistorialMedicionesScreen extends StatelessWidget {
  const HistorialMedicionesScreen({super.key, required this.mediciones, required this.ganaderos});

  final List<Medicion> mediciones;
  final List<Ganadero> ganaderos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de mediciones')),
      body: mediciones.isEmpty
          ? const Center(child: Text('Aún no hay mediciones registradas.'))
          : ListView.builder(
              itemCount: mediciones.length,
              itemBuilder: (context, index) {
                final medicion = mediciones[index];
                final ganadero = ganaderos.firstWhere(
                  (item) => item.id == medicion.ganaderoId,
                  orElse: () => const Ganadero(id: '', nombre: '', apellidoPaterno: '', apellidoMaterno: '', rancho: '', tel: ''),
                );
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(ganadero.nombreCompleto.isEmpty ? 'Ganadero eliminado' : ganadero.nombreCompleto),
                    subtitle: Text('pH: ${medicion.ph} • Agua: ${medicion.agua} • Temp: ${medicion.temperatura}\n${medicion.fecha}'),
                  ),
                );
              },
            ),
    );
  }
}
