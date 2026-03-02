import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const windowsSettings = WindowsInitializationSettings(
      appName: 'PrintHelper',
      appUserModelId: 'com.printhelper.app',
      guid: '2c0d1f1b-9f1b-4a7a-8f4d-0b4c6b8a8d1a',
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );
    // 1. Initialize the plugin
    await _plugin.initialize(initSettings);
    // 2. Request Permission for Android 13+
    // (This is critical, otherwise notifications will silently fail)
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> showChatNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    debugPrint("🔔 TRYING TO SHOW NOTIFICATION: $title");
    // 1. CHANGE CHANNEL ID: Changed to 'chat_channel_new' to force high importance
    const androidDetails = AndroidNotificationDetails(
      'chat_channel_new', // CHANGED ID
      'Chat Messages High Priority', // CHANGED NAME
      channelDescription: 'Incoming chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      // 2. CHECK ICON: Ensure this exact file exists in android/app/src/main/res/mipmap-*/
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(id, title, body, notificationDetails);
      debugPrint("NOTIFICATION SENT TO PLUGIN"); // Debug Log 2
    } catch (e) {
      debugPrint("NOTIFICATION ERROR: $e"); // Catch any hidden errors
    }
  }
}
