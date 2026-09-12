import 'package:flutter/material.dart';
import '../database/dao/usuario_dao.dart';
import '../models/usuario.dart';
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

  Future<void> _loadUsersData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ServiceLocator.authService;
      final clienteId = auth.activeClienteId;

      final admin = await ServiceLocator.usuarioRepository.getAdminByCliente(clienteId);
      final operator = await ServiceLocator.usuarioRepository.getOperatorByCliente(clienteId);
      final printer = await ThermalPrinterService.instance.getConfiguredPrinter();

      if (mounted) {
        setState(() {
          _adminUser = admin ?? auth.currentUser;
          _operatorUser = operator;
          _configuredPrinter = printer;
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
      MaterialPageRoute(
        builder: (ctx) => const ConfigurarImpresoraScreen(),
      ),
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
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
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

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
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
                      if (val != passwordCtrl.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ServiceLocator.authService.createOperator(
                      username: usernameCtrl.text,
                      nombre: nombreCtrl.text,
                      password: passwordCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on OperatorLimitExceededException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } on AuthException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } catch (e) {
                    setDialogState(() => dialogError = 'Error al crear operador: $e');
                  }
                }
              },
              child: const Text('Crear Operador'),
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

    await _loadUsersData();
  }

  Future<void> _showEditOperatorDialog() async {
    if (_operatorUser == null) return;
    final usernameCtrl = TextEditingController(text: _operatorUser!.username);
    final nombreCtrl = TextEditingController(text: _operatorUser!.nombre);
    final formKey = GlobalKey<FormState>();
    String? dialogError;

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
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ServiceLocator.authService.updateOperator(
                      operatorId: _operatorUser!.id,
                      username: usernameCtrl.text,
                      nombre: nombreCtrl.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } on AuthException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } catch (e) {
                    setDialogState(() => dialogError = 'Error: $e');
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    usernameCtrl.dispose();
    nombreCtrl.dispose();

    await _loadUsersData();
  }

  Future<void> _showChangeOperatorPasswordDialog() async {
    if (_operatorUser == null) return;
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;

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
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ServiceLocator.authService.updateOperator(
                      operatorId: _operatorUser!.id,
                      newPassword: passwordCtrl.text,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } on AuthException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } catch (e) {
                    setDialogState(() => dialogError = 'Error inesperado: $e');
                  }
                }
              },
              child: const Text('Actualizar Contraseña'),
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
        content: Text('¿Está seguro de que desea $actionName al operador "${_operatorUser!.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: newStatus ? Colors.green : Colors.orange),
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
        content: Text('¿Desea desactivar al operador "${_operatorUser!.nombre}"? El registro se conservará por trazabilidad pero no podrá iniciar sesión.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
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
        await _loadUsersData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
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
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña Actual'),
                  validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva Contraseña'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF008C83)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await ServiceLocator.authService.changeOwnPassword(
                      currentPassCtrl.text,
                      newPassCtrl.text,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } on AuthException catch (e) {
                    setDialogState(() => dialogError = e.message);
                  } catch (e) {
                    setDialogState(() => dialogError = 'Error: $e');
                  }
                }
              },
              child: const Text('Actualizar'),
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFF008C83))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _loadUsersData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),
            ],

            // SECCIÓN ADMINISTRADOR
            const Text(
              'PROPIETARIO DE LA CUENTA',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
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
                      child: const Icon(Icons.admin_panel_settings, color: Color(0xFF008C83), size: 30),
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
                                  _adminUser?.nombre ?? 'Administrador',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'ADMINISTRADOR',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Usuario: ${_adminUser?.username ?? 'admin'}', style: TextStyle(color: Colors.grey.shade700)),
                          Text('Correo: ${_adminUser?.correo ?? 'admin@bioscan.com'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (!isOperatorMode)
                      IconButton(
                        icon: const Icon(Icons.lock_reset, color: Color(0xFF008C83)),
                        tooltip: 'Cambiar Mi Contraseña',
                        onPressed: _showChangeOwnPasswordDialog,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SECCIÓN OPERADOR (MAX 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'USUARIO OPERADOR (MÁX. 1 POR CUENTA)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                  ),
                ),
                if (_operatorUser == null && !isOperatorMode)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008C83),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Crear Operador'),
                    onPressed: _showCreateOperatorDialog,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_operatorUser != null) ...[
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (!isOperatorMode)
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Editar'),
                              onPressed: _showEditOperatorDialog,
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.key, size: 18),
                            label: const Text('Clave'),
                            onPressed: isOperatorMode ? _showChangeOwnPasswordDialog : _showChangeOperatorPasswordDialog,
                          ),
                          if (!isOperatorMode)
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
                          if (!isOperatorMode)
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
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Límite de cuenta alcanzado: 1 Administrador + 1 Operador. Para crear un nuevo operador debe eliminar o desactivar el existente.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.person_add_disabled, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay usuario Operador registrado',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Puede registrar un usuario Operador para permitir mediciones limitadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
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

            const SizedBox(height: 24),

            // SECCIÓN IMPRESORA TÉRMICA BLUETOOTH
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'IMPRESORA TÉRMICA BLUETOOTH',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.settings_bluetooth, size: 16, color: Color(0xFF008C83)),
                  label: const Text('Gestionar', style: TextStyle(color: Color(0xFF008C83))),
                  onPressed: _abrirConfigurarImpresora,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                                      _configuredPrinter != null
                                          ? _configuredPrinter!['name']!
                                          : 'Impresora No Configurada',
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
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005267)),
                                  )
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

            const SizedBox(height: 24),

            // SECCIÓN SIMULADOR DE HARDWARE
            const Text(
              'HERRAMIENTAS DE DESARROLLO Y PRUEBAS',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
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
                              child: Icon(
                                Icons.science_rounded,
                                color: isSimulationActive ? Colors.deepPurple : Colors.grey.shade700,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Modo Simulador',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
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
                                    isSimulationActive
                                        ? 'Conectado a BioScan-Demo • Batería 100%'
                                        : 'Buscando prototipo físico ESP32 vía BLE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSimulationActive ? Colors.deepPurple.shade700 : Colors.grey.shade600,
                                    ),
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
                                    content: Text(enabled
                                        ? 'Modo Simulador Activo: Dispositivo BioScan-Demo listo para pruebas'
                                        : 'Modo Simulador Desactivado: Cambiando a hardware Bluetooth real'),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
