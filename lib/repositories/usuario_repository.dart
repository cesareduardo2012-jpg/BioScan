import '../database/dao/usuario_dao.dart';
import '../models/usuario.dart';

abstract class UsuarioRepository {
  Future<List<Usuario>> getUsuarios();
  Future<List<Usuario>> getUsuariosByCliente(String clienteId);
  Future<Usuario?> getUsuarioById(String id);
  Future<Usuario?> getUsuarioByUsername(String username);
  Future<Usuario?> getOperatorByCliente(String clienteId);
  Future<Usuario?> getAdminByCliente(String clienteId);
  Future<void> insertUsuario(Usuario usuario);
  Future<void> updateUsuario(Usuario usuario);
  Future<void> deleteUsuario(String id);
  Future<void> hardDeleteUsuario(String id);
}

class UsuarioRepositoryImpl implements UsuarioRepository {
  final UsuarioDao _usuarioDao;

  UsuarioRepositoryImpl(this._usuarioDao);

  @override
  Future<List<Usuario>> getUsuarios() => _usuarioDao.getAll();

  @override
  Future<List<Usuario>> getUsuariosByCliente(String clienteId) => _usuarioDao.getByClienteId(clienteId);

  @override
  Future<Usuario?> getUsuarioById(String id) => _usuarioDao.getById(id);

  @override
  Future<Usuario?> getUsuarioByUsername(String username) => _usuarioDao.getByUsername(username);

  @override
  Future<Usuario?> getOperatorByCliente(String clienteId) => _usuarioDao.getOperatorByClienteId(clienteId);

  @override
  Future<Usuario?> getAdminByCliente(String clienteId) => _usuarioDao.getAdminByClienteId(clienteId);

  @override
  Future<void> insertUsuario(Usuario usuario) => _usuarioDao.insert(usuario);

  @override
  Future<void> updateUsuario(Usuario usuario) => _usuarioDao.update(usuario);

  @override
  Future<void> deleteUsuario(String id) => _usuarioDao.delete(id);

  @override
  Future<void> hardDeleteUsuario(String id) => _usuarioDao.hardDelete(id);
}
