import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Service to handle local push notifications (e.g. proximity geofence alerts)
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  Ref? _ref;

  /// Initialize notification settings for Android and iOS
  Future<void> initialize(Ref ref) async {
    if (_isInitialized) return;
    _ref = ref;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && _ref != null) {
            // Set the state so the UI listener triggers the bottom sheet popup
            _ref!.read(activeNotificationPayloadProvider.notifier).setPayload(payload);
          }
        },
      );
      _isInitialized = true;
    } catch (e) {
      AppLogger.error('Failed to initialize local notifications: $e', error: e);
    }
  }

  /// Trigger a push notification alert
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'bkk_transit_proximity_channel',
      'Proximity Presence Alerts',
      channelDescription: 'Alerts when near transit stations',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFF4F46E5), // Brand indigo color to style accent and headers
      colorized: true,          // Allow system tinting of the notification card when supported
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      AppLogger.error('Failed to show notification: $e', error: e);
    }
  }
}
