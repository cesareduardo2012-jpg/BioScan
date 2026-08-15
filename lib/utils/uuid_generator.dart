import 'package:uuid/uuid.dart';

class UuidGenerator {
  UuidGenerator._();

  static const _uuid = Uuid();

  static String generate() {
    return _uuid.v4();
  }
}
