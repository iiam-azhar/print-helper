import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:uuid/uuid.dart';

import '../constants/strings.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';

class CallDeviceService {
  CallDeviceService._();
  // Toggle to enable/disable call features across the app.
  // Set to true to enable Twilio/ConnectionService registration.
  static bool callEnabled = true;

  /// Places an external call using the specific outbound-voice-url API.
  static Future<bool> placeExternalCall({
    required String toNumber,
    int? conversationId,
    required bool record,
    String? toUserId,
    String? fromNumber,
  }) async {
    if (!callEnabled) {
      printData(
        title: "CallDevice/placeExternalCall",
        data: "Call features disabled.",
      );
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token") ?? "";
    if (authToken.isEmpty) {
      printData(
        title: "CallDevice/placeExternalCall",
        data: "No auth token found",
        e: true,
      );
      return false;
    }
    printData(
      title: "CallDevice/placeExternalCall",
      data: "Initiating external call to $toNumber (conv: $conversationId)",
    );
    // 1. Fetch Call Configuration (Voice URL) from Backend
    Map<String, dynamic>? callConfig;
    try {
      final sanitizedToNumber = toNumber.replaceAll(RegExp(r'[^\d+]'), '');
      String queryParams =
          "to_number=$sanitizedToNumber"
          "&record=${record ? 1 : 0}";

      if (conversationId != null) {
        queryParams += "&conversation_id=$conversationId";
      }
      // Laravel expects `to_user_id` to be defined in the array, so we always pass it.
      // If it's null or empty, it just gets passed as an empty string.
      queryParams += "&to_user_id=${toUserId ?? ''}";

      // Use the newly added route
      final endpoint = "${ApiRoutes.outboundVoiceUrl}?$queryParams";

      final data = await ApiService().getDataFromApi(
        api: endpoint,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $authToken",
        },
        showRes: true,
      );

      if (data is Map<String, dynamic>) {
        if (data["success"] == true) {
          callConfig = data["data"];
        } else {
          final msg = data["message"] ?? "Unknown error";
          printData(
            title: "CallDevice/placeExternalCall",
            data: "API Error: $msg",
            e: true,
          );
          return false;
        }
      }
    } catch (e) {
      printData(
        title: "CallDevice/placeExternalCall",
        data: "Exception during API call: $e",
        e: true,
      );
      return false;
    }
    if (callConfig == null) return false;
    // 2. Handle Bridge vs Direct Call
    final bool expectBridge = callConfig["expect_incoming_bridge"] ?? false;
    expectingBridgeLeg = expectBridge;
    if (expectBridge) {
      printData(
        title: "CallDevice/placeExternalCall",
        data: "Bridge call requested. Waiting for incoming leg...",
      );
      // The backend initiates the call. Expect incoming bridge.
      return true;
    }
    // 3. Place Direct Call via Twilio SDK using returned config
    try {
      // Ensure E.164 format for To number
      String twilioTo = callConfig["to_number"] ?? toNumber;
      if (!twilioTo.startsWith('+')) twilioTo = "+$twilioTo";
      // Use Client Identity (user_ID) as 'from' to ensure it's treated as a Client Connection
      // The actual Caller ID (PSTN number) is handled by the backend/TwiML via voice_url or from_number
      String userId = prefs.getInt("user_id")?.toString() ?? "";
      // Try to get userId from token if missing (fallback logic from syncTwilioTokens)
      if (userId.isEmpty && authToken.isNotEmpty) {
        try {
          Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
          userId =
              decodedToken['sub']?.toString() ??
              decodedToken['id']?.toString() ??
              "";
        } catch (_) {}
      }
      String twilioFrom = "client:user_$userId"; // Default format
      // If we can't find user ID, fall back to "Client" or device ID, but NOT a phone number
      if (userId.isEmpty) {
        twilioFrom = "Client";
      } else {
        // Ensure "user_" prefix is consistently applied if just numeric
        if (RegExp(r'^\d+$').hasMatch(userId)) {
          twilioFrom = "client:user_$userId";
        } else if (!userId.startsWith("client:")) {
          twilioFrom = "client:$userId";
        }
      }
      final voiceUrl = callConfig["voice_url"]; // The TwiML URL from backend
      final extraOptions = <String, dynamic>{
        if (conversationId != null)
          "conversation_id": conversationId.toString(),
        "voice_url": voiceUrl, // Pass to backend mechanism
        // Pass original fromNumber if needed by backend params, but not as the 'from' identity
        if (fromNumber != null) "from_number": fromNumber,
      };
      printData(
        title: "CallDevice/placeExternalCall",
        data:
            "Placing Twilio call to $twilioTo (Client: $twilioFrom) with config: $extraOptions",
      );
      final result = await TwilioVoice.instance.call.place(
        from: twilioFrom,
        to: twilioTo,
        extraOptions: extraOptions,
      );
      return result ?? false;
    } catch (e) {
      printData(
        title: "CallDevice/placeExternalCall",
        data: "Twilio SDK Place Error: $e",
        e: true,
      );
      return false;
    }
  }

  static const String _deviceIdKey = "device_id";
  static const String _registeredFcmTokenKey = "registered_fcm_token";
  // static const String _twilioAccessTokenKey = "twilio_access_token";

  /// Flag to indicate we are waiting for a bridge call (outgoing via backend).
  /// If true, the next incoming call will be auto-answered.
  ///
  /// NOTE: This bridge flow means we do NOT place an outgoing call via the SDK/OS.
  /// Therefore, the Native Android Outgoing Call UI will NOT appear.
  /// We must simulate the UI (e.g. via Custom CallScreen) until the bridge leg arrives.
  /// To enable Native Outgoing UI, the backend must support Direct VoIP Outbound calls.
  static bool expectingBridgeLeg = false;

  /// Flag to prevent duplicate initialization
  static bool _isInitialized = false;

  /// 1. Main Entry Point called from main.dart
  static Future<void> bootstrap({bool forceRegister = false}) async {
    if (!callEnabled) {
      printData(title: "CallDevice/bootstrap", data: "Call features disabled.");
      return;
    }

    if (_isInitialized && !forceRegister) {
      printData(
        title: "CallDevice/bootstrap",
        data: "Skipped: Already initialized.",
      );
      return;
    }

    // A. Register device with backend if needed
    await _registerDeviceIfNeeded(force: forceRegister);
    // B. Sync tokens and register with Twilio and Android Telecom
    await _syncTwilioTokens();

    _isInitialized = true;
  }

  /// 2. Setup Call Event Listeners - Call this from main.dart after MaterialApp is initialized
  static void setupCallListeners({
    required Function(String callerName, String callerNumber) onCallAnswered,
  }) {
    TwilioVoice.instance.callEventsListener.listen((event) async {
      printData(title: "Twilio Event", data: event.toString());
      switch (event) {
        case CallEvent.incoming:
          printData(
            title: "Incoming Call Event",
            data: "Checking Bridge Flag: $expectingBridgeLeg",
          );
          if (expectingBridgeLeg) {
            printData(
              title: "Incoming Call",
              data: "Auto-answering bridge leg for outgoing call",
            );
            expectingBridgeLeg = false;
            try {
              // Wait a moment for the SDK to populate the active call info
              // User requested immediate answer, so reducing delay or removing it.
              // await Future.delayed(const Duration(milliseconds: 500));
              final activeCall = TwilioVoice.instance.call.activeCall;
              printData(
                title: "Bridge Auto-Answer Debug",
                data: "Active Call: ${activeCall?.from} -> ${activeCall?.to}",
              );
              await TwilioVoice.instance.call.answer();
              // Ensure mic is unmuted and speaker is off by default for bridge answer
              await TwilioVoice.instance.call.toggleMute(false);
              await TwilioVoice.instance.call.toggleSpeaker(false);
              printData(
                title: "Bridge Auto-Answer",
                data: "Answer command sent + Unmuted",
              );
            } catch (e) {
              printData(title: "Bridge Auto-Answer Error", data: e, e: true);
            }
            return;
          }
          printData(
            title: "Incoming Call",
            data:
                "Call received - Android ConnectionService will show native UI",
          );
          // Task explanation provided in text.r UI is automatically shown by Twilio SDK
          // via ConnectionService when registerPhoneAccount() was called
          break;
        case CallEvent.connected:
          printData(title: "Call Connected", data: "Call is now active");
          // Get caller information from the active call
          final activeCall = TwilioVoice.instance.call.activeCall;
          final callerName = activeCall?.fromFormatted ?? "Unknown Caller";
          final callerNumber = activeCall?.from ?? "Unknown";
          // Navigate to CallScreen
          onCallAnswered(callerName, callerNumber);
          // Force enable audio
          TwilioVoice.instance.call.toggleMute(false);
          TwilioVoice.instance.call.toggleSpeaker(true);
          break;
        case CallEvent.callEnded:
          printData(title: "Call Ended", data: "Call has been terminated");
          break;
        case CallEvent.declined:
          printData(title: "Call Declined", data: "User declined the call");
          break;
        case CallEvent.answer:
          printData(title: "Call Answered", data: "User answered the call");
          break;
        case CallEvent.missedCall:
          printData(title: "Missed Call", data: "Call was not answered");
          break;
        case CallEvent.returningCall:
          printData(title: "Returning Call", data: "Returning to active call");
          break;

        default:
          printData(title: "Twilio Event", data: "Unhandled event: $event");
      }
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

    String userId = prefs.getInt("user_id")?.toString() ?? "";
    // Prioritize getting userId from token if local pref is empty
    if (authToken.isNotEmpty && userId.isEmpty) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
        final tokenUserId =
            decodedToken['sub']?.toString() ??
            decodedToken['id']?.toString() ??
            "";
        if (tokenUserId.isNotEmpty) userId = tokenUserId;
      } catch (e) {
        // ignore
      }
    }

    final deviceId = await _getOrCreateDeviceId(prefs);

    final registeredToken = prefs.getString(_registeredFcmTokenKey);
    final registeredUserId = prefs.getString("registered_user_id");
    final registeredDeviceId = prefs.getString("registered_device_id");

    // Check if we can skip:
    // If NOT forced AND all 3 values match what we last successfully registered -> SKIP
    if (!force &&
        registeredToken == fcmToken &&
        registeredUserId == userId &&
        registeredDeviceId == deviceId) {
      printData(
        title: "CallDevice/register",
        data: "Skipped: Device/User/Token already registered and unchanged.",
      );
      return;
    }

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
      printData(
        title: "CallDevice/register",
        data: "Posting device registration (Force: $force)",
      );

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
        // SAVE the successful state
        await prefs.setString(_registeredFcmTokenKey, fcmToken);
        await prefs.setString("registered_user_id", userId);
        await prefs.setString("registered_device_id", deviceId);

        printData(
          title: "CallDevice/register",
          data: "Backend Registered Successfully. Saved local state.",
        );
      } else {
        printData(
          title: "CallDevice/register",
          data: "Backend registration failed: $data",
          e: true,
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

      if (Platform.isAndroid) {
        String userId = prefs.getInt("user_id")?.toString() ?? "";
        final userName = prefs.getString("name") ?? "Print Helper";

        // Prioritize getting userId from token if local pref is empty OR if we want to be sure
        if (authToken.isNotEmpty) {
          try {
            Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
            // Check 'sub' or 'id'
            final tokenUserId =
                decodedToken['sub']?.toString() ??
                decodedToken['id']?.toString() ??
                "";
            if (tokenUserId.isNotEmpty) {
              userId = tokenUserId;
            }
          } catch (e) {
            printData(
              title: "Twilio Setup",
              data: "Failed to decode token for userId: $e",
              e: true,
            );
          }
        }

        // Fix: Ensure userId format matches backend expectation (e.g. "user_2")
        // If userId is numeric (e.g. "2"), prepend "user_"
        if (userId.isNotEmpty && RegExp(r'^\d+$').hasMatch(userId)) {
          userId = "user_$userId";
        }

        printData(
          title: "Twilio Setup",
          data:
              "Attempting registerClient for Android. UserID: '$userId', Name: '$userName'",
        );

        if (userId.isNotEmpty) {
          final success = await TwilioVoice.instance.registerClient(
            userId,
            userName,
          );
          printData(
            title: "Twilio Setup",
            data: "registerClient result: $success",
          );
        } else {
          printData(
            title: "Twilio Setup",
            data: "Skipping registerClient: UserID is empty",
            e: true,
          );
        }
      }

      // Register phone account with Android TelecomManager — required for
      // incoming calls via ConnectionService on Android.
      try {
        final registered = await TwilioVoice.instance.registerPhoneAccount();
        printData(
          title: "Twilio Setup",
          data: "registerPhoneAccount result: $registered",
        );

        // Check if the phone account is enabled
        if (registered == true) {
          final isEnabled = await TwilioVoice.instance.isPhoneAccountEnabled();
          printData(
            title: "Twilio Setup",
            data: "Phone account enabled: $isEnabled",
          );

          if (isEnabled == false) {
            printData(
              title: "Twilio Setup",
              data: "⚠️ Phone account not enabled. Opening settings...",
            );
            // Automatically open the phone account settings for the user
            await TwilioVoice.instance.openPhoneAccountSettings();
          }
        }
      } catch (e) {
        printData(
          title: "Twilio Setup",
          data: "registerPhoneAccount error: $e",
          e: true,
        );
      }

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
