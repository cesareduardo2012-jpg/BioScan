import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/analisis_leche.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';

/// Modelo interno de evaluación analítica para diagnosticar la muestra según normas oficiales
class _MilkAnalysis {
  final double? ph;
  final double? densidad;
  final double? temp;
  final String rawPh;
  final String rawDensidad;
  final String rawTemp;

  final bool hasWaterAdulteration;
  final double? estimatedWaterPct;
  final bool isAcidic;
  final bool isAlkaline;
  final bool isPhNormal;
  final bool isDensNormal;
  final bool isGlobalApproved;
  final bool isGlobalWarning;
  final bool isGlobalDanger;

  final String globalTitle;
  final String globalSubtitle;
  final PdfColor globalColor;
  final PdfColor globalBgColor;
  final PdfColor globalBorderColor;

  _MilkAnalysis({
    required this.ph,
    required this.densidad,
    required this.temp,
    required this.rawPh,
    required this.rawDensidad,
    required this.rawTemp,
    required this.hasWaterAdulteration,
    required this.estimatedWaterPct,
    required this.isAcidic,
    required this.isAlkaline,
    required this.isPhNormal,
    required this.isDensNormal,
    required this.isGlobalApproved,
    required this.isGlobalWarning,
    required this.isGlobalDanger,
    required this.globalTitle,
    required this.globalSubtitle,
    required this.globalColor,
    required this.globalBgColor,
    required this.globalBorderColor,
  });

  factory _MilkAnalysis.evaluate(Medicion medicion) {
    // Evaluación unificada con el modelo normativo oficial compartido con el ticket térmico
    final base = AnalisisLeche.evaluate(medicion);

    PdfColor color;
    PdfColor bgColor;
    PdfColor borderColor;

    if (base.isGlobalDanger) {
      color = PdfColor.fromHex('#C62828'); // Rojo alerta
      bgColor = PdfColor.fromHex('#FFEBEE');
      borderColor = PdfColor.fromHex('#EF9A9A');
    } else if (base.isGlobalWarning) {
      color = PdfColor.fromHex('#E65100'); // Ámbar advertencia
      bgColor = PdfColor.fromHex('#FFF3E0');
      borderColor = PdfColor.fromHex('#FFE0B2');
    } else {
      color = PdfColor.fromHex('#008C83'); // BioScan Secundario
      bgColor = PdfColor.fromHex('#E6F5F4');
      borderColor = PdfColor.fromHex('#B0DCD8');
    }

    return _MilkAnalysis(
      ph: base.ph,
      densidad: base.densidad,
      temp: base.temp,
      rawPh: base.rawPh,
      rawDensidad: base.rawDensidad,
      rawTemp: base.rawTemp,
      hasWaterAdulteration: base.hasWaterAdulteration,
      estimatedWaterPct: base.estimatedWaterPct,
      isAcidic: base.isAcidic,
      isAlkaline: base.isAlkaline,
      isPhNormal: base.isPhNormal,
      isDensNormal: base.isDensNormal,
      isGlobalApproved: base.isGlobalApproved,
      isGlobalWarning: base.isGlobalWarning,
      isGlobalDanger: base.isGlobalDanger,
      globalTitle: base.globalTitle,
      globalSubtitle: base.globalSubtitle,
      globalColor: color,
      globalBgColor: bgColor,
      globalBorderColor: borderColor,
    );
  }
}

class PdfReportService {
  PdfReportService._();

  static Future<Directory> getReportsDirectory() async {
    Directory baseDir;
    if (!kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      baseDir = Directory(p.join(Directory.current.path, '.bioscan_data', 'reports'));
    } else {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        baseDir = Directory(p.join(docsDir.path, 'pdf_reports'));
      } catch (_) {
        baseDir = Directory(p.join(Directory.current.path, '.bioscan_data', 'reports'));
      }
    }
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  /// Guarda el reporte PDF generado físicamente en el almacenamiento persistente del dispositivo
  static Future<File> saveMeasurementReportPdf({
    required Medicion medicion,
    required Ganadero ganadero,
    Cliente? cliente,
    Usuario? usuario,
    Dispositivo? dispositivo,
  }) async {
    final pdfBytes = await generateMeasurementReport(
      medicion: medicion,
      ganadero: ganadero,
      cliente: cliente,
      usuario: usuario,
      dispositivo: dispositivo,
    );

    final reportsDir = await getReportsDirectory();
    final sanitizedGanadero = ganadero.nombre.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final filename = 'reporte_bioscan_${sanitizedGanadero.isNotEmpty ? '${sanitizedGanadero}_' : ''}${medicion.id.length > 8 ? medicion.id.substring(0, 8) : medicion.id}.pdf';
    final file = File(p.join(reportsDir.path, filename));
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  /// Obtiene los bytes del PDF desde el archivo persistido si existe, o lo genera dinámicamente.
  /// Si [forceRegenerate] es true, genera nuevamente el documento con la plantilla actual y actualiza el archivo persistido.
  static Future<Uint8List> loadOrGeneratePdfBytes({
    required Medicion medicion,
    required Ganadero ganadero,
    Cliente? cliente,
    Usuario? usuario,
    Dispositivo? dispositivo,
    bool forceRegenerate = false,
  }) async {
    if (!forceRegenerate && medicion.pdfPath != null && medicion.pdfPath!.isNotEmpty) {
      final file = File(medicion.pdfPath!);
      if (await file.exists()) {
        try {
          return await file.readAsBytes();
        } catch (e) {
          debugPrint('Error al leer PDF persistido: $e. Regenerando...');
        }
      }
    }

    final bytes = await generateMeasurementReport(
      medicion: medicion,
      ganadero: ganadero,
      cliente: cliente,
      usuario: usuario,
      dispositivo: dispositivo,
    );

    // Si se solicitó forzar la regeneración y existe ruta física, actualizar el archivo en disco
    if (forceRegenerate && medicion.pdfPath != null && medicion.pdfPath!.isNotEmpty) {
      try {
        final file = File(medicion.pdfPath!);
        await file.writeAsBytes(bytes, flush: true);
      } catch (e) {
        debugPrint('Error actualizando PDF en disco: $e');
      }
    }

    return bytes;
  }

  /// Genera el reporte oficial de medición con diseño de alta visibilidad para el ganadero
  static Future<Uint8List> generateMeasurementReport({
    required Medicion medicion,
    required Ganadero ganadero,
    Cliente? cliente,
    Usuario? usuario,
    Dispositivo? dispositivo,
  }) async {
    final pdf = pw.Document();

    // Paleta Corporativa BioScan
    final primaryStrong = PdfColor.fromHex('#005267'); // BioScan Fuerte
    final secondaryMild = PdfColor.fromHex('#008C83');  // BioScan Leve
    final cardBgColor = PdfColor.fromHex('#F4F8F8');    // Fondo suave con tinte BioScan
    final borderColor = PdfColor.fromHex('#D2E5E4');    // Borde suave
    final darkTextColor = PdfColor.fromHex('#1B2E2D');  // Texto oscuro de alto contraste
    final subtleTextColor = PdfColor.fromHex('#4F6B6A');

    final folioShort = medicion.id.length > 8 ? medicion.id.substring(0, 8).toUpperCase() : medicion.id.toUpperCase();

    // Intentar cargar el logotipo oficial de BioScan
    pw.MemoryImage? logoImage;
    try {
      final byteData = await rootBundle.load('assets/images/logo.png');
      final bytes = byteData.buffer.asUint8List();
      if (bytes.isNotEmpty) {
        logoImage = pw.MemoryImage(bytes);
      }
    } catch (_) {
      logoImage = null;
    }

    // Análisis diagnóstico de la muestra
    final analysis = _MilkAnalysis.evaluate(medicion);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. ENCABEZADO CORPORATIVO BIOSCAN
              // ==========================================
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: primaryStrong,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              if (logoImage != null) ...[
                                pw.Container(
                                  width: 40,
                                  height: 40,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.white,
                                    borderRadius: pw.BorderRadius.circular(6),
                                  ),
                                  padding: const pw.EdgeInsets.all(3),
                                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                ),
                                pw.SizedBox(width: 10),
                              ],
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'BioScan',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 22,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    'SISTEMA DE ANÁLISIS Y CONTROL DE CALIDAD DE LECHE',
                                    style: pw.TextStyle(
                                      color: PdfColor.fromHex('#B2DFDB'),
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                cliente?.nombre.toUpperCase() ?? 'CENTRO DE ACOPIO / PRODUCTOR',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (cliente?.empresa != null && cliente!.empresa.isNotEmpty)
                                pw.Text(
                                  cliente.empresa,
                                  style: pw.TextStyle(
                                    color: PdfColor.fromHex('#E0F2F1'),
                                    fontSize: 8.5,
                                  ),
                                ),
                              pw.SizedBox(height: 3),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: pw.BoxDecoration(
                                  color: secondaryMild,
                                  borderRadius: pw.BorderRadius.circular(3),
                                ),
                                child: pw.Text(
                                  'DICTAMEN TÉCNICO OFICIAL',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Línea de acento inferior en BioScan Leve
                    pw.Container(
                      height: 4,
                      decoration: pw.BoxDecoration(
                        color: secondaryMild,
                        borderRadius: const pw.BorderRadius.only(
                          bottomLeft: pw.Radius.circular(6),
                          bottomRight: pw.Radius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ==========================================
              // 2. BARRA DE FOLIO Y FECHA DE MUESTREO
              // ==========================================
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'FOLIO DE MEDICIÓN: ',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: subtleTextColor),
                        ),
                        pw.Text(
                          '#$folioShort',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryStrong),
                        ),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text(
                          'FECHA Y HORA: ',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: subtleTextColor),
                        ),
                        pw.Text(
                          medicion.fecha,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ==========================================
              // 3. SEMÁFORO / DICTAMEN GLOBAL PARA EL GANADERO
              // ==========================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: analysis.globalBgColor,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: analysis.globalBorderColor, width: 1.5),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      decoration: pw.BoxDecoration(
                        color: analysis.globalColor,
                        shape: pw.BoxShape.circle,
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        analysis.hasWaterAdulteration ? '!' : (analysis.isGlobalApproved ? 'v' : 'i'),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            analysis.globalTitle,
                            style: pw.TextStyle(
                              color: analysis.globalColor,
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            analysis.globalSubtitle,
                            style: pw.TextStyle(
                              color: darkTextColor,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // ==========================================
              // 4. DATOS DEL GANADERO Y MUESTREO
              // ==========================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Columna Ganadero
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(width: 3, height: 10, color: secondaryMild),
                              pw.SizedBox(width: 5),
                              pw.Text(
                                'DATOS DEL PRODUCTOR / GANADERO',
                                style: pw.TextStyle(color: primaryStrong, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          _buildDetailItem('Productor:', ganadero.nombreCompleto),
                          _buildDetailItem('Rancho / Parcela:', ganadero.rancho),
                          _buildDetailItem('Teléfono de Contacto:', ganadero.telefono.isNotEmpty ? ganadero.telefono : 'No registrado'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Columna Equipo y Operador
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(width: 3, height: 10, color: secondaryMild),
                              pw.SizedBox(width: 5),
                              pw.Text(
                                'DATOS DE MUESTREO Y EQUIPO',
                                style: pw.TextStyle(color: primaryStrong, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          _buildDetailItem('Técnico Responsable:', usuario?.nombre ?? 'Técnico BioScan'),
                          _buildDetailItem('Dispositivo:', dispositivo?.nombre ?? 'BioScan Terminal'),
                          _buildDetailItem('No. de Serie:', dispositivo?.numeroSerie ?? 'BS-SENS-01'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // ==========================================
              // 5. TARJETAS VISUALES COMPARATIVAS ("CÓMO DEBERÍA SER VS CÓMO ESTÁ")
              // ==========================================
              pw.Row(
                children: [
                  pw.Container(width: 4, height: 12, color: primaryStrong),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'RESULTADOS VISUALES DEL ANÁLISIS FISICOQUÍMICO',
                    style: pw.TextStyle(color: primaryStrong, fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Fila con las 3 tarjetas de parámetros visuales
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Tarjeta 1: Densidad y Agua Adicionada (CON ALERTA EN ROJO SI TIENE AGUA)
                  pw.Expanded(
                    child: _buildParameterCard(
                      title: 'DENSIDAD Y AGUA',
                      measuredValue: analysis.densidad != null ? '${analysis.densidad!.toStringAsFixed(3)} g/mL' : medicion.agua,
                      subValueNote: analysis.hasWaterAdulteration
                          ? 'ALERTA: ~${analysis.estimatedWaterPct?.toStringAsFixed(1)}% AGUA ADICIONADA'
                          : '0.0% AGUA (Conforme)',
                      referenceText: '1.028 - 1.034 g/mL (0% Agua)',
                      sourceText: 'NOM-155-SCFI-2012 / COFOCALEC',
                      statusBadgeText: analysis.hasWaterAdulteration ? 'AGUA DETECTADA' : (analysis.isDensNormal ? 'DENSIDAD ÓPTIMA' : 'ALTERACIÓN'),
                      isDanger: analysis.hasWaterAdulteration,
                      isWarning: !analysis.hasWaterAdulteration && !analysis.isDensNormal,
                      primaryColor: primaryStrong,
                      secondaryColor: secondaryMild,
                      gaugeWidget: _buildGaugeBar(
                        valueFraction: analysis.densidad != null ? ((analysis.densidad! - 1.020) / (1.040 - 1.020)).clamp(0.05, 0.95) : 0.5,
                        optStartFraction: 0.40, // 1.028 en escala 1.020 - 1.040
                        optEndFraction: 0.70,   // 1.034 en escala 1.020 - 1.040
                        labelLow: 'Aguada (<1.028)',
                        labelOpt: 'Óptima',
                        labelHigh: 'Alta (>1.034)',
                        isDanger: analysis.hasWaterAdulteration,
                        secondaryColor: secondaryMild,
                      ),
                      practicalNote: analysis.hasWaterAdulteration
                          ? '¡Agua detectada! Provoca rechazo o castigo en pago de leche por reducción de sólidos.'
                          : 'Concentración normal de grasa y sólidos totales. No presenta agua agregada.',
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Tarjeta 2: pH / Acidez
                  pw.Expanded(
                    child: _buildParameterCard(
                      title: 'ACIDEZ Y pH',
                      measuredValue: analysis.ph != null ? '${analysis.ph!.toStringAsFixed(2)} pH' : medicion.ph,
                      subValueNote: analysis.isAcidic
                          ? 'ACIDEZ ELEVADA (Fermentación)'
                          : (analysis.isAlkaline ? 'ALCALINA (Sospecha Mastitis)' : 'FRESCA Y ESTABLE'),
                      referenceText: '6.60 a 6.80 pH a 20°C',
                      sourceText: 'NOM-155-SCFI-2012 / FAO',
                      statusBadgeText: analysis.isAcidic ? 'LECHE ÁCIDA' : (analysis.isAlkaline ? 'ALCALINA' : 'pH ÓPTIMO'),
                      isDanger: analysis.isAcidic,
                      isWarning: analysis.isAlkaline,
                      primaryColor: primaryStrong,
                      secondaryColor: secondaryMild,
                      gaugeWidget: _buildGaugeBar(
                        valueFraction: analysis.ph != null ? ((analysis.ph! - 6.20) / (7.20 - 6.20)).clamp(0.05, 0.95) : 0.5,
                        optStartFraction: 0.40, // 6.60 en escala 6.20 - 7.20
                        optEndFraction: 0.60,   // 6.80 en escala 6.20 - 7.20
                        labelLow: 'Ácida (<6.5)',
                        labelOpt: '6.60 - 6.80',
                        labelHigh: 'Alcalina (>6.8)',
                        isDanger: analysis.isAcidic,
                        secondaryColor: secondaryMild,
                      ),
                      practicalNote: analysis.isAcidic
                          ? 'Acidez elevada por falta de frío inmediato. Riesgo de corte al calentar.'
                          : (analysis.isAlkaline
                              ? 'pH elevado. Posible mastitis en ubre o adición de neutralizantes.'
                              : 'Acidez balanceada. Leche fresca en condiciones microbiológicas óptimas.'),
                    ),
                  ),
                  pw.SizedBox(width: 8),

                  // Tarjeta 3: Temperatura
                  pw.Expanded(
                    child: _buildParameterCard(
                      title: 'TEMPERATURA',
                      measuredValue: analysis.temp != null ? '${analysis.temp!.toStringAsFixed(1)} °C' : medicion.temperatura,
                      subValueNote: (analysis.temp != null && analysis.temp! <= 4.0)
                          ? 'CONSERVACIÓN EN FRÍO ÓPTIMA'
                          : 'LECTURA DE CONTROL EN CAMPO',
                      referenceText: '<= 4.0 °C (Tanque frío)',
                      sourceText: 'NOM-243-SSA1-2010',
                      statusBadgeText: (analysis.temp != null && analysis.temp! <= 4.0) ? 'ENFRIAMIENTO ÓPTIMO' : 'TEMP. DE MUESTRA',
                      isDanger: false,
                      isWarning: (analysis.temp != null && analysis.temp! > 8.0),
                      primaryColor: primaryStrong,
                      secondaryColor: secondaryMild,
                      gaugeWidget: _buildGaugeBar(
                        valueFraction: analysis.temp != null ? ((analysis.temp! - 0.0) / (35.0 - 0.0)).clamp(0.05, 0.95) : 0.6,
                        optStartFraction: 0.05, // 2°C a 4°C en tanque
                        optEndFraction: 0.15,
                        labelLow: '0°C',
                        labelOpt: '<= 4°C Tanque',
                        labelHigh: '35°C Ordeño',
                        isDanger: false,
                        secondaryColor: secondaryMild,
                      ),
                      practicalNote: (analysis.temp != null && analysis.temp! <= 4.0)
                          ? 'Excelente cadena de frío. Inhibe multiplicación de bacterias lácticas.'
                          : 'La leche debe enfriarse a <= 4°C dentro de 2 horas tras la ordeña.',
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // ==========================================
              // 6. TABLA COMPARATIVA CON FUENTES OFICIALES
              // ==========================================
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.8),
                children: [
                  // Encabezado de Tabla en BioScan Fuerte (#005267)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryStrong),
                    children: [
                      _buildHeaderCell('PARÁMETRO'),
                      _buildHeaderCell('VALOR MEDIDO'),
                      _buildHeaderCell('CÓMO DEBE SER (NORMA)'),
                      _buildHeaderCell('ESTADO EVALUADO'),
                      _buildHeaderCell('FUENTE OFICIAL'),
                    ],
                  ),
                  // Fila Densidad
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: analysis.hasWaterAdulteration ? PdfColor.fromHex('#FFEBEE') : PdfColors.white,
                    ),
                    children: [
                      _buildDataCell('Densidad a 15/20°C', isBold: true),
                      _buildDataCell(
                        analysis.densidad != null ? '${analysis.densidad!.toStringAsFixed(3)} g/mL' : medicion.agua,
                        textColor: analysis.hasWaterAdulteration ? PdfColor.fromHex('#C62828') : darkTextColor,
                        isBold: analysis.hasWaterAdulteration,
                      ),
                      _buildDataCell('1.028 a 1.034 g/mL'),
                      _buildDataCell(
                        analysis.hasWaterAdulteration ? 'NO CONFORME (BAJA)' : 'CONFORME / EN NORMA',
                        textColor: analysis.hasWaterAdulteration ? PdfColor.fromHex('#C62828') : secondaryMild,
                        isBold: true,
                      ),
                      _buildDataCell('NOM-155-SCFI-2012'),
                    ],
                  ),
                  // Fila Agua Adicionada
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: analysis.hasWaterAdulteration ? PdfColor.fromHex('#FFCDD2') : cardBgColor,
                    ),
                    children: [
                      _buildDataCell('% Agua Adicionada', isBold: true),
                      _buildDataCell(
                        analysis.hasWaterAdulteration
                            ? '~${analysis.estimatedWaterPct?.toStringAsFixed(1)}% AGUA'
                            : '0.0 % (Ausencia)',
                        textColor: analysis.hasWaterAdulteration ? PdfColor.fromHex('#B71C1C') : darkTextColor,
                        isBold: true,
                      ),
                      _buildDataCell('0.0 % (Inadmisible)'),
                      _buildDataCell(
                        analysis.hasWaterAdulteration ? '¡AGUA DETECTADA!' : 'LECHE GENUINA',
                        textColor: analysis.hasWaterAdulteration ? PdfColor.fromHex('#B71C1C') : secondaryMild,
                        isBold: true,
                      ),
                      _buildDataCell('NOM-155-SCFI (Crioscopía)'),
                    ],
                  ),
                  // Fila pH
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.white),
                    children: [
                      _buildDataCell('pH (Acidez Potencial)', isBold: true),
                      _buildDataCell(
                        analysis.ph != null ? analysis.ph!.toStringAsFixed(2) : medicion.ph,
                        textColor: (analysis.isAcidic || analysis.isAlkaline) ? PdfColor.fromHex('#E65100') : darkTextColor,
                        isBold: (analysis.isAcidic || analysis.isAlkaline),
                      ),
                      _buildDataCell('6.60 a 6.80 pH'),
                      _buildDataCell(
                        analysis.isAcidic
                            ? 'ÁCIDA (FERMENTADA)'
                            : (analysis.isAlkaline ? 'ALCALINA (MASTITIS)' : 'ÓPTIMO / FRESCA'),
                        textColor: (analysis.isAcidic || analysis.isAlkaline) ? PdfColor.fromHex('#E65100') : secondaryMild,
                        isBold: true,
                      ),
                      _buildDataCell('NOM-155 / Guía FAO'),
                    ],
                  ),
                  // Fila Temperatura
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: cardBgColor),
                    children: [
                      _buildDataCell('Temperatura de Muestra', isBold: true),
                      _buildDataCell(analysis.temp != null ? '${analysis.temp!.toStringAsFixed(1)} °C' : medicion.temperatura),
                      _buildDataCell('<= 4.0 °C (Tanque Frío)'),
                      _buildDataCell(
                        (analysis.temp != null && analysis.temp! <= 4.0) ? 'FRÍO CONFORME' : 'LECTURA DE CAMPO',
                        textColor: secondaryMild,
                      ),
                      _buildDataCell('NOM-243-SSA1-2010'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 6),

              // Fuente al pie de tabla
              pw.Text(
                'FUENTES OFICIALES DE REFERENCIA: Norma Oficial Mexicana NOM-155-SCFI-2012 (Leche cruda, especificaciones fisicoquímicas), NOM-243-SSA1-2010 (Sanidad y conservación en frío), NMX-F-700-COFOCALEC-2012 y Manual Técnico de Calidad de la FAO.',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
              ),

              pw.SizedBox(height: 8),

              // ==========================================
              // 7. OBSERVACIONES TÉCNICAS
              // ==========================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NOTAS TÉCNICAS Y OBSERVACIONES EN CAMPO:',
                      style: pw.TextStyle(color: primaryStrong, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      medicion.observaciones.isNotEmpty
                          ? medicion.observaciones
                          : 'Muestra analizada en punto de recolección. Los resultados reflejan el estado fisicoquímico al momento del muestreo con el analizador digital BioScan.',
                      style: pw.TextStyle(fontSize: 7.5, color: darkTextColor),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ==========================================
              // 8. FIRMAS DE CONFORMIDAD
              // ==========================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(width: 180, height: 0.8, color: PdfColors.grey500),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'FIRMA DEL PRODUCTOR / GANADERO',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                        ),
                        pw.Text(
                          ganadero.nombreCompleto,
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Container(width: 180, height: 0.8, color: PdfColors.grey500),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'FIRMA DEL TÉCNICO RESPONSABLE',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                        ),
                        pw.Text(
                          usuario?.nombre ?? 'Técnico de Laboratorio BioScan',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(color: borderColor, thickness: 0.5),

              // ==========================================
              // 9. PIE DE PÁGINA
              // ==========================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'BioScan Milk Quality Analytics (c) ${DateTime.now().year} | Certificado de Prueba Rápida de Campo',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Página 1 de 1',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // WIDGETS AUXILIARES PARA EL DISEÑO PDF
  // ==========================================

  static pw.Widget _buildDetailItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4F6B6A')),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1B2E2D')),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta visual comparativa para un parámetro
  static pw.Widget _buildParameterCard({
    required String title,
    required String measuredValue,
    required String subValueNote,
    required String referenceText,
    required String sourceText,
    required String statusBadgeText,
    required bool isDanger,
    required bool isWarning,
    required PdfColor primaryColor,
    required PdfColor secondaryColor,
    required pw.Widget gaugeWidget,
    required String practicalNote,
  }) {
    final cardBorder = isDanger
        ? PdfColor.fromHex('#EF9A9A')
        : (isWarning ? PdfColor.fromHex('#FFE0B2') : PdfColor.fromHex('#D2E5E4'));

    final cardBg = isDanger
        ? PdfColor.fromHex('#FFEBEE')
        : (isWarning ? PdfColor.fromHex('#FFF8E1') : PdfColor.fromHex('#F4F8F8'));

    final badgeBg = isDanger
        ? PdfColor.fromHex('#C62828')
        : (isWarning ? PdfColor.fromHex('#E65100') : secondaryColor);

    final valueColor = isDanger
        ? PdfColor.fromHex('#C62828')
        : (isWarning ? PdfColor.fromHex('#E65100') : primaryColor);

    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: cardBg,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: cardBorder, width: isDanger ? 1.5 : 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Título y Badge de estado
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: isDanger ? PdfColor.fromHex('#C62828') : primaryColor,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: pw.BoxDecoration(
                  color: badgeBg,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  statusBadgeText,
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 4),

          // Valor Obtenido (Grande y legible para el ganadero)
          pw.Text(
            measuredValue,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
          pw.Text(
            subValueNote,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: isDanger ? PdfColor.fromHex('#C62828') : secondaryColor,
            ),
          ),

          pw.SizedBox(height: 5),

          // Cómo debería de ser (Referencia)
          pw.Container(
            padding: const pw.EdgeInsets.all(3.5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'CÓMO DEBE SER: ',
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        referenceText,
                        style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 5),

          // Gráfico de barra de rango visual (Bullet gauge)
          gaugeWidget,

          pw.SizedBox(height: 4),

          // Nota práctica de interpretación para el productor
          pw.Text(
            practicalNote,
            style: pw.TextStyle(
              fontSize: 6,
              color: isDanger ? PdfColor.fromHex('#B71C1C') : PdfColor.fromHex('#37474F'),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de escala visual segmentada con cursor de posición
  static pw.Widget _buildGaugeBar({
    required double valueFraction,
    required double optStartFraction,
    required double optEndFraction,
    required String labelLow,
    required String labelOpt,
    required String labelHigh,
    required bool isDanger,
    required PdfColor secondaryColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Barra tricolor de fondo
        pw.ClipRRect(
          horizontalRadius: 2,
          verticalRadius: 2,
          child: pw.Container(
            height: 6,
            child: pw.Row(
              children: [
                // Rango Bajo
                pw.Expanded(
                  flex: (optStartFraction * 100).toInt().clamp(5, 90),
                  child: pw.Container(color: isDanger ? PdfColor.fromHex('#EF9A9A') : PdfColor.fromHex('#FFE0B2')),
                ),
                // Rango Óptimo en norma
                pw.Expanded(
                  flex: ((optEndFraction - optStartFraction) * 100).toInt().clamp(10, 90),
                  child: pw.Container(color: secondaryColor),
                ),
                // Rango Alto
                pw.Expanded(
                  flex: ((1.0 - optEndFraction) * 100).toInt().clamp(5, 90),
                  child: pw.Container(color: PdfColor.fromHex('#FFE0B2')),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        // Rótulos de la barra
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(labelLow, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
            pw.Text(labelOpt, style: pw.TextStyle(fontSize: 5.5, color: secondaryColor, fontWeight: pw.FontWeight.bold)),
            pw.Text(labelHigh, style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text, {
    bool isBold = false,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    );
  }
}
