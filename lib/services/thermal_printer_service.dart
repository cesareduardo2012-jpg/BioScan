import 'dart:async';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analisis_leche.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';

/// Excepción personalizada para errores del módulo de impresión térmica
class ThermalPrinterException implements Exception {
  final String message;
  const ThermalPrinterException(this.message);

  @override
  String toString() => message;
}

/// Servicio centralizado para configuración, conexión e impresión de tickets térmicos Bluetooth (58 mm)
class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  static const String _prefMacKey = 'bioscan_thermal_printer_mac';
  static const String _prefNameKey = 'bioscan_thermal_printer_name';

  // Caché en memoria
  String? _cachedMac;
  String? _cachedName;

  /// Inicializa cargando la impresora configurada desde SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedMac = prefs.getString(_prefMacKey);
    _cachedName = prefs.getString(_prefNameKey);
  }

  /// Retorna los datos de la impresora configurada (mac y name) o null si no hay ninguna
  Future<Map<String, String>?> getConfiguredPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefMacKey) ?? _cachedMac;
    final name = prefs.getString(_prefNameKey) ?? _cachedName;

    if (mac != null && mac.trim().isNotEmpty) {
      _cachedMac = mac;
      _cachedName = name;
      return {
        'mac': mac.trim(),
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : 'Impresora Térmica',
      };
    }
    return null;
  }

  /// Guarda permanentemente la impresora seleccionada en SharedPreferences
  Future<void> savePrinter({required String mac, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMacKey, mac.trim());
    await prefs.setString(_prefNameKey, name.trim());
    _cachedMac = mac.trim();
    _cachedName = name.trim();
    debugPrint('[THERMAL PRINTER] Impresora guardada: $name ($mac)');
  }

  /// Elimina la configuración de la impresora
  Future<void> clearConfiguredPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefMacKey);
    await prefs.remove(_prefNameKey);
    _cachedMac = null;
    _cachedName = null;
    try {
      await disconnect();
    } catch (_) {}
    debugPrint('[THERMAL PRINTER] Configuración de impresora eliminada.');
  }

  /// Verifica si el Bluetooth está encendido
  Future<bool> isBluetoothEnabled() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return true; // En desktop no bloqueamos el flujo por hardware móvil
    }
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('[THERMAL PRINTER] Error verificando bluetoothEnabled: $e');
      return true;
    }
  }

  /// Verifica los permisos de Bluetooth
  Future<bool> checkPermissions() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return true;
    }
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (e) {
      debugPrint('[THERMAL PRINTER] Error verificando permisos Bluetooth: $e');
      return true;
    }
  }

  /// Obtiene la lista de dispositivos Bluetooth emparejados en el sistema
  Future<List<BluetoothInfo>> getPairedPrinters() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return [];
    }
    try {
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('[THERMAL PRINTER] Dispositivos emparejados detectados: ${devices.length}');
      return devices;
    } catch (e) {
      debugPrint('[THERMAL PRINTER] Error obteniendo dispositivos emparejados: $e');
      return [];
    }
  }

  /// Verifica el estado de conexión actual con la impresora
  Future<bool> isConnected() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return _cachedMac != null;
    }
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Conecta con la impresora especificada o con la guardada en SharedPreferences
  Future<bool> connect({String? mac}) async {
    String? targetMac = mac ?? _cachedMac;
    if (targetMac == null || targetMac.isEmpty) {
      final configured = await getConfiguredPrinter();
      targetMac = configured?['mac'];
    }

    if (targetMac == null || targetMac.isEmpty) {
      throw const ThermalPrinterException('No hay ninguna impresora configurada.');
    }

    // Verificar si ya está conectada a la misma MAC
    final alreadyConnected = await isConnected();
    if (alreadyConnected) {
      return true;
    }

    final btEnabled = await isBluetoothEnabled();
    if (!btEnabled) {
      throw const ThermalPrinterException('El Bluetooth está desactivado. Actívelo para conectar la impresora.');
    }

    debugPrint('[THERMAL PRINTER] Conectando a $targetMac...');
    try {
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: targetMac)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw const ThermalPrinterException('Tiempo de espera agotado al intentar conectar con la impresora.');
      });

      if (!success) {
        throw const ThermalPrinterException('No fue posible conectar con la impresora. Verifique que esté encendida y en rango.');
      }

      debugPrint('[THERMAL PRINTER] Conexión establecida con éxito.');
      return true;
    } catch (e) {
      if (e is ThermalPrinterException) rethrow;
      throw ThermalPrinterException('Error al conectar con la impresora: $e');
    }
  }

  /// Desconecta de la impresora Bluetooth
  Future<void> disconnect() async {
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return;
    }
    try {
      await PrintBluetoothThermal.disconnect;
      debugPrint('[THERMAL PRINTER] Desconectado.');
    } catch (e) {
      debugPrint('[THERMAL PRINTER] Error al desconectar: $e');
    }
  }

  // ===========================================================================
  // FORMATEO Y GENERACIÓN DE BYTES ESC/POS (58 mm / 32 CARACTERES POR LÍNEA)
  // ===========================================================================

  /// Genera los bytes ESC/POS para la impresión de prueba
  Future<List<int>> generateTestTicketBytes({DateTime? fecha}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final dateNow = fecha ?? DateTime.now();
    final dateStr = '${dateNow.day.toString().padLeft(2, '0')}/${dateNow.month.toString().padLeft(2, '0')}/${dateNow.year} '
        '${dateNow.hour.toString().padLeft(2, '0')}:${dateNow.minute.toString().padLeft(2, '0')}';

    // Encabezado
    bytes += generator.text(
      '=== BIOSCAN ===',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'DIAGNOSTICO DE LECHE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Mensaje de prueba
    bytes += generator.feed(1);
    bytes += generator.text(
      'IMPRESION DE PRUEBA',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(1);
    bytes += generator.text(
      'Impresora lista para usar',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.feed(1);

    // Detalles técnicos
    bytes += generator.text('Formato: Ticket 58 mm');
    bytes += generator.text('Columnas: 32 caracteres');
    bytes += generator.text('Fecha: $dateStr');
    bytes += generator.text('Protocolo: ESC/POS Bluetooth');

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'BioScan Mobile System',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Genera los bytes ESC/POS para el ticket oficial de análisis de leche (58 mm)
  Future<List<int>> generateMeasurementTicketBytes({
    required Medicion medicion,
    required Ganadero ganadero,
    DateTime? fecha,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    final analysis = AnalisisLeche.evaluate(medicion);

    // Parsear fecha
    DateTime parsedDate;
    try {
      parsedDate = fecha ?? DateTime.parse(medicion.fecha);
    } catch (_) {
      parsedDate = fecha ?? DateTime.now();
    }
    final dateStr = '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} '
        '${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';

    final folioShort = medicion.id.length > 8 ? medicion.id.substring(0, 8).toUpperCase() : medicion.id.toUpperCase();

    // 1. ENCABEZADO
    bytes += generator.text(
      '=== BIOSCAN ===',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'LABORATORIO DE CALIDAD DE LECHE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // 2. DATOS DE IDENTIFICACIÓN
    bytes += generator.text('Folio:   #$folioShort', styles: const PosStyles(bold: true));
    bytes += generator.text('Fecha:   $dateStr');
    bytes += generator.text('Productor: ${_truncate(ganadero.nombreCompleto, 21)}');
    if (ganadero.rancho.trim().isNotEmpty) {
      bytes += generator.text('Rancho:    ${_truncate(ganadero.rancho, 21)}');
    }
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // 3. VEREDICTO PRINCIPAL (DESTACADO)
    if (analysis.isGlobalApproved) {
      bytes += generator.text(
        '[ LECHE APTA ]',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'OPTIMAS CONDICIONES',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Presencia de agua: NO',
        styles: const PosStyles(align: PosAlign.center),
      );
    } else if (analysis.isGlobalDanger) {
      bytes += generator.text(
        '[ LECHE NO APTA ]',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      final waterPctStr = analysis.estimatedWaterPct != null
          ? '${analysis.estimatedWaterPct!.toStringAsFixed(1)}%'
          : 'DETECTADA';
      bytes += generator.text(
        '** ADULTERACION CON AGUA **',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Presencia de agua: SI ($waterPctStr)',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    } else {
      bytes += generator.text(
        '[ NO OPTIMA / ALERTA ]',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'PARAMETROS FUERA DE RANGO',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Presencia de agua: NO',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // 4. TABLA DE PARÁMETROS CLAVE (32 COLUMNAS ESTRICTAS)
    // Encabezado tabla: 14 + 10 + 8 = 32 caracteres
    bytes += generator.text(
      _format3Cols('PARAMETRO', 'VALOR', 'ESTADO'),
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Densidad
    final densValStr = analysis.densidad != null ? analysis.densidad!.toStringAsFixed(3) : analysis.rawDensidad;
    final densStatus = analysis.isDensNormal ? 'OK' : (analysis.hasWaterAdulteration ? 'PELIGRO' : 'FUERA');
    bytes += generator.text(_format3Cols('Densidad', densValStr, densStatus));

    // pH
    final phValStr = analysis.ph != null ? analysis.ph!.toStringAsFixed(2) : analysis.rawPh;
    final phStatus = analysis.isPhNormal ? 'OK' : 'FUERA';
    bytes += generator.text(_format3Cols('pH', phValStr, phStatus));

    // Temperatura
    final tempValStr = analysis.temp != null ? '${analysis.temp!.toStringAsFixed(1)} C' : analysis.rawTemp;
    final tempStatus = (analysis.temp != null && analysis.temp! >= 4.0 && analysis.temp! <= 25.0) ? 'OK' : 'INFO';
    bytes += generator.text(_format3Cols('Temperatura', tempValStr, tempStatus));

    // Agua Adicionada
    final aguaValStr = analysis.hasWaterAdulteration
        ? '${analysis.estimatedWaterPct != null ? analysis.estimatedWaterPct!.toStringAsFixed(1) : ''}%'
        : '0.0%';
    final aguaStatus = analysis.hasWaterAdulteration ? 'ALERTA' : 'OK';
    bytes += generator.text(_format3Cols('Agua añadida', aguaValStr, aguaStatus));

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // 5. PIE DE TICKET
    bytes += generator.text(
      'Analisis generado por BioScan',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Norma Ref: NOM-155-SCFI / FAO',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Toma de muestra certificada',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Imprime el ticket de prueba en la impresora configurada
  Future<void> printTestTicket() async {
    final configured = await getConfiguredPrinter();
    if (configured == null) {
      throw const ThermalPrinterException('No hay ninguna impresora configurada. Por favor vincule una impresora primero.');
    }

    final isMacOsOrDesktop = !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

    // Generar bytes
    final bytes = await generateTestTicketBytes();

    if (isMacOsOrDesktop) {
      // En entorno de escritorio/simulador simulamos la salida con éxito para pruebas
      debugPrint('[THERMAL PRINTER SIMULADO] Impresión de prueba ejecutada exitosamente (${bytes.length} bytes).');
      return;
    }

    // Conectar y enviar bytes
    await connect(mac: configured['mac']);
    try {
      final success = await PrintBluetoothThermal.writeBytes(bytes);
      if (!success) {
        throw const ThermalPrinterException('No se pudo enviar la información a la impresora.');
      }
    } finally {
      // Dejamos un breve retraso para vaciar el búfer antes de cerrar
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  /// Imprime el ticket oficial de medición en la impresora configurada
  Future<void> printMeasurementTicket({
    required Medicion medicion,
    required Ganadero ganadero,
  }) async {
    final configured = await getConfiguredPrinter();
    if (configured == null) {
      throw const ThermalPrinterException('No hay ninguna impresora configurada.');
    }

    final isMacOsOrDesktop = !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

    final bytes = await generateMeasurementTicketBytes(
      medicion: medicion,
      ganadero: ganadero,
    );

    if (isMacOsOrDesktop) {
      debugPrint('[THERMAL PRINTER SIMULADO] Ticket de medición #${medicion.id} impreso con éxito (${bytes.length} bytes).');
      return;
    }

    await connect(mac: configured['mac']);
    try {
      final success = await PrintBluetoothThermal.writeBytes(bytes);
      if (!success) {
        throw const ThermalPrinterException('Error al enviar los datos a la impresora.');
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  // ===========================================================================
  // UTILIDADES DE FORMATEO (32 CARACTERES)
  // ===========================================================================

  /// Alinea 3 columnas exactamente en 32 caracteres (14 + 10 + 8)
  static String _format3Cols(String c1, String c2, String c3) {
    final col1 = _truncate(c1, 14).padRight(14);
    final col2 = _truncate(c2, 10).padLeft(10);
    final col3 = _truncate(c3, 8).padLeft(8);
    return '$col1$col2$col3';
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen);
  }
}
