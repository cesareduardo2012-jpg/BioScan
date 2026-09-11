import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../services/pdf_report_service.dart';
import '../services/thermal_printer_service.dart';
import 'configurar_impresora_screen.dart';

class ReportePdfScreen extends StatefulWidget {
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
  State<ReportePdfScreen> createState() => _ReportePdfScreenState();
}

class _ReportePdfScreenState extends State<ReportePdfScreen> {
  int _refreshKey = 0;
  bool _isSharing = false;
  bool _isPrinting = false;
  bool _isPrintingTicket = false;

  final GlobalKey _shareButtonKey = GlobalKey();
  final GlobalKey _printButtonKey = GlobalKey();

  String _getSanitizedFilename() {
    final sanitizedGanadero = widget.ganadero.nombre
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');
    final folioShort = widget.medicion.id.length > 8
        ? widget.medicion.id.substring(0, 8).toUpperCase()
        : widget.medicion.id.toUpperCase();
    return 'reporte_bioscan_${sanitizedGanadero.isNotEmpty ? '${sanitizedGanadero}_' : ''}$folioShort.pdf';
  }

  Future<void> _compartirReporte() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      // 1. Obtener o generar los bytes del documento
      final pdfBytes = await PdfReportService.loadOrGeneratePdfBytes(
        medicion: widget.medicion,
        ganadero: widget.ganadero,
        cliente: widget.cliente,
        usuario: widget.usuario,
        dispositivo: widget.dispositivo,
        forceRegenerate: _refreshKey > 0,
      );

      final filename = _getSanitizedFilename();

      // 2. Localizar archivo existente o crear archivo temporal seguro para compartir
      File fileToShare;
      if (widget.medicion.pdfPath != null && widget.medicion.pdfPath!.isNotEmpty) {
        final existingFile = File(widget.medicion.pdfPath!);
        if (await existingFile.exists()) {
          fileToShare = existingFile;
        } else {
          final tempDir = await getTemporaryDirectory();
          fileToShare = File(p.join(tempDir.path, filename));
          await fileToShare.writeAsBytes(pdfBytes, flush: true);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        fileToShare = File(p.join(tempDir.path, filename));
        await fileToShare.writeAsBytes(pdfBytes, flush: true);
      }

      // 3. Obtener coordenadas de anclaje (vital para iPad y tablets para no colapsar la app)
      Rect? originRect;
      final renderObject = _shareButtonKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox) {
        originRect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      }
      if (mounted) {
        originRect ??= Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, 100);
      } else {
        originRect ??= const Rect.fromLTWH(0, 0, 400, 100);
      }

      // 4. Compartir nativamente (soporta WhatsApp, AirDrop, Gmail, Telegram, etc.)
      final xFile = XFile(
        fileToShare.path,
        mimeType: 'application/pdf',
        name: filename,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Reporte Oficial de Calidad de Leche BioScan - Ganadero: ${widget.ganadero.nombreCompleto}',
          subject: 'Reporte BioScan - ${widget.ganadero.nombreCompleto}',
          sharePositionOrigin: originRect,
        ),
      );
    } catch (e) {
      debugPrint('Error en Share.shareXFiles: $e. Intentando con método alternativo...');
      try {
        final pdfBytes = await PdfReportService.loadOrGeneratePdfBytes(
          medicion: widget.medicion,
          ganadero: widget.ganadero,
          cliente: widget.cliente,
          usuario: widget.usuario,
          dispositivo: widget.dispositivo,
        );
        final filename = _getSanitizedFilename();
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: filename,
          subject: 'Reporte BioScan - ${widget.ganadero.nombreCompleto}',
          body: 'Adjunto reporte técnico de calidad de leche.',
        );
      } catch (fallbackError) {
        debugPrint('Error en fallback de compartir: $fallbackError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No fue posible compartir el archivo: $fallbackError'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _imprimirReporte() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final pdfBytes = await PdfReportService.loadOrGeneratePdfBytes(
        medicion: widget.medicion,
        ganadero: widget.ganadero,
        cliente: widget.cliente,
        usuario: widget.usuario,
        dispositivo: widget.dispositivo,
        forceRegenerate: _refreshKey > 0,
      );

      final filename = _getSanitizedFilename().replaceAll('.pdf', '');

      // Invoca el diálogo nativo de impresión del sistema operativo (AirPrint / Spooler)
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: filename,
        format: PdfPageFormat.letter,
      );
    } catch (e) {
      debugPrint('Error en módulo de impresión: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la impresión: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _imprimirTicketTermico() async {
    if (_isPrintingTicket) return;
    setState(() => _isPrintingTicket = true);

    final printerService = ThermalPrinterService.instance;
    final configured = await printerService.getConfiguredPrinter();

    if (!mounted) return;

    if (configured == null) {
      setState(() => _isPrintingTicket = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Impresora No Configurada'),
          content: const Text('No hay ninguna impresora térmica Bluetooth vinculada.\n¿Desea configurarla ahora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const ConfigurarImpresoraScreen()),
                );
              },
              child: const Text('Configurar Impresora'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Imprimiendo ticket en ${configured['name']}...'),
        backgroundColor: const Color(0xFF005267),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      await printerService.printMeasurementTicket(
        medicion: widget.medicion,
        ganadero: widget.ganadero,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket impreso con éxito en impresora térmica'),
            backgroundColor: Color(0xFF008C83),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir ticket: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTicket = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryStrong = Color(0xFF005267);
    const secondaryMild = Color(0xFF008C83);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reporte Oficial BioScan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: primaryStrong,
        foregroundColor: Colors.white,
        actions: [
          // Botón para actualizar y regenerar el diseño con la plantilla más reciente
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerar con plantilla actual',
            onPressed: () {
              setState(() => _refreshKey++);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reporte actualizado con el diseño oficial BioScan'),
                  duration: Duration(seconds: 2),
                  backgroundColor: secondaryMild,
                ),
              );
            },
          ),
          // Botón de Impresión de Ticket Térmico (58 mm)
          IconButton(
            icon: _isPrintingTicket
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long),
            tooltip: 'Imprimir Ticket Térmico (58 mm)',
            onPressed: _isPrintingTicket ? null : _imprimirTicketTermico,
          ),
          // Botón de Impresión Oficial Carta (AirPrint / Impresora)
          IconButton(
            key: _printButtonKey,
            icon: _isPrinting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: 'Imprimir Reporte (AirPrint / Impresora)',
            onPressed: _isPrinting ? null : _imprimirReporte,
          ),
          // Botón de Compartir Oficial (WhatsApp, AirDrop, etc.)
          IconButton(
            key: _shareButtonKey,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            tooltip: 'Compartir por WhatsApp, AirDrop y más',
            onPressed: _isSharing ? null : _compartirReporte,
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(_refreshKey),
        child: PdfPreview(
          // Se elimina la barra morada inferior de acciones por completo
          useActions: false,
          allowPrinting: false,
          allowSharing: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          pdfFileName: _getSanitizedFilename(),
          build: (format) => PdfReportService.loadOrGeneratePdfBytes(
            medicion: widget.medicion,
            ganadero: widget.ganadero,
            cliente: widget.cliente,
            usuario: widget.usuario,
            dispositivo: widget.dispositivo,
            forceRegenerate: _refreshKey > 0,
          ),
        ),
      ),
    );
  }
}
