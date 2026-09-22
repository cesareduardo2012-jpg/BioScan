import 'package:flutter/material.dart';
import '../database/dao/usuario_dao.dart';
import '../models/usuario.dart';
import '../models/cliente.dart';
import '../services/auth_service.dart';
import '../services/bluetooth_manager.dart';
import '../services/thermal_printer_service.dart';
import '../utils/service_locator.dart';
import 'configurar_impresora_screen.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  Usuario? _adminUser;
  Usuario? _operatorUser;
  Map<String, String>? _configuredPrinter;
  bool _isLoading = true;
  bool _isPrintingTest = false;
  String? _errorMessage;
  Cliente? _activeCliente;
  Usuario? _adminUserForOperator;

  @override
  void initState() {
    super.initState();
    _loadUsersData();
    BluetoothManager.instance.addListener(_onBtStateChanged);
  }

  void _onBtStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    BluetoothManager.instance.removeListener(_onBtStateChanged);
    super.dispose();
  }

  /// Muestra el aviso (si lo hay) cuando crear/editar/eliminar un operador
  /// se completó localmente pero falló al respaldarse en la nube por una
  /// razón distinta a estar sin conexión -- sin esto, la pantalla solo
  /// mostraba el mensaje de "éxito" y el admin nunca se enteraba.
  void _maybeShowOperatorCloudWarning() {
    final warning = ServiceLocator.authService
        .consumeLastOperatorCloudWarning();
    if (warning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _loadUsersData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ServiceLocator.authService;
      final clienteId = auth.activeClienteId;

      final admin = await ServiceLocator.usuarioRepository.getAdminByCliente(
        clienteId,
      );
      final operator = await ServiceLocator.usuarioRepository
          .getOperatorByCliente(clienteId);
      final printer = await ThermalPrinterService.instance
          .getConfiguredPrinter();
      final cliente = await ServiceLocator.clienteRepository.getClienteById(clienteId);

      Usuario? adminForOperator;
      if (auth.currentUser?.isOperador == true) {
         adminForOperator = admin ?? await ServiceLocator.usuarioRepository.getAdminByCliente(clienteId);
      }

      if (mounted) {
        setState(() {
          _adminUser = admin ?? (auth.currentUser?.isAdmin == true ? auth.currentUser : null);
          _operatorUser = operator;
          _configuredPrinter = printer;
          _activeCliente = cliente;
          _adminUserForOperator = adminForOperator;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar datos de configuración: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _abrirConfigurarImpresora() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const ConfigurarImpresoraScreen()),
    );
    await _loadUsersData();
  }

  Future<void> _imprimirPruebaRapida() async {
    if (_isPrintingTest) return;
    setState(() => _isPrintingTest = true);

    try {
      await ThermalPrinterService.instance.printTestTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket de prueba enviado a la impresora con éxito.'),
            backgroundColor: Color(0xFF008C83),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Error de Impresión'),
              ],
            ),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C83),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _abrirConfigurarImpresora();
                },
                child: const Text('Configurar Impresora'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTest = false);
    }
  }

  // --- DIÁLOGOS DE GESTIÓN DEL OPERADOR ---

  Future<void> _showCreateOperatorDialog() async {
    final usernameCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePass = true;
    String? dialogError;
    // Evita doble-tap: sin este guard, tocar rapido dos veces "Crear
    // Operador" disparaba dos createOperator() concurrentes contra la
    // regla de "maximo 1 operador por cuenta".
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Color(0xFF008C83)),
              SizedBox(width: 10),
              Text('Crear Usuario Operador'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario',
                      hintText: 'Ej. operador01',
                      prefixIcon: Icon(Icons.account_box),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Requerido';
                      if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      hintText: 'Ej. Juan Pérez',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Requerido';
                      if (val.trim().length < 4) return 'Mínimo 4 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: obscurePass,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Contraseña',
                      prefixIcon: Icon(Icons.lock_clock),
                    ),
                    validator: (val) {
                      if (val != passwordCtrl.text)
                        return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C83),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ServiceLocator.authService.createOperator(
                            username: usernameCtrl.text,
                            nombre: nombreCtrl.text,
                            password: passwordCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on OperatorLimitExceededException catch (e) {
                          setDialogState(() {
                            dialogError = e.message;
                            isSubmitting = false;
                          });
                        } on AuthException catch (e) {
                          setDialogState(() {
                            dialogError = e.message;
                            isSubmitting = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            dialogError = 'Error al crear operador: $e';
                            isSubmitting = false;
                          });
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Crear Operador'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      usernameCtrl.dispose();
      nombreCtrl.dispose();
      passwordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    });

    _maybeShowOperatorCloudWarning();
    await _loadUsersData();
  }

  Future<void> _showEditOperatorDialog() async {
    if (_operatorUser == null) return;
    final usernameCtrl = TextEditingController(text: _operatorUser!.username);
    final nombreCtrl = TextEditingController(text: _operatorUser!.nombre);
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Operador'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de Usuario',
                      prefixIcon: Icon(Icons.account_box),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Requerido';
                      if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C83),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ServiceLocator.authService.updateOperator(
                            operatorId: _operatorUser!.id,
                            username: usernameCtrl.text,
                            nombre: nombreCtrl.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } on AuthException catch (e) {
                          setDialogState(() {
                            dialogError = e.message;
                            isSubmitting = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            dialogError = 'Error: $e';
                            isSubmitting = false;
                          });
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    // Esperar a que la animación de cierre del diálogo termine antes de
    // liberar los controladores (evita "TextEditingController was used
    // after being disposed" -- este diálogo era el único de los 4 sin esta
    // espera, a diferencia de sus hermanos en este mismo archivo).
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    usernameCtrl.dispose();
    nombreCtrl.dispose();

    await _loadUsersData();
  }

  Future<void> _showChangeOperatorPasswordDialog() async {
    if (_operatorUser == null) return;
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Cambiar Contraseña de ${_operatorUser!.username}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) ...[
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva Contraseña',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Requerido';
                    if (val.trim().length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C83),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ServiceLocator.authService.updateOperator(
                            operatorId: _operatorUser!.id,
                            newPassword: passwordCtrl.text,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        } on AuthException catch (e) {
                          setDialogState(() {
                            dialogError = e.message;
                            isSubmitting = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            dialogError = 'Error inesperado: $e';
                            isSubmitting = false;
                          });
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Actualizar Contraseña'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      passwordCtrl.dispose();
    });

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada con éxito')),
      );
    }

    _maybeShowOperatorCloudWarning();
    await _loadUsersData();
  }

  Future<void> _toggleOperatorStatus() async {
    if (_operatorUser == null) return;
    final newStatus = !_operatorUser!.activo;
    final actionName = newStatus ? 'activar' : 'desactivar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${newStatus ? 'Activar' : 'Desactivar'} Operador'),
        content: Text(
          '¿Está seguro de que desea $actionName al operador "${_operatorUser!.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: newStatus ? Colors.green : Colors.orange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newStatus ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ServiceLocator.authService.updateOperator(
        operatorId: _operatorUser!.id,
        activo: newStatus,
      );
      await _loadUsersData();
    }
  }

  Future<void> _deleteOperator() async {
    if (_operatorUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar / Eliminar Operador'),
        content: Text(
          '¿Desea desactivar al operador "${_operatorUser!.nombre}"? El registro se conservará por trazabilidad pero no podrá iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar Operador'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ServiceLocator.authService.deleteOperator(_operatorUser!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Operador eliminado exitosamente.')),
          );
        }
        _maybeShowOperatorCloudWarning();
        await _loadUsersData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  // --- DIÁLOGO DE CAMBIO DE CONTRASEÑA PROPIA (ADMIN) ---

  Future<void> _showChangeOwnPasswordDialog() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar Mi Contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) ...[
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña Actual',
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva Contraseña',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Requerido';
                    if (val.trim().length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C83),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSubmitting = true);
                        try {
                          await ServiceLocator.authService.changeOwnPassword(
                            currentPassCtrl.text,
                            newPassCtrl.text,
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx, true);
                          }
                        } on AuthException catch (e) {
                          setDialogState(() {
                            dialogError = e.message;
                            isSubmitting = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            dialogError = 'Error: $e';
                            isSubmitting = false;
                          });
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      currentPassCtrl.dispose();
      newPassCtrl.dispose();
    });

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada con éxito')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ServiceLocator.authService;
    final currentUser = auth.currentUser;
    final isOperatorMode = currentUser?.isOperador == true;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF008C83)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Configuración y Perfil'),
        backgroundColor: const Color(0xFF008C83),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsersData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (currentUser != null) _buildProfileSection(currentUser),
            if (currentUser?.isSuperAdmin == false && _activeCliente != null) _buildCompanySection(),
            if (currentUser?.isOperador == true && _adminUserForOperator != null) _buildAdminInfoSection(),
            if (currentUser?.isAdmin == true) _buildOperatorManagementSection(isOperatorMode),
            
            _buildPrinterSection(),
            _buildSimulatorSection(),
            
            _buildAboutSection(),
            _buildTeamSection(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildProfileSection(Usuario currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI PERFIL'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF008C83).withValues(alpha: 0.15),
                  child: Icon(
                    currentUser.isAdmin ? Icons.admin_panel_settings : (currentUser.isSuperAdmin ? Icons.shield : Icons.person),
                    color: const Color(0xFF008C83),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.nombre,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Usuario: ${currentUser.username}', style: TextStyle(color: Colors.grey.shade700)),
                      Text('Correo: ${currentUser.correo}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currentUser.rol.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.lock_reset, color: Color(0xFF008C83)),
                  tooltip: 'Cambiar Mi Contraseña',
                  onPressed: _showChangeOwnPasswordDialog,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI EMPRESA'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business, color: Color(0xFF008C83)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeCliente!.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _activeCliente!.activo ? Colors.green.shade100 : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _activeCliente!.activo ? 'ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _activeCliente!.activo ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                if (_activeCliente!.empresa.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Razón Social: ${_activeCliente!.empresa}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                if (_activeCliente!.telefono.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Teléfono: ${_activeCliente!.telefono}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                if (_activeCliente!.correo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('Correo: ${_activeCliente!.correo}', style: TextStyle(color: Colors.grey.shade700)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MI ADMINISTRADOR'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: const Icon(Icons.admin_panel_settings, color: Colors.indigo),
            ),
            title: Text(_adminUserForOperator!.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_adminUserForOperator!.correo),
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorManagementSection(bool isOperatorMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.0, top: 24.0),
                child: Text(
                  'OPERADORES DE LA CUENTA (MÁX. 1)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                ),
              ),
            ),
            if (_operatorUser == null && !isOperatorMode)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF008C83),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Crear Operador'),
                  onPressed: _showCreateOperatorDialog,
                ),
              ),
          ],
        ),
        if (_operatorUser != null)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue.withValues(alpha: 0.15),
                        child: const Icon(Icons.engineering, color: Colors.blue, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _operatorUser!.nombre,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _operatorUser!.activo ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _operatorUser!.activo ? 'ACTIVO' : 'INACTIVO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _operatorUser!.activo ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Usuario: ${_operatorUser!.username}', style: TextStyle(color: Colors.grey.shade700)),
                            Text('Rol: Operador Limitado', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Editar'),
                        onPressed: _showEditOperatorDialog,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.key, size: 18),
                        label: const Text('Clave'),
                        onPressed: _showChangeOperatorPasswordDialog,
                      ),
                      TextButton.icon(
                        icon: Icon(
                          _operatorUser!.activo ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                          color: _operatorUser!.activo ? Colors.orange : Colors.green,
                        ),
                        label: Text(
                          _operatorUser!.activo ? 'Desactivar' : 'Activar',
                          style: TextStyle(color: _operatorUser!.activo ? Colors.orange : Colors.green),
                        ),
                        onPressed: _toggleOperatorStatus,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Eliminar Operador',
                        onPressed: _deleteOperator,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.person_add_disabled, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No hay usuario Operador registrado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Puede registrar un usuario Operador para permitir mediciones limitadas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008C83),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Crear Usuario Operador'),
                    onPressed: _showCreateOperatorDialog,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrinterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('IMPRESORA TÉRMICA BLUETOOTH'),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: TextButton.icon(
                icon: const Icon(Icons.settings_bluetooth, size: 16, color: Color(0xFF008C83)),
                label: const Text('Gestionar', style: TextStyle(color: Color(0xFF008C83))),
                onPressed: _abrirConfigurarImpresora,
              ),
            ),
          ],
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _configuredPrinter != null
                          ? const Color(0xFF008C83).withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.print,
                        color: _configuredPrinter != null ? const Color(0xFF008C83) : Colors.grey.shade600,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _configuredPrinter != null ? _configuredPrinter!['name']! : 'Impresora No Configurada',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _configuredPrinter != null ? Colors.green.shade100 : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _configuredPrinter != null ? 'CONECTADA / LISTA' : 'NO CONFIGURADA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _configuredPrinter != null ? Colors.green.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _configuredPrinter != null
                                ? 'MAC: ${_configuredPrinter!['mac']} • Formato 58 mm'
                                : 'Vincule una impresora térmica portátil para imprimir tickets de análisis',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF008C83),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bluetooth_searching, size: 18),
                        label: Text(_configuredPrinter != null ? 'Cambiar Impresora' : 'Configurar Impresora'),
                        onPressed: _abrirConfigurarImpresora,
                      ),
                    ),
                    if (_configuredPrinter != null) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF005267),
                          side: const BorderSide(color: Color(0xFF005267)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isPrintingTest
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005267)))
                            : const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Prueba'),
                        onPressed: _isPrintingTest ? null : _imprimirPruebaRapida,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('HERRAMIENTAS DE DESARROLLO Y PRUEBAS'),
        Builder(
          builder: (ctx) {
            final isSimulationActive = BluetoothManager.instance.isSimulationMode;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSimulationActive ? Colors.deepPurple.shade300 : Colors.transparent,
                  width: 1.5,
                ),
              ),
              color: isSimulationActive ? Colors.deepPurple.shade50.withValues(alpha: 0.6) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isSimulationActive ? Colors.deepPurple.shade100 : Colors.grey.shade100,
                          child: Icon(Icons.science_rounded, color: isSimulationActive ? Colors.deepPurple : Colors.grey.shade700, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Modo Simulador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSimulationActive ? Colors.green.shade100 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isSimulationActive ? 'SIMULADOR ACTIVO' : 'HARDWARE REAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSimulationActive ? Colors.green.shade800 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSimulationActive ? 'Conectado a BioScan-Demo • Batería 100%' : 'Buscando prototipo físico ESP32 vía BLE',
                                style: TextStyle(fontSize: 12, color: isSimulationActive ? Colors.deepPurple.shade700 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isSimulationActive,
                          activeThumbColor: Colors.deepPurple,
                          activeTrackColor: Colors.deepPurple.shade200,
                          onChanged: (enabled) {
                            BluetoothManager.instance.setSimulationMode(enabled);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enabled
                                      ? 'Modo Simulador Activo: Dispositivo BioScan-Demo listo para pruebas'
                                      : 'Modo Simulador Desactivado: Cambiando a hardware Bluetooth real',
                                ),
                                backgroundColor: enabled ? Colors.deepPurple : const Color(0xFF008C83),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Permite realizar mediciones completas por etapas (Densidad, Temperatura y pH) y compilar reportes PDF de forma 100% autónoma sin requerir el sensor físico conectado.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ACERCA DE BIOSCAN'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.biotech, size: 48, color: Color(0xFF008C83)),
                const SizedBox(height: 12),
                const Text(
                  'BioScan',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF005267)),
                ),
                const Text(
                  '"Confianza en cada gota"',
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BioScan es una solución tecnológica enfocada en ayudar a pequeños y medianos productores y procesadores de lácteos a obtener información rápida sobre la calidad de la leche mediante un dispositivo portátil.\n\nFunciona como un "laboratorio de bolsillo" para obtener al instante datos vitales de pH, temperatura y densidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Versión de la App', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const Text('1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('NUESTRO EQUIPO'),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'El equipo detrás de BioScan está comprometido con la innovación tecnológica en el sector lácteo, aportando pasión y experiencia para transformar el monitoreo de calidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.groups, color: Colors.teal),
                  ),
                  title: const Text('Equipo BioScan', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Desarrollo e Innovación'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
