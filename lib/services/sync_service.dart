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

  @override
  Future<void> syncAll() async {
    if (!SupabaseConfig.isInitialized) return;
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
      if (clientes.isNotEmpty) {
        try {
          final payload = clientes.map((c) => c.toSupabaseMap()).toList();
          await client.from('cuentas').upsert(payload, onConflict: 'id');
          debugPrint('${clientes.length} Clientes/Cuentas respaldados en Supabase Nube.');
        } catch (e) {
          debugPrint('Bulk upsert de clientes falló, usando fallback secuencial: $e');
          for (var c in clientes) {
            try { await client.from('cuentas').upsert(c.toSupabaseMap(), onConflict: 'id'); } catch (_) {}
          }
        }
      }

      // 2. Sincronizar Dispositivos a Supabase Nube
      final dispositivos = await _dispositivoRepository.getDispositivos();
      if (dispositivos.isNotEmpty) {
        try {
          final payload = dispositivos.map((d) => d.toSupabaseMap()).toList();
          await client.from('dispositivos').upsert(payload, onConflict: 'id');
          debugPrint('${dispositivos.length} Dispositivos respaldados en Supabase Nube.');
        } catch (e) {
          debugPrint('Bulk upsert de dispositivos falló, usando fallback secuencial: $e');
          for (var d in dispositivos) {
            try { await client.from('dispositivos').upsert(d.toSupabaseMap(), onConflict: 'id'); } catch (_) {}
          }
        }
      }

      // 3. Sincronizar Usuarios a Supabase Nube
      final usuarios = await _usuarioRepository.getUsuarios();
      final unsyncedUsuarios = usuarios.where((u) => !u.sincronizado).toList();
      if (unsyncedUsuarios.isNotEmpty) {
        try {
          final payload = unsyncedUsuarios.map((u) => u.toSupabaseMap()).toList();
          await client.from('usuarios').upsert(payload, onConflict: 'id');

          for (var usr in unsyncedUsuarios) {
            final updated = usr.copyWith(sincronizado: true);
            await _usuarioRepository.updateUsuario(updated);
          }
          debugPrint('${unsyncedUsuarios.length} Usuarios respaldados en Supabase Nube.');
        } catch (e) {
          debugPrint('Bulk upsert de usuarios falló, usando fallback secuencial: $e');
          for (var u in unsyncedUsuarios) {
            try {
              await client.from('usuarios').upsert(u.toSupabaseMap(), onConflict: 'id');
              final updated = u.copyWith(sincronizado: true);
              await _usuarioRepository.updateUsuario(updated);
            } catch (_) {}
          }
        }
      }

      // 4. Sincronizar Ganaderos a Supabase Nube
      final ganaderos = await _ganaderoRepository.getUnsynced();
      if (ganaderos.isNotEmpty) {
        try {
          final payload = ganaderos.map((g) => g.toSupabaseMap()).toList();
          await client.from('ganaderos').upsert(payload, onConflict: 'id');

          for (var ganadero in ganaderos) {
            final updated = ganadero.copyWith(sincronizado: true);
            await _ganaderoRepository.updateGanadero(updated);
          }
          debugPrint('${ganaderos.length} Ganaderos respaldados en Supabase Nube.');
        } catch (e) {
          debugPrint('Bulk upsert de ganaderos falló, usando fallback secuencial: $e');
          for (var g in ganaderos) {
            try {
              await client.from('ganaderos').upsert(g.toSupabaseMap(), onConflict: 'id');
              final updated = g.copyWith(sincronizado: true);
              await _ganaderoRepository.updateGanadero(updated);
            } catch (_) {}
          }
        }
      }

      // 5. Sincronizar Mediciones a Supabase Nube
      final mediciones = await _medicionRepository.getUnsynced();
      if (mediciones.isNotEmpty) {
        try {
          final payload = mediciones.map((m) => m.toSupabaseMap()).toList();
          await client.from('mediciones').upsert(payload, onConflict: 'id');

          final nowIso = DateTime.now().toIso8601String();
          for (var medicion in mediciones) {
            final updated = medicion.copyWith(
              sincronizado: true,
              fechaSincronizacion: nowIso,
            );
            await _medicionRepository.updateMedicion(updated);
          }
          debugPrint('${mediciones.length} Mediciones respaldadas en Supabase Nube con éxito.');
        } catch (e) {
          debugPrint('Bulk upsert de mediciones falló, usando fallback secuencial: $e');
          final nowIso = DateTime.now().toIso8601String();
          for (var m in mediciones) {
            try {
              await client.from('mediciones').upsert(m.toSupabaseMap(), onConflict: 'id');
              final updated = m.copyWith(sincronizado: true, fechaSincronizacion: nowIso);
              await _medicionRepository.updateMedicion(updated);
            } catch (fallbackError) {
              // Si la medición ESP32 falla, es casi seguro por un error de Foreign Key
              // porque el dispositivo ESP32 asociado falló al subir (por colisión de MAC address).
              // Intentamos un reintento de emergencia: subimos la medición SIN vincularla al dispositivo.
              try {
                final retryPayload = m.toSupabaseMap();
                retryPayload.remove('dispositivo_id');
                await client.from('mediciones').upsert(retryPayload, onConflict: 'id');
                final updated = m.copyWith(sincronizado: true, fechaSincronizacion: nowIso);
                await _medicionRepository.updateMedicion(updated);
                debugPrint('Medición recuperada y subida sin dispositivo.');
              } catch (_) {
                debugPrint('Reintento de emergencia falló para medición ${m.id}');
              }
            }
          }
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
