import 'dart:async';
import 'dart:math';

class MockReading {
  final String ph;
  final String temperatura;
  final String densidad;
  final String rawLine;

  const MockReading({
    required this.ph,
    required this.temperatura,
    required this.densidad,
    required this.rawLine,
  });
}

class MockSensorService {
  MockSensorService._();
  static final MockSensorService instance = MockSensorService._();

  final _random = Random();
  Timer? _timer;
  final _streamController = StreamController<MockReading>.broadcast();

  Stream<MockReading> get readingStream => _streamController.stream;
  bool get isRunning => _timer != null && _timer!.isActive;

  // Estado interno para variaciones continuas y suaves
  double _currentDensidad = 1.0305;
  double _currentTemp = 21.4;
  double _currentPh = 6.65;

  MockReading generateReading() {
    // 1. Variación suave de Densidad (Rango: 1.028 - 1.033)
    final deltaDens = (_random.nextDouble() - 0.5) * 0.0008;
    _currentDensidad = (_currentDensidad + deltaDens).clamp(1.0280, 1.0330);

    // 2. Variación suave de Temperatura (Rango: 18.0 - 24.0 °C)
    final deltaTemp = (_random.nextDouble() - 0.5) * 0.4;
    _currentTemp = (_currentTemp + deltaTemp).clamp(18.0, 24.0);

    // 3. Variación suave de pH (Rango: 6.50 - 6.80)
    final deltaPh = (_random.nextDouble() - 0.5) * 0.04;
    _currentPh = (_currentPh + deltaPh).clamp(6.50, 6.80);

    final phStr = _currentPh.toStringAsFixed(2);
    final tempStr = '${_currentTemp.toStringAsFixed(1)}°C';
    final densStr = _currentDensidad.toStringAsFixed(3);
    final rawLine = 'Ph: $phStr, T: $tempStr, D: $densStr';

    return MockReading(
      ph: phStr,
      temperatura: tempStr,
      densidad: densStr,
      rawLine: rawLine,
    );
  }

  void startSimulation({Duration interval = const Duration(milliseconds: 1200), void Function(MockReading)? onData}) {
    stopSimulation();
    // Emitir lectura inicial inmediata
    final initial = generateReading();
    _streamController.add(initial);
    if (onData != null) onData(initial);

    _timer = Timer.periodic(interval, (_) {
      final reading = generateReading();
      _streamController.add(reading);
      if (onData != null) onData(reading);
    });
  }

  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopSimulation();
    _streamController.close();
  }
}
