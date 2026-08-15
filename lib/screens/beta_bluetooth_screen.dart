import 'package:flutter/material.dart';
import '../services/bluetooth_manager.dart';

class BetaBluetoothScreen extends StatefulWidget {
  const BetaBluetoothScreen({super.key});

  @override
  State<BetaBluetoothScreen> createState() => _BetaBluetoothScreenState();
}

class _BetaBluetoothScreenState extends State<BetaBluetoothScreen> {
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
    final bt = BluetoothManager.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beta BLE Scanner"),
        backgroundColor: Colors.orange,
        actions: [
          if (bt.connectedDevice != null)
            IconButton(icon: const Icon(Icons.bluetooth_disabled), onPressed: bt.disconnectDevice)
        ],
      ),
      body: Column(
        children: [
          if (bt.connectedDevice == null) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: bt.isScanning ? bt.stopScan : bt.startScan,
                icon: Icon(bt.isScanning ? Icons.stop : Icons.search),
                label: Text(bt.isScanning ? "Detener Escaneo" : "Buscar Dispositivos"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: bt.isScanning ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: bt.scanResults.length,
                itemBuilder: (context, index) {
                  final result = bt.scanResults[index];
                  String name = result.device.platformName;
                  if (name.isEmpty) name = "Dispositivo Desconocido";
                  
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(result.device.remoteId.toString()),
                    trailing: ElevatedButton(
                      onPressed: () => bt.connectToDevice(
                        result.device,
                        onError: () {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Error al conectar")),
                            );
                          }
                        },
                      ),
                      child: const Text("Conectar"),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Conectado a: ${bt.connectedDevice!.platformName.isNotEmpty ? bt.connectedDevice!.platformName : bt.connectedDevice!.remoteId.toString()}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
            const Divider(),
            const Text("Datos Recibidos (Raw):", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: SingleChildScrollView(
                  child: Text(
                    bt.receivedData.isEmpty ? "Esperando datos del ESP32..." : bt.receivedData,
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                  ),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}
