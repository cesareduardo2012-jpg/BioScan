import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../services/bluetooth_manager.dart';
import '../utils/service_locator.dart';
import '../utils/uuid_generator.dart';
import '../widgets/sensor_box.dart';
import 'reporte_pdf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ganaderos,
    required this.selectedGanaderoId,
    required this.onSelectedGanaderoChanged,
    required this.onMeasurementSaved,
    this.cliente,
    this.usuario,
  });

  final List<Ganadero> ganaderos;
  final String? selectedGanaderoId;
  final ValueChanged<String?> onSelectedGanaderoChanged;
  final Future<void> Function() onMeasurementSaved;
  final Cliente? cliente;
  final Usuario? usuario;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    BluetoothManager.instance.addListener(_onBluetoothStateChanged);
  }

  void _onBluetoothStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    BluetoothManager.instance.removeListener(_onBluetoothStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btManager = BluetoothManager.instance;
    final isConnected = btManager.connectedDevice != null;

    final ph = btManager.phActual;
    final temp = btManager.temperaturaActual;
    final densidad = btManager.densidadActual;

    final hasGanaderos = widget.ganaderos.isNotEmpty;
    final selectedGanadero = widget.ganaderos.where((ganadero) => ganadero.id == widget.selectedGanaderoId).cast<Ganadero?>().firstOrNull;
    final canRegister = isConnected && selectedGanadero != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BioScan - Terminal de Escaneo'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.redAccent),
              tooltip: 'Desconectar ESP32',
              onPressed: btManager.disconnectDevice,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de Ganadero
              DropdownButtonFormField<String>(
                initialValue: widget.selectedGanaderoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ganadero Responsable',
                  prefixIcon: Icon(Icons.person_pin),
                  border: OutlineInputBorder(),
                ),
                items: widget.ganaderos
                    .map((ganadero) => DropdownMenuItem<String>(
                          value: ganadero.id,
                          child: Text(
                            '${ganadero.nombreCompleto} (${ganadero.rancho})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: widget.onSelectedGanaderoChanged,
                hint: const Text('Selecciona un ganadero'),
              ),
              const SizedBox(height: 12),

              if (!hasGanaderos)
                Card(
                  color: Colors.amber.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline, color: Colors.amber),
                    title: Text('Sin ganaderos'),
                    subtitle: Text('Agrega ganaderos en la pestaña Ganaderos para poder asignarlos al escaneo.'),
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

              const SizedBox(height: 16),

              // Estado de Conexión BLE
              ListTile(
                tileColor: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  Icons.bluetooth,
                  color: isConnected ? Colors.blue : Colors.grey,
                  size: 28,
                ),
                title: Text(
                  isConnected
                      ? 'Conectado a: ${btManager.connectedDevice!.platformName.isNotEmpty ? btManager.connectedDevice!.platformName : btManager.connectedDevice!.remoteId.toString()}'
                      : 'Dispositivo Desconectado',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isConnected ? 'Recibiendo flujo de datos BLE en tiempo real' : 'Presiona buscar para conectar al sensor ESP32',
                ),
                trailing: isConnected
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: btManager.disconnectDevice,
                      )
                    : null,
              ),
              const SizedBox(height: 10),

              if (!isConnected)
                ElevatedButton.icon(
                  onPressed: () {
                    btManager.startScan();
                    _showDeviceSelectionDialog(context);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar Dispositivos BLE (ESP32)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              const SizedBox(height: 20),

              // Cajas de Sensores (pH, Temperatura, Densidad)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: SensorBox(label: 'pH', value: ph, active: isConnected)),
                  const SizedBox(width: 8),
                  Expanded(child: SensorBox(label: 'Temperatura', value: temp, active: isConnected)),
                  const SizedBox(width: 8),
                  Expanded(child: SensorBox(label: 'Densidad', value: densidad, active: isConnected)),
                ],
              ),

              const SizedBox(height: 24),

              // Botón Guardar Medición
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: canRegister
                      ? () async {
                          try {
                            final medicion = Medicion(
                              id: UuidGenerator.generate(),
                              clienteId: widget.cliente?.id ?? ServiceLocator.authService.activeClienteId,
                              ganaderoId: selectedGanadero.id,
                              dispositivoId: btManager.connectedDevice?.remoteId.toString(),
                              usuarioId: widget.usuario?.id ?? ServiceLocator.authService.currentUser?.id,
                              ph: ph,
                              agua: densidad,
                              temperatura: temp,
                              fecha: DateTime.now().toIso8601String(),
                              observaciones: btManager.latestRawLine,
                              sincronizado: false,
                            );
                            await ServiceLocator.medicionRepository.insertMedicion(medicion);
                            await widget.onMeasurementSaved();

                            // Sincronizar y respaldar en tiempo real a Supabase Nube
                            ServiceLocator.syncService.syncPendingRecords();

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Medición registrada para ${selectedGanadero.nombreCompleto}')),
                            );

                            // Desplegar automáticamente el reporte PDF
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => ReportePdfScreen(
                                  medicion: medicion,
                                  ganadero: selectedGanadero,
                                  cliente: widget.cliente,
                                  usuario: widget.usuario,
                                ),
                              ),
                            );
                          } catch (e, stackTrace) {
                            debugPrint('Error al registrar medición: $e');
                            debugPrint(stackTrace.toString());
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Error al guardar'),
                                  content: Text('No se pudo guardar la medición: $e'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext),
                                      child: const Text('Aceptar'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Registrar y Generar Reporte PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008C83),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return ListenableBuilder(
          listenable: BluetoothManager.instance,
          builder: (context, _) {
            final bt = BluetoothManager.instance;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Buscar Dispositivos BLE'),
                  if (bt.isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.orange),
                      onPressed: bt.startScan,
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 260,
                child: bt.scanResults.isEmpty
                    ? Center(
                        child: Text(
                          bt.isScanning ? 'Buscando sensores ESP32...' : 'No se encontraron dispositivos',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: bt.scanResults.length,
                        itemBuilder: (ctx, index) {
                          final result = bt.scanResults[index];
                          String name = result.device.platformName;
                          if (name.isEmpty) name = "Dispositivo Desconocido";

                          return ListTile(
                            leading: const Icon(Icons.bluetooth, color: Colors.blue),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(result.device.remoteId.toString()),
                            onTap: () {
                              bt.connectToDevice(
                                result.device,
                                onError: () {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      const SnackBar(content: Text('Error al conectar con el dispositivo ESP32')),
                                    );
                                  }
                                },
                              );
                              Navigator.pop(dialogContext);
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    bt.stopScan();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

extension on Iterable<Ganadero?> {
  Ganadero? get firstOrNull => isEmpty ? null : first;
}
