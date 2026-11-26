import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pitstop/core/services/auth_service.dart';
import 'package:pitstop/core/services/cloud_sync_service.dart';
import 'package:pitstop/core/services/notification_service.dart';

/// Top-level background FCM message handler required by `firebase_messaging`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint(
    'PitStop background push received: ${message.messageId} (${message.notification?.title})',
  );
}

/// Manages Firebase Cloud Messaging (FCM) push notifications:
/// - Requests push notification permissions
/// - Registers & refreshes the device FCM token with the PitStop backend
/// - Displays foreground pushes as local heads-up banners via [NotificationService]
class PushNotificationService {
  PushNotificationService({
    required this.authService,
    required this.notificationService,
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? CloudSyncService.resolveDefaultBaseUrl(),
        _client = client ?? http.Client();

  final AuthService authService;
  final NotificationService notificationService;
  final String baseUrl;
  final http.Client _client;

  bool _initialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;

    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
        registerTokenWithBackend(token);
      });

      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await registerTokenWithBackend(token);
      }

      _initialized = true;
    } catch (e) {
      debugPrint('PushNotificationService.initialize skipped: $e');
    }
  }

  /// Registers the current FCM token with `POST /api/notifications/devices`.
  Future<bool> registerTokenWithBackend([String? tokenOverride]) async {
    final token = tokenOverride ?? _currentToken;
    if (token == null || token.isEmpty) return false;

    try {
      final idToken = await authService.getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken'
        else
          'x-dev-uid': 'local-device',
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/devices'),
            headers: headers,
            body: jsonEncode({
              'token': token,
              'platform': _resolvePlatform(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('PushNotificationService.registerTokenWithBackend failed: $e');
      return false;
    }
  }

  /// Schedules a backend BullMQ push reminder via `POST /api/notifications/schedule-reminder`.
  Future<bool> scheduleBackendReminder({
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? vehicleId,
    String? reminderType,
  }) async {
    try {
      final idToken = await authService.getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (idToken != null && idToken.isNotEmpty)
          'Authorization': 'Bearer $idToken'
        else
          'x-dev-uid': 'local-device',
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/notifications/schedule-reminder'),
            headers: headers,
            body: jsonEncode({
              'title': title,
              'body': body,
              'scheduledAt': scheduledAt.toUtc().toIso8601String(),
              'vehicleId': ?vehicleId,
              'reminderType': ?reminderType,
            }),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('PushNotificationService.scheduleBackendReminder failed: $e');
      return false;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    notificationService.showInstantNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title ?? 'PitStop',
      body: body ?? '',
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }
}
