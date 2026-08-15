import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../services/pdf_report_service.dart';

class ReportePdfScreen extends StatelessWidget {
  const ReportePdfScreen({
    super.key,
    required this.medicion,
    required this.ganadero,
    this.cliente,
    this.usuario,
    this.dispositivo,
  });

  final Medicion medicion;
  final Ganadero ganadero;
  final Cliente? cliente;
  final Usuario? usuario;
  final Dispositivo? dispositivo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte PDF - Medición'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartir PDF',
            onPressed: () async {
              final pdfBytes = await PdfReportService.generateMeasurementReport(
                medicion: medicion,
                ganadero: ganadero,
                cliente: cliente,
                usuario: usuario,
                dispositivo: dispositivo,
              );
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: 'Reporte_BioScan_${ganadero.nombre}_${medicion.id.substring(0, 5)}.pdf',
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Reporte_BioScan_${ganadero.nombre}.pdf',
        build: (format) => PdfReportService.generateMeasurementReport(
          medicion: medicion,
          ganadero: ganadero,
          cliente: cliente,
          usuario: usuario,
          dispositivo: dispositivo,
        ),
      ),
    );
  }
}
