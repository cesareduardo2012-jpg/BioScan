import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'beta_bluetooth_screen.dart';

void main() => runApp(const BioScanApp());

class BioScanApp extends StatelessWidget {
  const BioScanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
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
  final List<Widget> _pages = [const HomeScreen(), const GanaderosCRUD(), const BetaBluetoothScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.biotech_outlined), selectedIcon: Icon(Icons.biotech), label: 'Escaneo'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Ganaderos'),
          NavigationDestination(icon: Icon(Icons.bluetooth_searching_outlined), selectedIcon: Icon(Icons.bluetooth_searching), label: 'Beta BLE'),
        ],
      ),
    );
  }
}

// --- MODELO LOCAL: ganadero disponible para asignar al escaneo ---
// (Lista de demostración; el CRUD real vive en GanaderosCRUD.)
class _GanaderoOption {
  const _GanaderoOption(this.id, this.nombre, this.rancho);
  final int id;
  final String nombre;
  final String rancho;
}

const _ganaderoOptions = [
  _GanaderoOption(1, 'Juan Pérez', 'Rancho El Sol'),
  _GanaderoOption(2, 'María López', 'La Loma'),
];

enum _Nivel { bueno, revisar, alerta }

// --- PANTALLA DE ESCANEO ---
// Tratada como un certificado de análisis que se emite al momento, no como
// un formulario de captura: encabezado de marca, campo de ganadero,
// indicador de instrumento conectado y un semáforo de calidad por lectura.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isConnected = false;
  int? selectedGanaderoId;

  // Datos de la BD (Simulados hasta conectar)
  String phValue = 'N/D';
  String aguaValue = 'N/D';
  String tempValue = 'N/D';

  void _toggleConexion() {
    setState(() {
      isConnected = !isConnected;
      if (isConnected) {
        // Al conectar, los sensores "cobran vida"
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

  Future<void> _elegirGanadero() async {
    final elegido = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ganadero responsable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            for (final opcion in _ganaderoOptions)
              ListTile(
                title: Text(opcion.nombre),
                subtitle: Text(opcion.rancho),
                trailing: opcion.id == selectedGanaderoId ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, opcion.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido != null) {
      setState(() => selectedGanaderoId = elegido);
    }
  }

  double? _numero(String valor) => double.tryParse(valor.replaceAll(RegExp(r'[^0-9.\-]'), ''));

  _Nivel? _nivelPh() {
    final v = _numero(phValue);
    if (v == null) return null;
    if (v >= 6.6 && v <= 6.8) return _Nivel.bueno;
    if (v >= 6.4 && v <= 7.0) return _Nivel.revisar;
    return _Nivel.alerta;
  }

  _Nivel? _nivelAgua() {
    final v = _numero(aguaValue);
    if (v == null) return null;
    if (v <= 2) return _Nivel.bueno;
    if (v <= 4) return _Nivel.revisar;
    return _Nivel.alerta;
  }

  _Nivel? _nivelTemp() {
    final v = _numero(tempValue);
    if (v == null) return null;
    if (v >= 2 && v <= 10) return _Nivel.bueno;
    if (v <= 15) return _Nivel.revisar;
    return _Nivel.alerta;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BioScanColors>()!;
    final ganadero = _ganaderoOptions.where((g) => g.id == selectedGanaderoId).cast<_GanaderoOption?>().firstOrNull;
    final canRegister = isConnected && ganadero != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandHeader(colors: colors),
              const SizedBox(height: 26),
              _GanaderoField(colors: colors, ganadero: ganadero, onTap: _elegirGanadero),
              const SizedBox(height: 14),
              _InstrumentStatus(colors: colors, isConnected: isConnected, onTap: _toggleConexion),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _ResultTile(colors: colors, label: 'pH', value: phValue, nivel: isConnected ? _nivelPh() : null)),
                  const SizedBox(width: 8),
                  Expanded(child: _ResultTile(colors: colors, label: 'Agua', value: aguaValue, nivel: isConnected ? _nivelAgua() : null)),
                  const SizedBox(width: 8),
                  Expanded(child: _ResultTile(colors: colors, label: 'Temp', value: tempValue, nivel: isConnected ? _nivelTemp() : null)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: canRegister ? () {
                  // Aquí iría el INSERT a la tabla 'mediciones'
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resultado emitido para ${ganadero.nombre}')),
                  );
                } : null,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('EMITIR RESULTADO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colors});
  final BioScanColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 30, height: 30, child: CustomPaint(painter: _LogoMarkPainter(color: colors.brand))),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                style: TextStyle(fontFamily: kSerifFamily, fontSize: 22, color: colors.ink),
                children: [
                  TextSpan(text: 'Bio', style: TextStyle(fontWeight: FontWeight.w700, color: colors.brandStrong)),
                  const TextSpan(text: 'Scan', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 2),
          child: Text(
            'CONFIANZA EN CADA GOTA',
            style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: colors.inkMuted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  _LogoMarkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    final center = Offset(size.width * 0.42, size.height * 0.5);
    final radius = size.width * 0.28;
    canvas.drawCircle(center, radius, stroke);
    final handleStart = Offset(center.dx + radius * 0.72, center.dy + radius * 0.72);
    final handleEnd = Offset(size.width * 0.95, size.height * 0.95);
    canvas.drawLine(handleStart, handleEnd, stroke);

    canvas.drawCircle(Offset(center.dx, center.dy + radius * 0.15), size.width * 0.045, fill);
    canvas.drawCircle(Offset(center.dx - radius * 0.1, center.dy + radius * 0.65), size.width * 0.03, fill);
    canvas.drawCircle(Offset(center.dx + radius * 0.35, center.dy + radius * 0.75), size.width * 0.03, fill);
  }

  @override
  bool shouldRepaint(covariant _LogoMarkPainter oldDelegate) => oldDelegate.color != color;
}

class _GanaderoField extends StatelessWidget {
  const _GanaderoField({required this.colors, required this.ganadero, required this.onTap});
  final BioScanColors colors;
  final _GanaderoOption? ganadero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GANADERO RESPONSABLE', style: TextStyle(fontSize: 10.5, letterSpacing: 1, color: colors.inkMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    ganadero?.nombre ?? 'Selecciona un ganadero',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ganadero == null ? colors.inkMuted : colors.ink),
                  ),
                ],
              ),
            ),
            if (ganadero != null)
              Text(ganadero!.rancho, style: TextStyle(fontSize: 12.5, color: colors.inkMuted)),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, color: colors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InstrumentStatus extends StatelessWidget {
  const _InstrumentStatus({required this.colors, required this.isConnected, required this.onTap});
  final BioScanColors colors;
  final bool isConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            _SignalRing(colors: colors, active: isConnected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? 'Sensor conectado' : 'Sensor desconectado',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  Text(
                    isConnected ? 'Recibiendo lecturas del ESP32' : 'Toca para simular la conexión',
                    style: TextStyle(fontSize: 12, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalRing extends StatefulWidget {
  const _SignalRing({required this.colors, required this.active});
  final BioScanColors colors;
  final bool active;

  @override
  State<_SignalRing> createState() => _SignalRingState();
}

class _SignalRingState extends State<_SignalRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.active ? widget.colors.brand : widget.colors.border;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: 2.4)),
      alignment: Alignment.center,
      child: widget.active
          ? FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.3).animate(_controller),
              child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.colors.brand)),
            )
          : Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.colors.border)),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.colors, required this.label, required this.value, required this.nivel});
  final BioScanColors colors;
  final String label;
  final String value;
  final _Nivel? nivel;

  Color get _stripeColor {
    switch (nivel) {
      case _Nivel.bueno:
        return colors.good;
      case _Nivel.revisar:
        return colors.warn;
      case _Nivel.alerta:
        return colors.alert;
      case null:
        return colors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(border: Border.all(color: colors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.8, color: colors.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontFamily: kMonoFamily, fontSize: 18, fontWeight: FontWeight.w700, color: colors.ink)),
          const SizedBox(height: 8),
          Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: _stripeColor, borderRadius: BorderRadius.circular(3))),
        ],
      ),
    );
  }
}

extension on Iterable<_GanaderoOption?> {
  _GanaderoOption? get firstOrNull => isEmpty ? null : first;
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
