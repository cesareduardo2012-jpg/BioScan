import 'package:flutter/material.dart';

void main() => runApp(const BioScanApp());

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

// --- NAVEGACIÓN PRINCIPAL ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const HomeScreen(), const GanaderosCRUD()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.biotech), label: 'Escaneo'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Ganaderos'),
        ],
      ),
    );
  }
}

// --- PANTALLA DE ESCANEO (CON LÓGICA DE BLUETOOTH) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  int? selectedGanaderoId;
  
  // Datos de la BD (Simulados hasta conectar)
  String phValue = "N/D";
  String aguaValue = "N/D";
  String tempValue = "N/D";

  void _connectBluetooth() {
    setState(() {
      isConnected = !isConnected;
      if (isConnected) {
        // Al conectar, los sensores "cobran vida"
        phValue = "6.7";
        aguaValue = "0.0%";
        tempValue = "24°C";
      } else {
        phValue = "N/D";
        aguaValue = "N/D";
        tempValue = "N/D";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BioScan - Terminal")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Selector de Ganadero (Ref: tabla ganaderos)
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: "Ganadero Responsable", border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 1, child: Text("Juan Pérez (Rancho El Sol)")),
                DropdownMenuItem(value: 2, child: Text("María López (La Loma)")),
              ],
              onChanged: (val) => setState(() => selectedGanaderoId = val),
            ),
            const SizedBox(height: 20),

            // 2. Control de Bluetooth
            ListTile(
              tileColor: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Icon(Icons.bluetooth, color: isConnected ? Colors.blue : Colors.grey),
              title: Text(isConnected ? "Dispositivo Conectado" : "Dispositivo Desconectado"),
              trailing: Switch(value: isConnected, onChanged: (val) => _connectBluetooth()),
            ),
            const SizedBox(height: 20),

            // 3. Lectura de Sensores (Solo disponibles si isConnected == true)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SensorBox(label: "pH", value: phValue, active: isConnected),
                _SensorBox(label: "Agua", value: aguaValue, active: isConnected),
                _SensorBox(label: "Temp", value: tempValue, active: isConnected),
              ],
            ),
            const Spacer(),

            // 4. Botón Guardar (Solo habilitado si hay conexión y ganadero)
            ElevatedButton(
              onPressed: (isConnected && selectedGanaderoId != null) ? () {
                // Aquí iría el INSERT a la tabla 'mediciones'
              } : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              child: const Text("REGISTRAR MEDICIÓN EN BD"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CRUD DE GANADEROS (PÁGINA INDEPENDIENTE) ---
class GanaderosCRUD extends StatefulWidget {
  const GanaderosCRUD({super.key});
  @override
  State<GanaderosCRUD> createState() => _GanaderosCRUDState();
}

class _GanaderosCRUDState extends State<GanaderosCRUD> {
  // Lista simulada que representa la tabla 'ganaderos' de tu SQL Server
  final List<Map<String, String>> _ganaderos = [
    {"id": "1", "nombre": "Juan Pérez", "rancho": "Rancho El Sol", "tel": "3411234567"},
    {"id": "2", "nombre": "María López", "rancho": "La Loma", "tel": "3417654321"},
  ];

  void _showForm(int? index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(index == null ? "Nuevo Ganadero" : "Editar Ganadero", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const TextField(decoration: InputDecoration(labelText: "Nombre")),
            const TextField(decoration: InputDecoration(labelText: "Apellido Paterno")),
            const TextField(decoration: InputDecoration(labelText: "Apellido Materno")),
            const TextField(decoration: InputDecoration(labelText: "Nombre del Rancho")),
            const TextField(decoration: InputDecoration(labelText: "Teléfono")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Guardar Ganadero")),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de Ganaderos")),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(null), child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: _ganaderos.length,
        itemBuilder: (ctx, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: ListTile(
            title: Text(_ganaderos[i]['nombre']!),
            subtitle: Text("Rancho: ${_ganaderos[i]['rancho']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(i)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para los sensores
class _SensorBox extends StatelessWidget {
  final String label, value;
  final bool active;
  const _SensorBox({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Container(
          width: 80, height: 60,
          decoration: BoxDecoration(color: active ? Colors.indigo.shade50 : Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: active ? Colors.indigo : Colors.grey)),
        ),
      ],
    );
  }
}
