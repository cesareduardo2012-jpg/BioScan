import 'package:flutter/foundation.dart';
import '../database/dao/ganadero_dao.dart';
import '../models/ganadero.dart';
import '../utils/supabase_config.dart';

abstract class GanaderoRepository {
  Future<List<Ganadero>> getGanaderos();
  Future<List<Ganadero>> getUnsynced();
  Future<Ganadero?> getGanaderoById(String id);
  Future<List<Ganadero>> getGanaderosByCliente(String clienteId);
  Future<void> insertGanadero(Ganadero ganadero);
  Future<void> updateGanadero(Ganadero ganadero);
  Future<void> deleteGanadero(String id);
}

class GanaderoRepositoryImpl implements GanaderoRepository {
  final GanaderoDao _ganaderoDao;

  GanaderoRepositoryImpl(this._ganaderoDao);

  @override
  Future<List<Ganadero>> getGanaderos() => _ganaderoDao.getAll();

  @override
  Future<List<Ganadero>> getUnsynced() => _ganaderoDao.getUnsynced();

  @override
  Future<Ganadero?> getGanaderoById(String id) => _ganaderoDao.getById(id);

  @override
  Future<List<Ganadero>> getGanaderosByCliente(String clienteId) => _ganaderoDao.getByClienteId(clienteId);

  @override
  Future<void> insertGanadero(Ganadero ganadero) async {
    debugPrint('[GANADERO REPOSITORY] Intentando insertar ganadero:');
    debugPrint('  ID: ${ganadero.id}');
    debugPrint('  clienteId: ${ganadero.clienteId}');
    debugPrint('  nombreCompleto: ${ganadero.nombreCompleto}');
    await _ganaderoDao.insert(ganadero);
    debugPrint('[GANADERO REPOSITORY] Método insertGanadero en DAO finalizado con éxito.');
  }

  @override
  Future<void> updateGanadero(Ganadero ganadero) async {
    debugPrint('[GANADERO REPOSITORY] Actualizando ganadero ID: ${ganadero.id}');
    await _ganaderoDao.update(ganadero);
  }

  @override
  Future<void> deleteGanadero(String id) async {
    debugPrint('[GANADERO REPOSITORY] Eliminando ganadero (Soft Delete) ID: $id');
    
    // 1. Obtener el ganadero local
    final ganadero = await _ganaderoDao.getById(id);
    if (ganadero == null) {
      debugPrint('[GANADERO REPOSITORY] El ganadero $id no existe localmente.');
      return;
    }

    // 2. Marcar como inactivo
    final deletedGanadero = ganadero.copyWith(
      activo: false,
      sincronizado: false,
    );

    // 3. Actualizar en Supabase si hay red
    if (SupabaseConfig.isInitialized) {
      try {
        final payload = deletedGanadero.toSupabaseMap();
        await SupabaseConfig.client.from('ganaderos').upsert(payload, onConflict: 'id');
        
        // Si se actualizó en Supabase, lo marcamos como sincronizado
        final syncedDeletedGanadero = deletedGanadero.copyWith(sincronizado: true);
        await _ganaderoDao.update(syncedDeletedGanadero);
        debugPrint('[GANADERO REPOSITORY] Soft delete en Supabase exitoso.');
        return;
      } catch (e) {
        debugPrint('[GANADERO REPOSITORY] Aviso: No se pudo hacer soft delete en Supabase: $e');
      }
    }
    
    // 4. Si falló Supabase o no hay red, actualizar solo en SQLite para que la sincronización lo suba después
    await _ganaderoDao.update(deletedGanadero);
  }
}
