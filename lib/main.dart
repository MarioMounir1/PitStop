import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torq/app.dart';
import 'package:torq/injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15 edge-to-edge system chrome configuration.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  await initDependencies();

  runApp(const TorqApp());
}
