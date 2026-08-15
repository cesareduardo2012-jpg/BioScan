import '../database/dao/medicion_dao.dart';
import '../models/medicion.dart';

abstract class MedicionRepository {
  Future<List<Medicion>> getMediciones();
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
  Future<List<Medicion>> getMedicionesByCliente(String clienteId) => _medicionDao.getByClienteId(clienteId);

  @override
  Future<List<Medicion>> getMedicionesByGanadero(String ganaderoId) => _medicionDao.getByGanaderoId(ganaderoId);

  @override
  Future<void> insertMedicion(Medicion medicion) => _medicionDao.insert(medicion);

  @override
  Future<void> updateMedicion(Medicion medicion) => _medicionDao.update(medicion);

  @override
  Future<void> deleteMedicion(String id) => _medicionDao.delete(id);
}
