import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  BluetoothManager._();
  static final BluetoothManager instance = BluetoothManager._();

  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  String receivedData = "";
  String latestRawLine = "";

  String phActual = "N/D";
  String temperaturaActual = "N/D";
  String densidadActual = "N/D";

  void init() {
    FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      notifyListeners();
    });
    FlutterBluePlus.isScanning.listen((state) {
      isScanning = state;
      notifyListeners();
    });
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void startScan() async {
    await requestPermissions();
    scanResults.clear();
    receivedData = "";
    latestRawLine = "";
    phActual = "N/D";
    temperaturaActual = "N/D";
    densidadActual = "N/D";
    notifyListeners();
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Error al escanear: $e");
    }
  }

  void stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  void connectToDevice(BluetoothDevice device, {required VoidCallback onError}) async {
    stopScan();
    try {
      await device.connect();
      connectedDevice = device;
      notifyListeners();
      _discoverServices(device);
    } catch (e) {
      debugPrint("Error al conectar: $e");
      onError();
    }
  }

  void disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      receivedData = "";
      latestRawLine = "";
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      notifyListeners();
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
            debugPrint("Error setting notify: $e");
          }
        } else if (characteristic.properties.read) {
          try {
            var value = await characteristic.read();
            _handleReceivedData(value);
          } catch (e) {
            debugPrint("Error reading: $e");
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

    receivedData += strData;
    latestRawLine = strData.trim();

    // Control de tamaño de buffer para evitar fugas de memoria
    if (receivedData.length > 2000) {
      receivedData = receivedData.substring(receivedData.length - 1000);
    }

    parseIncomingData(receivedData);
    notifyListeners();
  }

  /// Procesa la cadena acumulada o fragmentada buscando SIEMPRE la ÚLTIMA lectura enviada por el ESP32
  void parseIncomingData(String data) {
    final cleanData = data.trim();
    if (cleanData.isEmpty) return;

    // 1. Si la entrada viene como JSON estructurado
    try {
      if (cleanData.startsWith('{') && cleanData.endsWith('}')) {
        final parsed = jsonDecode(cleanData) as Map<String, dynamic>;
        if (parsed.containsKey('ph') || parsed.containsKey('Ph')) {
          phActual = (parsed['ph'] ?? parsed['Ph']).toString();
        }
        if (parsed.containsKey('temp') || parsed.containsKey('temperatura') || parsed.containsKey('T')) {
          temperaturaActual = (parsed['temp'] ?? parsed['temperatura'] ?? parsed['T']).toString();
        }
        if (parsed.containsKey('densidad') || parsed.containsKey('dens') || parsed.containsKey('D')) {
          densidadActual = (parsed['densidad'] ?? parsed['dens'] ?? parsed['D']).toString();
        }
        return;
      }
    } catch (_) {}

    // 2. Extraer SIEMPRE la ÚLTIMA ocurrencia usando Expresiones Regulares para Ph, T, D
    final phMatches = RegExp(r'(?:Ph|PH|ph)\s*:\s*([0-9.]+)', caseSensitive: false).allMatches(cleanData);
    if (phMatches.isNotEmpty && phMatches.last.group(1) != null) {
      phActual = phMatches.last.group(1)!;
    }

    final tempMatches = RegExp(r'(?:Temp|Temperatura|T)\s*:\s*([0-9.]+\s*°?[CC]?)', caseSensitive: false).allMatches(cleanData);
    if (tempMatches.isNotEmpty && tempMatches.last.group(1) != null) {
      temperaturaActual = tempMatches.last.group(1)!;
    }

    final densMatches = RegExp(r'(?:Densidad|Dens|Agua|D)\s*:\s*([0-9.]+%?)', caseSensitive: false).allMatches(cleanData);
    if (densMatches.isNotEmpty && densMatches.last.group(1) != null) {
      densidadActual = densMatches.last.group(1)!;
    }
  }
}
