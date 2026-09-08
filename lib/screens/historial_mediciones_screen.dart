import 'dart:io';
import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../services/pdf_report_service.dart';
import '../utils/service_locator.dart';
import 'reporte_pdf_screen.dart';

class HistorialMedicionesScreen extends StatefulWidget {
  const HistorialMedicionesScreen({
    super.key,
    required this.mediciones,
    required this.ganaderos,
    this.cliente,
    this.usuario,
  });

  final List<Medicion> mediciones;
  final List<Ganadero> ganaderos;
  final Cliente? cliente;
  final Usuario? usuario;

  @override
  State<HistorialMedicionesScreen> createState() => _HistorialMedicionesScreenState();
}

class _HistorialMedicionesScreenState extends State<HistorialMedicionesScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _abrirReportePdf(Medicion medicion) async {
    final ganadero = widget.ganaderos.firstWhere(
      (item) => item.id == medicion.ganaderoId,
      orElse: () => const Ganadero(
        id: '',
        nombre: 'Ganadero',
        apellidoPaterno: 'No Identificado',
        apellidoMaterno: '',
        rancho: 'Rancho General',
        tel: 'N/D',
      ),
    );

    // Obtener cliente y usuario
    final cliente = widget.cliente ??
        (await ServiceLocator.clienteRepository.getClienteById(medicion.clienteId)) ??
        const Cliente(
          id: '00000000-0000-0000-0000-000000000001',
          nombre: 'Cliente BioScan',
          empresa: 'BioScan System',
          telefono: '0000000000',
          correo: 'contacto@bioscan.com',
          fechaRegistro: '',
        );

    Usuario? usuario = widget.usuario;
    if (usuario == null && medicion.usuarioId != null) {
      usuario = await ServiceLocator.usuarioRepository.getUsuarioById(medicion.usuarioId!);
    }

    Dispositivo? dispositivo;
    if (medicion.dispositivoId != null) {
      dispositivo = await ServiceLocator.dispositivoRepository.getDispositivoById(medicion.dispositivoId!);
    }

    bool pdfExiste = false;
    if (medicion.pdfPath != null && medicion.pdfPath!.isNotEmpty) {
      final file = File(medicion.pdfPath!);
      pdfExiste = await file.exists();
    }

    if (!pdfExiste) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generando y persistiendo reporte PDF en el dispositivo...'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF008C83),
          ),
        );
      }

      try {
        final newFile = await PdfReportService.saveMeasurementReportPdf(
          medicion: medicion,
          ganadero: ganadero,
          cliente: cliente,
          usuario: usuario,
          dispositivo: dispositivo,
        );

        // Actualizar la ruta en la base de datos local
        final updatedMedicion = medicion.copyWith(pdfPath: newFile.path);
        await ServiceLocator.medicionRepository.updateMedicion(updatedMedicion);
      } catch (e) {
        debugPrint('Error al regenerar y guardar PDF: $e');
      }
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ReportePdfScreen(
          medicion: medicion,
          ganadero: ganadero,
          cliente: cliente,
          usuario: usuario,
          dispositivo: dispositivo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMediciones = widget.mediciones.where((medicion) {
      if (_searchQuery.isEmpty) return true;
      final ganadero = widget.ganaderos.firstWhere(
        (g) => g.id == medicion.ganaderoId,
        orElse: () => const Ganadero(id: '', nombre: '', apellidoPaterno: '', apellidoMaterno: '', rancho: '', tel: ''),
      );
      final searchLower = _searchQuery.toLowerCase();
      return ganadero.nombreCompleto.toLowerCase().contains(searchLower) ||
          ganadero.rancho.toLowerCase().contains(searchLower) ||
          medicion.fecha.toLowerCase().contains(searchLower) ||
          medicion.id.toLowerCase().contains(searchLower);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Mediciones'),
      ),
      body: Column(
        children: [
          // Barra de búsqueda y contador
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ganadero, rancho, fecha...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total de registros: ${filteredMediciones.length}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Toca una tarjeta para ver el PDF',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de mediciones
          Expanded(
            child: filteredMediciones.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No se encontraron resultados para "$_searchQuery"' : 'Aún no hay mediciones registradas.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredMediciones.length,
                    itemBuilder: (context, index) {
                      final medicion = filteredMediciones[index];
                      final ganadero = widget.ganaderos.firstWhere(
                        (item) => item.id == medicion.ganaderoId,
                        orElse: () => const Ganadero(
                          id: '',
                          nombre: 'Ganadero',
                          apellidoPaterno: 'Eliminado',
                          apellidoMaterno: '',
                          rancho: 'Rancho General',
                          tel: '',
                        ),
                      );

                      final folio = medicion.id.length > 8 ? medicion.id.substring(0, 8).toUpperCase() : medicion.id.toUpperCase();
                      final tieneArchivoLocal = medicion.pdfPath != null && medicion.pdfPath!.isNotEmpty;

                      return Card(
                        elevation: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrirReportePdf(medicion),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Encabezado de la tarjeta
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ganadero.nombreCompleto.isEmpty ? 'Ganadero Desconocido' : ganadero.nombreCompleto,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF005267),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  ganadero.rancho.isNotEmpty ? ganadero.rancho : 'Rancho General',
                                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Badge Folio y Sync
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF008C83).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF008C83).withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            '#$folio',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF008C83),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              medicion.sincronizado ? Icons.cloud_done : Icons.cloud_queue,
                                              size: 14,
                                              color: medicion.sincronizado ? Colors.green : Colors.orange,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              medicion.sincronizado ? 'Nube' : 'Local',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: medicion.sincronizado ? Colors.green : Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Parámetros Medidos (pH, Densidad, Temperatura)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildMetricChip(Icons.water_drop, 'pH', medicion.ph, Colors.purple),
                                      Container(height: 24, width: 1, color: Colors.grey.shade300),
                                      _buildMetricChip(Icons.science_outlined, 'Densidad', medicion.agua, Colors.teal),
                                      Container(height: 24, width: 1, color: Colors.grey.shade300),
                                      _buildMetricChip(Icons.thermostat, 'Temp', medicion.temperatura, Colors.orange),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Pie de tarjeta: Fecha y Botón PDF
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          medicion.fecha.length > 19 ? medicion.fecha.substring(0, 19).replaceAll('T', ' ') : medicion.fecha,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: const Color(0xFF005267).withValues(alpha: 0.1),
                                        foregroundColor: const Color(0xFF005267),
                                      ),
                                      onPressed: () => _abrirReportePdf(medicion),
                                      icon: Icon(
                                        tieneArchivoLocal ? Icons.picture_as_pdf : Icons.picture_as_pdf_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Ver PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            Text(value.isNotEmpty ? value : 'N/D', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
