import 'package:flutter/material.dart';
import '../app/navigation.dart';
import '../screens/login_screen.dart';
import '../utils/service_locator.dart';
import '../services/bluetooth_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  String _statusText = "Iniciando BioScan...";
  bool _hasError = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    
    // Al finalizar el primer frame de animación, iniciamos la carga pesada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[FIRST_FRAME] ${DateTime.now().toIso8601String()}');
      _startInitialization();
    });
  }

  Future<void> _startInitialization() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorMessage = "";
      _statusText = "Iniciando BioScan...";
    });

    try {
      await ServiceLocator.init(
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _statusText = status;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _statusText = "Iniciando hardware...";
        });
      }
      
      // BluetoothManager can be initialized securely now
      BluetoothManager.instance.init();

      if (mounted) {
        setState(() {
          _statusText = "Listo";
        });
      }
      
      // Pequeño delay de 200ms para asegurar que el usuario alcance a leer "Listo" y la animación se vea fluida
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      final auth = ServiceLocator.authService;
      final targetScreen = auth.isLoggedIn ? const MainNavigation() : const LoginScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    } catch (e, stackTrace) {
      debugPrint('Error durante inicialización: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = "No se pudo completar la carga inicial.\n\n$e";
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo image
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // App Title
              const Text(
                'BioScan',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confianza en cada gota.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startInitialization,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reintentar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.indigo.shade300,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Loading indicator
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
