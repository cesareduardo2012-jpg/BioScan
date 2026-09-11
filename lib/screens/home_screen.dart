import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../services/bluetooth_manager.dart';
import '../services/pdf_report_service.dart';
import '../services/thermal_printer_service.dart';
import '../utils/service_locator.dart';
import '../utils/uuid_generator.dart';
import '../widgets/sensor_box.dart';
import 'configurar_impresora_screen.dart';
import 'reporte_pdf_screen.dart';

enum MeasurementStep {
  densidad,
  tempAndPh,
  consolidacion,
}

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
  MeasurementStep _currentStep = MeasurementStep.densidad;
  String? _densidadCapturada;
  String? _phCapturado;
  String? _tempCapturada;
  bool _isSaving = false;

  bool _isDensityStabilizing = false;
  bool _isSensorsStabilizing = false;
  Timer? _densityTimer;
  Timer? _sensorsTimer;

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
    _densityTimer?.cancel();
    _sensorsTimer?.cancel();
    BluetoothManager.instance.removeListener(_onBluetoothStateChanged);
    super.dispose();
  }

  void _resetFlow() {
    _densityTimer?.cancel();
    _sensorsTimer?.cancel();
    setState(() {
      _currentStep = MeasurementStep.densidad;
      _densidadCapturada = null;
      _phCapturado = null;
      _tempCapturada = null;
      _isDensityStabilizing = false;
      _isSensorsStabilizing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final btManager = BluetoothManager.instance;
    final isConnected = btManager.connectedDevice != null;
    final isMeasurementActive = btManager.isMeasurementActive;

    final ph = isMeasurementActive ? btManager.phActual : "N/D";
    final temp = isMeasurementActive ? btManager.temperaturaActual : "N/D";
    final densidad = isMeasurementActive ? btManager.densidadActual : "N/D";

    final hasGanaderos = widget.ganaderos.isNotEmpty;
    final selectedGanadero = widget.ganaderos.where((ganadero) => ganadero.id == widget.selectedGanaderoId).cast<Ganadero?>().firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BioScan - Terminal de Escaneo'),
        actions: [
          // Interruptor Modo Simulación / Demo
          IconButton(
            icon: Icon(
              btManager.isSimulationMode ? Icons.science : Icons.science_outlined,
              color: btManager.isSimulationMode ? Colors.amberAccent : Colors.white,
            ),
            tooltip: btManager.isSimulationMode ? 'Desactivar Modo Simulación' : 'Activar Modo Simulación (Demo)',
            onPressed: () {
              final newMode = !btManager.isSimulationMode;
              btManager.setSimulationMode(newMode);
              _resetFlow();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(newMode ? 'Modo Simulación (Demo) Activado' : 'Modo Hardware Real Activado'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: newMode ? Colors.deepPurple : const Color(0xFF008C83),
                ),
              );
            },
          ),
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled, color: Colors.redAccent),
              tooltip: 'Desconectar ESP32',
              onPressed: () {
                btManager.disconnectDevice();
                _resetFlow();
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner de Modo Simulación Activo
              if (btManager.isSimulationMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.orange, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODO SIMULACIÓN (DEMO) ACTIVO',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                            ),
                            Text(
                              'Emulando lecturas físico-químicas automáticas • Batería 100%',
                              style: TextStyle(fontSize: 11, color: Colors.brown),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          btManager.setSimulationMode(false);
                          _resetFlow();
                        },
                        child: const Text('Salir', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                      ),
                    ],
                  ),
                ),

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

              // Estado de Conexión BLE / Simulación
              ListTile(
                tileColor: isConnected
                    ? (btManager.isSimulationMode ? Colors.purple.shade50 : Colors.green.shade50)
                    : Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  btManager.isSimulationMode ? Icons.science : Icons.bluetooth,
                  color: isConnected
                      ? (btManager.isSimulationMode ? Colors.purple : Colors.blue)
                      : Colors.grey,
                  size: 28,
                ),
                title: Text(
                  isConnected
                      ? (btManager.isSimulationMode
                          ? 'Dispositivo Conectado: BioScan-Demo (Batería 100%)'
                          : 'Conectado a: ${btManager.connectedDevice!.platformName.isNotEmpty ? btManager.connectedDevice!.platformName : btManager.connectedDevice!.remoteId.toString()}')
                      : 'Dispositivo Desconectado',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  !isConnected
                      ? 'Presiona buscar para conectar al sensor ESP32'
                      : (isMeasurementActive
                          ? (btManager.isSimulationMode
                              ? 'Generando flujo de datos simulados en tiempo real'
                              : 'Recibiendo flujo de datos BLE en tiempo real')
                          : 'Sensor listo. Presiona "Comenzar la medición" para iniciar.'),
                ),
                trailing: isConnected
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          btManager.disconnectDevice();
                          _resetFlow();
                        },
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
                )
              else if (!isMeasurementActive) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '¿Deseas verificar que la muestra esté a temperatura óptima antes de comenzar?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _showQuickTempCheckDialog(context, btManager),
                        icon: const Icon(Icons.thermostat, color: Colors.orange),
                        label: const Text('Verificar Temperatura', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade300, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSensorWarningDialog(context, btManager),
                  icon: const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text(
                    'Comenzar la medición',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF008C83),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () {
                    btManager.resetMeasurement();
                    _resetFlow();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Reiniciar Lectura / Nueva Muestra'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    foregroundColor: const Color(0xFF008C83),
                    side: const BorderSide(color: Color(0xFF008C83)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),

              if (isConnected && isMeasurementActive) ...[
                const SizedBox(height: 20),
                _buildStepperIndicator(),
                const SizedBox(height: 16),
                _buildCurrentStepContent(
                  selectedGanadero: selectedGanadero,
                  densidad: densidad,
                  temp: temp,
                  ph: ph,
                  isConnected: isConnected,
                  isMeasurementActive: isMeasurementActive,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepCircle(1, 'Densidad', _currentStep == MeasurementStep.densidad, _densidadCapturada != null),
          Expanded(child: Container(height: 2, color: _densidadCapturada != null ? const Color(0xFF008C83) : Colors.grey.shade300)),
          _buildStepCircle(2, 'pH y Temp', _currentStep == MeasurementStep.tempAndPh, _phCapturado != null && _tempCapturada != null),
          Expanded(child: Container(height: 2, color: (_phCapturado != null && _tempCapturada != null) ? const Color(0xFF008C83) : Colors.grey.shade300)),
          _buildStepCircle(3, 'Reporte', _currentStep == MeasurementStep.consolidacion, false),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int stepNumber, String title, bool isActive, bool isCompleted) {
    const activeColor = Color(0xFF008C83);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isCompleted
              ? Colors.green
              : (isActive ? activeColor : Colors.grey.shade300),
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? activeColor : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent({
    required Ganadero? selectedGanadero,
    required String densidad,
    required String temp,
    required String ph,
    required bool isConnected,
    required bool isMeasurementActive,
  }) {
    switch (_currentStep) {
      case MeasurementStep.densidad:
        return _buildStep1Densidad(
          densidad: densidad,
          canConfirm: selectedGanadero != null && densidad != 'N/D' && densidad.isNotEmpty,
        );

      case MeasurementStep.tempAndPh:
        return _buildStep2TempAndPh(
          temp: temp,
          ph: ph,
          canConfirm: selectedGanadero != null && temp != 'N/D' && ph != 'N/D',
        );

      case MeasurementStep.consolidacion:
        return _buildStep3Consolidacion(selectedGanadero: selectedGanadero);
    }
  }

  /// Paso 1: Cálculo y Lectura exclusiva de Densidad
  Widget _buildStep1Densidad({
    required String densidad,
    required bool canConfirm,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008C83).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science_outlined, color: Color(0xFF008C83), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso 1: Medición de Densidad',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                      ),
                      Text(
                        'Verifica que sean EXACTAMENTE 50 ml de leche y que no este nada encima de la balanza. \nEspere la estabilización.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Lectura destacada de Densidad
            Center(
              child: SizedBox(
                width: 220,
                child: SensorBox(
                  label: 'Densidad (g/mL o % Agua)',
                  value: densidad,
                  active: true,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón de acción requerido: "Guardar medición de la densidad"
            ElevatedButton.icon(
              onPressed: (canConfirm && !_isDensityStabilizing)
                  ? () {
                      setState(() {
                        _isDensityStabilizing = true;
                      });
                      _densityTimer = Timer(const Duration(seconds: 3), () {
                        if (mounted) {
                          setState(() {
                            _isDensityStabilizing = false;
                            _densidadCapturada = densidad;
                          });
                          _showSensorsPlacementDialog();
                        }
                      });
                    }
                  : null,
              icon: _isDensityStabilizing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 22),
              label: Text(
                _isDensityStabilizing ? 'Estabilizando balanza...' : 'Guardar medición de la densidad',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF008C83),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Paso 2: Lectura Simultánea de Temperatura y pH
  Widget _buildStep2TempAndPh({
    required String temp,
    required String ph,
    required bool canConfirm,
  }) {
    double? tempValue;
    try {
      tempValue = double.tryParse(temp.replaceAll(RegExp(r'[^0-9.-]'), ''));
    } catch (_) {}

    bool isTempWarning = false;
    String? tempWarningMessage;

    if (tempValue != null) {
      if (tempValue < 14.0) {
        isTempWarning = true;
        tempWarningMessage = 'Temperatura baja: Espera a que la muestra se caliente un poco para evitar distorsión en la densidad.';
      } else if (tempValue > 16.0) {
        isTempWarning = true;
        tempWarningMessage = 'Temperatura elevada: Refrigera la muestra unos minutos para alcanzar los 15°C óptimos.';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de Densidad ya confirmada
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Densidad guardada: $_densidadCapturada',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                      ),
                    ],
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() => _currentStep = MeasurementStep.densidad),
                    child: const Text('Recalcular', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF008C83).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.thermostat, color: Color(0xFF008C83), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso 2: Temperatura y pH',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                      ),
                      Text(
                        'Lectura simultánea de sensores fisicoquímicos en la muestra.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Sensores pH y Temperatura
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SensorBox(
                    label: 'pH',
                    value: ph,
                    active: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SensorBox(
                    label: 'Temperatura',
                    value: temp,
                    active: true,
                    isWarning: isTempWarning,
                    warningMessage: tempWarningMessage,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botón de confirmación Paso 2
            ElevatedButton.icon(
              onPressed: (canConfirm && !_isSensorsStabilizing)
                  ? () {
                      setState(() {
                        _phCapturado = ph;
                        _tempCapturada = temp;
                        _currentStep = MeasurementStep.consolidacion;
                      });
                    }
                  : null,
              icon: _isSensorsStabilizing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.arrow_forward_rounded, size: 22),
              label: Text(
                _isSensorsStabilizing ? 'Estabilizando sensores...' : 'Confirmar Temperatura y pH',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF008C83),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Paso 3: Consolidación y Generación de Reporte PDF
  Widget _buildStep3Consolidacion({required Ganadero? selectedGanadero}) {
    final btManager = BluetoothManager.instance;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_turned_in, color: Color(0xFF1A237E), size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paso 3: Consolidación y Reporte',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                      ),
                      Text(
                        'Verifique los 3 parámetros antes de generar el PDF y guardar.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resumen de Ganadero y Dispositivo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFF1A237E)),
                      const SizedBox(width: 6),
                      Text(
                        selectedGanadero?.nombreCompleto ?? 'Ganadero no asignado',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rancho: ${selectedGanadero?.rancho ?? "N/D"} • Teléfono: ${selectedGanadero?.tel ?? "N/D"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tabla/Tarjetas de los 3 parámetros consolidados
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF008C83).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF008C83).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildConsolidatedRow('Densidad de la muestra:', _densidadCapturada ?? 'N/D', Icons.science_outlined, Colors.teal),
                  const Divider(height: 16),
                  _buildConsolidatedRow('Potencial de Hidrógeno (pH):', _phCapturado ?? 'N/D', Icons.water_drop, Colors.purple),
                  const Divider(height: 16),
                  _buildConsolidatedRow('Temperatura:', _tempCapturada ?? 'N/D', Icons.thermostat, Colors.orange),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botón de Guardar Medición y Generar Reporte PDF
            ElevatedButton.icon(
              onPressed: (_isSaving || selectedGanadero == null)
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      try {
                        final clienteId = widget.cliente?.id ?? ServiceLocator.authService.activeClienteId;
                        final connectedDevice = btManager.connectedDevice;

                        // Registrar dispositivo si existe
                        if (connectedDevice != null) {
                          await ServiceLocator.dispositivoRepository.insertDispositivo(
                            Dispositivo(
                              id: connectedDevice.remoteId.toString(),
                              clienteId: clienteId,
                              numeroSerie: connectedDevice.remoteId.toString(),
                              nombre: connectedDevice.platformName.isNotEmpty ? connectedDevice.platformName : 'Sensor ESP32',
                              modelo: 'ESP32 BioScan',
                              fechaRegistro: DateTime.now().toIso8601String(),
                            ),
                          );
                        }

                        final medicionId = UuidGenerator.generate();
                        final medicionPrevia = Medicion(
                          id: medicionId,
                          clienteId: clienteId,
                          ganaderoId: selectedGanadero.id,
                          dispositivoId: connectedDevice?.remoteId.toString(),
                          usuarioId: widget.usuario?.id ?? ServiceLocator.authService.currentUser?.id,
                          ph: _phCapturado ?? 'N/D',
                          agua: _densidadCapturada ?? 'N/D',
                          temperatura: _tempCapturada ?? 'N/D',
                          fecha: DateTime.now().toIso8601String(),
                          observaciones: btManager.latestRawLine,
                          sincronizado: false,
                        );

                        // Generar y persistir físicamente el PDF en el almacenamiento local del dispositivo
                        File? savedPdfFile;
                        try {
                          savedPdfFile = await PdfReportService.saveMeasurementReportPdf(
                            medicion: medicionPrevia,
                            ganadero: selectedGanadero,
                            cliente: widget.cliente,
                            usuario: widget.usuario,
                            dispositivo: connectedDevice != null
                                ? Dispositivo(
                                    id: connectedDevice.remoteId.toString(),
                                    clienteId: clienteId,
                                    numeroSerie: connectedDevice.remoteId.toString(),
                                    nombre: connectedDevice.platformName.isNotEmpty ? connectedDevice.platformName : 'Sensor ESP32',
                                    modelo: 'ESP32 BioScan',
                                    fechaRegistro: DateTime.now().toIso8601String(),
                                  )
                                : null,
                          );
                        } catch (e) {
                          debugPrint('Error guardando archivo PDF local: $e');
                        }

                        final medicionFinal = medicionPrevia.copyWith(
                          pdfPath: savedPdfFile?.path,
                        );

                        // Insertar en la base de datos local SQLite
                        await ServiceLocator.medicionRepository.insertMedicion(medicionFinal);
                        await widget.onMeasurementSaved();

                        // Sincronizar en segundo plano con Supabase Nube
                        ServiceLocator.syncService.syncPendingRecords();

                        // Reiniciar Bluetooth y flujo para la siguiente muestra
                        btManager.resetMeasurement();
                        _resetFlow();

                        if (!mounted) return;

                        // Obtener los datos persistidos en SQLite para garantizar alineación absoluta
                        final medicionPersistida = await ServiceLocator.medicionRepository.getMedicionById(medicionFinal.id) ?? medicionFinal;
                        final ganaderoPersistido = await ServiceLocator.ganaderoRepository.getGanaderoById(selectedGanadero.id) ?? selectedGanadero;

                        if (!mounted) return;

                        // Mostrar diálogo modal selector de exportación (Estilo Kyte)
                        _mostrarSelectorExportacion(context, medicionPersistida, ganaderoPersistido);
                      } catch (e, stackTrace) {
                        debugPrint('Error al registrar medición: $e');
                        debugPrint(stackTrace.toString());
                        if (mounted) {
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
                      } finally {
                        if (mounted) {
                          setState(() => _isSaving = false);
                        }
                      }
                    },
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.assignment_turned_in, size: 22),
              label: Text(
                _isSaving ? 'Guardando Análisis...' : 'Finalizar y Emitir Comprobante',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF008C83),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Botón para repetir la toma de muestra si se requiere
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _resetFlow,
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Reiniciar flujo / Medir de nuevo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsolidatedRow(String label, String value, IconData icon, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
        ),
      ],
    );
  }

  void _mostrarSelectorExportacion(
    BuildContext context,
    Medicion medicion,
    Ganadero ganadero,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF008C83).withValues(alpha: 0.15),
                  child: const Icon(Icons.check, color: Color(0xFF008C83)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¡Análisis Guardado en Base de Datos!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Productor: ${ganadero.nombreCompleto}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'SELECCIONE CÓMO DESEA EMITIR EL COMPROBANTE:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
            ),
            const SizedBox(height: 12),
            // Opción 1: Generar Reporte PDF
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF005267).withValues(alpha: 0.12),
                  child: const Icon(Icons.picture_as_pdf, color: Color(0xFF005267)),
                ),
                title: const Text('Generar PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Reporte oficial en PDF para compartir por WhatsApp, AirDrop o imprimir en hoja carta.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.pop(modalCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ReportePdfScreen(
                        medicion: medicion,
                        ganadero: ganadero,
                        cliente: widget.cliente,
                        usuario: widget.usuario,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Opción 2: Imprimir Ticket Térmico
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF008C83).withValues(alpha: 0.12),
                  child: const Icon(Icons.receipt_long, color: Color(0xFF008C83)),
                ),
                title: const Text('Imprimir Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Impresión inmediata en ticket físico de 58 mm vía Bluetooth portátil.'),
                trailing: const Icon(Icons.print, size: 20, color: Color(0xFF008C83)),
                onTap: () {
                  Navigator.pop(modalCtx);
                  _ejecutarImpresionTicket(context, medicion, ganadero);
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(modalCtx),
                child: const Text('Cerrar y continuar escaneando', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarImpresionTicket(
    BuildContext context,
    Medicion medicion,
    Ganadero ganadero,
  ) async {
    final printerService = ThermalPrinterService.instance;
    final configured = await printerService.getConfiguredPrinter();

    if (!context.mounted) return;

    if (configured == null) {
      await showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print_disabled_outlined, color: Colors.orange),
              SizedBox(width: 10),
              Text('Impresora No Configurada'),
            ],
          ),
          content: const Text(
            'No hay ninguna impresora térmica Bluetooth vinculada para imprimir el ticket (58 mm).\n\n'
            '¿Desea configurar y emparejar su impresora ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              icon: const Icon(Icons.settings_bluetooth, size: 18),
              label: const Text('Configurar Impresora'),
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => const ConfigurarImpresoraScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    // Mostrar SnackBar de progreso
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Imprimiendo ticket en ${configured['name']}...'),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF005267),
      ),
    );

    try {
      await printerService.printMeasurementTicket(
        medicion: medicion,
        ganadero: ganadero,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket impreso correctamente para ${ganadero.nombreCompleto}'),
          backgroundColor: const Color(0xFF008C83),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (errCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error de Impresión'),
            ],
          ),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(errCtx),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () {
                Navigator.pop(errCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => const ConfigurarImpresoraScreen(),
                  ),
                );
              },
              child: const Text('Revisar Impresora'),
            ),
          ],
        ),
      );
    }
  }

  void _showQuickTempCheckDialog(BuildContext context, BluetoothManager btManager) {
    btManager.startMeasurement();
    bool confirmed = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalCtx) {
        return ListenableBuilder(
          listenable: btManager,
          builder: (ctx, child) {
            final temp = btManager.temperaturaActual;
            double? tempValue;
            try {
              tempValue = double.tryParse(temp.replaceAll(RegExp(r'[^0-9.-]'), ''));
            } catch (_) {}

            bool isOptimal = false;
            bool isLow = false;
            bool isHigh = false;

            if (tempValue != null) {
              if (tempValue >= 14.0 && tempValue <= 16.0) isOptimal = true;
              else if (tempValue < 14.0) isLow = true;
              else if (tempValue > 16.0) isHigh = true;
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thermostat, size: 40, color: Colors.orange),
                  const SizedBox(height: 12),
                  const Text('Pre-chequeo Térmico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(
                    temp == 'N/D' ? 'Obteniendo...' : temp,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: isOptimal ? Colors.green : (temp == 'N/D' ? Colors.grey : Colors.amber.shade900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (isOptimal)
                    const Text('Lista para análisis (15°C óptimo)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600))
                  else if (isLow)
                    const Text('Temperatura baja. Caliente la muestra.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600))
                  else if (isHigh)
                    const Text('Temperatura elevada. Refrigere la muestra.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(modalCtx);
                          },
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
                          onPressed: isOptimal ? () {
                            confirmed = true;
                            Navigator.pop(modalCtx);
                            btManager.resetMeasurement();
                            _showSensorWarningDialog(context, btManager);
                          } : null,
                          child: const Text('Iniciar Análisis'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (!confirmed) {
        btManager.resetMeasurement();
      }
    });
  }

  void _showSensorWarningDialog(BuildContext context, BluetoothManager btManager) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Preparación y Calibración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Antes de iniciar, verifica lo siguiente:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _ChecklistItem(text: 'Volumen exacto: Exactamente 50 ml de leche en el recipiente.'),
            _ChecklistItem(text: 'Balanza despejada: Sin objetos sobre la celda de carga.'),
            _ChecklistItem(text: 'Sin sensores sumergidos: Ningún sensor dentro del recipiente durante el pesaje inicial.'),
            _ChecklistItem(text: 'Temperatura: Recomendado 15°C (14°C - 16°C).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008C83),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar Prueba'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              btManager.startMeasurement();
            },
          ),
        ],
      ),
    );
  }

  void _showSensorsPlacementDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Paso 2: Colocación de Sensores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          'Coloca cuidadosamente tanto el sensor de temperatura como el de pH sumergidos en la muestra de leche sin tocar el fondo ni las paredes.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008C83),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar con la medición'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              setState(() {
                _currentStep = MeasurementStep.tempAndPh;
                _isSensorsStabilizing = true;
              });
              _sensorsTimer = Timer(const Duration(seconds: 6), () {
                if (mounted) {
                  setState(() {
                    _isSensorsStabilizing = false;
                  });
                }
              });
            },
          ),
        ],
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

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
