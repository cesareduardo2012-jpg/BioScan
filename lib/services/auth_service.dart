import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/dao/usuario_dao.dart';

import '../database/migrations/database_migrator.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';
import '../utils/password_hasher.dart';
import '../utils/uuid_generator.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  final UsuarioRepository _usuarioRepository;
  Usuario? _currentUser;
  bool _initialized = false;

  AuthService(this._usuarioRepository);

  Usuario? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isOperador => _currentUser?.isOperador ?? false;
  String get activeClienteId => _currentUser?.clienteId ?? DatabaseMigrator.defaultClienteId;

  static const String _prefUserIdKey = 'bioscan_auth_user_id';
  static const String _prefClienteIdKey = 'bioscan_auth_cliente_id';

  Future<void> init() async {
    if (_initialized) return;

    // 1. Asegurar la existencia del Administrador inicial si la base de datos está vacía de administradores
    await ensureDefaultAdmin();

    // 2. Intentar restaurar sesión activa desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString(_prefUserIdKey);

    if (savedUserId != null && savedUserId.isNotEmpty) {
      final user = await _usuarioRepository.getUsuarioById(savedUserId);
      if (user != null && user.activo) {
        _currentUser = user;
      } else {
        await prefs.remove(_prefUserIdKey);
        await prefs.remove(_prefClienteIdKey);
      }
    }

    _initialized = true;
    notifyListeners();
  }

  /// Provisión segura del Administrador inicial sin credenciales hardcodeadas en vistas.
  Future<void> ensureDefaultAdmin() async {
    const defaultClienteId = DatabaseMigrator.defaultClienteId;
    final adminUser = await _usuarioRepository.getAdminByCliente(defaultClienteId);

    if (adminUser == null) {
      const initialUsername = 'admin';
      const initialRawPassword = 'admin123';
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hashPassword(initialRawPassword, salt);

      final newAdmin = Usuario(
        id: 'usr-admin-default-001',
        clienteId: defaultClienteId,
        username: initialUsername,
        nombre: 'Administrador BioScan',
        correo: 'admin@bioscan.com',
        passwordHash: hash,
        salt: salt,
        rol: 'ADMINISTRADOR',
        fechaRegistro: DateTime.now().toIso8601String(),
        activo: true,
      );

      await _usuarioRepository.insertUsuario(newAdmin);
      debugPrint('Administrador inicial provisionado con éxito (Username: $initialUsername).');
    }
  }

  /// Inicia sesión validando credenciales y estado del usuario.
  Future<Usuario> login(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.trim().isEmpty) {
      throw AuthException('Por favor ingrese su usuario y contraseña.');
    }

    Usuario? user;
    try {
      user = await _usuarioRepository.getUsuarioByUsername(cleanUsername);
    } catch (e) {
      debugPrint('Error al consultar usuario en login: $e');
      throw AuthException('Ocurrió un error al verificar las credenciales. Intente nuevamente.');
    }

    if (user == null) {
      throw AuthException('Usuario o contraseña incorrectos.');
    }

    if (!user.activo) {
      throw AuthException('El usuario ingresado se encuentra desactivado. Contacte a su administrador.');
    }

    // Si el usuario legados no tiene password_hash o salt, migrar en el primer login
    if (user.passwordHash.isEmpty || user.salt.isEmpty) {
      final newSalt = PasswordHasher.generateSalt();
      final newHash = PasswordHasher.hashPassword(password, newSalt);
      user = user.copyWith(passwordHash: newHash, salt: newSalt);
      await _usuarioRepository.updateUsuario(user);
    } else {
      final isValidPassword = PasswordHasher.verifyPassword(password, user.salt, user.passwordHash);
      if (!isValidPassword) {
        throw AuthException('Usuario o contraseña incorrectos.');
      }
    }

    // Actualizar último acceso
    final nowIso = DateTime.now().toIso8601String();
    final updatedUser = user.copyWith(ultimoAcceso: nowIso);
    await _usuarioRepository.updateUsuario(updatedUser);

    // Guardar sesión
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserIdKey, updatedUser.id);
    await prefs.setString(_prefClienteIdKey, updatedUser.clienteId);

    _currentUser = updatedUser;
    notifyListeners();
    return updatedUser;
  }

  /// Cierra la sesión activa y limpia la persistencia local.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUserIdKey);
    await prefs.remove(_prefClienteIdKey);
    _currentUser = null;
    notifyListeners();
  }

  /// Permite al Administrador crear el único usuario Operador permitido por cuenta.
  Future<Usuario> createOperator({
    required String username,
    required String nombre,
    required String password,
    String? correo,
  }) async {
    if (!isAdmin) {
      throw AuthException('Acceso denegado. Solamente el Administrador puede crear usuarios.');
    }

    final clienteId = activeClienteId;

    // Verificar si ya existe un operador registrado para la cuenta
    final existingOperator = await _usuarioRepository.getOperatorByCliente(clienteId);
    if (existingOperator != null) {
      throw OperatorLimitExceededException('Esta cuenta BioScan ya cuenta con 1 usuario Operador (${existingOperator.username}). No es posible crear operadores adicionales.');
    }

    final cleanUsername = username.trim().toLowerCase();
    final existingUsername = await _usuarioRepository.getUsuarioByUsername(cleanUsername);
    if (existingUsername != null) {
      throw AuthException('El nombre de usuario "$cleanUsername" ya se encuentra registrado. Elija otro.');
    }

    final salt = PasswordHasher.generateSalt();
    final passwordHash = PasswordHasher.hashPassword(password, salt);

    final newOperator = Usuario(
      id: UuidGenerator.generate(),
      clienteId: clienteId,
      username: cleanUsername,
      nombre: nombre.trim(),
      correo: (correo ?? '').trim().isEmpty ? '$cleanUsername@bioscan.local' : correo!.trim(),
      passwordHash: passwordHash,
      salt: salt,
      rol: 'OPERADOR',
      fechaRegistro: DateTime.now().toIso8601String(),
      activo: true,
    );

    await _usuarioRepository.insertUsuario(newOperator);
    return newOperator;
  }

  /// Actualiza los datos, usuario o contraseña del operador por parte del Administrador.
  Future<void> updateOperator({
    required String operatorId,
    String? username,
    String? nombre,
    String? newPassword,
    bool? activo,
  }) async {
    if (!isAdmin) {
      throw AuthException('Acceso denegado. Solamente el Administrador puede gestionar usuarios.');
    }

    final operatorUser = await _usuarioRepository.getUsuarioById(operatorId);
    if (operatorUser == null) {
      throw AuthException('El operador no fue encontrado.');
    }

    String newUsername = operatorUser.username;
    if (username != null && username.trim().isNotEmpty) {
      final cleanUsername = username.trim().toLowerCase();
      if (cleanUsername != operatorUser.username.toLowerCase()) {
        final existingUser = await _usuarioRepository.getUsuarioByUsername(cleanUsername);
        if (existingUser != null && existingUser.id != operatorId) {
          throw AuthException('El nombre de usuario "$cleanUsername" ya se encuentra en uso por otro usuario.');
        }
        newUsername = cleanUsername;
      }
    }

    String passwordHash = operatorUser.passwordHash;
    String salt = operatorUser.salt;

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      salt = PasswordHasher.generateSalt();
      passwordHash = PasswordHasher.hashPassword(newPassword.trim(), salt);
    }

    final updated = operatorUser.copyWith(
      username: newUsername,
      nombre: nombre?.trim().isNotEmpty == true ? nombre!.trim() : operatorUser.nombre,
      passwordHash: passwordHash,
      salt: salt,
      activo: activo ?? operatorUser.activo,
    );

    await _usuarioRepository.updateUsuario(updated);
  }

  /// Permite al usuario logueado cambiar su propia contraseña.
  Future<void> changeOwnPassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) throw AuthException('No hay una sesión activa.');
    if (newPassword.trim().length < 4) {
      throw AuthException('La nueva contraseña debe contener al menos 4 caracteres.');
    }

    final isValid = PasswordHasher.verifyPassword(currentPassword, _currentUser!.salt, _currentUser!.passwordHash);
    if (!isValid) {
      throw AuthException('La contraseña actual es incorrecta.');
    }

    final newSalt = PasswordHasher.generateSalt();
    final newHash = PasswordHasher.hashPassword(newPassword.trim(), newSalt);

    final updated = _currentUser!.copyWith(
      passwordHash: newHash,
      salt: newSalt,
    );

    await _usuarioRepository.updateUsuario(updated);
    _currentUser = updated;
    notifyListeners();
  }

  /// Permite al Administrador cambiar sus propios datos (nombre, correo).
  Future<void> updateOwnProfile({required String nombre, required String correo}) async {
    if (_currentUser == null) throw AuthException('No hay una sesión activa.');

    final updated = _currentUser!.copyWith(
      nombre: nombre.trim(),
      correo: correo.trim(),
    );

    await _usuarioRepository.updateUsuario(updated);
    _currentUser = updated;
    notifyListeners();
  }
}
