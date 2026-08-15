import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../screens/beta_bluetooth_screen.dart';
import '../screens/ganaderos_crud.dart';
import '../screens/historial_mediciones_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/usuarios_screen.dart';
import '../utils/service_locator.dart';
import '../utils/uuid_generator.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<Cliente> _clientes = [];
  List<Ganadero> _ganaderos = [];
  List<Medicion> _mediciones = [];
  String? _selectedClienteId;
  String? _selectedGanaderoId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final auth = ServiceLocator.authService;
    if (!auth.isLoggedIn) return;

    final clientes = await ServiceLocator.clienteRepository.getClientes();
    final activeClienteId = auth.activeClienteId;

    if (!mounted) return;

    setState(() {
      _clientes = clientes;
      _selectedClienteId = activeClienteId;
    });

    await _loadFilteredData();
  }

  Future<void> _loadFilteredData() async {
    final clienteId = _selectedClienteId ?? ServiceLocator.authService.activeClienteId;

    final ganaderos = await ServiceLocator.ganaderoRepository.getGanaderosByCliente(clienteId);
    final mediciones = await ServiceLocator.medicionRepository.getMedicionesByCliente(clienteId);

    if (!mounted) return;

    setState(() {
      _ganaderos = ganaderos;
      _mediciones = mediciones;
      if (_selectedGanaderoId != null && !_ganaderos.any((g) => g.id == _selectedGanaderoId)) {
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
    await _loadInitialData();
  }

  Future<void> _addGanadero(Ganadero ganadero) async {
    final activeClienteId = _selectedClienteId ?? ServiceLocator.authService.activeClienteId;
    final newGanadero = ganadero.id.isEmpty
        ? ganadero.copyWith(
            id: UuidGenerator.generate(),
            clienteId: activeClienteId,
            fechaRegistro: DateTime.now().toIso8601String(),
            sincronizado: false,
          )
        : ganadero.copyWith(clienteId: activeClienteId);

    await ServiceLocator.ganaderoRepository.insertGanadero(newGanadero);
    await _loadFilteredData();
  }

  Future<void> _updateGanadero(Ganadero ganadero) async {
    await ServiceLocator.ganaderoRepository.updateGanadero(ganadero);
    await _loadFilteredData();
  }

  Future<void> _deleteGanadero(String id) async {
    await ServiceLocator.ganaderoRepository.deleteGanadero(id);
    await _loadFilteredData();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro de que desea salir de BioScan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ServiceLocator.authService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ServiceLocator.authService;
    final currentUser = auth.currentUser;

    // Guard de Autenticación
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedCliente = _clientes.where((c) => c.id == _selectedClienteId).cast<Cliente?>().firstOrNull;

    // Configuración de páginas según rol (AuthGuard & Role Navigation)
    final List<Widget> pages = [
      HomeScreen(
        ganaderos: _ganaderos,
        selectedGanaderoId: _selectedGanaderoId,
        onSelectedGanaderoChanged: _selectGanadero,
        onMeasurementSaved: _refreshData,
        cliente: selectedCliente,
        usuario: currentUser,
      ),
      GanaderosCRUD(
        ganaderos: _ganaderos,
        onAddGanadero: _addGanadero,
        onEditGanadero: _updateGanadero,
        onDeleteGanadero: _deleteGanadero,
      ),
      HistorialMedicionesScreen(mediciones: _mediciones, ganaderos: _ganaderos),
      if (currentUser.isAdmin) const UsuariosScreen(),
      const BetaBluetoothScreen(),
    ];

    final List<NavigationDestination> destinations = [
      const NavigationDestination(icon: Icon(Icons.biotech), label: 'Escaneo'),
      const NavigationDestination(icon: Icon(Icons.group), label: 'Ganaderos'),
      const NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
      if (currentUser.isAdmin) const NavigationDestination(icon: Icon(Icons.manage_accounts), label: 'Usuarios'),
      const NavigationDestination(icon: Icon(Icons.bluetooth_searching), label: 'Beta BLE'),
    ];

    // Asegurar que el índice de navegación no exceda las pestañas disponibles
    final safeIndex = _selectedIndex >= pages.length ? 0 : _selectedIndex;
    const topBarColor = Color(0xFF008C83);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: topBarColor,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      currentUser.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Rol: ${currentUser.rol}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Cerrar Sesión',
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: destinations,
      ),
    );
  }
}

extension on Iterable<Cliente?> {
  Cliente? get firstOrNull => isEmpty ? null : first;
}
