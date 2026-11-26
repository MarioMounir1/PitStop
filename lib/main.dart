import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pitstop/app.dart';
import 'package:pitstop/core/services/push_notification_service.dart';
import 'package:pitstop/core/theme/app_theme.dart';
import 'package:pitstop/core/widgets/pitstop_preload_screen.dart';
import 'package:pitstop/injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15 edge-to-edge system chrome configuration.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const _PitStopBootstrap());
}

class _PitStopBootstrap extends StatefulWidget {
  const _PitStopBootstrap();

  @override
  State<_PitStopBootstrap> createState() => _PitStopBootstrapState();
}

class _PitStopBootstrapState extends State<_PitStopBootstrap> {
  bool _ready = false;
  double _progress = 0.15;
  String _status = 'Starting PitStop...';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();

    _updateProgress(0.35, 'Connecting services...');
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase.initializeApp skipped: $e');
    }

    _updateProgress(0.70, 'Loading your garage...');
    await initDependencies();

    // Initialize FCM push notifications in background without blocking launch.
    sl<PushNotificationService>().initialize();

    _updateProgress(1.0, 'Ready');

    // Keep preload visible briefly so the bar completes smoothly.
    final elapsed = DateTime.now().difference(startedAt);
    const minDuration = Duration(milliseconds: 850);
    if (elapsed < minDuration) {
      await Future<void>.delayed(minDuration - elapsed);
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  void _updateProgress(double value, String label) {
    if (!mounted) return;
    setState(() {
      _progress = value;
      _status = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const PitStopApp();
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: PitStopPreloadScreen(
        progress: _progress,
        statusLabel: _status,
      ),
    );
  }
}
