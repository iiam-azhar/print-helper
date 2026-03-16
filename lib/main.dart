import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/providers/cust_pro.dart';
import 'package:print_helper/providers/files_pro.dart';
import 'package:print_helper/providers/project_pro.dart';
import 'package:print_helper/providers/setting_pro.dart';
import 'package:print_helper/admin/chat/service/chat_push_notify.dart';
import 'package:print_helper/utils/no_ssl_http_override.dart';
import 'package:print_helper/services/call_device_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/console_util.dart';

import 'package:permission_handler/permission_handler.dart';
import 'providers/auth_pro.dart';
import 'admin/chat/provider/chat_pro.dart';
import 'providers/client_pro.dart';
import 'providers/lang_pro.dart';
import 'providers/user_pro.dart';
import 'root.dart';
import 'utils/system_chromes.dart';

// Top-level background handler for incoming FCM messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Twilio plugin handles its own background messages via the native service,
  // but we keep this for Chat notifications.
  printData(title: "Handling a background message:", data: message.messageId);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. Initialize Firebase
  await Firebase.initializeApp();
  // 2. Set Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 3. SSL Override (Development only)
  HttpOverrides.global = MyHttpOverrides();
  // 4. Initialize Local Notifications
  await NotificationService.instance.init();
  // 5. System UI settings
  SysChromes.setSystemChromes();
  // 5.1 Lock orientation based on physical device size
  await _setOrientationByPhysicalDeviceSize();
  // 6. Request Permissions FIRST
  await _checkPermissions();
  // 7. Setup Firebase Messaging & Twilio Voice
  await _initFirebaseMessaging();
  runApp(multiProviders());
}

Future<void> _setOrientationByPhysicalDeviceSize() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final physicalShortestSide = view.physicalSize.shortestSide;
  final devicePixelRatio = view.devicePixelRatio;
  final shortestSide = physicalShortestSide / devicePixelRatio;

  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  // Request Notification Permissions (Critical for iOS/Android 13+)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  printData(
    title: 'User granted permission:',
    data: settings.authorizationStatus,
  );

  final prefs = await SharedPreferences.getInstance();

  // Get FCM Token
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    printData(title: "FCM Token:", data: token);
    await prefs.setString("fcm_token", token);
  }

  // Listen for Token Refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    printData(title: "FCM Token Refreshed:", data: newToken);
    if (newToken.isNotEmpty) {
      await prefs.setString("fcm_token", newToken);
      // Notify Service to update Twilio
      await CallDeviceService.handleFcmTokenRefresh(newToken);
    }
  });

  // 7. Bootstrap Twilio Voice Service
  // This will handle fetching the access token from Laravel and registering with Twilio
  await CallDeviceService.bootstrap(forceRegister: false);
}

Future<void> _checkPermissions() async {
  if (Platform.isAndroid) {
    // 1. Standard Permissions
    // Request critical permissions sequentially to ensure they are handled
    if (!await Permission.phone.isGranted) {
      await Permission.phone.request();
    }
    if (!await Permission.bluetoothConnect.isGranted) {
      await Permission.bluetoothConnect.request();
    }
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }

    // Note: Phone Account (ConnectionService) check requires a valid Context
    // We should move that check to the UI layer (e.g. inside MyApp or a splash screen)
  }
}

MultiProvider multiProviders() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: LangPro.instance),
      ChangeNotifierProvider(create: (_) => AuthPro()),
      ChangeNotifierProvider(create: (_) => UserPro()),
      ChangeNotifierProvider(create: (_) => CustomerPro()),
      ChangeNotifierProvider(create: (_) => ProjectPro()),
      ChangeNotifierProvider(create: (_) => FilesPro()),
      ChangeNotifierProvider(create: (_) => AdminPro()),
      ChangeNotifierProvider(create: (_) => ClientPro()),
      ChangeNotifierProvider(create: (_) => SettingsPro()),
      ChangeNotifierProvider(create: (_) => ChatPro()),
    ],
    child: const MyApp(),
  );
}
