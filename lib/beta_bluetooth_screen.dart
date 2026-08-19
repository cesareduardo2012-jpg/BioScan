import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_theme.dart';

class BetaBluetoothScreen extends StatefulWidget {
  const BetaBluetoothScreen({super.key});

  @override
  State<BetaBluetoothScreen> createState() => _BetaBluetoothScreenState();
}

class _BetaBluetoothScreenState extends State<BetaBluetoothScreen> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  String _receivedData = "";

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });
    FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void _startScan() async {
    await _requestPermissions();
    _scanResults.clear();
    setState(() {
      _receivedData = "";
    });
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al escanear: $e")));
      }
    }
  }

  void _stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  void _connectToDevice(BluetoothDevice device) async {
    _stopScan();
    try {
      await device.connect();
      setState(() {
        _connectedDevice = device;
      });
      _discoverServices(device);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al conectar: $e")));
      }
    }
  }

  void _disconnectDevice() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      setState(() {
        _connectedDevice = null;
      });
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify || characteristic.properties.indicate) {
          try {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              _handleReceivedData(value);
            });
          } catch (e) {
            print("Error setting notify: $e");
          }
        } else if (characteristic.properties.read) {
          try {
            var value = await characteristic.read();
            _handleReceivedData(value);
          } catch (e) {
            print("Error reading: $e");
          }
        }
      }
    }
  }

  void _handleReceivedData(List<int> value) {
    if (value.isEmpty) return;
    String strData;
    try {
      strData = utf8.decode(value, allowMalformed: true);
    } catch (e) {
      strData = value.toString();
    }
    
    if (mounted) {
      setState(() {
        _receivedData += "$strData\n";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BioScanColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Beta BLE Scanner"),
        actions: [
          if (_connectedDevice != null)
            IconButton(icon: const Icon(Icons.bluetooth_disabled), onPressed: _disconnectDevice)
        ],
      ),
      body: Column(
        children: [
          if (_connectedDevice == null) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: _isScanning ? _stopScan : _startScan,
                icon: Icon(_isScanning ? Icons.stop : Icons.search),
                label: Text(_isScanning ? "Detener Escaneo" : "Buscar Dispositivos"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? colors.alert : colors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  final result = _scanResults[index];
                  String name = result.device.platformName;
                  if (name.isEmpty) name = "Dispositivo Desconocido";
                  
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(result.device.remoteId.toString()),
                    trailing: ElevatedButton(
                      onPressed: () => _connectToDevice(result.device),
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
                "Conectado a: ${_connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : _connectedDevice!.remoteId.toString()}",
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
                    _receivedData.isEmpty ? "Esperando datos del ESP32..." : _receivedData,
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

  @override
  void dispose() {
    _stopScan();
    _disconnectDevice();
    super.dispose();
  }
}
