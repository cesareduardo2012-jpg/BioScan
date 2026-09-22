import 'dart:async';
import 'dart:math';

class HardwareReading {
  final String ph;
  final String temperatura;
  final String densidad;
  final String rawLine;
  final int batteryLevel;

  const HardwareReading({
    required this.ph,
    required this.temperatura,
    required this.densidad,
    required this.rawLine,
    this.batteryLevel = 100,
  });
}

/// Servicio dedicado para emulación de hardware ESP32 y sensores físico-químicos.
/// Maneja ciclo de vida completo (start, stop, dispose) con liberación inmediata de recursos.
class HardwareSimulatorService {
  HardwareSimulatorService._();
  static final HardwareSimulatorService instance = HardwareSimulatorService._();

  final _random = Random();
  Timer? _timer;
  StreamController<HardwareReading>? _streamController;

  Stream<HardwareReading> get readingStream {
    _streamController ??= StreamController<HardwareReading>.broadcast();
    return _streamController!.stream;
  }

  bool get isRunning => _timer != null && _timer!.isActive;

  // Estado interno para variaciones continuas y suaves
  double _currentDensidad = 1.0305;
  double _currentTemp = 20.5;
  double _currentPh = 6.65;

  HardwareReading generateReading() {
    // 1. Variación suave de Densidad (Rango típico de leche fresca: 1.028 - 1.033 g/cm³)
    final deltaDens = (_random.nextDouble() - 0.5) * 0.0006;
    _currentDensidad = (_currentDensidad + deltaDens).clamp(1.0280, 1.0330);

    // 2. Variación suave de Temperatura (Rango: 18.0 - 23.0 °C)
    final deltaTemp = (_random.nextDouble() - 0.5) * 0.3;
    _currentTemp = (_currentTemp + deltaTemp).clamp(18.0, 23.0);

    // 3. Variación suave de pH (Rango: 6.50 - 6.80)
    final deltaPh = (_random.nextDouble() - 0.5) * 0.03;
    _currentPh = (_currentPh + deltaPh).clamp(6.50, 6.80);

    final phStr = _currentPh.toStringAsFixed(2);
    final tempStr = '${_currentTemp.toStringAsFixed(1)}°C';
    final densStr = _currentDensidad.toStringAsFixed(3);
    final rawLine = 'Ph: $phStr, T: $tempStr, D: $densStr';

    return HardwareReading(
      ph: phStr,
      temperatura: tempStr,
      densidad: densStr,
      rawLine: rawLine,
      batteryLevel: 100,
    );
  }

  /// Inicia la emisión periódica de datos simulados cada 1.5 segundos
  void start({Duration interval = const Duration(milliseconds: 1500), void Function(HardwareReading)? onData}) {
    stop();

    _streamController ??= StreamController<HardwareReading>.broadcast();

    // Emitir lectura inicial inmediata
    final initial = generateReading();
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.add(initial);
    }
    if (onData != null) onData(initial);

    // Iniciar timer periódico
    _timer = Timer.periodic(interval, (_) {
      final reading = generateReading();
      if (_streamController != null && !_streamController!.isClosed) {
        _streamController!.add(reading);
      }
      if (onData != null) onData(reading);
    });
  }

  /// Detiene inmediatamente el timer y cancela el consumo de CPU/memoria
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Libera recursos y cierra controladores de stream
  void dispose() {
    stop();
    _streamController?.close();
    _streamController = null;
  }
}
