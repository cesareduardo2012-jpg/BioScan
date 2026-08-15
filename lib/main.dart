import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/bluetooth_manager.dart';
import 'utils/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.init();
  BluetoothManager.instance.init();
  runApp(const BioScanApp());
}
