import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:print_helper/models/search_modals.dart';
import 'package:print_helper/models/twilio_models.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/services/api_service.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_group_model.dart';
import '../models/chat_models.dart';
import '../../../models/profile_models.dart';
import '../../../services/api_routes.dart';
import '../service/chat_push_notify.dart';
import '../service/reverb_service.dart';
import '../service/voice_recorder_service.dart';
import '../../../utils/console_util.dart';
import '../../../widgets/loaders.dart';

class ChatPro extends ChangeNotifier {
  bool isConnecting = true;
  // NEW: Track user online status
  bool isOtherUserOnline = false;
  bool isOtherUserTyping = false;
  bool isChatScreenOpen = false;
  int? currentActiveConversationId;
  int totalUnreadCount = 0; // Aggregated badge count for nav
  String? _currentUserId; // Stored on socket init for group-event comparisons
  final Set<int> _groupRemovalInProgress =
      {}; // Deduplicates concurrent firings
  final List<ChatConversation> conversations = [];
  final List<ChatMessage> messages = [];
  ReverbSocketService? _chatListSocket; // Keeps global user events (new chats)
  ReverbSocketService? _conversationSocket;

  Timer? _typingThrottle;
  Timer? _typingAutoClear;

  GroupDetail? currentGroup;
  bool isGroupLoading = false;

  List<SearchUsers> searchResults = [];
  final Set<int> selectedUserIdss = {};
  final List<SearchUsers> selectedUsers = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _debounce;

  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;

  // Message search-related state
  List<ChatMessage> messageSearchResults = [];
  bool isSearching = false;
  String searchQuery = "";
  int searchTotalResults = 0;
  int searchCurrentPage = 1;
  int searchLastPage = 1;
  ProfileData? _userProfile;
  // String? get errorMessage => _errorMessage;
  ProfileData? get userProfile => _userProfile;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool isRecordingVoice = false;

  // Twilio Numbers
  List<TwilioCredential> twilioNumbers = [];
  bool isTwilioLoading = false;
  bool twilioHasError = false;

  // Twilio Clients with Contacts
  List<TwilioClient> twilioClients = [];
  bool isTwilioClientsLoading = false;
  bool twilioClientsHasError = false;
  // Twilio Pagination
  int twilioCurrentPage = 1;
  int twilioLastPage = 1;
  int twilioPerPage = 10;
  int twilioTotal = 0;

  // Twilio Credentials
  String? twilioAccountSid;
  String? twilioApiKeySid;
  String? twilioApiKeySecret;
  String? twilioTwimlAppSid;
  bool isTwilioCredentialsLoading = false;
  bool twilioCredentialsHasError = false;
  bool isTwilioSyncing = false;

  // Twilio Search Filters
  String? twilioSearchPhone;
  String? twilioSearchClient;
  String? twilioSearchContact;
  String? twilioSearchAccount;

  // Twilio Staff (Assigned Accounts)
  List<AssignedAccount> twilioStaff = [];
  bool isTwilioStaffLoading = false;
  bool twilioStaffHasError = false;
  int twilioNumbersRevision = 0;
  int twilioClientsRevision = 0;
  int twilioStaffRevision = 0;

  // Twilio API Credentials
  TwilioApiCredentials? twilioApiCredentials;

  Future<void> startDummyVoiceRecording() async {
    isRecordingVoice = true;
    notifyListeners();
    await _voiceRecorder.start();
  }

  /// ---------------- API HEADERS ----------------
  Future<Map<String, String>> apiHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token") ?? "";
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $authToken",
    };
  }

  /// Initiate a call via the backend API.
  /// Returns the call data map on success, or null on failure.
  Future<Map<String, dynamic>?> initiateCall({
    required String toNumber,
    int? toUserId,
    int? conversationId,
    bool record = true,
  }) async {
    // Print input parameters
    printData(
      title: "initiateCall - START",
      data:
          "toNumber: $toNumber, toUserId: $toUserId, conversationId: $conversationId, record: $record",
    );

    try {
      final headers = await apiHeaders();
      printData(title: "initiateCall - Headers", data: headers);

      final Map<String, dynamic> body = {
        "to_number": toNumber,
        "to_user_id": toUserId,
        if (conversationId != null) "conversation_id": conversationId,
        "record": record,
      };
      final payload = jsonEncode(body);
      printData(title: "initiateCall - Payload", data: payload);

      printData(
        title: "initiateCall - API Call",
        data: "Calling ${ApiRoutes.initiateCall}",
      );

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.initiateCall,
        headers: headers,
        payload: payload,
      );

      printData(title: "initiateCall - Response", data: data);

      if (data is Map<String, dynamic> && data["success"] == true) {
        printData(title: "initiateCall - SUCCESS", data: data["data"]);
        return data["data"] as Map<String, dynamic>?;
      } else {
        final msg = data is Map ? data["message"] : "Failed to initiate call";
        printData(
          title: "initiateCall - FAILED",
          data: "Message: $msg, Full response: $data",
          e: true,
        );
        showToast(message: msg ?? "Failed to initiate call");
      }
    } catch (e) {
      printData(title: "initiateCall - EXCEPTION", data: e, e: true);
      showToast(message: "Failed to initiate call");
    }

    printData(title: "initiateCall - END", data: "Returning null");
    return null;
  }

  Future<Map<String, dynamic>?> getOutboundVoiceUrl({
    required String toNumber,
    int? conversationId,
    required bool record,
    String? toUserId,
  }) async {
    try {
      final headers = await apiHeaders();
      String url =
          "${ApiRoutes.baseUrl}calls/outbound-voice-url?"
          "to_number=$toNumber"
          "&record=${record ? 1 : 0}";
      if (conversationId != null) {
        url += "&conversation_id=$conversationId";
      }
      url += "&to_user_id=${toUserId ?? ''}";
      printData(title: "getOutboundVoiceUrl - URL", data: url);
      final response = await http.get(Uri.parse(url), headers: headers);
      printData(title: "getOutboundVoiceUrl - Response", data: response.body);
      if (response.statusCode != 200) {
        showToast(message: "Failed to get voice URL: ${response.statusCode}");
        return null;
      }
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        return data["data"];
      } else {
        showToast(message: data["message"] ?? "Failed to get voice URL");
        return null;
      }
    } catch (e) {
      printData(title: "getOutboundVoiceUrl - EXCEPTION", data: e, e: true);
      showToast(message: "Failed to connect for external call");
      return null;
    }
  }

  Future<String?> getTwilioAccessToken({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString("twilio_access_token");
    if (!forceRefresh && cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final headers = await apiHeaders();
      printData(
        title: "Twilio access token request:",
        data: "${ApiRoutes.baseUrl}${ApiRoutes.twilioAccessToken}",
      );
      printData(title: "Twilio access token headers:", data: headers);
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.twilioAccessToken,
        headers: headers,
        showRes: true,
      );
      printData(title: "Twilio access token raw response:", data: data);
      if (data is Map<String, dynamic>) {
        final dynamic payload = data["data"] ?? data;
        printData(title: "Twilio access token payload:", data: payload);
        final token = payload is Map<String, dynamic>
            ? (payload["token"] ?? payload["access_token"])
            : null;
        printData(title: "Twilio access token parsed:", data: token);
        if (token is String && token.isNotEmpty) {
          await prefs.setString("twilio_access_token", token);
          return token;
        }
      }
    } catch (e) {
      printData(title: "Twilio access token error:", data: e, e: true);
    }
    return null;
  }

  Future<List<CallFromNumber>> fetchCallFromNumbers() async {
    try {
      final url = Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.callFromNumbers}");
      final headers = await apiHeaders();
      printData(title: "call-from-numbers url:", data: url);
      printData(title: "call-from-numbers headers:", data: headers);
      final res = await http.get(url, headers: headers);
      printData(title: "call-from-numbers status:", data: res.statusCode);
      printData(title: "call-from-numbers body:", data: res.body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> numbers = data['data']['numbers'] ?? [];
          return numbers
              .map((e) => CallFromNumber.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      printData(title: "fetchCallFromNumbers error:", data: e, e: true);
    }
    return [];
  }

  Future<CallPopupData?> fetchCallPopupData(int conversationId) async {
    try {
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.callPopupData(conversationId)}",
      );
      final headers = await apiHeaders();
      printData(title: "call-popup-data url:", data: url);
      final res = await http.get(url, headers: headers);
      printData(title: "call-popup-data status:", data: res.statusCode);
      printData(title: "call-popup-data body:", data: res.body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          return CallPopupData.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      printData(title: "fetchCallPopupData error:", data: e, e: true);
    }
    return null;
  }

  Future<List<CallFromNumber>> fetchUserTwilioNumbers(int userId) async {
    try {
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.userTwilioNumbers(userId)}",
      );
      final headers = await apiHeaders();
      printData(title: "user-twilio-numbers url:", data: url);
      printData(title: "user-twilio-numbers headers:", data: headers);
      final res = await http.get(url, headers: headers);
      printData(title: "user-twilio-numbers status:", data: res.statusCode);
      printData(title: "user-twilio-numbers body:", data: res.body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> numbers = data['data']['numbers'] ?? [];
          return numbers
              .map((e) => CallFromNumber.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      printData(title: "fetchUserTwilioNumbers error:", data: e, e: true);
    }
    return [];
  }

  Future<void> fetchTwilioApiCredentials() async {
    isTwilioCredentialsLoading = true;
    notifyListeners();
    try {
      final headers = await apiHeaders();
      final res = await ApiService().getDataFromApi(
        api: ApiRoutes.twilioCredentials,
        headers: headers,
      );
      printData(title: "fetchTwilioApiCredentials response:", data: res);
      if (res is Map<String, dynamic> && res['success'] == true) {
        twilioApiCredentials = TwilioApiCredentials.fromJson(res['data']);
      }
    } catch (e) {
      printData(title: "fetchTwilioApiCredentials error:", data: e, e: true);
    } finally {
      isTwilioCredentialsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTwilioApiCredentials({
    required int id,
    required String accountSid,
    required String apiKeySid,
    required String apiKeySecret,
    required String twimlAppSid,
  }) async {
    try {
      final headers = await apiHeaders();
      final payload = jsonEncode({
        "id": id,
        "account_sid": accountSid,
        "api_key_sid": apiKeySid,
        "api_key_secret": apiKeySecret,
        "twiml_app_sid": twimlAppSid,
      });

      printData(title: "updateTwilioApiCredentials payload:", data: payload);

      final res = await ApiService().postDataToApi(
        api: ApiRoutes.twilioCredentials,
        headers: headers,
        payload: payload,
      );

      printData(title: "updateTwilioApiCredentials response:", data: res);

      if (res is Map<String, dynamic> && res['success'] == true) {
        showToast(message: res['message'] ?? "Credentials saved successfully");
        // Update local model
        if (res['data'] != null) {
          twilioApiCredentials = TwilioApiCredentials.fromJson(res['data']);
          notifyListeners();
        }
        return true;
      } else {
        showToast(message: res['message'] ?? "Failed to save credentials");
      }
    } catch (e) {
      printData(title: "updateTwilioApiCredentials error:", data: e, e: true);
      showToast(message: "An error occurred while saving");
    }
    return false;
  }

  /// ---------------- INIT CHAT LIST SOCKET ----------------
  Future<void> initChatListSocket({
    required String userId,
    required dynamic context,
  }) async {
    if (_chatListSocket != null) return;
    _currentUserId = userId; // store for group-event comparisons
    final headers = await apiHeaders();
    _chatListSocket = ReverbSocketService(
      onConnected: () {
        printData(title: "✅ Chat list socket connected", data: "");
      },
      onMessageReceived: (data) {
        printData(title: "📩 CHAT LIST DATA:", data: data);
        _handleRealtimeChatListMessage(data, userId);
      },
      onTypingReceived: (isTyping) {
        isOtherUserTyping = isTyping;
        notifyListeners();
        _typingAutoClear?.cancel();
        if (isTyping) {
          _typingAutoClear = Timer(const Duration(seconds: 3), () {
            isOtherUserTyping = false;
            notifyListeners();
          });
        }
      },
      onConversationCreated: (data) {
        _handleNewConversation(data);
      },
      onGroupMemberAdded: (data) {
        _handleGroupMemberAdded(data);
      },
      onGroupMemberRemoved: (data) {
        _handleGroupMemberRemoved(data);
      },
      onConversationUpdated: (data) {
        _handleConversationUpdated(data);
      },
      onUnreadCountUpdated: (data) {
        _handleUnreadCountUpdated(data);
      },
    );
    _chatListSocket!.connectUserChannel(
      host: ApiRoutes.socketHost,
      port: ApiRoutes.socketPort,
      appKey: ApiRoutes.appKey,
      userId: userId,
      authEndpoint: Uri.parse("${ApiRoutes.baseUrl}broadcasting/auth"),
      headers: headers,
      context: context,
    );
  }

  Future<void> initConversationSocket({
    required int conversationId,
    required int currentUserId,
  }) async {
    disconnectConversationSocket();
    currentActiveConversationId = conversationId;
    final headers = await apiHeaders();
    _conversationSocket = ReverbSocketService(
      currentUserId: currentUserId.toString(),
      onConnected: () {
        printData(title: "✅ Conversation socket connected", data: "");
      },
      onMessageReceived: (data) {
        _handleRealtimeConversationMessage(data, currentUserId, conversationId);
      },
      onTypingReceived: (isTyping) {
        isOtherUserTyping = isTyping;
        notifyListeners();
        _typingAutoClear?.cancel();
        if (isTyping) {
          _typingAutoClear = Timer(const Duration(seconds: 4), () {
            isOtherUserTyping = false;
            notifyListeners();
          });
        }
      }, // 3. ✅ NEW: Message Deleted
      onMessageDeleted: (data) {
        _handleMessageDeleted(data);
      },
      // 4. ✅ NEW: Message Status (Read/Delivered)
      onMessageStatusUpdated: (data) {
        _handleMessageStatusUpdate(data);
      },
      // 5. ✅ NEW: User Status (Online/Offline)
      onUserStatusChanged: (data) {
        _handleUserStatusChange(data);
      },
    );
    _conversationSocket!.connectConversationChannel(
      host: ApiRoutes.socketHost,
      port: ApiRoutes.socketPort,
      appKey: ApiRoutes.appKey,
      conversationId: conversationId.toString(),
      authEndpoint: Uri.parse("${ApiRoutes.baseUrl}broadcasting/auth"),
      headers: headers,
    );
  }

  void disconnectConversationSocket() {
    if (_conversationSocket != null) {
      printData(title: "🔌 Disconnecting Conversation Socket...", data: "");
      _conversationSocket!.disconnect();
      _conversationSocket = null;
      isOtherUserTyping = false;
      isOtherUserOnline = false;
      currentActiveConversationId = null;
    }
  }

  // 1. Handle New Message (Existing)
  // void _handleRealtimeConversationMessage(
  //   Map<String, dynamic> data,
  //   int currentUserId,
  //   int conversationId,
  // ) {
  //   final payload = data.containsKey('message') && data['message'] is Map
  //       ? data['message']
  //       : data;
  //   if (payload['conversation_id'].toString() != conversationId.toString()) {
  //     return;
  //   }
  //   final msg = ChatMessage.fromJson(payload, currentUserId);
  //   if (msg.senderId == currentUserId) return; // Prevent duplicate self-message
  //   messages.insert(0, msg);
  //   debugPrint("📩 Message received. ChatScreenOpen: $isChatScreenOpen");
  //   if (!isChatScreenOpen) {
  //     NotificationService.instance.showChatNotification(
  //       title: "New message",
  //       body: msg.message,
  //       id: msg.id,
  //     );
  //   }
  //   // If we are in the chat, mark as read immediately via API
  //   markConversAsRead(conversationId);
  //   notifyListeners();
  // }

  void _handleRealtimeConversationMessage(
    Map<String, dynamic> data,
    int currentUserId,
    int conversationId,
  ) {
    final payload = data.containsKey('message') && data['message'] is Map
        ? data['message']
        : data;
    if (payload['conversation_id'].toString() != conversationId.toString()) {
      return;
    }
    final msg = ChatMessage.fromJson(payload, currentUserId);

    /// Prevent duplicate self-message (but allow backend-generated call messages)
    final isCallMessage = msg.type == 'call' || msg.isCallRecording;
    if (msg.senderId == currentUserId && !isCallMessage) return;

    /// Check if message already exists
    final existingIndex = messages.indexWhere((m) => m.id == msg.id);

    /// If exists → update message
    if (existingIndex != -1) {
      messages[existingIndex] = msg;
    }
    /// If new → insert at top
    else {
      messages.insert(0, msg);

      /// Show notification only for new messages & when chat is closed
      if (!isChatScreenOpen) {
        NotificationService.instance.showChatNotification(
          title: "New message",
          body: msg.message,
          id: msg.id,
        );
      }
    }
    printData(
      title: "📩 Message received. ChatScreenOpen:",
      data: isChatScreenOpen,
    );
    printData(title: "📩 Message received Payload:", data: payload);

    /// If chat screen is open, mark as read
    if (isChatScreenOpen) {
      markConversAsRead(conversationId);
    }

    notifyListeners();
  }

  // 2. ✅ Handle Message Deletion
  void _handleMessageDeleted(Map<String, dynamic> data) {
    // Expected data: { "id": 123, "conversation_id": 456 }
    final messageId = data['id'];
    if (messageId == null) return;
    messages.removeWhere((m) => m.id.toString() == messageId.toString());
    notifyListeners();
  }

  void _handleMessageStatusUpdate(Map<String, dynamic> data) {
    final status = data['status']; // "read" | "delivered"
    final messageId = data['id'];
    if (messageId == null) return;
    final index = messages.indexWhere(
      (m) => m.id.toString() == messageId.toString(),
    );
    if (index == -1) return;
    if (status == 'read') {
      messages[index] = messages[index].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
    }
    if (status == 'delivered') {
      messages[index] = messages[index].copyWith(
        isDelivered: true,
        deliveredAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  // 4. ✅ Handle User Online Status
  void _handleUserStatusChange(Map<String, dynamic> data) {
    // Expected data: { "user_id": 99, "status": "online" }
    final status = data['status']; // 'online' or 'offline'
    isOtherUserOnline = (status == 'online');
    notifyListeners();
  }

  // 5. ✅ Handle New Conversation (Chat List)
  void _handleNewConversation(Map<String, dynamic> data) {
    // Add logic here if you want new chats to appear instantly in the list
    // strictly parsing data into ChatConversation and inserting at index 0
    try {
      final newChat = ChatConversation.fromJson(data['conversation']);
      final existingIndex = conversations.indexWhere((c) => c.id == newChat.id);
      if (existingIndex != -1) {
        // Replace existing conversation to avoid duplicates
        conversations[existingIndex] = newChat;
      } else {
        conversations.insert(0, newChat);
      }
      notifyListeners();
    } catch (e) {
      printData(title: "Error parsing new conversation", data: e, e: true);
    }
  }

  // 6. ✅ Handle Group Member Added
  void _handleGroupMemberAdded(Map<String, dynamic> data) async {
    try {
      final conversationId = data['conversation_id'];
      if (conversationId == null) return;
      printData(title: "Member added to group", data: conversationId);

      // If the event payload contains the full conversation, use it directly
      // to avoid an API race condition with message.sent
      if (data['conversation'] != null) {
        try {
          final newConvo = ChatConversation.fromJson(data['conversation']);
          final index = conversations.indexWhere((c) => c.id == newConvo.id);
          if (index != -1) {
            final existing = conversations[index];
            // Preserve existing latestMessage if it was already set by message.sent
            final merged = ChatConversation(
              id: newConvo.id,
              type: newConvo.type,
              title: newConvo.title,
              participants: newConvo.participants,
              latestMessage: existing.latestMessage ?? newConvo.latestMessage,
              unreadCount: newConvo.unreadCount,
              updatedAt: newConvo.updatedAt,
              isDefault: newConvo.isDefault,
              image: newConvo.image,
            );
            conversations[index] = merged;
          } else {
            conversations.insert(0, newConvo);
          }
          notifyListeners();
          return;
        } catch (e) {
          printData(
            title: "Error parsing group.member.added conversation",
            data: e,
            e: true,
          );
        }
      }

      // Fallback: fetch from API if no conversation in payload
      // Add a short delay so that message.sent can process first
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateSingleConversation(conversationId);
      notifyListeners();
    } catch (e) {
      printData(title: "Error handling group member added:", data: e, e: true);
    }
  }

  // 7. ✅ Handle Group Member Removed
  void _handleGroupMemberRemoved(Map<String, dynamic> data) async {
    try {
      final rawId = data['conversation_id'];
      if (rawId == null) return;
      final conversationId = int.tryParse(rawId.toString());
      if (conversationId == null) return;

      // Deduplicate: drop if we're already processing this conversation_id
      if (_groupRemovalInProgress.contains(conversationId)) {
        printData(
          title: "➖ GROUP MEMBER REMOVED (duplicate, skipping)",
          data: conversationId,
        );
        return;
      }
      _groupRemovalInProgress.add(conversationId);

      // Note: backend does not send user_id in the payload.
      // We always call the API; a 403/404 response means the current
      // user was removed, and _updateSingleConversation handles that.
      final removedUserId = data['user_id']?.toString();
      printData(
        title: "➖ Group member removed",
        data:
            "removedUserId=$removedUserId currentUserId=$_currentUserId convoId=$conversationId",
      );

      // Fast-path only when the backend does include user_id
      if (removedUserId != null &&
          _currentUserId != null &&
          removedUserId == _currentUserId) {
        final index = conversations.indexWhere(
          (c) => c.id.toString() == conversationId.toString(),
        );
        if (index != -1) {
          conversations.removeAt(index);
          printData(
            title: "🗑️ Removed conversation (current user removed)",
            data: conversationId,
          );
        }
        notifyListeners();
        _groupRemovalInProgress.remove(conversationId);
        return;
      }

      // Fallback: let the API tell us (403 = removed, 200 = just update metadata)
      await _updateSingleConversation(conversationId);
      notifyListeners();
    } catch (e) {
      printData(
        title: "Error handling group member removed:",
        data: e,
        e: true,
      );
    } finally {
      final rawId = data['conversation_id'];
      final conversationId = int.tryParse(rawId?.toString() ?? '');
      if (conversationId != null)
        _groupRemovalInProgress.remove(conversationId);
    }
  }

  // 8. ✅ Handle Conversation Updated (title / image / participants)
  void _handleConversationUpdated(Map<String, dynamic> data) async {
    try {
      final conversationId = data['conversation_id'];
      if (conversationId == null) return;

      printData(
        title: "🔄 Conversation updated",
        data: "convoId=$conversationId",
      );

      // If the full conversation object is embedded, use it directly
      if (data['conversation'] != null) {
        try {
          final updatedConvo = ChatConversation.fromJson(data['conversation']);
          final index = conversations.indexWhere(
            (c) => c.id == updatedConvo.id,
          );
          if (index != -1) {
            final existing = conversations[index];
            conversations[index] = ChatConversation(
              id: updatedConvo.id,
              type: updatedConvo.type,
              title: updatedConvo.title,
              participants: updatedConvo.participants,
              latestMessage:
                  existing.latestMessage ?? updatedConvo.latestMessage,
              unreadCount: existing.unreadCount,
              updatedAt: updatedConvo.updatedAt,
              isDefault: updatedConvo.isDefault,
              image: updatedConvo.image,
            );
          }
          notifyListeners();
          return;
        } catch (e) {
          printData(
            title: "Error parsing conversation.updated payload",
            data: e,
            e: true,
          );
        }
      }

      // Fallback: fetch from API
      await _updateSingleConversation(conversationId);
      notifyListeners();
    } catch (e) {
      printData(
        title: "Error handling conversation updated:",
        data: e,
        e: true,
      );
    }
  }

  /// ---------------- UPDATE SINGLE CONVERSATION ----------------
  Future<void> _updateSingleConversation(int conversationId) async {
    try {
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}chat/conversations/$conversationId"),
        headers: await apiHeaders(),
      );
      printData(
        title: "_updateSingleConversation response:",
        data: res.statusCode,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        printData(title: "_updateSingleConversation data:", data: data);
        if (data['success'] == true && data['data'] != null) {
          final updatedConvo = ChatConversation.fromJson(data['data']);
          // Find and replace the conversation in the list
          final index = conversations.indexWhere((c) => c.id == conversationId);
          if (index != -1) {
            final existing = conversations[index];
            // Preserve existing latestMessage if API doesn't return one
            final merged = updatedConvo.latestMessage != null
                ? updatedConvo
                : ChatConversation(
                    id: updatedConvo.id,
                    type: updatedConvo.type,
                    title: updatedConvo.title,
                    participants: updatedConvo.participants,
                    latestMessage: existing.latestMessage,
                    unreadCount: updatedConvo.unreadCount,
                    updatedAt: updatedConvo.updatedAt,
                    isDefault: updatedConvo.isDefault,
                    image: updatedConvo.image,
                  );
            conversations[index] = merged;
            printData(
              title: "Updated conversation in list",
              data: conversationId,
            );
          } else {
            // If not found, add to top (new conversation)
            conversations.insert(0, updatedConvo);
            printData(
              title: "Added new conversation to list",
              data: conversationId,
            );
          }
        } else if (data['success'] == false) {
          // If backend returns success=false, user might have been removed
          printData(
            title: "Backend returned success=false for conversation",
            data: conversationId,
            e: true,
          );
          final index = conversations.indexWhere((c) => c.id == conversationId);
          if (index != -1) {
            conversations.removeAt(index);
            printData(
              title: "Removed conversation from list (no access)",
              data: conversationId,
            );
          }
        }
      } else if (res.statusCode == 403 || res.statusCode == 404) {
        // User no longer has access to this conversation (removed from group)
        printData(
          title: "User removed from conversation",
          data: conversationId,
        );
        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          conversations.removeAt(index);
          printData(
            title: "Removed conversation from list",
            data: conversationId,
          );
        }
      }
    } catch (e) {
      printData(title: "_updateSingleConversation error:", data: e, e: true);
    }
  }

  /// ---------------- HANDLE REALTIME MESSAGE (CHAT LIST) ----------------
  // void _handleRealtimeChatListMessage(
  //   Map<String, dynamic> data,
  //   String currentUserId,
  // ) {
  //   final conversationId = data['conversation_id'];
  //   final senderId = data['user_id'];
  //   final index = conversations.indexWhere(
  //     (c) => c.id.toString() == conversationId.toString(),
  //   );
  //   // if (index == -1) {
  //   //   // Optional: Reload list if a new conversation appears that isn't in the list yet
  //   //   // loadConversations();
  //   //   return;
  //   // }
  //   final old = conversations[index];
  //   final latestMessage = ChatLatestMessage.fromJson(data);

  //   final existingIndex = messages.indexWhere((m) {
  //     logData(title: "m.id, m.message", data: "${m.id}, ${m.message}");

  //     logData(title: "latestMessage.id", data: latestMessage.id);
  //     return m.id == latestMessage.id;
  //   });
  //   logData(title: "existingIndex", data: '$existingIndex');

  //   final insertIndex = existingIndex != -1 ? existingIndex : 0;
  //   logData(title: "insertIndex", data: insertIndex);

  //   final updatedConversation = ChatConversation(
  //     id: old.id,
  //     type: old.type,
  //     title: old.title,
  //     participants: old.participants,
  //     latestMessage: latestMessage,
  //     unreadCount: senderId.toString() == currentUserId
  //         ? old.unreadCount
  //         : old.unreadCount + 1,
  //     updatedAt: DateTime.now(),
  //     isDefault: old.isDefault,
  //   );
  //   conversations
  //     ..removeAt(index)
  //     ..insert(insertIndex, updatedConversation);

  //   NotificationService.instance.showChatNotification(
  //     title: "New message From ${latestMessage.userName}",
  //     body: latestMessage.message,
  //     id: latestMessage.id,
  //   );
  //   notifyListeners();
  // }

  void _handleRealtimeChatListMessage(
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final conversationId = data['conversation_id'];
    final senderId = data['user_id'];

    final convoIndex = conversations.indexWhere(
      (c) => c.id.toString() == conversationId.toString(),
    );

    printData(
      title: "_handleRealtimeChatListMessage",
      data:
          "type=${data['type']} convoId=$conversationId convoIndex=$convoIndex totalConvos=${conversations.length}",
    );

    if (convoIndex == -1) {
      // If the conversation is not in the list but the payload provides it, add it
      if (data['conversation'] != null) {
        try {
          final newChat = ChatConversation.fromJson(data['conversation']);
          final latestMessage = ChatLatestMessage.fromJson(data);

          final updatedNewChat = ChatConversation(
            id: newChat.id,
            type: newChat.type,
            title: newChat.title,
            participants: newChat.participants,
            latestMessage: latestMessage,
            unreadCount: senderId.toString() == currentUserId ? 0 : 1,
            updatedAt: DateTime.now(),
            isDefault: newChat.isDefault,
            image: newChat.image,
          );

          conversations.insert(0, updatedNewChat);

          if (senderId.toString() != currentUserId) {
            totalUnreadCount = totalUnreadCount + 1;
            NotificationService.instance.showChatNotification(
              title: "New message from ${latestMessage.userName ?? 'User'}",
              body: latestMessage.message,
              id: latestMessage.id,
            );
          }

          _recomputeTotalUnreadFromList();
          notifyListeners();
        } catch (e) {
          printData(
            title: "Error adding unknown conversation from chat list message",
            data: e,
            e: true,
          );
        }
      }
      return;
    }

    final oldConversation = conversations[convoIndex];
    final latestMessage = ChatLatestMessage.fromJson(data);

    /// Check if this message already exists
    final existingIndex = messages.indexWhere((m) => m.id == latestMessage.id);

    /// Update unread count
    final unreadCount = senderId.toString() == currentUserId
        ? oldConversation.unreadCount
        : oldConversation.unreadCount + 1;

    // final updatedConversation = oldConversation.copyWith(
    //   latestMessage: latestMessage,
    //   unreadCount: unreadCount,
    //   updatedAt: DateTime.now(),
    // );

    final updatedConversation = ChatConversation(
      id: oldConversation.id,
      type: oldConversation.type,
      title: oldConversation.title,
      participants: oldConversation.participants,
      latestMessage: latestMessage,
      unreadCount: unreadCount,
      updatedAt: DateTime.now(),
      isDefault: oldConversation.isDefault,
      image: oldConversation.image,
    );

    /// Remove old position
    conversations.removeAt(convoIndex);

    /// 👉 If message exists → keep it in same position
    /// 👉 If new message → move to top (index 0)
    final insertIndex = existingIndex != -1 ? convoIndex : 0;

    conversations.insert(insertIndex, updatedConversation);

    // Keep aggregated unread badge in sync for nav
    if (senderId.toString() != currentUserId && existingIndex == -1) {
      totalUnreadCount = totalUnreadCount + 1;
    }

    _recomputeTotalUnreadFromList();

    /// Show notification only for new incoming messages
    if (senderId.toString() != currentUserId && existingIndex == -1) {
      NotificationService.instance.showChatNotification(
        title: "New message from ${latestMessage.userName}",
        body: latestMessage.message,
        id: latestMessage.id,
      );
    }

    notifyListeners();
  }

  /// ---------------- LOAD CONVERSATIONS ----------------
  Future<void> loadConversations() async {
    Loaders.show();
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}chat/conversations"),
        headers: await apiHeaders(),
      );
      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}");
      }
      final decoded = jsonDecode(res.body);
      totalUnreadCount = decoded['total_unread_count'] ?? 0;
      printData(title: "totalUnreadCount:", data: totalUnreadCount);
      final List list = decoded['data'] ?? [];

      conversations
        ..clear()
        ..addAll(
          list.map(
            (e) => ChatConversation.fromJson(
              e,
              totalUnreadCount: totalUnreadCount,
            ),
          ),
        );

      _recomputeTotalUnreadFromList();
    } catch (e) {
      printData(title: "loadConversations error:", data: e, e: true);
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  void _handleUnreadCountUpdated(Map<String, dynamic> data) {
    try {
      final dynamic raw =
          data['total_unread_count'] ?? data['count'] ?? data['unread_count'];
      final int parsed = int.tryParse(raw?.toString() ?? '') ?? 0;
      totalUnreadCount = parsed;
      notifyListeners();
    } catch (e) {
      printData(title: "_handleUnreadCountUpdated error", data: e, e: true);
    }
  }

  Future<void> fetchMessages({
    required String conversationId,
    required int currentUserId,
    int? lastPage,
    bool loadMore = false,
  }) async {
    if (_isLoadingMore || (!_hasMore && loadMore)) return;
    if (!loadMore) {
      // initial load: show loader and clear any previous state
      Loaders.show();
      notifyListeners();
    } else {
      _isLoadingMore = true;
      notifyListeners();
      await delayed(millisec: 1000);
    }
    final pageToLoad = _currentPage;
    try {
      final res = await http.get(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages?page=$pageToLoad",
        ),
        headers: await apiHeaders(),
      );
      printData(title: "Uri", data: res.request!.url);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        // Try to read last_page from API meta if caller didn't provide it
        final metaLastPage = decoded['meta']?['last_page'] ?? lastPage ?? 1;
        final List data = decoded['data'] ?? [];
        final fetched = data
            .map((e) => ChatMessage.fromJson(e, currentUserId))
            .toList()
            .reversed
            .toList(); // already oldest→newest
        messages.addAll(fetched);
        // go to next page
        _currentPage++;
        // check if more pages exist
        _hasMore = _currentPage <= metaLastPage;
        printData(
          title: "Pagination",
          data:
              'currentPage $_currentPage lastPage $metaLastPage hasMore $_hasMore',
        );
      }
    } catch (e) {
      printData(title: "fetchMessages error", data: e, e: true);
    } finally {
      _isLoadingMore = false;
      if (!loadMore) Loaders.hide();
      notifyListeners();
    }
  }

  /// Cleanup on screen exit
  void reset() {
    messages.clear();
    _currentPage = 1;
    _hasMore = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// ---------------- SEARCH MESSAGES ----------------
  Future<void> searchMessages({
    required String conversationId,
    required String query,
    required int currentUserId,
  }) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    isSearching = true;
    searchQuery = query;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages/search?query=${Uri.encodeComponent(query)}",
        ),
        headers: await apiHeaders(),
      );
      printData(title: "Search URI", data: res.request!.url);
      printData(title: "Search Response", data: res.body);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true) {
          final List data = decoded['data'] ?? [];
          final meta = decoded['meta'];
          messageSearchResults = data
              .map((e) => ChatMessage.fromJson(e, currentUserId))
              .toList();
          // If meta is available, use it; otherwise use data length
          searchTotalResults = meta?['total'] ?? data.length;
          searchCurrentPage = meta?['current_page'] ?? 1;
          searchLastPage = meta?['last_page'] ?? 1;
          printData(title: "Search found", data: "$searchTotalResults results");
        }
      }
    } catch (e) {
      printData(title: "searchMessages error", data: e, e: true);
    } finally {
      notifyListeners();
    }
  }

  void clearSearch() {
    messageSearchResults.clear();
    isSearching = false;
    searchQuery = "";
    searchTotalResults = 0;
    searchCurrentPage = 1;
    searchLastPage = 1;
    notifyListeners();
  }

  /// ---------------- SEND MESSAGE ----------------
  // Future<void> sendMessage({
  //   required String text,
  //   required int conversationId,
  //   required int currentUserId,
  // }) async {
  //   if (text.trim().isEmpty) return;
  //   final tempMessage = ChatMessage(
  //     id: DateTime.now().millisecondsSinceEpoch,
  //     senderId: currentUserId,
  //     conversationId: conversationId,
  //     isMe: true,
  //     message: text,
  //     createdAt: DateTime.now(),
  //   );
  //   // Only add to UI list if we are currently inside THIS specific chat
  //   if (currentActiveConversationId == conversationId) {
  //     messages.insert(0, tempMessage);
  //   }
  //   // messages.insert(0, tempMessage);
  //   final index = conversations.indexWhere((c) => c.id == conversationId);
  //   if (index != -1) {
  //     final old = conversations[index];
  //     final updatedConversation = ChatConversation(
  //       id: old.id,
  //       type: old.type,
  //       title: old.title,
  //       participants: old.participants,
  //       latestMessage: ChatLatestMessage(
  //         id: tempMessage.id,
  //         message: text,
  //         type: "text",
  //         createdAt: DateTime.now(),
  //         userId: currentUserId,
  //         userName: userProfile?.name ?? "You",
  //       ),
  //       unreadCount: 0, // sender = me
  //       updatedAt: DateTime.now(),
  //       isDefault: old.isDefault,
  //       image: old.image,
  //     );
  //     conversations
  //       ..removeAt(index)
  //       ..insert(0, updatedConversation);
  //   }
  //   notifyListeners();
  //   /// API call
  //   try {
  //     await http.post(
  //       Uri.parse(
  //         "${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages",
  //       ),
  //       headers: await apiHeaders(),
  //       body: jsonEncode({"message": text, "type": "text"}),
  //     );
  //   } catch (e) {
  //     debugPrint("sendMessage error: $e");
  //   }
  // }               //old

  // Inside ChatPro class

  Future<void> sendMessage({
    required String text,
    required int conversationId,
    required int currentUserId,
    String type = 'text',
    String? audioUrl,
    int? audioDuration,
  }) async {
    // 1. Create Optimistic Message
    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      senderId: currentUserId,
      conversationId: conversationId,
      isMe: true,
      message: text,
      createdAt: DateTime.now(),
      type: type, //  Use passed type
      audioUrl: audioUrl, // Use passed URL
      audioDuration: audioDuration,
    );
    // 2. Add to UI List (Only if in current chat)
    if (currentActiveConversationId == conversationId) {
      messages.insert(0, tempMessage);
    }
    // 3. Update Chat List "Latest Message"
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final old = conversations[index];
      // Determine preview text based on type
      String previewText = text;
      if (type == 'voice') previewText = "🎙️Voice Message";
      if (type == 'image') previewText = "📷 Image";
      final updatedConversation = ChatConversation(
        id: old.id,
        type: old.type,
        title: old.title,
        participants: old.participants,
        latestMessage: ChatLatestMessage(
          id: tempMessage.id,
          message: previewText, //  Show correct preview
          type: type,
          createdAt: DateTime.now(),
          userId: currentUserId,
          userName: userProfile?.name ?? "You",
        ),
        unreadCount: 0,
        updatedAt: DateTime.now(),
        isDefault: old.isDefault,
        image: old.image,
      );
      conversations
        ..removeAt(index)
        ..insert(0, updatedConversation);
    }
    notifyListeners();
    try {
      final Map<String, dynamic> body = {"message": text, "type": type};
      // If forwarding voice, include the URL and Duration
      if (type == 'voice' && audioUrl != null) {
        body['audio_url'] = audioUrl;
        body['voice_duration'] = audioDuration;
      }
      await http.post(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages",
        ),
        headers: await apiHeaders(),
        body: jsonEncode(body),
      );
      printData(title: "📤 MESSAGE SENT (API):", data: body);
    } catch (e) {
      printData(title: "sendMessage error", data: e, e: true);
    }
  }

  /// ---------------- TYPING ----------------

  void onTextTyping({required int conversationId, required String text}) {
    if (conversationId <= 0) return;
    _typingThrottle?.cancel();
    final isTyping = text.isNotEmpty;
    _typingThrottle = Timer(const Duration(milliseconds: 1000), () {
      sendTypingStatus(conversationId: conversationId, isTyping: isTyping);
    });
    if (text.length == 1) {
      sendTypingStatus(conversationId: conversationId, isTyping: true);
    }
  }

  Future<void> sendTypingStatus({
    required int conversationId,
    required bool isTyping,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/typing",
        ),
        headers: await apiHeaders(),
        body: jsonEncode({"is_typing": isTyping ? "true" : "false"}),
      );
      printData(title: "Typing status sent", data: isTyping);
      printData(title: "Uri", data: res.request!.url);

      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}");
      }
    } catch (_) {}
  }

  /// MARK CONVERSATION AS READ
  Future<void> markConversAsRead(int conversationId) async {
    try {
      final res = await http.post(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/read",
        ),
        headers: await apiHeaders(),
      );
      if (res.statusCode == 200) {
        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final int unreadBefore = conversations[index].unreadCount;
          totalUnreadCount = totalUnreadCount - unreadBefore;
          if (totalUnreadCount < 0) totalUnreadCount = 0;
          conversations[index].unreadCount = 0;
          _recomputeTotalUnreadFromList();
          notifyListeners();
        }
        printData(title: "Marked as read", data: conversationId);
      } else {
        printData(
          title: "Failed to mark as read",
          data: "${res.statusCode}: ${res.body}",
          e: true,
        );
      }
    } catch (e) {
      printData(title: "markConversationAsRead error", data: e, e: true);
    }
  }

  void _recomputeTotalUnreadFromList() {
    final int sum = conversations.fold<int>(
      0,
      (acc, c) => acc + (c.unreadCount),
    );
    totalUnreadCount = sum;
  }

  Future<bool> createGroup({
    required String title,
    required List<int> userIds,
    File? image,
    required BuildContext context,
  }) async {
    Loaders.show();
    notifyListeners();
    try {
      final url = Uri.parse('${ApiRoutes.baseUrl}chat/conversations');
      final request = http.MultipartRequest('POST', url);
      final headers = await apiHeaders();
      request.headers.addAll(headers);
      request.fields['type'] = 'group';
      request.fields['title'] = title;
      for (int i = 0; i < userIds.length; i++) {
        request.fields['user_ids[$i]'] = userIds[i].toString();
      }
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // ✅ Immediately inject the new group conversation into the chat list
        // so it appears live without waiting for a Reverb event
        try {
          final raw = data['data'];
          if (raw != null) {
            final newConvo = ChatConversation.fromJson(
              raw is Map<String, dynamic>
                  ? raw
                  : raw['conversation'] as Map<String, dynamic>,
            );
            final existingIndex = conversations.indexWhere(
              (c) => c.id == newConvo.id,
            );
            if (existingIndex == -1) {
              conversations.insert(0, newConvo);
            } else {
              conversations[existingIndex] = newConvo;
            }
          }
        } catch (e) {
          printData(
            title: "createGroup - parse new conversation error",
            data: e,
            e: true,
          );
        }
        clearGroupCreationState();
        return true;
      } else {
        errorMessage = data['message'] ?? 'Failed to create group';
        return false;
      }
    } catch (e) {
      errorMessage = 'Network error';
      printData(title: "createGroup error", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  Future<bool> updateGroup({
    required int conversationId,
    required String title,
    required List<int> userIds,
    File? image,
  }) async {
    Loaders.show();
    notifyListeners();
    try {
      final url = Uri.parse(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/update',
      );
      printData(title: "URL", data: url);
      final request = http.MultipartRequest('POST', url);
      final headers = await apiHeaders();
      request.headers.addAll(headers);
      request.fields['title'] = title;
      for (int i = 0; i < userIds.length; i++) {
        request.fields['user_ids[$i]'] = userIds[i].toString();
      }
      printData(title: "request.fields", data: request.fields);
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      printData(title: "data", data: data);
      if (data['success'] == true) {
        // If API returns updated group data, update in-memory state
        try {
          final returned = data['data'];
          if (returned != null && returned is Map) {
            final Map<String, dynamic> returnedMap = Map<String, dynamic>.from(
              returned,
            );
            // Update currentGroup if full group details are returned
            if (returnedMap.containsKey('title')) {
              try {
                currentGroup = GroupDetail.fromJson(returnedMap);
              } catch (_) {}
            }
            // Update conversations list entry (title/image/updatedAt)
            final idx = conversations.indexWhere((c) => c.id == conversationId);
            if (idx != -1) {
              final old = conversations[idx];
              final updatedTitle = returnedMap['title'] ?? old.title;
              final updatedImage = returnedMap['image'] ?? old.image;
              final updatedAt = returnedMap['updated_at'] != null
                  ? DateTime.tryParse(returnedMap['updated_at'].toString()) ??
                        DateTime.now()
                  : DateTime.now();
              final updatedConversation = ChatConversation(
                id: old.id,
                type: old.type,
                title: updatedTitle,
                participants: old.participants,
                latestMessage: old.latestMessage,
                image: updatedImage,
                unreadCount: old.unreadCount,
                updatedAt: updatedAt,
                isDefault: old.isDefault,
              );
              conversations
                ..removeAt(idx)
                ..insert(idx, updatedConversation);
            }
          }
        } catch (e) {
          showToast(message: data['message'] ?? 'Failed to update group');
          printData(title: "updateGroup error", data: e, e: true);
        }
        clearGroupCreationState();
        notifyListeners();
        return true;
      } else {
        showToast(message: data['message'] ?? 'Failed to update group');
        errorMessage = data['message'] ?? 'Failed to update group';
        return false;
      }
    } catch (e) {
      errorMessage = 'Network error';
      printData(title: "updateGroup error", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  Future<GroupDetail?> getGroupDetails(int conversationId) async {
    try {
      currentGroup = null;
      isGroupLoading = true;
      notifyListeners();
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}chat/conversations/$conversationId"),
        headers: await apiHeaders(),
      );
      printData(title: "Uri", data: res.request!.url);
      final data = jsonDecode(res.body);
      printData(title: "data", data: data);

      if (data['success'] == true && data['data'] != null) {
        currentGroup = GroupDetail.fromJson(data['data']);
        selectedUsers
          ..clear()
          ..addAll(
            currentGroup!.participants.map(
              (p) => SearchUsers(
                id: p.id,
                name: p.name,
                lastName: p.lastName,
                image: p.image,
                role: p.role,
              ),
            ),
          );

        // Update the conversation in the list so the ChatWindow header reflects changes
        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final existing = conversations[index];
          final updatedParticipants = currentGroup!.participants
              .map(
                (p) => ChatParticipant(
                  id: p.id,
                  name: p.name,
                  lastName: p.lastName,
                  username:
                      p.name, // Fallback since it's not in GroupParticipant
                  image: p.image,
                  isOnline: p.isOnline,
                  phoneNumbers: [], // Fallback
                ),
              )
              .toList();

          conversations[index] = ChatConversation(
            id: existing.id,
            type: existing.type,
            title: currentGroup!.title, // Updated title
            participants: updatedParticipants, // Updated participants
            latestMessage: existing.latestMessage,
            unreadCount: existing.unreadCount,
            updatedAt: existing.updatedAt,
            isDefault: existing.isDefault,
            image: currentGroup!.image ?? '', // Updated image
          );
        }

        notifyListeners();
        return currentGroup;
      }
    } catch (e) {
      printData(title: "getGroupDetails error", data: e, e: true);
    } finally {
      isGroupLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<void> _searchUsers(String query, {bool includeGroups = false}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final url = Uri.parse(
        '${ApiRoutes.baseUrl}chat/users/search?query=$query&include_groups=$includeGroups',
      );
      printData(title: "URL", data: url);
      final response = await http.get(url, headers: await apiHeaders());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        printData(title: "data", data: data);
        if (data['success'] == true) {
          searchResults = (data['data'] as List)
              .map((e) => SearchUsers.fromJson(e))
              .toList();
        } else {
          errorMessage = "Failed to load users";
          searchResults = [];
        }
      } else {
        errorMessage = "Server error (${response.statusCode})";
        searchResults = [];
        isLoading = false;
      }
    } catch (e) {
      errorMessage = "Network error";
      searchResults = [];
      isLoading = false;
    }
    isLoading = false;
    notifyListeners();
  }

  /// ---------------- FETCH PROFILE ----------------

  Future<void> fetchUserProfile(String id, {int? conversationId}) async {
    Loaders.show();
    errorMessage = null;
    notifyListeners();
    try {
      final uri = conversationId != null
          ? Uri.parse(
              "${ApiRoutes.baseUrl}chat/users/$id?conversationId=$conversationId",
            )
          : Uri.parse("${ApiRoutes.baseUrl}chat/users/$id");
      printData(title: "Fetching profile from", data: uri);
      final res = await http.get(uri, headers: await apiHeaders());
      printData(title: "Uri", data: res.request!.url);
      if (res.statusCode == 200) {
        final jsonResponse = json.decode(res.body);
        final profileResponse = ProfileResponse.fromJson(jsonResponse);
        if (profileResponse.success) {
          _userProfile = profileResponse.data;
        } else {
          errorMessage = "Failed to retrieve data";
        }
      } else {
        errorMessage = "Error: ${res.statusCode}";
      }
    } catch (e) {
      errorMessage = "Connection error: $e";
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  /// ---------------- CLEAR SEARCH ----------------
  void clearUserSearch() {
    _debounce?.cancel();
    searchResults.clear();
    errorMessage = null;
    isLoading = false;
    notifyListeners();
  }

  void clearGroupCreationState() {
    selectedUsers.clear();
    searchResults.clear();
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  void onSearchChanged(String query) {
    // Cancel previous debounce
    _debounce?.cancel();
    // If input is empty → clear immediately
    if (query.trim().isEmpty) {
      clearUserSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query.trim());
    });
  }

  void onSearchGlobalChanged(String query) {
    // Cancel previous debounce
    _debounce?.cancel();
    // If input is empty → clear immediately
    if (query.trim().isEmpty) {
      clearUserSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query.trim(), includeGroups: true);
    });
  }

  void toggleUserSelection(SearchUsers user) {
    final exists = selectedUsers.any((u) => u.id == user.id);
    if (exists) {
      selectedUsers.removeWhere((u) => u.id == user.id);
    } else {
      selectedUsers.add(user);
    }
    notifyListeners();
  }

  void removeSelectedUser(SearchUsers user) {
    selectedUsers.removeWhere((u) => u.id == user.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _typingThrottle?.cancel();
    _conversationSocket?.disconnect(); // Cleanup on full provider dispose
    _chatListSocket?.disconnect(); // Cleanup global socket
    _debounce?.cancel();
    super.dispose();
  }

  Future<int?> createConvId({
    required String type,
    required List<int> userIds,
    File? image,
    required BuildContext context,
  }) async {
    Loaders.show();
    notifyListeners();
    try {
      final url = Uri.parse('${ApiRoutes.baseUrl}chat/conversations');
      final request = http.MultipartRequest('POST', url);
      printData(title: "urlcreateConvId", data: url);
      final headers = await apiHeaders();
      request.headers.addAll(headers);
      request.fields['type'] = type;
      for (int i = 0; i < userIds.length; i++) {
        request.fields['user_ids[$i]'] = userIds[i].toString();
      }
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      printData(title: "datacreateConvId", data: data);
      if (data['success'] == true) {
        final convData = data['data'];
        final conv = ChatConversation.fromJson(convData);
        conversations.insert(0, conv);
        printData(title: "CONV ID", data: conv.id);
        return conv.id;
      } else {
        errorMessage = data['message'] ?? 'Failed to create';
        return null;
      }
    } catch (e) {
      errorMessage = 'Network error';
      printData(title: "create error", data: e, e: true);
      return null;
    } finally {
      Loaders.hide();
      notifyListeners();
    }
  }

  int? findPrivateConversationWithUser(int otherUserId) {
    try {
      final convo = conversations.firstWhere(
        (c) =>
            c.type == 'private' &&
            c.participants.any((p) => p.id == otherUserId),
      );
      return convo.id;
    } catch (_) {
      return null;
    }
  }

  /// Forward an existing voice message (without re-uploading)
  Future<void> forwardVoiceMessage({
    required String audioUrl,
    required int audioDuration,
    required int conversationId,
    required int currentUserId,
  }) async {
    Loaders.show();
    // 1. Create Optimistic Message with remote URL
    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      conversationId: conversationId,
      senderId: currentUserId,
      message: "Voice message", // Required by backend
      createdAt: DateTime.now(),
      isMe: true,
      type: 'voice',
      audioUrl: audioUrl, // Use the remote URL directly
      audioDuration: audioDuration,
      senderName: userProfile?.name ?? "Me",
      isRead: false,
      isDelivered: false,
    );
    // 2. Add to UI if in current conversation
    if (currentActiveConversationId == conversationId) {
      messages.insert(0, tempMessage);
    }
    // 3. Update conversation list
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final old = conversations[index];
      final updatedConversation = ChatConversation(
        id: old.id,
        type: old.type,
        title: old.title,
        participants: old.participants,
        latestMessage: ChatLatestMessage(
          id: tempMessage.id,
          message: "🎙️ Voice Message",
          type: 'voice',
          createdAt: DateTime.now(),
          userId: currentUserId,
          userName: userProfile?.name ?? "You",
        ),
        unreadCount: 0,
        updatedAt: DateTime.now(),
        isDefault: old.isDefault,
        image: old.image,
      );
      conversations
        ..removeAt(index)
        ..insert(0, updatedConversation);
    }
    notifyListeners();
    try {
      final url = Uri.parse(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages',
      );
      // Download the remote file and re-upload it as multipart
      final fileResponse = await http.get(Uri.parse(audioUrl));
      if (fileResponse.statusCode != 200) {
        throw Exception("Failed to download voice file");
      }
      final request = http.MultipartRequest('POST', url);
      final headers = await apiHeaders();
      headers.remove('Content-Type'); // Let multipart set it
      request.headers.addAll(headers);
      request.fields['type'] = 'voice';
      request.fields['voice_duration'] = audioDuration.toString();
      // Add the downloaded file as multipart
      request.files.add(
        http.MultipartFile.fromBytes(
          'voice_file',
          fileResponse.bodyBytes,
          filename: 'forwarded_voice.mp3',
          contentType: MediaType('audio', 'mpeg'),
        ),
      );
      printData(title: "Forwarding voice message", data: "");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      printData(title: "Forward voice response", data: response.statusCode);
      printData(title: "Forward voice response body", data: response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        printData(title: "Forward voice data received", data: data);
        if (data['success'] == true && data['data'] != null) {
          // Replace temp message with server response
          final realMessage = ChatMessage.fromJson(data['data'], currentUserId);
          printData(title: "Real message audioUrl", data: realMessage.audioUrl);
          printData(title: "Real message type", data: realMessage.type);
          printData(
            title: "Real message duration",
            data: realMessage.audioDuration,
          );
          printData(title: "Real message value", data: data['data']);
          final msgIndex = messages.indexWhere((m) => m.id == tempMessage.id);
          if (msgIndex != -1) {
            messages[msgIndex] = realMessage;
          }
        }
        showToast(message: "Voice message forwarded");
      } else {
        showToast(
          message: "Failed to forward voice message (${response.statusCode})",
        );
        messages.removeWhere((m) => m.id == tempMessage.id);
      }
    } catch (e) {
      printData(title: "Forward voice error", data: e, e: true);
      messages.removeWhere((m) => m.id == tempMessage.id);
      showToast(message: "Error forwarding voice message");
    } finally {
      Loaders.hide();
    }

    notifyListeners();
  }

  // 1. Start Recording
  DateTime? _recordingStartTime; // 1. Add this variable to track start time
  Future<void> startVoiceRecording() async {
    try {
      // 2. Mark the start time
      _recordingStartTime = DateTime.now();
      await _voiceRecorder.start();
      isRecordingVoice = true;
      notifyListeners();
    } catch (e) {
      printData(title: "Error starting recorder", data: e, e: true);
      isRecordingVoice = false;
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndSend({
    required int conversationId,
    required int currentUserId,
  }) async {
    if (!isRecordingVoice) return;
    try {
      final path = await _voiceRecorder.stop();
      // 3. Calculate duration
      final startTime = _recordingStartTime ?? DateTime.now();
      final difference = DateTime.now().difference(startTime).inSeconds;
      // 4. Ensure minimum duration is 1 second (Backend Requirement)
      final duration = difference < 1 ? 1 : difference;
      isRecordingVoice = false;
      notifyListeners();
      if (path != null) {
        await sendVoiceMessage(
          filePath: path,
          duration: duration, // 5. Pass calculated duration
          conversationId: conversationId,
          currentUserId: currentUserId,
        );
      }
    } catch (e) {
      printData(title: "Error stopping recorder", data: e, e: true);
      isRecordingVoice = false;
      notifyListeners();
    }
  }

  // 3. Cancel (Called when user slides to cancel)
  Future<void> cancelRecording() async {
    if (!isRecordingVoice) return;
    try {
      await _voiceRecorder.stop();
      // Optional: Delete the file here if your service saves it
    } catch (e) {
      printData(title: "Error canceling recorder", data: e, e: true);
    } finally {
      isRecordingVoice = false;
      notifyListeners();
    }
  }

  Future<void> sendVoiceMessage({
    required String filePath,
    required int duration,
    required int conversationId,
    required int currentUserId,
  }) async {
    // 1. Create a Temporary "Optimistic" Message
    // We use the local file path so it plays immediately without downloading
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      message: "", // Voice messages usually have empty text
      createdAt: DateTime.now(),
      isMe: true,
      type: 'voice',
      audioUrl: filePath, // ✅ Use LOCAL path initially
      audioDuration: duration,
      senderName: userProfile?.name ?? "Me",
      isRead: false,
      isDelivered: false,
    );
    // 2. Insert into list immediately & Notify UI
    // messages.insert(0, tempMessage);
    if (currentActiveConversationId == conversationId) {
      messages.insert(0, tempMessage);
    }
    notifyListeners();
    try {
      final fileOnDisk = File(filePath);
      if (!await fileOnDisk.exists()) {
        printData(
          title: "Error: Voice file not found",
          data: filePath,
          e: true,
        );
        // Remove the temp message if file missing
        messages.removeWhere((m) => m.id == tempId);
        notifyListeners();
        return;
      }
      final url = Uri.parse(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages',
      );
      final request = http.MultipartRequest('POST', url);
      final headers = await apiHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      request.fields['type'] = 'voice';
      request.fields['voice_duration'] = duration.toString();
      final multipartFile = await http.MultipartFile.fromPath(
        'voice_file',
        filePath,
        contentType: MediaType('audio', 'mp4'),
      );
      request.files.add(multipartFile);
      printData(title: "SENDING VOICE MESSAGE", data: "");
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      printData(title: "SERVER RESPONSE", data: response.statusCode);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 3. Success!
        // Ideally, parse the response to get the REAL server ID and remote URL.
        final data = jsonDecode(response.body);
        printData(title: "Voice upload response", data: data);
        if (data['success'] == true && data['data'] != null) {
          // Parse the real message from server
          final realMessage = ChatMessage.fromJson(data['data'], currentUserId);
          printData(
            title: "Uploaded voice audioUrl",
            data: realMessage.audioUrl,
          );
          printData(title: "Uploaded voice type", data: realMessage.type);
          // Find the temp message index
          final index = messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            // Replace local file message with server URL message
            messages[index] = realMessage;
          }
        } else {
          // Fallback: Just fetch latest if parsing fails
          await fetchMessages(
            conversationId: conversationId.toString(),
            currentUserId: currentUserId,
          );
        }
      } else {
        // 4. Upload Failed: Remove the temp message so user knows it failed
        printData(title: "Upload failed", data: "", e: true);
        messages.removeWhere((m) => m.id == tempId);
        showToast(message: "Failed to send voice note");
      }
    } catch (e) {
      printData(title: "Voice send exception", data: e, e: true);
      // Remove temp message on error
      messages.removeWhere((m) => m.id == tempId);
    }
    notifyListeners();
  }

  Future<void> editMessage({
    required int messageId,
    required String newMessage,
  }) async {
    Loaders.show();
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      messages[index] = messages[index].copyWith(message: newMessage);
      notifyListeners();
    }
    try {
      final url = Uri.parse("${ApiRoutes.baseUrl}chat/messages/$messageId");
      printData(title: "Edit mesg url", data: url);
      final res = await http.put(
        url,
        headers: await apiHeaders(),
        body: jsonEncode({"message": newMessage}),
      );
      printData(
        title: "Edit response",
        data: "${res.statusCode} - ${res.body}",
      );
      if (res.statusCode == 200) {
        showToast(message: "Message edited successfully");
      } else {
        String backendMsg = "Unable to edit message";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['message'] is String) {
            backendMsg = decoded['message'];
          }
        } catch (_) {}
        showToast(message: backendMsg);
        printData(title: "Failed to edit message", data: "", e: true);
      }
    } catch (e) {
      printData(title: "editMessage error", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<void> deleteMessage({
    required int messageId,
    required int conversationId,
  }) async {
    Loaders.show();
    final int index = messages.indexWhere((m) => m.id == messageId);
    ChatMessage? deletedMessage;
    if (index != -1) {
      deletedMessage = messages[index];
      messages.removeAt(index);
      notifyListeners();
    }
    try {
      final url = Uri.parse("${ApiRoutes.baseUrl}chat/messages/$messageId");
      final res = await http.delete(url, headers: await apiHeaders());
      printData(title: "Delete response", data: res.statusCode);
      if (res.statusCode == 200 || res.statusCode == 204) {
        showToast(message: "Message deleted successfully");
      } else {
        if (deletedMessage != null && index != -1) {
          messages.insert(index, deletedMessage);
          notifyListeners();
          showToast(message: "Failed to delete message");
        }
      }
    } catch (e) {
      printData(title: "deleteMessage error", data: e, e: true);
      // Revert on error
      if (deletedMessage != null && index != -1) {
        messages.insert(index, deletedMessage);
        notifyListeners();
      }
    } finally {
      Loaders.hide();
    }
  }

  /// ---------------- FETCH TWILIO NUMBERS ----------------
  Future<void> fetchTwilioNumbers({
    String? phone,
    String? client,
    String? contact,
    String? account,
  }) async {
    isTwilioLoading = true;
    twilioHasError = false;
    notifyListeners();
    try {
      final Map<String, String> queryParams = {};
      if (phone != null && phone.isNotEmpty) queryParams['phone'] = phone;
      if (client != null && client.isNotEmpty) queryParams['client'] = client;
      if (contact != null && contact.isNotEmpty) {
        queryParams['contact'] = contact;
      }
      if (account != null && account.isNotEmpty) {
        queryParams['account'] = account;
      }
      final uri = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.twilioNumbers}",
      ).replace(queryParameters: queryParams);

      final res = await http.get(uri, headers: await apiHeaders());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> numbersData = data['data']['numbers'] ?? [];
          twilioNumbers = numbersData
              .map((json) => TwilioCredential.fromJson(json))
              .toList();
          twilioNumbersRevision++;
          isTwilioLoading = false;
          twilioHasError = false;
        } else {
          twilioHasError = true;
          isTwilioLoading = false;
          showToast(
            message: data['message'] ?? 'Failed to load Twilio numbers',
          );
        }
      } else {
        twilioHasError = true;
        isTwilioLoading = false;
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      twilioHasError = true;
      isTwilioLoading = false;
      showToast(message: 'Failed to fetch Twilio numbers');
      printData(title: "Error fetching Twilio numbers", data: e, e: true);
    }
    notifyListeners();
  }

  /// ---------------- FETCH TWILIO CLIENTS WITH CONTACTS ----------------
  Future<void> fetchTwilioClientsWithContacts() async {
    isTwilioClientsLoading = true;
    twilioClientsHasError = false;
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.twilioClientsWithContacts}"),
        headers: await apiHeaders(),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> clientsData = data['data']['clients'] ?? [];
          twilioClients = clientsData
              .map((json) => TwilioClient.fromJson(json))
              .toList();
          twilioClientsRevision++;
          isTwilioClientsLoading = false;
          twilioClientsHasError = false;
        } else {
          twilioClientsHasError = true;
          isTwilioClientsLoading = false;
          showToast(message: data['message'] ?? 'Failed to load clients');
        }
      } else {
        twilioClientsHasError = true;
        isTwilioClientsLoading = false;
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      twilioClientsHasError = true;
      isTwilioClientsLoading = false;
      showToast(message: 'Failed to fetch clients');
      printData(title: "Error fetching Twilio clients", data: e, e: true);
    }
    notifyListeners();
  }

  /// ---------------- FETCH TWILIO STAFF (ASSIGNED ACCOUNTS) ----------------
  Future<void> fetchTwilioStaff() async {
    isTwilioStaffLoading = true;
    twilioStaffHasError = false;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.twilioStaff}"),
        headers: await apiHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        printData(title: "data", data: data);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> staffData = data['data']['staff'] ?? [];
          twilioStaff = staffData
              .map((json) => AssignedAccount.fromJson(json))
              .toList();
          twilioStaffRevision++;
          printData(title: "twilioStaff", data: twilioStaff);
          isTwilioStaffLoading = false;
          twilioStaffHasError = false;
        } else {
          twilioStaffHasError = true;
          isTwilioStaffLoading = false;
          showToast(message: data['message'] ?? 'Failed to load staff');
        }
      } else {
        twilioStaffHasError = true;
        isTwilioStaffLoading = false;
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      twilioStaffHasError = true;
      isTwilioStaffLoading = false;
      showToast(message: 'Failed to fetch staff');
      printData(title: "Error fetching twilio staff", data: e, e: true);
    }
    notifyListeners();
  }

  Future<List<AssignedAccount>> fetchStaffByClient({int? clientId}) async {
    try {
      var uri = Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.twilioStaff}");
      if (clientId != null) {
        uri = uri.replace(queryParameters: {"client_id": clientId.toString()});
      }

      final res = await http.get(uri, headers: await apiHeaders());

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> staffData = data['data']['staff'] ?? [];
          return staffData
              .map((json) => AssignedAccount.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      printData(title: "Error fetching staff by client", data: e, e: true);
    }
    return [];
  }

  /// ---------------- UPDATE TWILIO NUMBER ASSIGNMENTS ----------------
  Future<bool> updateTwilioNumberAssignments({
    required int numberId,
    required int? clientId,
    required List<int> contactIds,
    required List<int> accountIds,
  }) async {
    try {
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.twilioNumbers}/$numberId",
      );
      printData(title: "updating Twilio number", data: url);
      final payload = {
        "client_id": clientId,
        "contact_ids": contactIds,
        "account_ids": accountIds,
      };
      printData(title: "updating Twilio payload", data: payload);

      final res = await http.put(
        url,
        headers: await apiHeaders(),
        body: jsonEncode(payload),
      );
      printData(title: "updating Twilio body", data: res.body);

      if (res.statusCode == 200 || res.statusCode == 204) {
        return true;
      }

      final data = jsonDecode(res.body);
      printData(title: "updating Twilio number", data: data);
      showToast(message: data['message'] ?? 'Failed to update number');
      return false;
    } catch (e) {
      printData(title: "Error updating Twilio number", data: e, e: true);
      showToast(message: 'Failed to update number');
      return false;
    }
  }

  Future<void> syncTwilioNumbers() async {
    if (isTwilioSyncing) return;
    isTwilioSyncing = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.twilioSyncNumbers}"),
        headers: await apiHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          showToast(
            message: data['message'] ?? 'Twilio numbers synced successfully',
          );
          await fetchTwilioNumbersTab(page: twilioCurrentPage);
        } else {
          showToast(
            message: data['message'] ?? 'Failed to sync Twilio numbers',
          );
        }
      } else {
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      showToast(message: 'Failed to sync Twilio numbers');
      debugPrint('Error syncing Twilio numbers: $e');
    } finally {
      isTwilioSyncing = false;
      notifyListeners();
    }
  }

  Future<void> fetchTwilioNumbersTab({
    int page = 1,
    String? phone,
    String? client,
    String? contact,
    String? account,
  }) async {
    isTwilioLoading = true;
    twilioHasError = false;
    notifyListeners();
    try {
      if (phone != null ||
          client != null ||
          contact != null ||
          account != null) {
        twilioSearchPhone = phone;
        twilioSearchClient = client;
        twilioSearchContact = contact;
        twilioSearchAccount = account;
      }

      final queryParams = <String, String>{'page': page.toString()};
      if ((twilioSearchPhone ?? '').isNotEmpty) {
        queryParams['phone'] = twilioSearchPhone!.trim();
      }
      if ((twilioSearchClient ?? '').isNotEmpty) {
        queryParams['client'] = twilioSearchClient!.trim();
      }
      if ((twilioSearchContact ?? '').isNotEmpty) {
        queryParams['contact'] = twilioSearchContact!.trim();
      }
      if ((twilioSearchAccount ?? '').isNotEmpty) {
        queryParams['account'] = twilioSearchAccount!.trim();
      }

      final res = await http.get(
        Uri.parse(
          "${ApiRoutes.baseUrl}${ApiRoutes.twilioNumbers}",
        ).replace(queryParameters: queryParams),
        headers: await apiHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> numbersData = data['data']['numbers'] ?? [];
          twilioNumbers = numbersData
              .map((json) => TwilioCredential.fromJson(json))
              .toList();

          // Store pagination meta
          if (data['meta'] != null) {
            twilioCurrentPage = data['meta']['current_page'] ?? 1;
            twilioLastPage = data['meta']['last_page'] ?? 1;
            twilioPerPage = data['meta']['per_page'] ?? 10;
            twilioTotal = data['meta']['total'] ?? 0;
          }

          twilioNumbersRevision++;
          isTwilioLoading = false;
          twilioHasError = false;
        } else {
          twilioHasError = true;
          isTwilioLoading = false;
          showToast(
            message: data['message'] ?? 'Failed to load Twilio numbers',
          );
        }
      } else {
        twilioHasError = true;
        isTwilioLoading = false;
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      twilioHasError = true;
      isTwilioLoading = false;
      showToast(message: 'Failed to fetch Twilio numbers');
      debugPrint('Error fetching Twilio numbers: $e');
    }
    notifyListeners();
  }

  Future<void> fetchTwilioCredentials() async {
    isTwilioCredentialsLoading = true;
    twilioCredentialsHasError = false;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.twilioCredentials}"),
        headers: await apiHeaders(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final credentials = data['data'];
          twilioAccountSid = credentials['account_sid']?.toString();
          twilioApiKeySid = credentials['api_key_sid']?.toString();
          twilioApiKeySecret = credentials['api_key_secret']?.toString();
          twilioTwimlAppSid = credentials['twiml_app_sid']?.toString();
          isTwilioCredentialsLoading = false;
          twilioCredentialsHasError = false;
        } else {
          twilioCredentialsHasError = true;
          isTwilioCredentialsLoading = false;
          showToast(
            message: data['message'] ?? 'Failed to load Twilio credentials',
          );
        }
      } else {
        twilioCredentialsHasError = true;
        isTwilioCredentialsLoading = false;
        showToast(message: 'Error: ${res.statusCode}');
      }
    } catch (e) {
      twilioCredentialsHasError = true;
      isTwilioCredentialsLoading = false;
      showToast(message: 'Failed to fetch Twilio credentials');
      debugPrint('Error fetching Twilio credentials: $e');
    }
    notifyListeners();
  }
}
