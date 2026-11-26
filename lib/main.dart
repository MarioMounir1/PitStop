import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pitstop/app.dart';
import 'package:pitstop/core/services/push_notification_service.dart';
import 'package:pitstop/injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely (Android/iOS use google-services.json / Info.plist).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase.initializeApp skipped: $e');
  }

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
  // Initialize FCM push notifications in background without blocking first frame.
  sl<PushNotificationService>().initialize();

  runApp(const PitStopApp());
}
