import '../database/app_database.dart';
import '../database/dao/cliente_dao.dart';
import '../database/dao/dispositivo_dao.dart';
import '../database/dao/ganadero_dao.dart';
import '../database/dao/medicion_dao.dart';
import '../database/dao/usuario_dao.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/dispositivo_repository.dart';
import '../repositories/ganadero_repository.dart';
import '../repositories/medicion_repository.dart';
import '../repositories/usuario_repository.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/supabase_config.dart';

class ServiceLocator {
  ServiceLocator._();

  static late AppDatabase database;
  static late ClienteRepository clienteRepository;
  static late UsuarioRepository usuarioRepository;
  static late DispositivoRepository dispositivoRepository;
  static late GanaderoRepository ganaderoRepository;
  static late MedicionRepository medicionRepository;
  static late AuthService authService;
  static late SyncService syncService;

  static Future<void> init() async {
    database = AppDatabase.instance;
    await database.init();

    await SupabaseConfig.init();

    final clienteDao = ClienteDao(database);
    final usuarioDao = UsuarioDao(database);
    final dispositivoDao = DispositivoDao(database);
    final ganaderoDao = GanaderoDao(database);
    final medicionDao = MedicionDao(database);

    clienteRepository = ClienteRepositoryImpl(clienteDao);
    usuarioRepository = UsuarioRepositoryImpl(usuarioDao);
    dispositivoRepository = DispositivoRepositoryImpl(dispositivoDao);
    ganaderoRepository = GanaderoRepositoryImpl(ganaderoDao);
    medicionRepository = MedicionRepositoryImpl(medicionDao);

    authService = AuthService(usuarioRepository);
    await authService.init();

    syncService = SyncServiceImpl(
      clienteRepository,
      usuarioRepository,
      dispositivoRepository,
      ganaderoRepository,
      medicionRepository,
    );
  }
}
