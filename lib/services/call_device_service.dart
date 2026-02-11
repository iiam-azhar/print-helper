// import 'dart:convert';
// import 'dart:io';

// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:twilio_voice/twilio_voice.dart';
// import 'package:uuid/uuid.dart';

// import '../constants/strings.dart';
// import '../services/api_routes.dart';
// import '../services/api_service.dart';
// import '../utils/console_util.dart';

// class CallDeviceService {
//   CallDeviceService._();

//   static const String _deviceIdKey = "device_id";
//   static const String _registeredFcmTokenKey = "registered_fcm_token";
//   static const String _twilioAccessTokenKey = "twilio_access_token";

//   static Future<void> bootstrap({bool forceRegister = false}) async {
//     await _registerDeviceIfNeeded(force: forceRegister);
//     await _syncTwilioTokens();
//   }

//   static Future<void> handleFcmTokenRefresh(String newToken) async {
//     if (newToken.isEmpty) return;
//     await _registerDeviceIfNeeded(force: true);
//     await _syncTwilioTokens();
//   }

//   static Future<void> _registerDeviceIfNeeded({bool force = false}) async {
//     final prefs = await SharedPreferences.getInstance();
//     final authToken = prefs.getString("token") ?? "";
//     final fcmToken = prefs.getString("fcm_token") ?? "";
//     if (authToken.isEmpty || fcmToken.isEmpty) {
//       printData(
//         title: "CallDevice/register",
//         data: "Skipped: missing auth or fcm token",
//       );
//       return;
//     }

//     final registeredToken = prefs.getString(_registeredFcmTokenKey);
//     if (!force && registeredToken == fcmToken) {
//       printData(
//         title: "CallDevice/register",
//         data: "Skipped: token already registered",
//       );
//       return;
//     }

//     final deviceId = await _getOrCreateDeviceId(prefs);
//     final payload = {
//       "device_id": deviceId,
//       "device_type": _deviceType(),
//       "fcm_token": fcmToken,
//       "device_name": _deviceName(),
//       "platform": _platformLabel(),
//       "app_version": _appVersion(),
//     };

//     try {
//       printData(
//         title: "CallDevice/register",
//         data: "Posting device registration",
//       );
//       final data = await ApiService().postDataToApi(
//         api: ApiRoutes.registerDevice,
//         headers: {
//           "Accept": "application/json",
//           "Content-Type": "application/json",
//           "Authorization": "Bearer $authToken",
//         },
//         payload: jsonEncode(payload),
//       );
//       if (data is Map<String, dynamic> && data["success"] == true) {
//         await prefs.setString(_registeredFcmTokenKey, fcmToken);
//         printData(title: "CallDevice/register", data: "Success");
//       } else {
//         printData(
//           title: "CallDevice/register",
//           data:
//               "Failed: ${data is Map<String, dynamic> ? data["message"] : data}",
//           e: true,
//         );
//       }
//     } catch (e) {
//       printData(title: "CallDevice/register", data: "Error: $e", e: true);
//     }
//   }

//   static Future<void> _syncTwilioTokens() async {
//     final prefs = await SharedPreferences.getInstance();
//     final authToken = prefs.getString("token") ?? "";
//     final fcmToken = prefs.getString("fcm_token") ?? "";
//     if (authToken.isEmpty || fcmToken.isEmpty) {
//       printData(
//         title: "CallDevice/tokens",
//         data: "Skipped: missing auth or fcm token",
//       );
//       return;
//     }

//     final accessToken = await _getTwilioAccessToken(authToken: authToken);
//     if (accessToken == null || accessToken.isEmpty) {
//       printData(
//         title: "CallDevice/tokens",
//         data: "Skipped: empty twilio token",
//         e: true,
//       );
//       return;
//     }

//     try {
//       final result = await TwilioVoice.instance.setTokens(
//         accessToken: accessToken,
//         deviceToken: Platform.isAndroid ? fcmToken : null,
//       );
//       printData(title: "CallDevice/tokens", data: "Twilio setTokens: $result");
//     } catch (e) {
//       printData(
//         title: "CallDevice/tokens",
//         data: "Twilio setTokens error: $e",
//         e: true,
//       );
//     }
//   }

//   static Future<String?> _getTwilioAccessToken({
//     required String authToken,
//   }) async {
//     final prefs = await SharedPreferences.getInstance();
//     final cached = prefs.getString(_twilioAccessTokenKey);
//     if (cached != null && cached.isNotEmpty) return cached;

//     try {
//       printData(
//         title: "CallDevice/token",
//         data: "Fetching Twilio access token",
//       );
//       final data = await ApiService().getDataFromApi(
//         api: ApiRoutes.twilioAccessToken,
//         headers: {
//           "Accept": "application/json",
//           "Content-Type": "application/json",
//           "Authorization": "Bearer $authToken",
//         },
//         showRes: false,
//       );
//       if (data is Map<String, dynamic>) {
//         final dynamic payload = data["data"] ?? data;
//         final token = payload is Map<String, dynamic>
//             ? (payload["token"] ?? payload["access_token"])
//             : null;
//         if (token is String && token.isNotEmpty) {
//           await prefs.setString(_twilioAccessTokenKey, token);
//           printData(
//             title: "CallDevice/token",
//             data: "Twilio access token received",
//           );
//           return token;
//         }
//       }
//     } catch (e) {
//       printData(
//         title: "CallDevice/token",
//         data: "Token fetch error: $e",
//         e: true,
//       );
//     }
//     return null;
//   }

//   static Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
//     final existing = prefs.getString(_deviceIdKey);
//     if (existing != null && existing.isNotEmpty) return existing;
//     final id = const Uuid().v4();
//     await prefs.setString(_deviceIdKey, id);
//     return id;
//   }

//   static String _deviceType() {
//     if (Platform.isAndroid) return "android";
//     if (Platform.isIOS) return "ios";
//     return Platform.operatingSystem.toLowerCase();
//   }

//   static String _platformLabel() {
//     if (Platform.isAndroid) return "Android";
//     if (Platform.isIOS) return "iOS";
//     return Platform.operatingSystem;
//   }

//   static String _deviceName() {
//     final host = Platform.localHostname;
//     if (host.isNotEmpty) return host;
//     return "Unknown Device";
//   }

//   static String _appVersion() {
//     final raw = Platform.isIOS ? AppStrings.iosVrsn : AppStrings.androidVrsn;
//     final cleaned = raw.replaceFirst(RegExp(r"^v"), "");
//     return cleaned.split("+").first;
//   }
// }

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this package if missing

import '../constants/strings.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';

class CallDeviceService {
  CallDeviceService._();

  static const String _deviceIdKey = "device_id";
  static const String _registeredFcmTokenKey = "registered_fcm_token";
  static const String _twilioAccessTokenKey = "twilio_access_token";

  /// 1. Main Entry Point called from main.dart
  static Future<void> bootstrap({bool forceRegister = false}) async {
    // A. Request Microphone Permissions immediately
    await _requestPermissions();

    // B. Register Device with your Backend
    await _registerDeviceIfNeeded(force: forceRegister);

    // C. Sync Tokens with Twilio SDK
    await _syncTwilioTokens();

    // D. Listen for Call Events (Optional but recommended for debugging)
    TwilioVoice.instance.callEventsListener.listen((event) {
      printData(title: "Twilio Event", data: event.toString());
    });
  }

  static Future<void> handleFcmTokenRefresh(String newToken) async {
    if (newToken.isEmpty) return;
    printData(title: "FCM Refresh", data: "Updating Twilio with new token");

    // Update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("fcm_token", newToken);

    // Re-register everything
    await _registerDeviceIfNeeded(force: true);
    await _syncTwilioTokens();
  }

  static Future<void> _requestPermissions() async {
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
    }
    // Android 12+ Bluetooth Connect permission (needed for headsets)
    if (Platform.isAndroid) {
      if (!await Permission.bluetoothConnect.isGranted) {
        await Permission.bluetoothConnect.request();
      }
    }
  }

  static Future<void> _registerDeviceIfNeeded({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token") ?? "";
    final fcmToken = prefs.getString("fcm_token") ?? "";

    if (authToken.isEmpty || fcmToken.isEmpty) {
      printData(
        title: "CallDevice/register",
        data: "Skipped: missing auth or fcm token",
      );
      return;
    }

    final registeredToken = prefs.getString(_registeredFcmTokenKey);
    // If not forced and token hasn't changed, skip backend API call
    if (!force && registeredToken == fcmToken) {
      return;
    }

    final deviceId = await _getOrCreateDeviceId(prefs);

    // Payload for your Laravel Backend
    final payload = {
      "device_id": deviceId,
      "device_type": _deviceType(),
      "fcm_token": fcmToken,
      "device_name": _deviceName(),
      "platform": _platformLabel(),
      "app_version": _appVersion(),
    };

    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.registerDevice,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        payload: jsonEncode(payload),
      );

      if (data is Map<String, dynamic> && data["success"] == true) {
        await prefs.setString(_registeredFcmTokenKey, fcmToken);
        printData(
          title: "CallDevice/register",
          data: "Backend Registered Successfully",
        );
      }
    } catch (e) {
      printData(title: "CallDevice/register", data: "Error: $e", e: true);
    }
  }

  static Future<void> _syncTwilioTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token") ?? "";
    final fcmToken = prefs.getString("fcm_token") ?? "";

    if (authToken.isEmpty) return;

    // 1. Get Access Token from Your Laravel Backend
    final accessToken = await _getTwilioAccessToken(authToken: authToken);

    if (accessToken == null || accessToken.isEmpty) {
      printData(
        title: "CallDevice/tokens",
        data: "Skipped: Could not fetch Twilio Access Token",
        e: true,
      );
      return;
    }

    // 2. Register with Twilio SDK
    try {
      printData(title: "Twilio Setup", data: "Registering with FCM: $fcmToken");

      final result = await TwilioVoice.instance.setTokens(
        accessToken: accessToken,
        deviceToken: Platform.isAndroid
            ? fcmToken
            : null, // iOS handles APNS internally usually
      );

      if (result == true) {
        printData(
          title: "Twilio Setup",
          data: "✅ Twilio Voice Registered Successfully",
        );
      } else {
        printData(
          title: "Twilio Setup",
          data: "❌ Twilio Registration Failed",
          e: true,
        );
      }
    } catch (e) {
      printData(
        title: "CallDevice/tokens",
        data: "Twilio setTokens error: $e",
        e: true,
      );
    }
  }

  static Future<String?> _getTwilioAccessToken({
    required String authToken,
  }) async {
    // You might want to remove caching here if tokens expire quickly (default is 1 hour)
    // For now, we will fetch fresh every time to be safe

    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.twilioAccessToken,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        showRes: false,
      );

      if (data is Map<String, dynamic>) {
        // Handle different JSON structures depending on your API response
        final dynamic payload = data["data"] ?? data;

        // Check for 'token' or 'access_token'
        final token = payload is Map<String, dynamic>
            ? (payload["token"] ?? payload["access_token"])
            : (data["token"] ?? data["access_token"]);

        if (token is String && token.isNotEmpty) {
          return token;
        }
      }
    } catch (e) {
      printData(
        title: "CallDevice/token",
        data: "Token fetch error: $e",
        e: true,
      );
    }
    return null;
  }

  // --- Utils ---
  static Future<String> _getOrCreateDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  static String _deviceType() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return Platform.operatingSystem.toLowerCase();
  }

  static String _platformLabel() {
    if (Platform.isAndroid) return "Android";
    if (Platform.isIOS) return "iOS";
    return Platform.operatingSystem;
  }

  static String _deviceName() {
    final host = Platform.localHostname;
    return host.isNotEmpty ? host : "Unknown Device";
  }

  static String _appVersion() {
    // Ensure AppStrings class exists in your project
    final raw = Platform.isIOS ? AppStrings.iosVrsn : AppStrings.androidVrsn;
    return raw.replaceFirst(RegExp(r"^v"), "").split("+").first;
  }
}
