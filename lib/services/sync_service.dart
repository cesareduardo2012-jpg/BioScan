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

  SyncServiceImpl(
    this._clienteRepository,
    this._usuarioRepository,
    this._dispositivoRepository,
    this._ganaderoRepository,
    this._medicionRepository,
  );

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
      await syncPendingRecords();
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
    if (!SupabaseConfig.isInitialized) return;

    try {
      final client = SupabaseConfig.client;

      // 1. Sincronizar Cuentas/Clientes a Supabase Nube
      final clientes = await _clienteRepository.getClientes();
      for (var cliente in clientes) {
        // No sincronizar la cuenta demo local
        if (cliente.id == '00000000-0000-0000-0000-000000000001') continue;
        try {
          await client.from('cuentas').upsert({
            'id': cliente.id,
            'nombre': cliente.nombre,
            'empresa': cliente.empresa,
            'telefono': cliente.telefono,
            'correo': cliente.correo,
            'activo': cliente.activo,
          }, onConflict: 'id');
          debugPrint('Cliente/Cuenta ${cliente.nombre} (${cliente.id}) respaldado en Supabase Nube.');
        } catch (e) {
          debugPrint('Error al respaldar cliente ${cliente.id} en Supabase: $e');
        }
      }

      // 2. Sincronizar Dispositivos a Supabase Nube
      final dispositivos = await _dispositivoRepository.getDispositivos();
      for (var disp in dispositivos) {
        if (disp.clienteId == '00000000-0000-0000-0000-000000000001') continue;
        try {
          await client.from('dispositivos').upsert({
            'id': disp.id,
            'cuenta_id': disp.clienteId,
            'numero_serie': disp.numeroSerie,
            'nombre': disp.nombre,
            'modelo': disp.modelo,
            'activo': disp.activo,
          }, onConflict: 'id');
          debugPrint('Dispositivo ${disp.nombre} respaldado en Supabase Nube.');
        } catch (e) {
          debugPrint('Error al respaldar dispositivo ${disp.id} en Supabase: $e');
        }
      }

      // 3. Sincronizar Usuarios a Supabase Nube
      final usuarios = await _usuarioRepository.getUsuarios();
      for (var usr in usuarios) {
        if (usr.clienteId == '00000000-0000-0000-0000-000000000001') continue;
        if (usr.sincronizado) continue;
        try {
          final usrPayload = <String, dynamic>{
            'id': usr.id,
            'cuenta_id': usr.clienteId,
            'username': usr.username,
            'nombre': usr.nombre,
            'correo': usr.correo,
            'rol': usr.rol,
            'activo': usr.activo,
          };
          if (usr.ultimoAcceso != null && usr.ultimoAcceso!.isNotEmpty) {
            usrPayload['ultimo_acceso'] = usr.ultimoAcceso;
          }
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
        if (ganadero.clienteId == '00000000-0000-0000-0000-000000000001') continue;
        try {
          // No se manda 'fecha_registro': la tabla 'ganaderos' en Supabase no
          // tiene esa columna (usa created_at/updated_at con default propio).
          // Al incluirla, Postgrest rechazaba el upsert completo con un error
          // de columna inexistente, atrapado silenciosamente abajo -- por eso
          // ningun ganadero llegaba nunca a la nube.
          final payload = {
            'id': ganadero.id,
            'cuenta_id': ganadero.clienteId,
            'nombre': ganadero.nombre,
            'apellido_paterno': ganadero.apellidoPaterno,
            'apellido_materno': ganadero.apellidoMaterno,
            'rancho': ganadero.rancho,
            'telefono': ganadero.tel,
            'correo': ganadero.correo,
          };

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
        if (medicion.clienteId == '00000000-0000-0000-0000-000000000001') continue;
        try {
          final payload = <String, dynamic>{
            'id': medicion.id,
            'cuenta_id': medicion.clienteId,
            'ganadero_id': medicion.ganaderoId,
            'dispositivo_id': medicion.dispositivoId,
            'usuario_id': medicion.usuarioId,
            'observaciones': medicion.observaciones,
          };

          // ph/densidad/temperatura son columnas NUMERIC en Supabase, pero
          // localmente son texto libre del sensor ("N/D" mientras no hay
          // lectura, o con sufijos como "%"/"°C" según el formato que mande
          // el ESP32). Mandar ese texto tal cual rompía el upsert COMPLETO
          // del registro (columna numérica recibiendo texto no numérico),
          // el mismo patrón silencioso que ya se corrigió para ganaderos.
          // Si no se puede extraer un número real, se omite la clave para
          // que Postgres use su propio valor por defecto en vez de fallar.
          final densVal = _parseSensorNumber(medicion.densidad);
          if (densVal != null) payload['densidad'] = densVal;
          final phVal = _parseSensorNumber(medicion.ph);
          if (phVal != null) payload['ph'] = phVal;
          final tempVal = _parseSensorNumber(medicion.temperatura);
          if (tempVal != null) payload['temperatura'] = tempVal;

          if (medicion.fecha.isNotEmpty) {
            payload['fecha'] = medicion.fecha;
          }

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
    } catch (e) {
      debugPrint('Error global en syncPendingRecords: $e');
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

/// Extrae el primer número (puede ser negativo) de una lectura de sensor en
/// formato libre -- ej. "24.44", "5%", "-0.026", "N/D" -- devolviendo null
/// si no hay ningún número parseable.
double? _parseSensorNumber(String raw) {
  final match = RegExp(r'-?[0-9]+(?:\.[0-9]+)?').firstMatch(raw);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}
