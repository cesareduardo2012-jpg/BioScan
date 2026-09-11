import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/thermal_printer_service.dart';

class ConfigurarImpresoraScreen extends StatefulWidget {
  const ConfigurarImpresoraScreen({super.key});

  @override
  State<ConfigurarImpresoraScreen> createState() => _ConfigurarImpresoraScreenState();
}

class _ConfigurarImpresoraScreenState extends State<ConfigurarImpresoraScreen> {
  final ThermalPrinterService _printerService = ThermalPrinterService.instance;

  Map<String, String>? _configuredPrinter;
  List<BluetoothInfo> _availableDevices = [];
  bool _isLoading = true;
  bool _isPrintingTest = false;
  bool _isConnecting = false;
  bool _bluetoothEnabled = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadPrinterData();
  }

  Future<void> _loadPrinterData() async {
    setState(() => _isLoading = true);
    try {
      final configured = await _printerService.getConfiguredPrinter();
      final btEnabled = await _printerService.isBluetoothEnabled();
      List<BluetoothInfo> devices = [];

      if (btEnabled) {
        devices = await _printerService.getPairedPrinters();
      }

      if (mounted) {
        setState(() {
          _configuredPrinter = configured;
          _bluetoothEnabled = btEnabled;
          _availableDevices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error cargando dispositivos: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seleccionarImpresora(BluetoothInfo device) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Vinculando con ${device.name}...';
    });

    try {
      final mac = device.macAdress;
      final name = device.name.isNotEmpty ? device.name : 'Impresora Bluetooth';

      await _printerService.savePrinter(mac: mac, name: name);

      if (!mounted) return;

      setState(() {
        _configuredPrinter = {'mac': mac, 'name': name};
        _statusMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impresora "$name" configurada como predeterminada.'),
          backgroundColor: const Color(0xFF008C83),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al vincular: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _desvincularImpresora() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Impresora'),
        content: const Text('¿Desea desvincular la impresora térmica actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _printerService.clearConfiguredPrinter();
      if (mounted) {
        setState(() {
          _configuredPrinter = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impresora desvinculada.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _imprimirPrueba() async {
    if (_isPrintingTest) return;
    setState(() => _isPrintingTest = true);

    try {
      await _printerService.printTestTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket de prueba enviado a la impresora con éxito.'),
            backgroundColor: Color(0xFF008C83),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryStrong = Color(0xFF005267);
    const secondaryMild = Color(0xFF008C83);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Configurar Impresora',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryStrong,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Buscar dispositivos',
            onPressed: _isLoading ? null : _loadPrinterData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: secondaryMild))
          : RefreshIndicator(
              onRefresh: _loadPrinterData,
              color: secondaryMild,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // 1. BANNER DE ESTADO ACTUAL
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: _configuredPrinter != null
                                    ? secondaryMild.withValues(alpha: 0.15)
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.print,
                                  color: _configuredPrinter != null ? secondaryMild : Colors.grey.shade600,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _configuredPrinter != null
                                                ? _configuredPrinter!['name']!
                                                : 'Sin Impresora Configurada',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _configuredPrinter != null
                                                ? Colors.green.shade100
                                                : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _configuredPrinter != null ? 'VINCULADA' : 'NO CONFIGURADA',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _configuredPrinter != null
                                                  ? Colors.green.shade800
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _configuredPrinter != null
                                          ? 'MAC: ${_configuredPrinter!['mac']}'
                                          : 'Seleccione un dispositivo de la lista para emparejar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_configuredPrinter != null) ...[
                            const Divider(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryStrong,
                                      side: const BorderSide(color: primaryStrong),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: _isPrintingTest
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryStrong),
                                          )
                                        : const Icon(Icons.receipt_long, size: 18),
                                    label: const Text('Impresión de Prueba'),
                                    onPressed: _isPrintingTest ? null : _imprimirPrueba,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  tooltip: 'Desvincular impresora',
                                  onPressed: _desvincularImpresora,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryStrong),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(fontSize: 13, color: primaryStrong),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2. ALERTA DE BLUETOOTH DESACTIVADO
                  if (!_bluetoothEnabled) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bluetooth_disabled, color: Colors.orange.shade800),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'El Bluetooth está desactivado. Por favor actívelo en los ajustes del dispositivo.',
                              style: TextStyle(fontSize: 13, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. TÍTULO DE LISTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DISPOSITIVOS BLUETOOTH DETECTADOS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.1,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.sync, size: 16, color: secondaryMild),
                        label: const Text('Escanear', style: TextStyle(color: secondaryMild)),
                        onPressed: _loadPrinterData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 4. LISTA DE DISPOSITIVOS
                  if (_availableDevices.isEmpty) ...[
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No se encontraron dispositivos emparejados',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Asegúrese de encender su impresora térmica (58 mm) y vincularla primero en los Ajustes de Bluetooth de su teléfono/tablet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = _availableDevices[index];
                        final isSelected = _configuredPrinter?['mac'] == device.macAdress;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? secondaryMild : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? secondaryMild.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                              child: Icon(
                                Icons.print,
                                color: isSelected ? secondaryMild : Colors.grey.shade700,
                              ),
                            ),
                            title: Text(
                              device.name.isNotEmpty ? device.name : 'Dispositivo Bluetooth',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? primaryStrong : Colors.black87,
                              ),
                            ),
                            subtitle: Text('MAC: ${device.macAdress}'),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: secondaryMild)
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: secondaryMild,
                                      side: const BorderSide(color: secondaryMild),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _isConnecting ? null : () => _seleccionarImpresora(device),
                                    child: const Text('Vincular'),
                                  ),
                            onTap: () => _seleccionarImpresora(device),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 5. NOTA INFORMATIVA
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Formato compatible: Impresoras térmicas portátiles de 58 mm que soporten comandos ESC/POS vía Bluetooth (ej. marcas Goojprt, Netum, Xprinter, MPT-II).',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
