import 'package:flutter/foundation.dart';
import '../database/dao/ganadero_dao.dart';
import '../models/ganadero.dart';

abstract class GanaderoRepository {
  Future<List<Ganadero>> getGanaderos();
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
    debugPrint('[GANADERO REPOSITORY] Eliminando ganadero ID: $id');
    await _ganaderoDao.delete(id);
  }
}
