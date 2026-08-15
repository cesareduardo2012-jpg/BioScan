import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';

class PdfReportService {
  PdfReportService._();

  static Future<Uint8List> generateMeasurementReport({
    required Medicion medicion,
    required Ganadero ganadero,
    Cliente? cliente,
    Usuario? usuario,
    Dispositivo? dispositivo,
  }) async {
    final pdf = pw.Document();

    final primaryColor = PdfColor.fromHex('#1A237E'); // Indigo primario
    final secondaryColor = PdfColor.fromHex('#303F9F');
    final accentBgColor = PdfColor.fromHex('#F0F2F5');
    final borderColor = PdfColor.fromHex('#E0E0E0');

    final folioShort = medicion.id.length > 8 ? medicion.id.substring(0, 8).toUpperCase() : medicion.id.toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Principal
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BioScan',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'SISTEMA DE ANÁLISIS DE CALIDAD DE LECHE',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          cliente?.nombre.toUpperCase() ?? 'CLIENTE BIOSCAN',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (cliente?.empresa != null && cliente!.empresa.isNotEmpty)
                          pw.Text(
                            cliente.empresa,
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Barra de Folio y Fecha
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: accentBgColor,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'FOLIO: #$folioShort',
                      style: pw.TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'FECHA Y HORA: ${medicion.fecha}',
                      style: const pw.TextStyle(
                        color: PdfColors.black,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Bloque de Información: Ganadero vs Operador/Dispositivo
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Columna Ganadero
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFORMACIÓN DEL GANADERO',
                            style: pw.TextStyle(
                              color: secondaryColor,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Divider(color: borderColor),
                          pw.SizedBox(height: 4),
                          _buildDetailRow('Nombre:', ganadero.nombreCompleto),
                          _buildDetailRow('Rancho:', ganadero.rancho),
                          _buildDetailRow('Teléfono:', ganadero.telefono.isNotEmpty ? ganadero.telefono : 'N/D'),
                          _buildDetailRow('Correo:', ganadero.correo.isNotEmpty ? ganadero.correo : 'N/D'),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 12),

                  // Columna Operador / Equipo
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderColor),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DATOS DEL MUESTREO Y EQUIPO',
                            style: pw.TextStyle(
                              color: secondaryColor,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Divider(color: borderColor),
                          pw.SizedBox(height: 4),
                          _buildDetailRow('Operador:', usuario?.nombre ?? 'Técnico Responsable'),
                          _buildDetailRow('Rol:', (usuario?.rol ?? 'Técnico').toUpperCase()),
                          _buildDetailRow('Dispositivo:', dispositivo?.nombre ?? 'BioScan Terminal'),
                          _buildDetailRow('N° Serie:', dispositivo?.numeroSerie ?? 'BS-STANDARD'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Tabla de Resultados Fisicoquímicos
              pw.Text(
                'RESULTADOS ANALÍTICOS DE LA MUESTRA',
                style: pw.TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 1),
                children: [
                  // Encabezado de Tabla
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor),
                    children: [
                      _buildTableCell('PARÁMETRO ANALIZADO', isHeader: true),
                      _buildTableCell('VALOR MEDIDO', isHeader: true),
                      _buildTableCell('ESTADO / REFERENCIA', isHeader: true),
                    ],
                  ),
                  // Fila pH
                  pw.TableRow(
                    children: [
                      _buildTableCell('pH (Potencial de Hidrógeno)'),
                      _buildTableCell(medicion.ph),
                      _buildTableCell('Rango Óptimo (6.5 - 6.8)'),
                    ],
                  ),
                  // Fila Densidad / Agua
                  pw.TableRow(
                    children: [
                      _buildTableCell('Densidad / % Agua Adicionada'),
                      _buildTableCell(medicion.agua),
                      _buildTableCell('Conforme a Norma'),
                    ],
                  ),
                  // Fila Temperatura
                  pw.TableRow(
                    children: [
                      _buildTableCell('Temperatura de Muestra'),
                      _buildTableCell(medicion.temperatura),
                      _buildTableCell('Lectura de Campo'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Sección de Observaciones
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: accentBgColor,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OBSERVACIONES Y NOTAS TÉCNICAS:',
                      style: pw.TextStyle(
                        color: secondaryColor,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      medicion.observaciones.isNotEmpty ? medicion.observaciones : 'Sin observaciones registradas durante la toma de muestra.',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Pie de página institucional
              pw.Divider(color: borderColor),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'BioScan System © ${DateTime.now().year} • Certificado de Lectura Local',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Página 1 de 1',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
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

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }
}
