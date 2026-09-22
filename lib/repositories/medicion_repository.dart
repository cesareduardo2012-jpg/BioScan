import '../database/dao/medicion_dao.dart';
import '../models/medicion.dart';
import '../utils/supabase_config.dart';
import 'package:flutter/foundation.dart';

abstract class MedicionRepository {
  Future<List<Medicion>> getMediciones();
  Future<List<Medicion>> getUnsynced();
  Future<Medicion?> getMedicionById(String id);
  Future<List<Medicion>> getMedicionesByCliente(String clienteId);
  Future<List<Medicion>> getMedicionesByGanadero(String ganaderoId);
  Future<void> insertMedicion(Medicion medicion);
  Future<void> updateMedicion(Medicion medicion);
  Future<void> deleteMedicion(String id);
}

class MedicionRepositoryImpl implements MedicionRepository {
  final MedicionDao _medicionDao;

  MedicionRepositoryImpl(this._medicionDao);

  @override
  Future<List<Medicion>> getMediciones() => _medicionDao.getAll();

  @override
  Future<List<Medicion>> getUnsynced() => _medicionDao.getUnsynced();

  @override
  Future<Medicion?> getMedicionById(String id) => _medicionDao.getById(id);

  @override
  Future<List<Medicion>> getMedicionesByCliente(String clienteId) => _medicionDao.getByClienteId(clienteId);

  @override
  Future<List<Medicion>> getMedicionesByGanadero(String ganaderoId) => _medicionDao.getByGanaderoId(ganaderoId);

  @override
  Future<void> insertMedicion(Medicion medicion) => _medicionDao.insert(medicion);

  @override
  Future<void> updateMedicion(Medicion medicion) => _medicionDao.update(medicion);

  @override
  Future<void> deleteMedicion(String id) async {
    debugPrint('[MEDICION REPOSITORY] Eliminando medicion ID: $id');
    if (SupabaseConfig.isInitialized) {
      try {
        await SupabaseConfig.client.from('mediciones').delete().eq('id', id);
        debugPrint('[MEDICION REPOSITORY] Eliminado de Supabase exitosamente.');
      } catch (e) {
        debugPrint('[MEDICION REPOSITORY] Aviso: No se pudo eliminar de Supabase: $e');
      }
    }
    await _medicionDao.delete(id);
  }
}
