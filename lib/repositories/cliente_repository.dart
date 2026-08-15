import '../database/dao/cliente_dao.dart';
import '../models/cliente.dart';

abstract class ClienteRepository {
  Future<List<Cliente>> getClientes();
  Future<Cliente?> getClienteById(String id);
  Future<void> insertCliente(Cliente cliente);
  Future<void> updateCliente(Cliente cliente);
  Future<void> deleteCliente(String id);
}

class ClienteRepositoryImpl implements ClienteRepository {
  final ClienteDao _clienteDao;

  ClienteRepositoryImpl(this._clienteDao);

  @override
  Future<List<Cliente>> getClientes() => _clienteDao.getAll();

  @override
  Future<Cliente?> getClienteById(String id) => _clienteDao.getById(id);

  @override
  Future<void> insertCliente(Cliente cliente) => _clienteDao.insert(cliente);

  @override
  Future<void> updateCliente(Cliente cliente) => _clienteDao.update(cliente);

  @override
  Future<void> deleteCliente(String id) => _clienteDao.delete(id);
}
