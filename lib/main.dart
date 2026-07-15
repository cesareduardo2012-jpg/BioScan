import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.init();
  runApp(const BioScanApp());
}

class BioScanApp extends StatelessWidget {
  const BioScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<Ganadero> _ganaderos = [];
  List<Medicion> _mediciones = [];
  String? _selectedGanaderoId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final ganaderos = await DatabaseHelper.instance.getGanaderos();
    final mediciones = await DatabaseHelper.instance.getMediciones();

    if (!mounted) {
      return;
    }

    setState(() {
      _ganaderos = ganaderos;
      _mediciones = mediciones;
      if (_selectedGanaderoId != null && !_ganaderos.any((ganadero) => ganadero.id == _selectedGanaderoId)) {
        _selectedGanaderoId = null;
      }
    });
  }

  void _selectGanadero(String? ganaderoId) {
    setState(() {
      _selectedGanaderoId = ganaderoId;
    });
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  Future<void> _addGanadero(Ganadero ganadero) async {
    final newGanadero = ganadero.id.isEmpty ? ganadero.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString()) : ganadero;
    await DatabaseHelper.instance.insertGanadero(newGanadero);
    await _refreshData();
  }

  Future<void> _updateGanadero(Ganadero ganadero) async {
    await DatabaseHelper.instance.updateGanadero(ganadero);
    await _refreshData();
  }

  Future<void> _deleteGanadero(String id) async {
    await DatabaseHelper.instance.deleteGanadero(id);
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        ganaderos: _ganaderos,
        selectedGanaderoId: _selectedGanaderoId,
        onSelectedGanaderoChanged: _selectGanadero,
        onMeasurementSaved: _refreshData,
      ),
      GanaderosCRUD(
        ganaderos: _ganaderos,
        onAddGanadero: _addGanadero,
        onEditGanadero: _updateGanadero,
        onDeleteGanadero: _deleteGanadero,
      ),
      HistorialMedicionesScreen(mediciones: _mediciones, ganaderos: _ganaderos),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.biotech), label: 'Escaneo'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Ganaderos'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  late Directory _appDir;
  late File _ganaderosFile;
  late File _medicionesFile;

  Future<void> init() async {
    Directory directory;

    try {
      directory = await getApplicationDocumentsDirectory();
    } on MissingPluginException {
      directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _appDir = directory;
    _ganaderosFile = File(p.join(_appDir.path, 'ganaderos.json'));
    _medicionesFile = File(p.join(_appDir.path, 'mediciones.json'));

    if (!await _ganaderosFile.exists()) {
      await _ganaderosFile.writeAsString('[]');
    }
    if (!await _medicionesFile.exists()) {
      await _medicionesFile.writeAsString('[]');
    }
  }

  Future<void> resetStorage() async {
    await _ganaderosFile.writeAsString('[]');
    await _medicionesFile.writeAsString('[]');
  }

  Future<List<Ganadero>> getGanaderos() async {
    final raw = await _ganaderosFile.readAsString();
    final parsed = jsonDecode(raw) as List<dynamic>;
    return parsed.map((item) => Ganadero.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<List<Medicion>> getMediciones() async {
    final raw = await _medicionesFile.readAsString();
    final parsed = jsonDecode(raw) as List<dynamic>;
    return parsed.map((item) => Medicion.fromMap(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<void> insertGanadero(Ganadero ganadero) async {
    final existing = await getGanaderos();
    final updated = [...existing, ganadero];
    await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
  }

  Future<void> insertMedicion({
    required String ganaderoId,
    required String ph,
    required String agua,
    required String temperatura,
  }) async {
    final medicion = Medicion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ganaderoId: ganaderoId,
      ph: ph,
      agua: agua,
      temperatura: temperatura,
      fecha: DateTime.now().toIso8601String(),
    );
    final existing = await getMediciones();
    final updated = [medicion, ...existing];
    await _medicionesFile.writeAsString(jsonEncode(updated.map((item) => {
      'id': item.id,
      'ganaderoId': item.ganaderoId,
      'ph': item.ph,
      'agua': item.agua,
      'temperatura': item.temperatura,
      'fecha': item.fecha,
    }).toList()));
  }

  Future<void> updateGanadero(Ganadero ganadero) async {
    final existing = await getGanaderos();
    final updated = existing.map((item) => item.id == ganadero.id ? ganadero : item).toList();
    await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
  }

  Future<void> deleteGanadero(String id) async {
    final existing = await getGanaderos();
    final updated = existing.where((item) => item.id != id).toList();
    await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
  }
}

class Medicion {
  const Medicion({
    required this.id,
    required this.ganaderoId,
    required this.ph,
    required this.agua,
    required this.temperatura,
    required this.fecha,
  });

  final String id;
  final String ganaderoId;
  final String ph;
  final String agua;
  final String temperatura;
  final String fecha;

  factory Medicion.fromMap(Map<String, dynamic> map) {
    return Medicion(
      id: map['id'].toString(),
      ganaderoId: map['ganaderoId'].toString(),
      ph: map['ph']?.toString() ?? '',
      agua: map['agua']?.toString() ?? '',
      temperatura: map['temperatura']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
    );
  }
}

class Ganadero {
  const Ganadero({
    required this.id,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.rancho,
    required this.tel,
  });

  final String id;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String rancho;
  final String tel;

  String get nombreCompleto {
    final parts = [nombre, apellidoPaterno, apellidoMaterno].where((value) => value.trim().isNotEmpty).toList();
    return parts.join(' ').trim();
  }

  Ganadero copyWith({String? id, String? nombre, String? apellidoPaterno, String? apellidoMaterno, String? rancho, String? tel}) {
    return Ganadero(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      rancho: rancho ?? this.rancho,
      tel: tel ?? this.tel,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'apellidoPaterno': apellidoPaterno,
        'apellidoMaterno': apellidoMaterno,
        'rancho': rancho,
        'tel': tel,
      };

  factory Ganadero.fromMap(Map<String, dynamic> map) {
    return Ganadero(
      id: map['id'].toString(),
      nombre: map['nombre']?.toString() ?? '',
      apellidoPaterno: map['apellidoPaterno']?.toString() ?? '',
      apellidoMaterno: map['apellidoMaterno']?.toString() ?? '',
      rancho: map['rancho']?.toString() ?? '',
      tel: map['tel']?.toString() ?? '',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.ganaderos,
    required this.selectedGanaderoId,
    required this.onSelectedGanaderoChanged,
    required this.onMeasurementSaved,
  });

  final List<Ganadero> ganaderos;
  final String? selectedGanaderoId;
  final ValueChanged<String?> onSelectedGanaderoChanged;
  final Future<void> Function() onMeasurementSaved;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  String phValue = 'N/D';
  String aguaValue = 'N/D';
  String tempValue = 'N/D';

  void _connectBluetooth() {
    setState(() {
      isConnected = !isConnected;
      if (isConnected) {
        phValue = '6.7';
        aguaValue = '0.0%';
        tempValue = '24°C';
      } else {
        phValue = 'N/D';
        aguaValue = 'N/D';
        tempValue = 'N/D';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasGanaderos = widget.ganaderos.isNotEmpty;
    final selectedGanadero = widget.ganaderos.where((ganadero) => ganadero.id == widget.selectedGanaderoId).cast<Ganadero?>().firstOrNull;
    final canRegister = isConnected && selectedGanadero != null;

    return Scaffold(
      appBar: AppBar(title: const Text('BioScan - Terminal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: widget.selectedGanaderoId,
              decoration: const InputDecoration(labelText: 'Ganadero Responsable', border: OutlineInputBorder()),
              items: widget.ganaderos
                  .map((ganadero) => DropdownMenuItem<String>(value: ganadero.id, child: Text('${ganadero.nombreCompleto} (${ganadero.rancho})')))
                  .toList(),
              onChanged: widget.onSelectedGanaderoChanged,
              hint: const Text('Selecciona un ganadero'),
            ),
            const SizedBox(height: 12),
            if (!hasGanaderos)
              Card(
                color: Colors.amber.shade50,
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.amber),
                  title: const Text('Sin ganaderos'),
                  subtitle: const Text('Agrega ganaderos en la pestaña Ganaderos para poder asignarlos al escaneo.'),
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
            const SizedBox(height: 20),
            ListTile(
              tileColor: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Icon(Icons.bluetooth, color: isConnected ? Colors.blue : Colors.grey),
              title: Text(isConnected ? 'Dispositivo Conectado' : 'Dispositivo Desconectado'),
              trailing: Switch(value: isConnected, onChanged: (val) => _connectBluetooth()),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SensorBox(label: 'pH', value: phValue, active: isConnected),
                _SensorBox(label: 'Agua', value: aguaValue, active: isConnected),
                _SensorBox(label: 'Temp', value: tempValue, active: isConnected),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: canRegister
                  ? () async {
                      await DatabaseHelper.instance.insertMedicion(
                        ganaderoId: selectedGanadero!.id,
                        ph: phValue,
                        agua: aguaValue,
                        temperatura: tempValue,
                      );
                      await widget.onMeasurementSaved();
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Medición registrada para ${selectedGanadero.nombreCompleto}')),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text('REGISTRAR MEDICIÓN EN BD'),
            ),
          ],
        ),
      ),
    );
  }
}

class GanaderosCRUD extends StatefulWidget {
  const GanaderosCRUD({
    super.key,
    required this.ganaderos,
    required this.onAddGanadero,
    required this.onEditGanadero,
    required this.onDeleteGanadero,
  });

  final List<Ganadero> ganaderos;
  final Future<void> Function(Ganadero) onAddGanadero;
  final Future<void> Function(Ganadero) onEditGanadero;
  final Future<void> Function(String) onDeleteGanadero;

  @override
  State<GanaderosCRUD> createState() => _GanaderosCRUDState();
}

class _GanaderosCRUDState extends State<GanaderosCRUD> {
  void _showForm({Ganadero? ganadero}) {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ganadero == null ? 'Nuevo Ganadero' : 'Editar Ganadero', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre')),
              TextField(controller: apellidoPaternoController, decoration: const InputDecoration(labelText: 'Apellido Paterno')),
              TextField(controller: apellidoMaternoController, decoration: const InputDecoration(labelText: 'Apellido Materno')),
              TextField(controller: ranchoController, decoration: const InputDecoration(labelText: 'Nombre del Rancho')),
              TextField(controller: telController, decoration: const InputDecoration(labelText: 'Teléfono')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final nombre = nombreController.text.trim();
                  final apellidoPaterno = apellidoPaternoController.text.trim();
                  final apellidoMaterno = apellidoMaternoController.text.trim();
                  final rancho = ranchoController.text.trim();
                  final tel = telController.text.trim();

                  if (nombre.isEmpty || apellidoPaterno.isEmpty || apellidoMaterno.isEmpty || rancho.isEmpty || tel.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos para guardar el ganadero.')));
                    return;
                  }

                  final values = Ganadero(id: ganadero?.id ?? '', nombre: nombre, apellidoPaterno: apellidoPaterno, apellidoMaterno: apellidoMaterno, rancho: rancho, tel: tel);

                  if (ganadero == null) {
                    await widget.onAddGanadero(values);
                  } else {
                    await widget.onEditGanadero(values);
                  }
                  if (mounted) {
                    Navigator.pop(sheetContext);
                  }
                },
                child: Text(ganadero == null ? 'Guardar Ganadero' : 'Guardar Cambios'),
              ),
              const SizedBox(height: 20),
            ],
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
      await widget.onDeleteGanadero(ganadero.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Ganaderos')),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add)),
      body: widget.ganaderos.isEmpty
          ? const Center(child: Text('No hay ganaderos registrados aún'))
          : ListView.builder(
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
    );
  }
}

class HistorialMedicionesScreen extends StatelessWidget {
  const HistorialMedicionesScreen({super.key, required this.mediciones, required this.ganaderos});

  final List<Medicion> mediciones;
  final List<Ganadero> ganaderos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de mediciones')),
      body: mediciones.isEmpty
          ? const Center(child: Text('Aún no hay mediciones registradas.'))
          : ListView.builder(
              itemCount: mediciones.length,
              itemBuilder: (context, index) {
                final medicion = mediciones[index];
                final ganadero = ganaderos.firstWhere(
                  (item) => item.id == medicion.ganaderoId,
                  orElse: () => const Ganadero(id: '', nombre: '', apellidoPaterno: '', apellidoMaterno: '', rancho: '', tel: ''),
                );
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(ganadero.nombreCompleto.isEmpty ? 'Ganadero eliminado' : ganadero.nombreCompleto),
                    subtitle: Text('pH: ${medicion.ph} • Agua: ${medicion.agua} • Temp: ${medicion.temperatura}\n${medicion.fecha}'),
                  ),
                );
              },
            ),
    );
  }
}

class _SensorBox extends StatelessWidget {
  const _SensorBox({required this.label, required this.value, required this.active});

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(color: active ? Colors.indigo.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: active ? Colors.indigo : Colors.grey)),
        ),
      ],
    );
  }
}

extension on Iterable<Ganadero?> {
  Ganadero? get firstOrNull => isEmpty ? null : first;
}
