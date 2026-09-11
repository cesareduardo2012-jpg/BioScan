import 'package:flutter/material.dart';
import '../models/ganadero.dart';

class GanaderosCRUD extends StatefulWidget {
  const GanaderosCRUD({
    super.key,
    required this.ganaderos,
    required this.onAddGanadero,
    required this.onEditGanadero,
    required this.onDeleteGanadero,
    this.onRefresh,
  });

  final List<Ganadero> ganaderos;
  final Future<void> Function(Ganadero) onAddGanadero;
  final Future<void> Function(Ganadero) onEditGanadero;
  final Future<void> Function(String) onDeleteGanadero;
  final Future<void> Function()? onRefresh;

  @override
  State<GanaderosCRUD> createState() => _GanaderosCRUDState();
}

class _GanaderosCRUDState extends State<GanaderosCRUD> {
  void _showForm({Ganadero? ganadero}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: ganadero?.nombre ?? '');
    final apellidoPaternoController = TextEditingController(text: ganadero?.apellidoPaterno ?? '');
    final apellidoMaternoController = TextEditingController(text: ganadero?.apellidoMaterno ?? '');
    final ranchoController = TextEditingController(text: ganadero?.rancho ?? '');
    final telController = TextEditingController(text: ganadero?.tel ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ganadero == null ? 'Nuevo Ganadero' : 'Editar Ganadero', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el nombre';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: apellidoPaternoController,
                  decoration: const InputDecoration(labelText: 'Apellido Paterno'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el apellido paterno';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: apellidoMaternoController,
                  decoration: const InputDecoration(labelText: 'Apellido Materno'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el apellido materno';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: ranchoController,
                  decoration: const InputDecoration(labelText: 'Nombre del Rancho'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el nombre del rancho';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: telController,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el teléfono';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    debugPrint('\n================================================================');
                    debugPrint('[GANADERO UI] Botón guardar presionado');
                    if (!formKey.currentState!.validate()) {
                      debugPrint('[GANADERO UI] Validación de formulario falló. Revise los campos.');
                      return;
                    }

                    final nombre = nombreController.text.trim();
                    final apellidoPaterno = apellidoPaternoController.text.trim();
                    final apellidoMaterno = apellidoMaternoController.text.trim();
                    final rancho = ranchoController.text.trim();
                    final tel = telController.text.trim();

                    debugPrint('[GANADERO UI] Datos ingresados:');
                    debugPrint('  nombre = $nombre');
                    debugPrint('  apellidoPaterno = $apellidoPaterno');
                    debugPrint('  apellidoMaterno = $apellidoMaterno');
                    debugPrint('  rancho = $rancho');
                    debugPrint('  telefono = $tel');

                    final values = Ganadero(
                      id: ganadero?.id ?? '',
                      clienteId: ganadero?.clienteId,
                      nombre: nombre,
                      apellidoPaterno: apellidoPaterno,
                      apellidoMaterno: apellidoMaterno,
                      rancho: rancho,
                      tel: tel,
                    );

                    try {
                      if (ganadero == null) {
                        debugPrint('[GANADERO UI] Invocando callback widget.onAddGanadero...');
                        await widget.onAddGanadero(values);
                        debugPrint('[GANADERO UI] widget.onAddGanadero completado con éxito.');
                      } else {
                        debugPrint('[GANADERO UI] Invocando callback widget.onEditGanadero...');
                        await widget.onEditGanadero(values);
                        debugPrint('[GANADERO UI] widget.onEditGanadero completado con éxito.');
                      }
                      if (sheetContext.mounted) {
                        Navigator.pop(sheetContext);
                      }
                    } catch (e, stackTrace) {
                      debugPrint('[GANADERO UI ERROR] Excepción al guardar ganadero: $e');
                      debugPrint(stackTrace.toString());
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Error al guardar'),
                            content: Text('No se pudo guardar el ganadero: $e'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  child: Text(ganadero == null ? 'Guardar Ganadero' : 'Guardar Cambios'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Ganadero ganadero) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar ganadero'),
        content: Text('¿Deseas eliminar a ${ganadero.nombreCompleto}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.onDeleteGanadero(ganadero.id);
      } catch (e, stackTrace) {
        debugPrint('Error al eliminar ganadero: $e');
        debugPrint(stackTrace.toString());
        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Error al eliminar'),
              content: Text('No se pudo eliminar el ganadero: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Ganaderos')),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: widget.ganaderos.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No hay ganaderos registrados aún\nDesliza hacia abajo para sincronizar con la nube', textAlign: TextAlign.center)),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: widget.ganaderos.length,
                itemBuilder: (ctx, i) {
                  final ganadero = widget.ganaderos[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: ListTile(
                      title: Text(ganadero.nombreCompleto),
                      subtitle: Text('Rancho: ${ganadero.rancho} • Tel: ${ganadero.tel}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(ganadero: ganadero)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(ganadero)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
