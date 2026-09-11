import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hardware_simulator_service.dart';

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

  bool isMeasurementActive = false;
  bool isSimulationMode = false;

  void init() {
    FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
      notifyListeners();
    });
    FlutterBluePlus.isScanning.listen((state) {
      isScanning = state;
      notifyListeners();
    });

    _loadSimulationPreference();
  }

  Future<void> _loadSimulationPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSim = prefs.getBool('bioscan_simulation_mode') ?? false;
      if (savedSim) {
        setSimulationMode(true);
      }
    } catch (e) {
      debugPrint("Error al cargar preferencia de simulación: $e");
    }
  }

  /// Activa o desactiva el Modo Simulador de Hardware (BioScan-Demo)
  void setSimulationMode(bool enabled) {
    if (isSimulationMode == enabled && connectedDevice != null) return;
    isSimulationMode = enabled;

    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('bioscan_simulation_mode', enabled);
      });
    } catch (_) {}

    if (enabled) {
      // Desconectar hardware físico si estuviera conectado
      if (connectedDevice != null && connectedDevice!.remoteId.str != 'BioScan-Demo') {
        connectedDevice!.disconnect().catchError((_) {});
      }
      // Conectar cliente simulador BioScan-Demo
      connectedDevice = BluetoothDevice.fromId('BioScan-Demo');
      isMeasurementActive = false;
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      latestRawLine = "SIMULADOR CONECTADO (BioScan-Demo)";
      notifyListeners();
    } else {
      // Apagado limpio inmediato del servicio y timers
      HardwareSimulatorService.instance.stop();
      connectedDevice = null;
      isMeasurementActive = false;
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      latestRawLine = "";
      notifyListeners();
    }
  }

  Future<void> requestPermissions() async {
    if (isSimulationMode) return;
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  void startScan() async {
    if (isSimulationMode) return;
    await requestPermissions();
    scanResults.clear();
    receivedData = "";
    latestRawLine = "";
    isMeasurementActive = false;
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
    if (isSimulationMode) return;
    await FlutterBluePlus.stopScan();
  }

  void connectToDevice(BluetoothDevice device, {required VoidCallback onError}) async {
    if (isSimulationMode) return;
    stopScan();
    try {
      await device.connect();
      connectedDevice = device;
      isMeasurementActive = false;
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      notifyListeners();
      _discoverServices(device);
    } catch (e) {
      debugPrint("Error al conectar: $e");
      onError();
    }
  }

  void disconnectDevice() async {
    if (isSimulationMode) {
      HardwareSimulatorService.instance.stop();
      connectedDevice = null;
      isMeasurementActive = false;
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      latestRawLine = "";
      notifyListeners();
      return;
    }

    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
      receivedData = "";
      latestRawLine = "";
      isMeasurementActive = false;
      phActual = "N/D";
      temperaturaActual = "N/D";
      densidadActual = "N/D";
      notifyListeners();
    }
  }

  /// Inicia activamente la medición y el procesamiento proyectado de datos (real o simulado)
  void startMeasurement() {
    isMeasurementActive = true;
    if (isSimulationMode) {
      HardwareSimulatorService.instance.start(
        interval: const Duration(milliseconds: 1500),
        onData: (reading) {
          phActual = reading.ph;
          temperaturaActual = reading.temperatura;
          densidadActual = reading.densidad;
          latestRawLine = reading.rawLine;
          notifyListeners();
        },
      );
    } else {
      if (receivedData.isNotEmpty) {
        parseIncomingData(receivedData);
      }
    }
    notifyListeners();
  }

  /// Reinicia la medición y oculta la proyección hasta una nueva confirmación
  void resetMeasurement() {
    isMeasurementActive = false;
    if (isSimulationMode) {
      HardwareSimulatorService.instance.stop();
    }
    phActual = "N/D";
    temperaturaActual = "N/D";
    densidadActual = "N/D";
    notifyListeners();
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

    if (isMeasurementActive) {
      parseIncomingData(receivedData);
    }
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
    // El ESP32 manda valores que pueden ser negativos (ej. "D:-0.026", "P:-0.3"),
    // por lo que el signo "-" debe ser parte del valor capturado.
    final phMatches = RegExp(r'(?:Ph|PH|ph)\s*:\s*(-?[0-9.]+)', caseSensitive: false).allMatches(cleanData);
    if (phMatches.isNotEmpty && phMatches.last.group(1) != null) {
      phActual = phMatches.last.group(1)!;
    }

    final tempMatches = RegExp(r'(?:Temp|Temperatura|T)\s*:\s*(-?[0-9.]+\s*°?[CC]?)', caseSensitive: false).allMatches(cleanData);
    if (tempMatches.isNotEmpty && tempMatches.last.group(1) != null) {
      temperaturaActual = tempMatches.last.group(1)!;
    }

    // "D" (Densidad) es el valor a mostrar. "P" (Peso) llega en la misma trama
    // pero se ignora deliberadamente: el ESP32 ya usa P para calcular D internamente.
    final densMatches = RegExp(r'(?:Densidad|Dens|Agua|D)\s*:\s*(-?[0-9.]+%?)', caseSensitive: false).allMatches(cleanData);
    if (densMatches.isNotEmpty && densMatches.last.group(1) != null) {
      densidadActual = densMatches.last.group(1)!;
    }
  }
}
