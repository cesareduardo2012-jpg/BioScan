import 'package:flutter/foundation.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/dispositivo_repository.dart';
import '../repositories/ganadero_repository.dart';
import '../repositories/medicion_repository.dart';
import '../repositories/usuario_repository.dart';

abstract class SyncService {
  Future<void> syncPendingRecords();
  Future<void> downloadChanges();
  Future<void> resolveConflicts();
}

class SyncServiceImpl implements SyncService {
  final ClienteRepository _clienteRepository;
  final UsuarioRepository _usuarioRepository;
  final DispositivoRepository _dispositivoRepository;
  final GanaderoRepository _ganaderoRepository;
  final MedicionRepository _medicionRepository;

  SyncServiceImpl(
    this._clienteRepository,
    this._usuarioRepository,
    this._dispositivoRepository,
    this._ganaderoRepository,
    this._medicionRepository,
  );

  @override
  Future<void> syncPendingRecords() async {
    final clientes = await _clienteRepository.getClientes();
    final usuarios = await _usuarioRepository.getUsuarios();
    final dispositivos = await _dispositivoRepository.getDispositivos();
    final ganaderos = await _ganaderoRepository.getGanaderos();
    final mediciones = await _medicionRepository.getMediciones();

    final pendingGanaderos = ganaderos.where((g) => !g.sincronizado).toList();
    final pendingMediciones = mediciones.where((m) => !m.sincronizado).toList();

    debugPrint(
      'Sincronización: detectados ${clientes.length} clientes, ${usuarios.length} usuarios, ${dispositivos.length} dispositivos, ${pendingGanaderos.length} ganaderos pendientes y ${pendingMediciones.length} mediciones pendientes.',
    );
  }

  @override
  Future<void> downloadChanges() async {
    // TODO: Implementar descarga de cambios desde Supabase
  }

  @override
  Future<void> resolveConflicts() async {
    // TODO: Implementar resolución de conflictos
  }
}
