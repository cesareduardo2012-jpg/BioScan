import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ganadero.dart';
import '../models/medicion.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  late Directory _appDir;
  late File _ganaderosFile;
  late File _medicionesFile;

  Future<void> init() async {
    Directory directory;

    try {
      directory = await getApplicationDocumentsDirectory();
    } on MissingPluginException {
      directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
    } catch (e, stackTrace) {
      debugPrint('Error al inicializar directorio de documentos: $e');
      debugPrint(stackTrace.toString());
      directory = Directory(p.join(Directory.current.path, '.bioscan_data'));
    }

    try {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      _appDir = directory;
      _ganaderosFile = File(p.join(_appDir.path, 'ganaderos.json'));
      _medicionesFile = File(p.join(_appDir.path, 'mediciones.json'));

      if (!await _ganaderosFile.exists()) {
        await _ganaderosFile.writeAsString('[]');
      }
      if (!await _medicionesFile.exists()) {
        await _medicionesFile.writeAsString('[]');
      }
    } catch (e, stackTrace) {
      debugPrint('Error al crear los archivos de base de datos: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> resetStorage() async {
    try {
      await _ganaderosFile.writeAsString('[]');
      await _medicionesFile.writeAsString('[]');
    } catch (e, stackTrace) {
      debugPrint('Error al resetear almacenamiento: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<List<Ganadero>> getGanaderos() async {
    try {
      final raw = await _ganaderosFile.readAsString();
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((item) => Ganadero.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } catch (e, stackTrace) {
      debugPrint('Error al leer ganaderos: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  Future<List<Medicion>> getMediciones() async {
    try {
      final raw = await _medicionesFile.readAsString();
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((item) => Medicion.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    } catch (e, stackTrace) {
      debugPrint('Error al leer mediciones: $e');
      debugPrint(stackTrace.toString());
      return [];
    }
  }

  Future<void> insertGanadero(Ganadero ganadero) async {
    try {
      final existing = await getGanaderos();
      final updated = [...existing, ganadero];
      await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
    } catch (e, stackTrace) {
      debugPrint('Error al insertar ganadero: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> insertMedicion({
    required String ganaderoId,
    required String ph,
    required String agua,
    required String temperatura,
  }) async {
    try {
      final medicion = Medicion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ganaderoId: ganaderoId,
        ph: ph,
        agua: agua,
        temperatura: temperatura,
        fecha: DateTime.now().toIso8601String(),
      );
      final existing = await getMediciones();
      final updated = [medicion, ...existing];
      await _medicionesFile.writeAsString(jsonEncode(updated.map((item) => {
        'id': item.id,
        'ganaderoId': item.ganaderoId,
        'ph': item.ph,
        'agua': item.agua,
        'temperatura': item.temperatura,
        'fecha': item.fecha,
      }).toList()));
    } catch (e, stackTrace) {
      debugPrint('Error al insertar medición: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> updateGanadero(Ganadero ganadero) async {
    try {
      final existing = await getGanaderos();
      final updated = existing.map((item) => item.id == ganadero.id ? ganadero : item).toList();
      await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
    } catch (e, stackTrace) {
      debugPrint('Error al actualizar ganadero: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> deleteGanadero(String id) async {
    try {
      final existing = await getGanaderos();
      final updated = existing.where((item) => item.id != id).toList();
      await _ganaderosFile.writeAsString(jsonEncode(updated.map((item) => item.toMap()).toList()));
    } catch (e, stackTrace) {
      debugPrint('Error al eliminar ganadero: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }
}
