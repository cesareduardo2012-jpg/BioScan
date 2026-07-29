import 'package:flutter/material.dart';
import '../models/ganadero.dart';
import '../services/database_helper.dart';
import '../widgets/sensor_box.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ganaderos,
    required this.selectedGanaderoId,
    required this.onSelectedGanaderoChanged,
    required this.onMeasurementSaved,
  });

  final List<Ganadero> ganaderos;
  final String? selectedGanaderoId;
  final ValueChanged<String?> onSelectedGanaderoChanged;
  final Future<void> Function() onMeasurementSaved;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  String phValue = 'N/D';
  String aguaValue = 'N/D';
  String tempValue = 'N/D';

  void _connectBluetooth() {
    setState(() {
      isConnected = !isConnected;
      if (isConnected) {
        phValue = '6.7';
        aguaValue = '0.0%';
        tempValue = '24°C';
      } else {
        phValue = 'N/D';
        aguaValue = 'N/D';
        tempValue = 'N/D';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasGanaderos = widget.ganaderos.isNotEmpty;
    final selectedGanadero = widget.ganaderos.where((ganadero) => ganadero.id == widget.selectedGanaderoId).cast<Ganadero?>().firstOrNull;
    final canRegister = isConnected && selectedGanadero != null;

    return Scaffold(
      appBar: AppBar(title: const Text('BioScan - Terminal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: widget.selectedGanaderoId,
              decoration: const InputDecoration(labelText: 'Ganadero Responsable', border: OutlineInputBorder()),
              items: widget.ganaderos
                  .map((ganadero) => DropdownMenuItem<String>(value: ganadero.id, child: Text('${ganadero.nombreCompleto} (${ganadero.rancho})')))
                  .toList(),
              onChanged: widget.onSelectedGanaderoChanged,
              hint: const Text('Selecciona un ganadero'),
            ),
            const SizedBox(height: 12),
            if (!hasGanaderos)
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.amber),
                  title: const Text('Sin ganaderos'),
                  subtitle: const Text('Agrega ganaderos en la pestaña Ganaderos para poder asignarlos al escaneo.'),
                ),
              )
            else if (selectedGanadero != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(selectedGanadero.nombreCompleto),
                  subtitle: Text('Rancho: ${selectedGanadero.rancho} • Tel: ${selectedGanadero.tel}'),
                ),
              ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Icon(Icons.bluetooth, color: isConnected ? Colors.blue : Colors.grey),
              title: Text(isConnected ? 'Dispositivo Conectado' : 'Dispositivo Desconectado'),
              trailing: Switch(value: isConnected, onChanged: (val) => _connectBluetooth()),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SensorBox(label: 'pH', value: phValue, active: isConnected),
                SensorBox(label: 'Agua', value: aguaValue, active: isConnected),
                SensorBox(label: 'Temp', value: tempValue, active: isConnected),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: canRegister
                  ? () async {
                      try {
                        await DatabaseHelper.instance.insertMedicion(
                          ganaderoId: selectedGanadero.id,
                          ph: phValue,
                          agua: aguaValue,
                          temperatura: tempValue,
                        );
                        await widget.onMeasurementSaved();
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Medición registrada para ${selectedGanadero.nombreCompleto}')),
                        );
                      } catch (e, stackTrace) {
                        debugPrint('Error al registrar medición: $e');
                        debugPrint(stackTrace.toString());
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Error al guardar'),
                              content: Text('Ocurrió un error al guardar la medición: $e'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('REGISTRAR MEDICIÓN EN BD'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Iterable<Ganadero?> {
  Ganadero? get firstOrNull => isEmpty ? null : first;
}
