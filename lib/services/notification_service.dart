import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to handle local push notifications (e.g. proximity geofence alerts)
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize notification settings for Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
      );
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize local notifications: $e');
    }
  }

  /// Trigger a push notification alert
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'bkk_transit_proximity_channel',
      'Proximity Presence Alerts',
      channelDescription: 'Alerts when near transit stations',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      print('Failed to show notification: $e');
    }
  }
}
