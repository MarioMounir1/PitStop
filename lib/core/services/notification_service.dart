import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notification scheduler for PitStop maintenance and document reminders.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'pitstop_reminders';
  static const String _channelName = 'Maintenance Reminders';
  static const String _channelDescription =
      'Scheduled reminders for vehicle maintenance, license, and insurance.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Initializes timezone database, notification plugin, and requests
  /// platform permissions gracefully (including Android 14/15 exact alarms).
  Future<void> initialize({
    DidReceiveNotificationResponseCallback? onNotificationTap,
  }) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: onNotificationTap,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService.initialize failed: $e');
    }
  }

  /// Requests notification & Android 14/15 exact alarm permissions gracefully.
  /// Returns `true` if notifications are allowed (or platform does not require
  /// runtime permission).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin == null) return false;

        final notificationsGranted =
            await androidPlugin.requestNotificationsPermission() ?? true;

        // Android 14/15 exact alarm permission — optional; we fall back to
        // inexact scheduling if the user declines.
        try {
          final canScheduleExact =
              await androidPlugin.canScheduleExactNotifications() ?? false;
          if (!canScheduleExact) {
            await androidPlugin.requestExactAlarmsPermission();
          }
        } catch (e) {
          debugPrint('Exact alarm permission request skipped: $e');
        }

        return notificationsGranted;
      }

      if (Platform.isIOS) {
        final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        return await iosPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      if (Platform.isMacOS) {
        final macPlugin = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        return await macPlugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('NotificationService.requestPermissions failed: $e');
    }

    return false;
  }

  /// Schedules a local reminder notification at [scheduledDate].
  /// Automatically falls back to inexact scheduling on Android 14/15 if exact
  /// alarm permission has not been granted.
  Future<void> scheduleReminder(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final now = DateTime.now();
    if (!scheduledDate.isAfter(now)) {
      return;
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final scheduleMode = await _resolveAndroidScheduleMode();

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledDate,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: payload,
      );
    } catch (e) {
      // Fallback to inexact scheduling if exact alarms throw a SecurityException.
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: tzScheduledDate,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
          return;
        } catch (fallbackError) {
          debugPrint(
            'NotificationService fallback schedule failed: $fallbackError',
          );
        }
      }
      debugPrint('NotificationService.scheduleReminder failed: $e');
    }
  }

  /// Displays an immediate notification (used for foreground FCM push messages).
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await initialize();
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService.showInstantNotification failed: $e');
    }
  }

  /// Cancels a single scheduled reminder by [id].
  Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('NotificationService.cancelReminder($id) failed: $e');
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll failed: $e');
    }
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  void _configureLocalTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final locations = tz.timeZoneDatabase.locations.values;
      for (final location in locations) {
        if (location.currentTimeZone.offset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
      tz.setLocalLocation(tz.UTC);
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }
}
