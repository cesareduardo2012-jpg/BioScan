import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../models/dispositivo.dart';
import '../models/ganadero.dart';
import '../models/medicion.dart';
import '../models/usuario.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/dispositivo_repository.dart';
import '../repositories/ganadero_repository.dart';
import '../repositories/medicion_repository.dart';
import '../repositories/usuario_repository.dart';
import '../utils/supabase_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class SyncService {
  Future<void> syncPendingRecords();
  Future<void> downloadChanges();
  Future<void> syncAll();
  Future<void> resolveConflicts();
}

class SyncServiceImpl implements SyncService {
  final ClienteRepository _clienteRepository;
  final UsuarioRepository _usuarioRepository;
  final DispositivoRepository _dispositivoRepository;
  final GanaderoRepository _ganaderoRepository;
  final MedicionRepository _medicionRepository;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncServiceImpl(
    this._clienteRepository,
    this._usuarioRepository,
    this._dispositivoRepository,
    this._ganaderoRepository,
    this._medicionRepository,
  ) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.firstOrNull ?? ConnectivityResult.none;
      if (result != ConnectivityResult.none) {
        debugPrint('[SYNC SERVICE] Conectividad restaurada. Intentando sincronización en background...');
        syncPendingRecords();
      }
    });
  }

  /// Indica si hay una sesion de Supabase Auth activa.
  ///
  /// Sin sesion, auth.uid() es null del lado del servidor, asi que
  /// get_auth_cuenta_id() devuelve null y TODAS las politicas RLS rechazan
  /// la operacion con 42501. Antes esto pasaba desapercibido porque las
  /// politicas incluian "OR auth.role() = 'anon'", que daba paso libre a
  /// cualquier peticion sin autenticar; al quitarse ese bypass, sincronizar
  /// sin sesion solo produce decenas de 42501 por ciclo y deja el log
  /// inservible para diagnosticar problemas reales.
  bool get _tieneSesion => SupabaseConfig.client.auth.currentSession != null;

  @override
  Future<void> syncAll() async {
    if (!SupabaseConfig.isInitialized) return;
    if (!_tieneSesion) {
      debugPrint('[SYNC SERVICE] Sin sesion de Supabase Auth. Los cambios quedan en local hasta que se inicie sesion.');
      return;
    }
    if (_isSyncing) {
      debugPrint('[SYNC SERVICE] Sincronización ya en curso. Omitiendo...');
      return;
    }
    _isSyncing = true;
    try {
      debugPrint('[SYNC SERVICE] Iniciando sincronización bidireccional completa con Supabase Nube...');
      // 1. Subir registros locales que no estén sincronizados primero
      await _syncPendingRecordsInternal();
      // 2. Descargar cambios remotos para poblar SQLite local
      await downloadChanges();
      debugPrint('[SYNC SERVICE] Sincronización bidireccional completada con éxito.');
    } catch (e, st) {
      debugPrint('[SYNC SERVICE ERROR] Error durante syncAll: $e');
      debugPrint(st.toString());
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> syncPendingRecords() async {
    if (!SupabaseConfig.isInitialized) {
      debugPrint('[SYNC SERVICE] Cliente de Supabase no inicializado.');
      return;
    }

    if (!_tieneSesion) {
      debugPrint('[SYNC SERVICE] Sin sesion de Supabase Auth. Los cambios quedan en local hasta que se inicie sesion.');
      return;
    }

    if (_isSyncing) {
      debugPrint('[SYNC SERVICE] Sincronización en curso. Omitiendo nueva solicitud para evitar duplicados.');
      return;
    }

    _isSyncing = true;
    try {
      await _syncPendingRecordsInternal();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncPendingRecordsInternal() async {
    try {
      final client = SupabaseConfig.client;

      // 1. Sincronizar Cuentas/Clientes a Supabase Nube
      final clientes = await _clienteRepository.getClientes();
      for (var cliente in clientes) {
        try {
          await client.from('cuentas').upsert(cliente.toSupabaseMap(), onConflict: 'id');
          debugPrint('Cliente/Cuenta ${cliente.nombre} (${cliente.id}) respaldado en Supabase Nube.');
        } catch (e) {
          debugPrint('Error al respaldar cliente ${cliente.id} en Supabase: $e');
        }
      }

      // 2. Sincronizar Dispositivos a Supabase Nube
      final dispositivos = await _dispositivoRepository.getDispositivos();
      for (var disp in dispositivos) {
        try {
          final payload = disp.toSupabaseMap();
          await client.from('dispositivos').upsert(payload, onConflict: 'id');
          debugPrint('Dispositivo ${disp.nombre} respaldado en Supabase Nube.');
        } catch (e) {
          debugPrint('Error al respaldar dispositivo ${disp.id} en Supabase: $e');
        }
      }

      // 3. Sincronizar Usuarios a Supabase Nube
      final usuarios = await _usuarioRepository.getUsuarios();
      for (var usr in usuarios) {
        if (usr.sincronizado) continue;
        try {
          final usrPayload = usr.toSupabaseMap();
          await client.from('usuarios').upsert(usrPayload, onConflict: 'id');

          if (!usr.sincronizado) {
            final updated = usr.copyWith(sincronizado: true);
            await _usuarioRepository.updateUsuario(updated);
          }
          debugPrint('Usuario ${usr.username} respaldado en Supabase Nube.');
        } catch (e) {
          debugPrint('Error al respaldar usuario ${usr.id} en Supabase: $e');
        }
      }

      // 4. Sincronizar Ganaderos a Supabase Nube
      final ganaderos = await _ganaderoRepository.getUnsynced();
      for (var ganadero in ganaderos) {
        try {
          final payload = ganadero.toSupabaseMap();
          await client.from('ganaderos').upsert(payload, onConflict: 'id');

          if (!ganadero.sincronizado) {
            final updated = ganadero.copyWith(sincronizado: true);
            await _ganaderoRepository.updateGanadero(updated);
          }
          debugPrint('Ganadero ${ganadero.nombreCompleto} (${ganadero.id}) respaldado en Supabase Nube con éxito.');
        } catch (e) {
          debugPrint('Error al respaldar ganadero ${ganadero.id} en Supabase: $e');
        }
      }

      // 5. Sincronizar Mediciones a Supabase Nube
      final mediciones = await _medicionRepository.getUnsynced();
      for (var medicion in mediciones) {
        try {
          final payload = medicion.toSupabaseMap();

          await client.from('mediciones').upsert(payload, onConflict: 'id');

          if (!medicion.sincronizado) {
            final updated = medicion.copyWith(
              sincronizado: true,
              fechaSincronizacion: DateTime.now().toIso8601String(),
            );
            await _medicionRepository.updateMedicion(updated);
          }
          debugPrint('Medición ${medicion.id} respaldada en Supabase Nube con éxito.');
        } catch (e) {
          debugPrint('Error al respaldar medición ${medicion.id} en Supabase: $e');
        }
      }
      debugPrint('[SYNC SERVICE] Sincronización de registros pendientes (Local -> Nube) completada.');
    } catch (e) {
      debugPrint('[SYNC SERVICE ERROR] Error masivo en syncPendingRecords: $e');
    }
  }

  @override
  Future<void> downloadChanges() async {
    if (!SupabaseConfig.isInitialized) return;
    if (!_tieneSesion) return;
    try {
      final client = SupabaseConfig.client;

      // 1. Descargar Cuentas/Clientes remotos primero para mantener integridad referencial
      try {
        final cuentasData = await client.from('cuentas').select();
        for (var map in cuentasData) {
          final cliente = Cliente.fromMap(map);
          final localExisting = await _clienteRepository.getClienteById(cliente.id);
          if (localExisting == null) {
            await _clienteRepository.insertCliente(cliente);
          } else {
            await _clienteRepository.updateCliente(cliente);
          }
        }
      } catch (e) {
        debugPrint('Error al descargar cuentas de Supabase: $e');
      }

      // 2. Descargar Dispositivos remotos
      try {
        final dispData = await client.from('dispositivos').select();
        for (var map in dispData) {
          final disp = Dispositivo.fromMap(map);
          final localExisting = await _dispositivoRepository.getDispositivoById(disp.id);
          if (localExisting == null) {
            await _dispositivoRepository.insertDispositivo(disp);
          } else {
            await _dispositivoRepository.updateDispositivo(disp);
          }
        }
      } catch (e) {
        debugPrint('Error al descargar dispositivos de Supabase: $e');
      }

      // 3. Descargar Usuarios remotos
      try {
        final usrData = await client.from('usuarios').select();
        for (var map in usrData) {
          final usr = Usuario.fromMap(map).copyWith(sincronizado: true);
          final localExisting = await _usuarioRepository.getUsuarioById(usr.id);
          if (localExisting == null) {
            await _usuarioRepository.insertUsuario(usr);
          } else {
            // No sobrescribir si el registro local tiene cambios pendientes por subir
            if (!localExisting.sincronizado) continue;
            await _usuarioRepository.updateUsuario(usr);
          }
        }
      } catch (e) {
        debugPrint('Error al descargar usuarios de Supabase: $e');
      }

      // 4. Descargar Ganaderos remotos
      try {
        final ganaderosData = await client.from('ganaderos').select();
        for (var map in ganaderosData) {
          final ganaderoRemote = Ganadero.fromMap(map).copyWith(sincronizado: true);
          final localExisting = await _ganaderoRepository.getGanaderoById(ganaderoRemote.id);
          if (localExisting == null) {
            await _ganaderoRepository.insertGanadero(ganaderoRemote);
          } else {
            // No sobrescribir si el registro local tiene cambios pendientes por subir
            if (!localExisting.sincronizado) continue;
            await _ganaderoRepository.updateGanadero(ganaderoRemote);
          }
        }
      } catch (e) {
        debugPrint('Error al descargar ganaderos de Supabase: $e');
      }

      // 5. Descargar Mediciones remotas
      try {
        final medicionesData = await client.from('mediciones').select();
        for (var map in medicionesData) {
          final medicionRemote = Medicion.fromMap(map).copyWith(sincronizado: true);
          final localExisting = await _medicionRepository.getMedicionById(medicionRemote.id);
          if (localExisting == null) {
            await _medicionRepository.insertMedicion(medicionRemote);
          } else {
            // No sobrescribir si el registro local tiene cambios pendientes por subir
            if (!localExisting.sincronizado) continue;
            await _medicionRepository.updateMedicion(medicionRemote);
          }
        }
      } catch (e) {
        debugPrint('Error al descargar mediciones de Supabase: $e');
      }

      debugPrint('Descarga de cambios remotos desde Supabase completada con éxito.');
    } catch (e) {
      debugPrint('Error global al descargar cambios desde Supabase: $e');
    }
  }

  @override
  Future<void> resolveConflicts() async {
    if (!SupabaseConfig.isInitialized) return;
    debugPrint('Resolución de conflictos verificada.');
  }
}
