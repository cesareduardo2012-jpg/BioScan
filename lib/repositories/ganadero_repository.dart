import '../database/dao/ganadero_dao.dart';
import '../models/ganadero.dart';

abstract class GanaderoRepository {
  Future<List<Ganadero>> getGanaderos();
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
  Future<List<Ganadero>> getGanaderosByCliente(String clienteId) => _ganaderoDao.getByClienteId(clienteId);

  @override
  Future<void> insertGanadero(Ganadero ganadero) => _ganaderoDao.insert(ganadero);

  @override
  Future<void> updateGanadero(Ganadero ganadero) => _ganaderoDao.update(ganadero);

  @override
  Future<void> deleteGanadero(String id) => _ganaderoDao.delete(id);
}
