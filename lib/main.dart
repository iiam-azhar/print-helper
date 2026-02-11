// // import 'package:easy_localization/easy_localization.dart';
// import 'dart:io';

// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:print_helper/providers/admin_pro.dart';
// import 'package:print_helper/providers/cust_pro.dart';
// import 'package:print_helper/providers/files_pro.dart';
// import 'package:print_helper/providers/project_pro.dart';
// import 'package:print_helper/providers/setting_pro.dart';
// import 'package:print_helper/admin/chat/service/chat_push_notify.dart';
// import 'package:print_helper/utils/no_ssl_http_override.dart';
// import 'package:print_helper/services/call_device_service.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:twilio_voice/twilio_voice.dart';

// import 'providers/auth_pro.dart';
// import 'admin/chat/provider/chat_pro.dart';
// import 'providers/client_pro.dart';
// import 'providers/lang_pro.dart';
// import 'providers/user_pro.dart';
// import 'root.dart';
// import 'utils/system_chromes.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await NotificationService.instance.init();
//   HttpOverrides.global = MyHttpOverrides();
//   // await EasyLocalization.ensureInitialized();
//   await Firebase.initializeApp();
//   await _initFirebaseMessaging();
//   SysChromes.setSystemChromes();
//   // runApp(localize());
//   runApp(multiProviders());
// }

// Future<void> initVoiceService(String myAccessToken) async {
//   // 1. Get the Firebase Cloud Messaging (FCM) token for this device
//   String? fcmToken = await FirebaseMessaging.instance.getToken();

//   if (fcmToken == null) {
//     print("Error: Could not get FCM token. Notifications won't work.");
//     return;
//   }

//   // 2. Register with Twilio
//   // This sends the FCM token + Access Token to Twilio
//   await TwilioVoice.instance.setTokens(
//     accessToken: myAccessToken,
//     deviceToken: fcmToken,
//   );

//   print("Twilio Registered with FCM Token: $fcmToken");
// }

// Future<void> _initFirebaseMessaging() async {
//   final messaging = FirebaseMessaging.instance;
//   await messaging.requestPermission();

//   final prefs = await SharedPreferences.getInstance();
//   final token = await messaging.getToken();
//   if (token != null && token.isNotEmpty) {
//     await prefs.setString("fcm_token", token);
//   }

//   await CallDeviceService.bootstrap(forceRegister: true);

//   FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
//     if (newToken.isNotEmpty) {
//       await prefs.setString("fcm_token", newToken);
//       await CallDeviceService.handleFcmTokenRefresh(newToken);
//     }
//   });
// }

// // EasyLocalization localize() {
// //   return EasyLocalization(
// //     path: 'assets/translations',
// //     supportedLocales: const [Locale('en', 'US'), Locale('ar', 'QA')],
// //     saveLocale: true,
// //     child: multiProviders(),
// //   );
// // }

// MultiProvider multiProviders() {
//   return MultiProvider(
//     providers: [
//       ChangeNotifierProvider.value(value: LangPro.instance),
//       ChangeNotifierProvider(create: (_) => AuthPro()),
//       ChangeNotifierProvider(create: (_) => UserPro()),
//       ChangeNotifierProvider(create: (_) => CustomerPro()),
//       ChangeNotifierProvider(create: (_) => ProjectPro()),
//       ChangeNotifierProvider(create: (_) => FilesPro()),
//       ChangeNotifierProvider(create: (_) => AdminPro()),
//       ChangeNotifierProvider(create: (_) => ClientPro()),
//       ChangeNotifierProvider(create: (_) => SettingsPro()),
//       ChangeNotifierProvider(create: (_) => ChatPro()),
//     ],
//     child: const MyApp(),
//   );
// }

// // import 'dart:async';
// // import 'dart:convert';
// // import 'dart:io';

// // import 'package:flutter/material.dart';
// // import 'package:dart_pusher_channels/dart_pusher_channels.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:intl/intl.dart';
// // import 'package:shared_preferences/shared_preferences.dart'; // Add intl: ^0.18.0 to pubspec.yaml if you want nice dates

// // void main() {
// //   runApp(
// //     const MaterialApp(
// //       debugShowCheckedModeBanner: false,
// //       home: RemoteChatScreen(),
// //     ),
// //   );
// // }

// // // =======================================================
// // // 🔧 CONFIGURATION
// // // =======================================================
// // Future<String> apiHeaders() async {
// //   final prefs = await SharedPreferences.getInstance();
// //   final authToken = prefs.getString("token") ?? "";
// //   // return {
// //   //   "Accept": "application/json",
// //   //   "Content-Type": "application/json",
// //   //   "Authorization": "Bearer $authToken",
// //   // };
// //   return authToken;
// // }

// // const String serverIp = "production.printhelpers.com";
// // const String socketHost = serverIp;
// // const int socketPort = 443;
// // const String appKey = "8xK9mP2nL5qR7vW4jH6tY3bF1sD0gX8e";
// // const String apiBaseUrl = "https://$serverIp";

// // // 👤 USERS
// // const String currentUserId = "1";
// // const String targetUserId = "4";

// // // 🔑 AUTH TOKEN (Keep this fresh)
// // // const String authToken =
// // //     "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIwMTliN2RlMS1hODlmLTcyZjMtYTdlNi0zMzZhMzc4MjNhYzQiLCJqdGkiOiI2YTAxYjVkZTQ0N2QwNGI4OWJmYTEyMzUxN2YyZGI2MDJkZGU4MTk1MTg3Njk5MmYxYjVlMzgyNjc3MjUyZDE0NTUyOTRlODUwMWQ0OWQ3YyIsImlhdCI6MTc2NzM0NjI3Ni44NTg3NTYsIm5iZiI6MTc2NzM0NjI3Ni44NTg3NTksImV4cCI6MTc4Mjk4NDY3Ni44NDc5NDQsInN1YiI6IjEiLCJzY29wZXMiOltdfQ.onLQdRlefOwlIArMngVv7NgRpAE0dyfaJDwKEr8w8xqOd3q5zw3VAKKYW6MqY0ga7p9fCUaZ2EUFNyMsTrnyU-MxCi2rO9RTt5Z8BrNbn6-sVgqVUlY1oF57A8kmN9ddAsZ4oW8Ppetvv7D-xaBH69vNbdxcToNH5lvlTLTqTQyvV_WU3DEA-TeCfgcYggcdqtUrW4CPUldwALIStRWeLFR8HZxw8b1Uv0QQxe-XOg4GpdU2hgVBtL5X6MOFkFzJ8ta2dmgYtqOrJwDgWFU74QvlffNNyBNLyEUTEZT0KNwg3RUKvTrMjrH_dPV4MWStSobw6g8bMyfMR5pcP1mJwuiKPTzzDr63C3vT4Z8_R8kNj5xtSXfDY0LLLOIQBWdCqn9a0S7DTYHkrAs1hOhMYvHMQ1QcoV78XSpEtDye03lX3Sid5t6-DN-QoDLrcZSSkqb1Ftk-KV7RFhvTZVdqU0rd05PFZX7qU9928mJ3UEdPCS-gFp6j5r-U79tjPP5xog5vm5SlWMeMBLM6E40plG4Eh8yXm29ijFvIzmj1bvNMXJWsawq4--khR-mFSSiKft6TKBJwscmasCVBI_UTMudKN352aL-A-Fa0Ni0Xo4Juyuo1YDv86ThfdBRizXKxksykqry9OzLZkrjGnO6PUjRVuVkphrdYKge_014KWqY";

// // // =======================================================
// // // 📦 DATA MODEL
// // // =======================================================

// // class ChatMessage {
// //   final int id;
// //   final String text;
// //   final int senderId;
// //   final int conversationId;
// //   final DateTime sentAt;
// //   final bool isMe;

// //   ChatMessage({
// //     required this.id,
// //     required this.text,
// //     required this.senderId,
// //     required this.conversationId,
// //     required this.sentAt,
// //     required this.isMe,
// //   });

// //   factory ChatMessage.fromJson(Map<String, dynamic> json) {
// //     return ChatMessage(
// //       id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
// //       // Fix for the specific crash: Ensure we grab 'message' string, not object
// //       text: json['message'] ?? "",
// //       senderId: json['user_id'] is int
// //           ? json['user_id']
// //           : int.parse(json['user_id'].toString()),
// //       conversationId: json['conversation_id'] is int
// //           ? json['conversation_id']
// //           : int.parse(json['conversation_id'].toString()),
// //       sentAt: DateTime.parse(json['created_at']),
// //       isMe: (json['user_id'].toString() == currentUserId),
// //     );
// //   }
// // }

// // // =======================================================
// // // 📱 SCREEN
// // // =======================================================

// // class RemoteChatScreen extends StatefulWidget {
// //   const RemoteChatScreen({super.key});

// //   @override
// //   State<RemoteChatScreen> createState() => _RemoteChatScreenState();
// // }

// // class _RemoteChatScreenState extends State<RemoteChatScreen> {
// //   // WebSocket Client
// //   late PusherChannelsClient client;
// //   PrivateChannel? userChannel; // Listens for Messages
// //   PrivateChannel? conversationChannel; // Listens for Typing
// //   StreamSubscription? messageSub;
// //   StreamSubscription? typingSub;

// //   // State
// //   final List<ChatMessage> messages = [];
// //   final TextEditingController _textController = TextEditingController();
// //   final ScrollController _scrollController = ScrollController();

// //   String? conversationId;
// //   bool isConnecting = true;

// //   // Typing State
// //   bool isOtherUserTyping = false;
// //   Timer? _typingSendThrottle; // Prevent spamming API
// //   Timer? _typingAutoClear; // Hide "typing..." if socket packet lost

// //   @override
// //   void initState() {
// //     super.initState();
// //     _startChatFlow();
// //   }

// //   @override
// //   void dispose() {
// //     messageSub?.cancel();
// //     typingSub?.cancel();
// //     client.dispose();
// //     _textController.dispose();
// //     _scrollController.dispose();
// //     _typingSendThrottle?.cancel();
// //     _typingAutoClear?.cancel();
// //     super.dispose();
// //   }

// //   // ----------------------------------------------------------------------
// //   // 1️⃣ INITIALIZATION FLOW
// //   // ----------------------------------------------------------------------

// //   Future<void> _startChatFlow() async {
// //     // 1. Get Conversation ID from API
// //     await _fetchConversationId();

// //     // 2. Load History
// //     if (conversationId != null) {
// //       await _loadMessageHistory();

// //       // 3. Connect to WebSocket
// //       _connectToReverb();
// //     }
// //   }

// //   // ----------------------------------------------------------------------
// //   // 2️⃣ WEBSOCKET CONNECTION
// //   // ----------------------------------------------------------------------

// //   void _connectToReverb() {
// //     PusherChannelsPackageLogger.enableLogs();

// //     final options = PusherChannelsOptions.fromHost(
// //       scheme: 'wss',
// //       host: socketHost,
// //       port: socketPort,
// //       key: appKey,
// //       metadata: PusherChannelsOptionsMetadata.byDefault(),
// //     );

// //     client = PusherChannelsClient.websocket(
// //       options: options,
// //       connectionErrorHandler: (err, trace, refresh) {
// //         print("⚠️ Reverb Connection Error: $err");
// //         refresh();
// //       },
// //     );

// //     // Monitor Connection State
// //     client.onConnectionEstablished.listen((_) {
// //       print("⚡ Connected to Reverb");
// //       _subscribeChannels();
// //     });

// //     client.connect();
// //   }

// //   void _subscribeChannels() async {
// //     if (conversationId == null) return;
// //     final authDelegate =
// //         EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
// //           authorizationEndpoint: Uri.parse("$apiBaseUrl/api/broadcasting/auth"),
// //           headers: await _apiHeaders(),
// //         );

// //     // ⚠️ IMPORTANT: Listening to the current user's private channel
// //     userChannel = client.privateChannel(
// //       "private-user.$currentUserId",
// //       authorizationDelegate: authDelegate,
// //     );

// //     // Bind to the Event
// //     messageSub = userChannel!.bind("message.sent").listen((event) {
// //       print("📩 Realtime Event Received: ${event.data}");
// //       _handleIncomingMessage(event.data);
// //     });

// //     // 2. Subscribe to CONVERSATION Channel (For Typing Events)
// //     print(
// //       "🔐 Subscribing to conversation channel: private-conversation.$conversationId",
// //     );
// //     conversationChannel = client.privateChannel(
// //       "private-conversation.$conversationId",
// //       authorizationDelegate: authDelegate,
// //     );

// //     typingSub = conversationChannel!.bind("user.typing").listen((event) {
// //       _handleTypingEvent(event.data);
// //     });

// //     userChannel!.subscribeIfNotUnsubscribed();
// //     conversationChannel!.subscribeIfNotUnsubscribed();
// //   }

// //   // ⌨️ TYPING: RECEIVING (From Socket)
// //   // ----------------------------------------------------------------------

// //   void _handleTypingEvent(dynamic rawData) {
// //     try {
// //       final data = jsonDecode(rawData);

// //       // Data from PHP: { user_id, user_name, is_typing, conversation_id }
// //       String senderId = data['user_id'].toString();
// //       bool isTyping = data['is_typing'] ?? false;

// //       // Ignore my own typing events (though broadcast()->toOthers() handles this usually)
// //       if (senderId == currentUserId) return;

// //       if (mounted) {
// //         setState(() {
// //           isOtherUserTyping = isTyping;
// //         });
// //       }

// //       // Safety: Auto-hide "typing..." after 4 seconds if no new event comes
// //       _typingAutoClear?.cancel();
// //       if (isTyping) {
// //         _typingAutoClear = Timer(const Duration(seconds: 4), () {
// //           if (mounted) setState(() => isOtherUserTyping = false);
// //         });
// //       }
// //     } catch (e) {
// //       print("❌ Typing Parse Error: $e");
// //     }
// //   }

// //   // ----------------------------------------------------------------------
// //   // ⌨️ TYPING: SENDING (To API)
// //   // ----------------------------------------------------------------------

// //   void _onTextChanged(String text) {
// //     if (conversationId == null) return;

// //     bool isTypingNow = text.isNotEmpty;

// //     // THROTTLE: Don't spam the API. Only send once every 1.5 seconds.
// //     if (_typingSendThrottle != null && _typingSendThrottle!.isActive) return;

// //     _typingSendThrottle = Timer(const Duration(milliseconds: 1500), () {
// //       _sendTypingStatusToApi(isTypingNow);
// //     });

// //     // Immediate trigger on first character
// //     if (text.length == 1) _sendTypingStatusToApi(true);
// //   }

// //   Future<void> _sendTypingStatusToApi(bool isTyping) async {
// //     try {
// //       // ⚠️ IMPORTANT: Your PHP validation expects "true" or "false" as STRINGS
// //       String typingPayload = isTyping ? "true" : "false";

// //       await http.post(
// //         Uri.parse("$apiBaseUrl/api/chat/conversations/$conversationId/typing"),
// //         headers: await _apiHeaders(),
// //         body: jsonEncode({
// //           "is_typing": typingPayload, // Sending String!
// //         }),
// //       );
// //     } catch (e) {
// //       print("Failed to send typing status: $e");
// //     }
// //   }

// //   // ----------------------------------------------------------------------
// //   // 3️⃣ MESSAGE HANDLING
// //   // ----------------------------------------------------------------------

// //   void _handleIncomingMessage(dynamic rawData) {
// //     setState(() => isOtherUserTyping = false);
// //     try {
// //       // Decode String to JSON
// //       final json = jsonDecode(rawData);

// //       // Parse to Model
// //       final newMessage = ChatMessage.fromJson(json);

// //       // Verify it belongs to this conversation
// //       if (newMessage.conversationId.toString() == conversationId) {
// //         // Avoid adding my own messages twice (if echo is on)
// //         if (!newMessage.isMe) {
// //           setState(() {
// //             messages.insert(
// //               0,
// //               newMessage,
// //             ); // Add to bottom (index 0 because list is reversed)
// //           });
// //         }
// //       }
// //     } catch (e) {
// //       print("❌ PARSING ERROR: $e");
// //     }
// //   }

// //   // ----------------------------------------------------------------------
// //   // API HELPERS
// //   // ----------------------------------------------------------------------

// //   Future<void> _fetchConversationId() async {
// //     try {
// //       final res = await http.post(
// //         Uri.parse("$apiBaseUrl/api/chat/conversations"),
// //         headers: await _apiHeaders(),
// //         body: jsonEncode({
// //           "user_ids": [int.parse(targetUserId)],
// //           "type": "private",
// //         }),
// //       );

// //       if (res.statusCode == 200 || res.statusCode == 201) {
// //         final data = jsonDecode(res.body);
// //         setState(() => conversationId = data['data']['id'].toString());
// //         print("✅ Conversation ID: $conversationId");
// //       }
// //     } catch (e) {
// //       print("❌ Error fetching conversation: $e");
// //     }
// //   }

// //   Future<void> _loadMessageHistory() async {
// //     try {
// //       final res = await http.get(
// //         Uri.parse(
// //           "$apiBaseUrl/api/chat/conversations/$conversationId/messages",
// //         ),
// //         headers: await _apiHeaders(),
// //       );

// //       if (res.statusCode == 200) {
// //         final data = jsonDecode(res.body);
// //         final List<dynamic> list = data['data'];

// //         setState(() {
// //           messages.clear();
// //           // Map API data to Models
// //           final history = list.map((e) => ChatMessage.fromJson(e)).toList();
// //           messages.addAll(history.reversed); // Reverse for ListView
// //           isConnecting = false;
// //         });
// //         print("📚 Loaded ${messages.length} messages");
// //       }
// //     } catch (e) {
// //       print("❌ Failed to load history: $e");
// //     }
// //   }

// //   Future<void> _sendMessage() async {
// //     final text = _textController.text.trim();
// //     if (text.isEmpty || conversationId == null) return;

// //     // Optimistic UI Update
// //     final tempMsg = ChatMessage(
// //       id: DateTime.now().millisecondsSinceEpoch,
// //       text: text,
// //       senderId: int.parse(currentUserId),
// //       conversationId: int.parse(conversationId!),
// //       sentAt: DateTime.now(),
// //       isMe: true,
// //     );

// //     setState(() {
// //       messages.insert(0, tempMsg);
// //     });
// //     _textController.clear();

// //     // Stop typing indicator immediately when sending
// //     _sendTypingStatusToApi(false);

// //     try {
// //       await http.post(
// //         Uri.parse(
// //           "$apiBaseUrl/api/chat/conversations/$conversationId/messages",
// //         ),
// //         headers: await _apiHeaders(),
// //         body: jsonEncode({"message": text, "type": "text"}),
// //       );
// //     } catch (e) {
// //       print("❌ Failed to send: $e");
// //       // Optional: Mark message as failed in UI
// //     }
// //   }

// //   Future<Map<String, String>> _apiHeaders() async {
// //     final authToken = await apiHeaders();

// //     return {
// //       "Accept": "application/json",
// //       "Content-Type": "application/json",
// //       "Authorization": "Bearer $authToken",
// //     };
// //   }

// //   // ----------------------------------------------------------------------
// //   // 4️⃣ UI
// //   // ----------------------------------------------------------------------

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text("Chat with User $targetUserId"),
// //             if (isOtherUserTyping)
// //               const Text(
// //                 "Typing...",
// //                 style: TextStyle(
// //                   fontSize: 12,
// //                   color: Colors.white70,
// //                   fontStyle: FontStyle.italic,
// //                 ),
// //               ),
// //           ],
// //         ),
// //         backgroundColor: Colors.teal,
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.refresh),
// //             onPressed: _loadMessageHistory,
// //           ),
// //         ],
// //       ),
// //       backgroundColor: const Color(0xFFF2F2F2),
// //       body: isConnecting && conversationId == null
// //           ? const Center(child: CircularProgressIndicator())
// //           : Column(
// //               children: [
// //                 // Chat List
// //                 Expanded(
// //                   child: ListView.builder(
// //                     controller: _scrollController,
// //                     reverse: true, // Start from bottom
// //                     itemCount: messages.length,
// //                     padding: const EdgeInsets.symmetric(
// //                       horizontal: 10,
// //                       vertical: 20,
// //                     ),
// //                     itemBuilder: (context, index) {
// //                       return _buildMessageBubble(messages[index]);
// //                     },
// //                   ),
// //                 ),

// //                 // Optional: Floating bubbles animation
// //                 if (isOtherUserTyping)
// //                   Align(
// //                     alignment: Alignment.centerLeft,
// //                     child: Padding(
// //                       padding: const EdgeInsets.only(left: 16, bottom: 8),
// //                       child: Container(
// //                         padding: const EdgeInsets.symmetric(
// //                           horizontal: 12,
// //                           vertical: 8,
// //                         ),
// //                         decoration: BoxDecoration(
// //                           color: Colors.white,
// //                           borderRadius: BorderRadius.circular(15),
// //                         ),
// //                         child: const Text(
// //                           "•••",
// //                           style: TextStyle(
// //                             color: Colors.grey,
// //                             fontWeight: FontWeight.bold,
// //                           ),
// //                         ),
// //                       ),
// //                     ),
// //                   ),

// //                 _buildInputArea(),
// //               ],
// //             ),
// //     );
// //   }

// //   Widget _buildMessageBubble(ChatMessage msg) {
// //     return Align(
// //       alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
// //       child: Container(
// //         margin: const EdgeInsets.symmetric(vertical: 4),
// //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
// //         constraints: BoxConstraints(
// //           maxWidth: MediaQuery.of(context).size.width * 0.75,
// //         ),
// //         decoration: BoxDecoration(
// //           color: msg.isMe ? Colors.teal : Colors.white,
// //           borderRadius: BorderRadius.only(
// //             topLeft: const Radius.circular(12),
// //             topRight: const Radius.circular(12),
// //             bottomLeft: msg.isMe ? const Radius.circular(12) : Radius.zero,
// //             bottomRight: msg.isMe ? Radius.zero : const Radius.circular(12),
// //           ),
// //           boxShadow: [
// //             BoxShadow(
// //               color: Colors.black.withOpacity(0.05),
// //               blurRadius: 3,
// //               offset: const Offset(0, 1),
// //             ),
// //           ],
// //         ),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(
// //               msg.text,
// //               style: TextStyle(
// //                 color: msg.isMe ? Colors.white : Colors.black87,
// //                 fontSize: 16,
// //               ),
// //             ),
// //             const SizedBox(height: 4),
// //             Text(
// //               // Simple time formatting
// //               "${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}",
// //               style: TextStyle(
// //                 color: msg.isMe ? Colors.white70 : Colors.grey,
// //                 fontSize: 10,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildInputArea() {
// //     return Container(
// //       padding: const EdgeInsets.all(10),
// //       color: Colors.white,
// //       child: SafeArea(
// //         child: Row(
// //           children: [
// //             Expanded(
// //               child: Container(
// //                 decoration: BoxDecoration(
// //                   color: Colors.grey[200],
// //                   borderRadius: BorderRadius.circular(25),
// //                 ),
// //                 child: TextField(
// //                   controller: _textController,
// //                   onChanged: _onTextChanged, // 👈 Calls the API
// //                   decoration: const InputDecoration(
// //                     hintText: "Type a message...",
// //                     border: InputBorder.none,
// //                     contentPadding: EdgeInsets.symmetric(
// //                       horizontal: 20,
// //                       vertical: 10,
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //             ),
// //             const SizedBox(width: 8),
// //             FloatingActionButton(
// //               onPressed: _sendMessage,
// //               backgroundColor: Colors.teal,
// //               mini: true,
// //               elevation: 0,
// //               child: const Icon(Icons.send, size: 20),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
// import 'package:twilio_voice/twilio_voice.dart'; // No longer needed directly here, handled in service

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
  print("Handling a background message: ${message.messageId}");
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

  // 6. Setup Firebase Messaging & Twilio Voice
  await _initFirebaseMessaging();

  runApp(multiProviders());
}

Future<void> _initFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // Request Notification Permissions (Critical for iOS/Android 13+)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  final prefs = await SharedPreferences.getInstance();

  // Get FCM Token
  final token = await messaging.getToken();
  if (token != null && token.isNotEmpty) {
    print("FCM Token: $token");
    await prefs.setString("fcm_token", token);
  }

  // Listen for Token Refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("FCM Token Refreshed: $newToken");
    if (newToken.isNotEmpty) {
      await prefs.setString("fcm_token", newToken);
      // Notify Service to update Twilio
      await CallDeviceService.handleFcmTokenRefresh(newToken);
    }
  });

  // 7. Bootstrap Twilio Voice Service
  // This will handle fetching the access token from Laravel and registering with Twilio
  await CallDeviceService.bootstrap(forceRegister: true);
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
