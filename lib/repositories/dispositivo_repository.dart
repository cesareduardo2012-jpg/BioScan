import '../database/dao/dispositivo_dao.dart';
import '../models/dispositivo.dart';

abstract class DispositivoRepository {
  Future<List<Dispositivo>> getDispositivos();
  Future<Dispositivo?> getDispositivoById(String id);
  Future<List<Dispositivo>> getDispositivosByCliente(String clienteId);
  Future<void> insertDispositivo(Dispositivo dispositivo);
  Future<void> updateDispositivo(Dispositivo dispositivo);
  Future<void> deleteDispositivo(String id);
}

class DispositivoRepositoryImpl implements DispositivoRepository {
  final DispositivoDao _dispositivoDao;

  DispositivoRepositoryImpl(this._dispositivoDao);

  @override
  Future<List<Dispositivo>> getDispositivos() => _dispositivoDao.getAll();

  @override
  Future<Dispositivo?> getDispositivoById(String id) => _dispositivoDao.getById(id);

  @override
  Future<List<Dispositivo>> getDispositivosByCliente(String clienteId) => _dispositivoDao.getByClienteId(clienteId);

  @override
  Future<void> insertDispositivo(Dispositivo dispositivo) => _dispositivoDao.insert(dispositivo);

  @override
  Future<void> updateDispositivo(Dispositivo dispositivo) => _dispositivoDao.update(dispositivo);

  @override
  Future<void> deleteDispositivo(String id) => _dispositivoDao.delete(id);
}
