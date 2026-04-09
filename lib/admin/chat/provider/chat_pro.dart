import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:print_helper/models/search_modals.dart';
import 'package:print_helper/models/twilio_models.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/services/api_service.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_group_model.dart';
import '../models/group_participants_model.dart';
import '../models/chat_models.dart';
import '../../../models/profile_models.dart';
import '../../../services/api_routes.dart';
import '../service/chat_push_notify.dart';
import '../service/reverb_service.dart';
import '../service/voice_recorder_service.dart';
import '../../../utils/console_util.dart';
import 'package:provider/provider.dart';
import '../../../providers/files_pro.dart';
import '../../../widgets/loaders.dart';

class ChatDuplicateFileMatch {
  final String originalName;
  final String? existingName;
  final String? hash;
  final int? size;
  final String? mimeType;
  final int? messageId;
  final String? attachmentUrl;
  final Map<String, dynamic> raw;

  const ChatDuplicateFileMatch({
    required this.originalName,
    this.existingName,
    this.hash,
    this.size,
    this.mimeType,
    this.messageId,
    this.attachmentUrl,
    this.raw = const {},
  });

  String get displayName =>
      (existingName != null && existingName!.trim().isNotEmpty)
      ? existingName!.trim()
      : originalName;

  bool get canReshare =>
      (attachmentUrl != null && attachmentUrl!.trim().isNotEmpty) ||
      messageId != null;
}

class ChatDuplicateFileCheckResult {
  final bool hasDuplicates;
  final List<ChatDuplicateFileMatch> matches;
  final Map<String, dynamic> raw;

  const ChatDuplicateFileCheckResult({
    required this.hasDuplicates,
    required this.matches,
    this.raw = const {},
  });
}

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
  final Map<int, int> _pendingDeletedMessageIndexes = {};
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

  // --- Group Participants (Create/Edit Group) ---
  bool isFetchingGroupParticipants = false;
  List<SearchUsers> staffList = [];
  List<ClientCompanyModel> clientCompanies = [];
  ClientCompanyModel? selectedClientCompany;
  String selectedClientFilter = 'All'; // 'All' | 'Contacts' | 'Customers'

  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isLoadingConversationList = false;

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

  // Attachment upload state (keyed by temp message id)
  final Map<int, double> uploadProgress = {};
  final Map<int, String> localAttachmentPaths = {};

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

        final activeConversationId = currentActiveConversationId;
        final dataConversationId = int.tryParse(
          data['conversation_id']?.toString() ?? '',
        );
        final parsedCurrentUserId = int.tryParse(userId);

        if (activeConversationId != null &&
            dataConversationId != null &&
            dataConversationId == activeConversationId &&
            parsedCurrentUserId != null) {
          _handleRealtimeConversationMessage(
            data,
            parsedCurrentUserId,
            activeConversationId,
          );
        }
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
      onMessageDeleted: (data) {
        _handleMessageDeleted(data);
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
      onFileOperation: (data) {
        // Relay file system mutations to the FilesPro provider for instant patching
        try {
          final filesPro = Provider.of<FilesPro>(context, listen: false);
          filesPro.handleFileSystemMutation(data);
        } catch (e) {
          printData(title: "⚠️ FilesPro Relay Error:", data: e, e: true);
        }
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
      onMessageUpdated: (data) {
        _handleRealtimeConversationMessage(data, currentUserId, conversationId);
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

  /// Disconnects the global chat list socket (for incoming messages/calls)
  void disconnectChatListSocket() {
    if (_chatListSocket != null) {
      printData(title: "🔌 Disconnecting Chat List Socket...", data: "");
      _chatListSocket!.disconnect();
      _chatListSocket = null;
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
    try {
      final payload = data.containsKey('message') && data['message'] is Map
          ? Map<String, dynamic>.from(data['message'])
          : Map<String, dynamic>.from(data);

      final eventConversationId = int.tryParse(
        payload['conversation_id']?.toString() ?? '',
      );
      final activeConversationId =
          currentActiveConversationId ?? conversationId;
      if (eventConversationId == null ||
          eventConversationId != activeConversationId) {
        return;
      }

      final msg = ChatMessage.fromJson(payload, currentUserId);
      final isCallMessage = msg.type == 'call' || msg.isCallRecording;

      final existingIndex = messages.indexWhere((m) => m.id == msg.id);
      if (existingIndex != -1) {
        messages[existingIndex] = msg;
      } else {
        if (msg.senderId == currentUserId && !isCallMessage) {
          final optimisticIndex = _findOptimisticReplacementIndex(
            incomingMessage: msg,
            conversationId: eventConversationId,
          );

          if (optimisticIndex != -1) {
            messages[optimisticIndex] = msg;
          } else {
            final duplicateIndex = _findLikelyDuplicateSelfMessageIndex(
              incomingMessage: msg,
              conversationId: eventConversationId,
            );
            if (duplicateIndex != -1) {
              messages[duplicateIndex] = msg;
            } else {
              messages.insert(0, msg);
            }
          }
        } else {
          messages.insert(0, msg);

          if (!isChatScreenOpen) {
            NotificationService.instance.showChatNotification(
              title: "New message",
              body: msg.message,
              id: msg.id,
            );
          }
        }
      }

      printData(
        title: "📩 Message received. ChatScreenOpen:",
        data: isChatScreenOpen,
      );
      printData(title: "📩 Message received Payload:", data: payload);

      if (isChatScreenOpen) {
        markConversAsRead(activeConversationId);
      }

      notifyListeners();
    } catch (e) {
      printData(
        title: "_handleRealtimeConversationMessage error",
        data: e,
        e: true,
      );
    }
  }

  int _findOptimisticReplacementIndex({
    required ChatMessage incomingMessage,
    required int conversationId,
  }) {
    final incomingType = incomingMessage.type;

    // Text messages are safe to match by content.
    if (incomingType == 'text') {
      return messages.indexWhere(
        (message) =>
            message.isMe &&
            message.conversationId == conversationId &&
            message.type == 'text' &&
            message.message == incomingMessage.message,
      );
    }

    // Attachments are frequently sent with identical fallback text (e.g. 📷 Image),
    // so match by "still optimistic" state instead of content.
    if (incomingType == 'image' || incomingType == 'file') {
      return messages.indexWhere(
        (message) =>
            message.isMe &&
            message.conversationId == conversationId &&
            (message.type == 'image' || message.type == 'file') &&
            localAttachmentPaths.containsKey(message.id),
      );
    }

    // Voice optimistic messages carry local file paths before server URL arrives.
    if (incomingType == 'voice') {
      return messages.indexWhere(
        (message) =>
            message.isMe &&
            message.conversationId == conversationId &&
            message.type == 'voice' &&
            message.audioUrl != null &&
            (message.audioUrl!.startsWith('/data') ||
                message.audioUrl!.startsWith('file://')),
      );
    }

    return -1;
  }

  int _findLikelyDuplicateSelfMessageIndex({
    required ChatMessage incomingMessage,
    required int conversationId,
  }) {
    return messages.indexWhere((message) {
      if (!message.isMe) return false;
      if (message.conversationId != conversationId) return false;

      final incomingIsAttachment =
          incomingMessage.type == 'image' || incomingMessage.type == 'file';
      final currentIsAttachment =
          message.type == 'image' || message.type == 'file';

      if (incomingIsAttachment && currentIsAttachment) {
        // treat image/file as equivalent attachment message families
      } else if (message.type != incomingMessage.type) {
        return false;
      }

      final ageGap = message.createdAt
          .difference(incomingMessage.createdAt)
          .inSeconds
          .abs();
      if (ageGap > 20) return false;

      if (incomingIsAttachment) {
        final incomingUrl = incomingMessage.attachmentUrl ?? '';
        final currentUrl = message.attachmentUrl ?? '';
        final incomingName = incomingMessage.attachmentName ?? '';
        final currentName = message.attachmentName ?? '';

        if (incomingUrl.isNotEmpty && currentUrl.isNotEmpty) {
          return incomingUrl == currentUrl;
        }

        if (incomingName.isNotEmpty && currentName.isNotEmpty) {
          return incomingName == currentName;
        }
      }

      return message.message == incomingMessage.message;
    });
  }

  Map<String, dynamic>? _messagePayloadFromResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['message'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['message'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return map;
    }
    return null;
  }

  Map<String, dynamic> _normalizeDeleteEnvelope(Map<String, dynamic> data) {
    if (data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return data;
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes';
    }
    return false;
  }

  ChatMessage? _buildPreservedDeletedMessage(Map<String, dynamic> rawData) {
    final data = _normalizeDeleteEnvelope(rawData);
    final shouldPreserve =
        _isTruthy(data['preserve_message']) ||
        _isTruthy(data['show_delete_card']) ||
        data['status']?.toString().toLowerCase() == 'deleted';

    if (!shouldPreserve) return null;

    final nested = data['message'];
    if (nested is! Map && nested is! Map<String, dynamic>) return null;

    final payload = Map<String, dynamic>.from(nested as Map);
    payload['id'] ??= data['message_id'] ?? data['id'] ?? data['messageId'];
    payload['conversation_id'] ??=
        data['conversation_id'] ?? data['conversationId'];
    payload['user_id'] ??= data['user_id'];
    payload['type'] = (payload['type'] ?? 'text').toString();
    payload['message'] = (payload['message'] ?? 'This message was deleted')
        .toString();
    payload['created_at'] ??= DateTime.now().toUtc().toIso8601String();

    if (payload['id'] == null || payload['conversation_id'] == null) {
      return null;
    }

    final parsedCurrentUserId = int.tryParse(_currentUserId ?? '') ?? -1;
    return ChatMessage.fromJson(payload, parsedCurrentUserId);
  }

  // 2. ✅ Handle Message Deletion
  void _handleMessageDeleted(Map<String, dynamic> data) {
    try {
      final envelope = _normalizeDeleteEnvelope(data);
      final preservedMessage = _buildPreservedDeletedMessage(envelope);

      final payload = envelope['message'] is Map
          ? Map<String, dynamic>.from(envelope['message'])
          : Map<String, dynamic>.from(envelope);

      final dynamic rawMessageId =
          payload['id'] ??
          envelope['message_id'] ??
          payload['message_id'] ??
          payload['messageId'];
      final dynamic rawConversationId =
          payload['conversation_id'] ??
          envelope['conversation_id'] ??
          payload['conversationId'];

      final messageId = int.tryParse(rawMessageId?.toString() ?? '');
      final conversationId = int.tryParse(rawConversationId?.toString() ?? '');

      if (messageId == null) {
        printData(
          title: "_handleMessageDeleted missing message id",
          data: data,
        );
        return;
      }

      if (preservedMessage != null) {
        final pendingIndex = _pendingDeletedMessageIndexes.remove(messageId);
        final existingIndex = messages.indexWhere((m) => m.id == messageId);
        if (existingIndex != -1) {
          messages[existingIndex] = preservedMessage;
        } else if (conversationId != null &&
            currentActiveConversationId == conversationId) {
          final insertionIndex =
              (pendingIndex != null &&
                  pendingIndex >= 0 &&
                  pendingIndex <= messages.length)
              ? pendingIndex
              : 0;
          messages.insert(insertionIndex, preservedMessage);
        }

        if (conversationId != null) {
          _syncConversationAfterMessageDeletion(
            conversationId: conversationId,
            deletedMessageId: messageId,
          );
          if (currentActiveConversationId != conversationId) {
            unawaited(_refreshConversationLatestMessage(conversationId));
          }
        }

        notifyListeners();
        return;
      }

      final before = messages.length;
      messages.removeWhere((m) => m.id == messageId);
      _pendingDeletedMessageIndexes.remove(messageId);
      final removed = before != messages.length;

      if (conversationId != null) {
        _syncConversationAfterMessageDeletion(
          conversationId: conversationId,
          deletedMessageId: messageId,
        );
      }

      if (removed) {
        notifyListeners();
      }
    } catch (e) {
      printData(title: "_handleMessageDeleted error", data: e, e: true);
    }
  }

  void _syncConversationAfterMessageDeletion({
    required int conversationId,
    required int deletedMessageId,
  }) {
    final convoIndex = conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex == -1) return;

    final convo = conversations[convoIndex];
    if (convo.latestMessage?.id != deletedMessageId) return;

    if (currentActiveConversationId == conversationId) {
      final replacement = messages.isNotEmpty ? messages.first : null;
      final updatedConversation = ChatConversation(
        id: convo.id,
        type: convo.type,
        title: convo.title,
        participants: convo.participants,
        latestMessage: replacement == null
            ? null
            : ChatLatestMessage(
                id: replacement.id,
                message: replacement.message,
                type: replacement.type,
                createdAt: replacement.createdAt,
                userId: replacement.senderId,
                userName: replacement.senderName,
              ),
        unreadCount: convo.unreadCount,
        updatedAt: DateTime.now(),
        isDefault: convo.isDefault,
        image: convo.image,
      );
      conversations[convoIndex] = updatedConversation;
      notifyListeners();
      return;
    }

    unawaited(_refreshConversationLatestMessage(conversationId));
  }

  Future<void> _refreshConversationLatestMessage(int conversationId) async {
    try {
      final res = await http.get(
        Uri.parse(
          "${ApiRoutes.baseUrl}chat/conversations/$conversationId/messages?page=1",
        ),
        headers: await apiHeaders(),
      );

      if (res.statusCode != 200) {
        await _updateSingleConversation(conversationId);
        return;
      }

      final decoded = jsonDecode(res.body);
      final List data = decoded['data'] ?? [];
      final convoIndex = conversations.indexWhere(
        (c) => c.id == conversationId,
      );
      if (convoIndex == -1) return;

      final convo = conversations[convoIndex];
      final ChatLatestMessage? latestMessage = data.isEmpty
          ? null
          : ChatLatestMessage.fromJson(
              Map<String, dynamic>.from(data.first as Map),
            );

      conversations[convoIndex] = ChatConversation(
        id: convo.id,
        type: convo.type,
        title: convo.title,
        participants: convo.participants,
        latestMessage: latestMessage,
        unreadCount: convo.unreadCount,
        updatedAt: DateTime.now(),
        isDefault: convo.isDefault,
        image: convo.image,
      );
      notifyListeners();
    } catch (e) {
      printData(
        title: "_refreshConversationLatestMessage error",
        data: e,
        e: true,
      );
      await _updateSingleConversation(conversationId);
    }
  }

  void _handleMessageStatusUpdate(Map<String, dynamic> data) {
    final status = data['status']; // "read" | "delivered"
    final rawMessageId = data['id'];
    if (rawMessageId == null) return;

    final targetMessageId = int.tryParse(rawMessageId.toString());
    if (targetMessageId == null) return;

    bool updated = false;
    for (int i = 0; i < messages.length; i++) {
      // Mark this message and any older messages as read/delivered
      if (messages[i].id <= targetMessageId) {
        if (status == 'read' && messages[i].isRead != true) {
          messages[i] = messages[i].copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
          updated = true;
        } else if (status == 'delivered' && messages[i].isDelivered != true) {
          messages[i] = messages[i].copyWith(
            isDelivered: true,
            deliveredAt: DateTime.now(),
          );
          updated = true;
        }
      }
    }

    if (updated) {
      notifyListeners();
    }
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
          _recomputeTotalUnreadFromList();
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
      _recomputeTotalUnreadFromList();
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
          _recomputeTotalUnreadFromList();
        }
        notifyListeners();
        _groupRemovalInProgress.remove(conversationId);
        return;
      }

      // Fallback: let the API tell us (403 = removed, 200 = just update metadata)
      await _updateSingleConversation(conversationId);
      _recomputeTotalUnreadFromList();
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
      if (conversationId != null) {
        _groupRemovalInProgress.remove(conversationId);
      }
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
            _recomputeTotalUnreadFromList();
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
      _recomputeTotalUnreadFromList();
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
    bool didMutate = false;
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
            didMutate = true;
            printData(
              title: "Updated conversation in list",
              data: conversationId,
            );
          } else {
            // If not found, add to top (new conversation)
            conversations.insert(0, updatedConvo);
            didMutate = true;
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
            didMutate = true;
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
          didMutate = true;
          printData(
            title: "Removed conversation from list",
            data: conversationId,
          );
        }
      }
    } catch (e) {
      printData(title: "_updateSingleConversation error:", data: e, e: true);
    } finally {
      if (didMutate) {
        _recomputeTotalUnreadFromList();
        notifyListeners();
      }
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
  Future<void> loadConversations({bool showLoading = true}) async {
    if (_isLoadingConversationList) return;
    _isLoadingConversationList = true;
    if (showLoading) {
      Loaders.show();
      notifyListeners();
    }
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
      _isLoadingConversationList = false;
      if (showLoading) {
        Loaders.hide();
      }
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

  /// Complete reset when user is switched (admin direct login)
  /// Disconnects sockets and clears all chat state
  void resetForUserSwitch() {
    printData(title: "🔄RESET FOR USER SWITCH - Starting", data: "");

    // 1. Disconnect all sockets with new token
    disconnectChatListSocket();
    disconnectConversationSocket();

    // 2. Clear all chat messages and conversations
    messages.clear();
    conversations.clear();
    messageSearchResults.clear();

    // 3. Reset UI state
    isChatScreenOpen = false;
    isOtherUserOnline = false;
    isOtherUserTyping = false;
    currentActiveConversationId = null;
    totalUnreadCount = 0;
    _currentUserId = null;

    // 4. Clear search state
    searchResults.clear();
    selectedUserIdss.clear();
    selectedUsers.clear();
    isLoading = false;
    searchQuery = "";
    messageSearchResults.clear();
    isSearching = false;

    // 5. Clear pagination state
    _currentPage = 1;
    _isLoadingMore = false;
    _hasMore = true;
    searchTotalResults = 0;
    searchCurrentPage = 1;
    searchLastPage = 1;

    // 6. Cancel any pending timers
    _typingThrottle?.cancel();
    _typingAutoClear?.cancel();
    _debounce?.cancel();

    // 7. Clear group state
    currentGroup = null;
    isGroupLoading = false;
    _groupRemovalInProgress.clear();

    printData(title: "✅ RESET FOR USER SWITCH - Complete", data: "");
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

        // 1. Set the selected users for the Edit UI
        selectedUsers.clear();
        selectedUsers.addAll(
          currentGroup!.participants.allSelectedParticipants,
        );

        // 2. Set the lists of staff and client companies so the UI can display them
        // We combine selected and available for the full list, deduplicating by ID
        final allStaffMap = <int, SearchUsers>{};
        for (var u in [
          ...currentGroup!.participants.selectedStaff,
          ...currentGroup!.participants.availableStaff,
        ]) {
          allStaffMap[u.id] = u;
        }
        staffList = allStaffMap.values.toList();

        final allClientsMap = <int, ClientCompanyModel>{};
        for (var c in [
          ...currentGroup!.participants.selectedClients,
          ...currentGroup!.participants.availableClients,
        ]) {
          if (allClientsMap.containsKey(c.id)) {
            // Merge members (contacts + customers)
            final existing = allClientsMap[c.id]!;
            final mergedContactsMap = <int, SearchUsers>{};
            for (var u in [...existing.contacts, ...c.contacts]) {
              mergedContactsMap[u.id] = u;
            }
            final mergedCustomersMap = <int, SearchUsers>{};
            for (var u in [...existing.customers, ...c.customers]) {
              mergedCustomersMap[u.id] = u;
            }
            allClientsMap[c.id] = ClientCompanyModel(
              id: c.id,
              companyName: c.companyName,
              email: c.email ?? existing.email,
              image: c.image ?? existing.image,
              contacts: mergedContactsMap.values.toList(),
              customers: mergedCustomersMap.values.toList(),
            );
          } else {
            allClientsMap[c.id] = c;
          }
        }
        clientCompanies = allClientsMap.values.toList();

        // 3. Auto-select the client company if any selected users are client members
        if (currentGroup!.participants.selectedClients.isNotEmpty) {
          final firstSelectedId =
              currentGroup!.participants.selectedClients.first.id;
          selectedClientCompany = allClientsMap[firstSelectedId];
        }

        // Update the conversation in the list so the ChatWindow header reflects changes
        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          final existing = conversations[index];
          final updatedParticipants = currentGroup!
              .participants
              .allSelectedParticipants
              .map(
                (p) => ChatParticipant(
                  id: p.id,
                  name: p.name,
                  lastName: p.lastName,
                  username: p.name,
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
    // Clear group participant state
    staffList.clear();
    clientCompanies.clear();
    selectedClientCompany = null;
    selectedClientFilter = 'All';
    isFetchingGroupParticipants = false;
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

  /// Fetches the full participants list (staff + client companies) for group creation.
  Future<void> fetchGroupParticipants() async {
    if (isFetchingGroupParticipants) return;
    isFetchingGroupParticipants = true;
    notifyListeners();
    try {
      final headers = await apiHeaders();
      final url = Uri.parse(
        '${ApiRoutes.baseUrl}${ApiRoutes.groupParticipants}',
      );
      final response = await http.get(url, headers: headers);
      printData(
        title: 'fetchGroupParticipants status:',
        data: response.statusCode,
      );
      printData(title: 'fetchGroupParticipants body:', data: response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final parsed = GroupParticipantsResponse.fromJson(
            decoded['data'] as Map<String, dynamic>,
          );
          staffList = parsed.staff;
          clientCompanies = parsed.clients;
        }
      }
    } catch (e) {
      printData(title: 'fetchGroupParticipants error:', data: e, e: true);
    } finally {
      isFetchingGroupParticipants = false;
      notifyListeners();
    }
  }

  /// Selects a client company and resets the member filter.
  /// If [company] is null (Clear), also removes all contacts/customers from selectedUsers.
  void setClientCompany(ClientCompanyModel? company) {
    selectedClientCompany = company;
    selectedClientFilter = 'All';
    // If we're setting a NEW company (not null and different from current),
    // THEN we enforce the "one client per group" rule by clearing previous client users.
    // If it's the SAME company, we don't clear anything.
    if (company != null) {
      // Check if any currently selected client users belong to a DIFFERENT company
      // Since we only allow one client company, if we select a company, we should
      // probably clear users that don't belong to THIS specific company if they are CONTACT/CUSTOMER.
      // However, the requirement is "no need that jude diaz needed to be selected until when it manually removes".
      // So we only clear if the company ID actually changes.

      // We don't have a direct way to check which company a SearchUser belongs to easily without searching,
      // but we can assume if selectedClientCompany changes, we might need to clear.
      // BUT, if the user just clicks the same company in the list, we shouldn't clear.
    }

    notifyListeners();
  }

  /// Sets the filter for viewing members in the selected client company.
  void setClientMemberFilter(String filter) {
    selectedClientFilter = filter;
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

  Future<bool> sendAttachmentMessage({
    required File file,
    required int conversationId,
    required int currentUserId,
    String? caption,
    String? overrideFileName,
  }) async {
    if (!await file.exists()) {
      showToast(message: 'Selected file not found');
      return false;
    }

    final fileName =
        (overrideFileName != null && overrideFileName.trim().isNotEmpty)
        ? overrideFileName.trim()
        : _extractFileName(file.path);
    final isImage = _isImageFile(fileName);
    final messageText = (caption != null && caption.trim().isNotEmpty)
        ? caption.trim()
        : (isImage ? '📷 Image' : '📎 $fileName');
    // Backend emits attachment realtime events as `type=file` (even for images).
    // Keep optimistic type aligned with backend so replacement is deterministic.
    const type = 'file';

    // 1. Insert optimistic message immediately
    final tempId = DateTime.now().millisecondsSinceEpoch;
    localAttachmentPaths[tempId] = file.path;
    uploadProgress[tempId] = 0.0;

    final tempMessage = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      message: messageText,
      createdAt: DateTime.now(),
      isMe: true,
      type: type,
      attachmentName: fileName,
      attachmentMimeType: _mimeTypeFromName(fileName),
      senderName: userProfile?.name ?? 'Me',
      isRead: false,
      isDelivered: false,
    );
    if (currentActiveConversationId == conversationId) {
      messages.insert(0, tempMessage);
    }

    // 2. Update conversation list preview
    final convIdx = conversations.indexWhere((c) => c.id == conversationId);
    if (convIdx != -1) {
      final old = conversations[convIdx];
      conversations
        ..removeAt(convIdx)
        ..insert(
          0,
          ChatConversation(
            id: old.id,
            type: old.type,
            title: old.title,
            participants: old.participants,
            latestMessage: ChatLatestMessage(
              id: tempId,
              message: messageText,
              type: type,
              createdAt: DateTime.now(),
              userId: currentUserId,
              userName: userProfile?.name ?? 'You',
            ),
            unreadCount: 0,
            updatedAt: DateTime.now(),
            isDefault: old.isDefault,
            image: old.image,
          ),
        );
    }
    notifyListeners();

    // 3. Upload using chat chunked flow:
    //    init -> upload chunks -> (optional status) -> complete
    try {
      final dioClient = dio_pkg.Dio();
      final jsonHeaders = await apiHeaders();

      final int fileSize = await file.length();
      const int requestedChunkSize = 1024 * 1024; // 1 MB

      printData(
        title: '📤 Chunk init',
        data:
            'name=$fileName size=$fileSize mime=${_mimeTypeFromName(fileName)} chunk_size=$requestedChunkSize',
      );

      final initResponse = await dioClient.post(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/files/chunk/init',
        data: {
          'name': fileName,
          'size': fileSize,
          'mime_type': _mimeTypeFromName(fileName),
          'chunk_size': requestedChunkSize,
        },
        options: dio_pkg.Options(headers: jsonHeaders),
      );

      final initPayload = initResponse.data is Map
          ? Map<String, dynamic>.from(initResponse.data as Map)
          : <String, dynamic>{};
      if (initPayload['success'] != true || initPayload['data'] is! Map) {
        throw Exception('Chunk init failed');
      }

      final initData = Map<String, dynamic>.from(initPayload['data'] as Map);
      final uploadId = initData['upload_id']?.toString() ?? '';
      if (uploadId.isEmpty) {
        throw Exception('Missing upload_id from chunk init');
      }

      final int chunkSize =
          int.tryParse('${initData['chunk_size'] ?? requestedChunkSize}') ??
          requestedChunkSize;
      final int totalChunks =
          int.tryParse('${initData['total_chunks'] ?? 0}') ??
          ((fileSize + chunkSize - 1) ~/ chunkSize);

      printData(
        title: '📤 Chunk upload start',
        data:
            'upload_id=$uploadId chunk_size=$chunkSize total_chunks=$totalChunks',
      );

      final multipartHeaders = await apiHeaders();
      multipartHeaders.remove('Content-Type');

      final randomAccess = await file.open();
      try {
        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final int start = chunkIndex * chunkSize;
          final int remaining = fileSize - start;
          final int currentChunkSize = remaining < chunkSize
              ? remaining
              : chunkSize;

          await randomAccess.setPosition(start);
          final bytes = await randomAccess.read(currentChunkSize);

          final formData = dio_pkg.FormData.fromMap({
            'chunk_index': chunkIndex,
            'chunk': dio_pkg.MultipartFile.fromBytes(
              bytes,
              filename: 'chunk_${chunkIndex.toString().padLeft(6, '0')}.part',
              contentType: MediaType('application', 'octet-stream'),
            ),
          });

          final chunkResponse = await dioClient.post(
            '${ApiRoutes.baseUrl}chat/conversations/$conversationId/files/chunk/$uploadId',
            data: formData,
            options: dio_pkg.Options(headers: multipartHeaders),
            onSendProgress: (sent, total) {
              if (total <= 0) return;
              final perChunk = sent / total;
              final overall = (chunkIndex + perChunk) / totalChunks;
              uploadProgress[tempId] = overall.clamp(0.0, 1.0);
              notifyListeners();
            },
          );

          final chunkPayload = chunkResponse.data is Map
              ? Map<String, dynamic>.from(chunkResponse.data as Map)
              : <String, dynamic>{};

          if (chunkPayload['success'] != true) {
            throw Exception(
              chunkPayload['message']?.toString() ?? 'Chunk upload failed',
            );
          }

          final chunkData = chunkPayload['data'] is Map
              ? Map<String, dynamic>.from(chunkPayload['data'] as Map)
              : <String, dynamic>{};
          final progressPercent =
              int.tryParse('${chunkData['progress'] ?? ''}') ??
              (((chunkIndex + 1) / totalChunks) * 100).floor();
          uploadProgress[tempId] = (progressPercent / 100).clamp(0.0, 1.0);
          notifyListeners();
        }
      } finally {
        await randomAccess.close();
      }

      final statusResponse = await dioClient.get(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/files/chunk/$uploadId/status',
        options: dio_pkg.Options(headers: jsonHeaders),
      );
      final statusPayload = statusResponse.data is Map
          ? Map<String, dynamic>.from(statusResponse.data as Map)
          : <String, dynamic>{};
      final statusData = statusPayload['data'] is Map
          ? Map<String, dynamic>.from(statusPayload['data'] as Map)
          : <String, dynamic>{};
      final statusProgress = int.tryParse('${statusData['progress'] ?? ''}');
      if (statusProgress != null) {
        uploadProgress[tempId] = (statusProgress / 100).clamp(0.0, 1.0);
        notifyListeners();
      }

      final dioResponse = await dioClient.post(
        '${ApiRoutes.baseUrl}chat/conversations/$conversationId/files/chunk/$uploadId/complete',
        options: dio_pkg.Options(headers: jsonHeaders),
      );

      printData(
        title: '📥 Chunk complete response',
        data: '${dioResponse.statusCode}: ${dioResponse.data}',
      );

      final data = dioResponse.data is Map<String, dynamic>
          ? dioResponse.data as Map<String, dynamic>
          : null;

      if (data != null && data['success'] == true && data['data'] != null) {
        final payload = _messagePayloadFromResponseData(data['data']);
        if (payload == null) {
          throw Exception('Missing message payload in chunk complete response');
        }
        final realMessage = ChatMessage.fromJson(payload, currentUserId);
        final idx = messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) messages[idx] = realMessage;
        uploadProgress.remove(tempId);
        localAttachmentPaths.remove(tempId);
        notifyListeners();
        return true;
      }

      uploadProgress.remove(tempId);
      localAttachmentPaths.remove(tempId);

      notifyListeners();
      return true;
    } on dio_pkg.DioException catch (e) {
      uploadProgress.remove(tempId);
      localAttachmentPaths.remove(tempId);
      messages.removeWhere((m) => m.id == tempId);

      String errMsg = 'Failed to send attachment';
      try {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) {
          errMsg = body['message'].toString();
        }
      } catch (_) {}

      printData(
        title: 'Attachment upload failed',
        data: '${e.response?.statusCode}: ${e.response?.data}',
        e: true,
      );
      showToast(message: errMsg);
      notifyListeners();
      return false;
    } catch (e) {
      uploadProgress.remove(tempId);
      localAttachmentPaths.remove(tempId);
      messages.removeWhere((m) => m.id == tempId);
      printData(title: 'sendAttachmentMessage error', data: e, e: true);
      showToast(message: 'Failed to send attachment');
      notifyListeners();
      return false;
    }
  }

  Future<ChatDuplicateFileCheckResult?> checkExistingAttachment({
    required File file,
    required int conversationId,
    String fileKey = 'file-1',
  }) async {
    if (!await file.exists()) {
      printData(
        title: '🧪 check-existing skipped',
        data: 'File not found on disk: ${file.path}',
        e: true,
      );
      return null;
    }

    try {
      final fileName = _extractFileName(file.path);
      final fileSize = await file.length();
      final mimeType = _mimeTypeFromName(fileName);
      final hash = await _sha256OfFileStream(file);
      final headers = await apiHeaders();
      final dioClient = dio_pkg.Dio();
      final endpoint =
          '${ApiRoutes.baseUrl}${ApiRoutes.checkExistingConversationFiles(conversationId)}';
      final requestBody = {
        'files': [
          {
            'key': fileKey,
            'name': fileName,
            'size': fileSize,
            'mime_type': mimeType,
            'hash': hash,
          },
        ],
      };

      printData(title: '🧪 check-existing request', data: 'POST $endpoint');
      printData(title: '🧪 check-existing payload', data: requestBody);

      final response = await dioClient.post(
        endpoint,
        data: requestBody,
        options: dio_pkg.Options(headers: headers),
      );

      printData(
        title: '🧪 check-existing response',
        data: 'status=${response.statusCode} data=${response.data}',
      );

      final payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      if (payload.isEmpty) {
        printData(
          title: '🧪 check-existing empty response',
          data: 'Response payload is empty',
          e: true,
        );
        return null;
      }

      final normalizedData = _normalizeDuplicatePayload(payload['data']);
      final data = normalizedData ?? payload;
      final matches = _extractDuplicateFileMatches(data);
      final hasDuplicates =
          _readBool(payload['has_duplicates']) ||
          _readBool(data['has_duplicates']) ||
          matches.isNotEmpty;

      printData(
        title: '🧪 check-existing parsed',
        data:
            'hasDuplicates=$hasDuplicates matches=${matches.length} conversationId=$conversationId file=$fileName',
      );

      return ChatDuplicateFileCheckResult(
        hasDuplicates: hasDuplicates,
        matches: matches,
        raw: data,
      );
    } on dio_pkg.DioException catch (e) {
      printData(
        title: 'checkExistingAttachment failed',
        data: '${e.response?.statusCode}: ${e.response?.data}',
        e: true,
      );
      return null;
    } catch (e) {
      printData(title: 'checkExistingAttachment error', data: e, e: true);
      return null;
    }
  }

  Future<bool> reshareDuplicateAttachment({
    required ChatDuplicateFileMatch match,
    required File originalFile,
    required String alternateFileName,
    required int conversationId,
    required int currentUserId,
    String? caption,
  }) async {
    try {
      // Get file statistics from original file
      final fileSize = await originalFile.length();
      final fileBytes = await originalFile.readAsBytes();
      final fileHash = sha256.convert(fileBytes).toString();

      // Get MIME type
      String mimeType = match.mimeType ?? 'application/octet-stream';
      if (mimeType.isEmpty) {
        mimeType = _guessMimeType(alternateFileName);
      }

      // Use provided fileName or fallback to match data
      final fileName = alternateFileName.isNotEmpty
          ? alternateFileName
          : (match.existingName != null &&
                match.existingName!.trim().isNotEmpty)
          ? match.existingName!.trim()
          : match.originalName.isNotEmpty
          ? match.originalName
          : 'file';

      if (fileName.isEmpty) {
        printData(
          title: '🧪 reshareDuplicateAttachment validation failed',
          data: 'No valid file name available',
          e: true,
        );
        showToast(message: 'File information incomplete');
        return false;
      }

      final requestBody = {
        'name': fileName,
        'size': fileSize.toString(),
        'mime_type': mimeType,
        'hash': fileHash,
        'message': caption ?? '',
      };

      final endpoint = ApiRoutes.restoreExistingConversationFile(
        conversationId,
      );

      printData(title: '🧪 restore-existing request', data: 'POST $endpoint');
      printData(title: '🧪 restore-existing payload', data: requestBody);

      final headers = await apiHeaders();
      final dioClient = dio_pkg.Dio();
      final dioResponse = await dioClient.post(
        '${ApiRoutes.baseUrl}$endpoint',
        data: requestBody,
        options: dio_pkg.Options(headers: headers),
      );

      printData(
        title: '🧪 restore-existing response',
        data: 'status=${dioResponse.statusCode} data=${dioResponse.data}',
      );

      final response = dioResponse.data is Map
          ? Map<String, dynamic>.from(dioResponse.data as Map)
          : null;

      if (response == null) {
        printData(
          title: '🧪 restore-existing null/invalid response',
          data: dioResponse.data,
          e: true,
        );
        showToast(message: 'Failed to restore file');
        return false;
      }

      final success = response['success'] == true;
      final message = response['message'];
      final messageStr = (message is String && message.isNotEmpty)
          ? message
          : '';

      if (success) {
        showToast(message: 'File restored successfully');
        return true;
      } else {
        showToast(
          message: messageStr.isNotEmpty
              ? messageStr
              : 'Failed to restore file',
        );
        return false;
      }
    } on dio_pkg.DioException catch (e) {
      printData(
        title: 'reshareDuplicateAttachment failed',
        data: '${e.response?.statusCode}: ${e.response?.data}',
        e: true,
      );
      showToast(message: 'Error restoring file');
      return false;
    } catch (e) {
      printData(title: 'reshareDuplicateAttachment error', data: e, e: true);
      showToast(message: 'Error restoring file');
      return false;
    }
  }

  Future<bool> forwardAttachmentMessage({
    required String attachmentUrl,
    required String fileName,
    required int conversationId,
    required int currentUserId,
    String? mimeType,
    String? caption,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}${Platform.pathSeparator}chat_forward_${DateTime.now().millisecondsSinceEpoch}.bin',
    );

    try {
      final dioClient = dio_pkg.Dio();
      await dioClient.download(
        _resolveAttachmentUrlForNetwork(attachmentUrl),
        tempFile.path,
        options: dio_pkg.Options(headers: await apiHeaders()),
      );

      return sendAttachmentMessage(
        file: tempFile,
        conversationId: conversationId,
        currentUserId: currentUserId,
        caption: caption,
        overrideFileName: fileName,
      );
    } on dio_pkg.DioException catch (e) {
      printData(
        title: 'forwardAttachmentMessage failed',
        data: '${e.response?.statusCode}: ${e.response?.data}',
        e: true,
      );
      showToast(message: 'Failed to reshare attachment');
      return false;
    } catch (e) {
      printData(title: 'forwardAttachmentMessage error', data: e, e: true);
      showToast(message: 'Failed to reshare attachment');
      return false;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  bool _isImageFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _mimeTypeFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return 'application/octet-stream';
  }

  String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : path;
  }

  Future<String> _sha256OfFileStream(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String _resolveAttachmentUrlForNetwork(String rawUrl) {
    if (rawUrl.isEmpty || rawUrl.startsWith('http')) return rawUrl;
    if (!rawUrl.startsWith('/')) return rawUrl;

    final apiUri = Uri.parse(ApiRoutes.baseUrl);
    final origin = apiUri.hasPort
        ? '${apiUri.scheme}://${apiUri.host}:${apiUri.port}'
        : '${apiUri.scheme}://${apiUri.host}';
    return '$origin$rawUrl';
  }

  List<ChatDuplicateFileMatch> _extractDuplicateFileMatches(
    Map<String, dynamic> payload,
  ) {
    final entries = <Map<String, dynamic>>[];

    void addEntry(dynamic value) {
      if (value is Map<String, dynamic>) {
        entries.add(value);
      } else if (value is Map) {
        entries.add(Map<String, dynamic>.from(value));
      } else if (value is List) {
        for (final item in value) {
          addEntry(item);
        }
      }
    }

    addEntry(payload['duplicates']);
    addEntry(payload['matches']);
    addEntry(payload['results']);
    addEntry(payload['files']);
    addEntry(payload['items']);
    if (entries.isEmpty && _looksLikeDuplicateEntry(payload)) {
      entries.add(payload);
    }

    final matches = <ChatDuplicateFileMatch>[];
    for (final entry in entries) {
      if (!_entryRepresentsDuplicate(entry)) continue;

      final existing = _firstNestedMap(entry, const [
        'existing_file',
        'existing',
        'duplicate',
        'match',
        'matched_file',
      ]);
      final message = _firstNestedMap(entry, const [
        'message',
        'existing_message',
      ]);
      final attachment = _firstNestedMap(entry, const ['attachment']);

      final rawUrl = _firstNonEmptyString([
        entry['url'],
        entry['file_url'],
        entry['image_url'],
        existing?['url'],
        existing?['file_url'],
        existing?['image_url'],
        attachment?['url'],
        attachment?['file_url'],
        attachment?['image_url'],
        message?['url'],
        message?['file_url'],
        message?['image_url'],
      ]);

      matches.add(
        ChatDuplicateFileMatch(
          originalName:
              _firstNonEmptyString([entry['name'], entry['file_name']]) ?? '',
          existingName: _firstNonEmptyString([
            existing?['name'],
            existing?['file_name'],
            attachment?['name'],
            attachment?['file_name'],
            message?['name'],
            message?['file_name'],
            entry['existing_name'],
            entry['duplicate_name'],
            entry['matched_name'],
            entry['name'],
            entry['file_name'],
          ]),
          hash: _firstNonEmptyString([existing?['hash'], entry['hash']]),
          size: _firstInt([
            existing?['size'],
            attachment?['size'],
            message?['size'],
            entry['size'],
          ]),
          mimeType: _firstNonEmptyString([
            existing?['mime_type'],
            attachment?['mime_type'],
            message?['mime_type'],
            entry['mime_type'],
          ]),
          messageId: _firstInt([
            existing?['message_id'],
            message?['id'],
            entry['message_id'],
            entry['existing_message_id'],
          ]),
          attachmentUrl: rawUrl,
          raw: entry,
        ),
      );
    }

    return matches;
  }

  Map<String, dynamic>? _normalizeDuplicatePayload(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) {
      return {'items': data};
    }
    return null;
  }

  bool _entryRepresentsDuplicate(Map<String, dynamic> entry) {
    if (entry.containsKey('exists')) {
      final existsValue = _readBool(entry['exists']);
      if (existsValue) return true;
    }

    if (_readBool(entry['duplicate']) ||
        _readBool(entry['is_duplicate']) ||
        _readBool(entry['already_exists']) ||
        entry.containsKey('existing_file') ||
        entry.containsKey('existing_message') ||
        entry.containsKey('matched_file')) {
      return true;
    }

    return false;
  }

  bool _looksLikeDuplicateEntry(Map<String, dynamic> entry) {
    return entry.containsKey('exists') ||
        entry.containsKey('duplicate') ||
        entry.containsKey('is_duplicate') ||
        entry.containsKey('existing_file') ||
        entry.containsKey('matches');
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  Map<String, dynamic>? _firstNestedMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  int? _firstInt(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is int) return value;
      final parsed = int.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'application/msword';
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return 'application/vnd.ms-excel';
    }
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return 'application/vnd.ms-powerpoint';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  ChatMessage? findExistingAttachmentMessage(ChatDuplicateFileMatch match) {
    if (match.messageId != null) {
      try {
        return messages.firstWhere((message) => message.id == match.messageId);
      } catch (_) {}
    }

    final desiredName = match.displayName.trim().toLowerCase();
    if (desiredName.isEmpty) return null;

    for (final message in messages) {
      final currentName = (message.attachmentName ?? '').trim().toLowerCase();
      if (currentName == desiredName) {
        return message;
      }
    }
    return null;
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
    String? deleteScope,
  }) async {
    Loaders.show();
    final int index = messages.indexWhere((m) => m.id == messageId);
    ChatMessage? deletedMessage;
    if (index != -1) {
      deletedMessage = messages[index];
      _pendingDeletedMessageIndexes[messageId] = index;
      messages.removeAt(index);
      notifyListeners();
    }
    try {
      final url = Uri.parse("${ApiRoutes.baseUrl}chat/messages/$messageId");
      final request = http.Request('DELETE', url);
      request.headers.addAll(await apiHeaders());
      if (deleteScope != null && deleteScope.trim().isNotEmpty) {
        request.body = jsonEncode({'delete_scope': deleteScope.trim()});
      }

      final sanitizedHeaders = Map<String, String>.from(request.headers);
      if (sanitizedHeaders.containsKey('Authorization')) {
        sanitizedHeaders['Authorization'] = 'Bearer ***';
      }
      if (sanitizedHeaders.containsKey('authorization')) {
        sanitizedHeaders['authorization'] = 'Bearer ***';
      }

      printData(title: "Delete request url", data: url.toString());
      printData(title: "Delete request method", data: request.method);
      printData(title: "Delete request headers", data: sanitizedHeaders);
      printData(
        title: "Delete request body",
        data: request.body.isEmpty ? "<empty>" : request.body,
      );

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      printData(title: "Delete response status", data: res.statusCode);
      printData(title: "Delete response headers", data: res.headers);
      printData(
        title: "Delete response body",
        data: res.body.isEmpty ? "<empty>" : res.body,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        Map<String, dynamic>? decodedResponse;
        if (res.body.isNotEmpty) {
          try {
            final dynamic parsed = jsonDecode(res.body);
            if (parsed is Map<String, dynamic>) {
              decodedResponse = parsed;
            } else if (parsed is Map) {
              decodedResponse = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        }

        final preservedMessage = decodedResponse != null
            ? _buildPreservedDeletedMessage(decodedResponse)
            : null;

        if (preservedMessage != null) {
          final existingIndex = messages.indexWhere(
            (m) => m.id == preservedMessage.id,
          );
          if (existingIndex != -1) {
            messages[existingIndex] = preservedMessage;
          } else if (index != -1 && index <= messages.length) {
            messages.insert(index, preservedMessage);
          } else {
            messages.insert(0, preservedMessage);
          }
        }

        _pendingDeletedMessageIndexes.remove(messageId);

        _syncConversationAfterMessageDeletion(
          conversationId: conversationId,
          deletedMessageId: messageId,
        );
        notifyListeners();
        showToast(message: "Message deleted successfully");
      } else {
        String backendMsg = "Failed to delete message";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map && decoded['message'] is String) {
            backendMsg = decoded['message'];
          }
        } catch (_) {}
        if (deletedMessage != null && index != -1) {
          messages.insert(index, deletedMessage);
          _pendingDeletedMessageIndexes.remove(messageId);
          notifyListeners();
        }
        showToast(message: backendMsg);
      }
    } catch (e) {
      printData(title: "deleteMessage error", data: e, e: true);
      // Revert on error
      if (deletedMessage != null && index != -1) {
        messages.insert(index, deletedMessage);
        _pendingDeletedMessageIndexes.remove(messageId);
        notifyListeners();
      }
      showToast(message: "Failed to delete message");
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
