import 'package:flutter/material.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../services/database_helper.dart';
import '../screens/home_screen.dart';
import '../screens/ganaderos_crud.dart';
import '../screens/historial_mediciones_screen.dart';

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
