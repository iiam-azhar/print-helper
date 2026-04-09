import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/cupertino.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/utils/console_util.dart';

class ReverbSocketService {
  late PusherChannelsClient _client;
  PrivateChannel? _conversationChannel;
  PrivateChannel?
  _userChannel; // Added to keep track of user channel explicitly
  Timer? _retryConnectTimer;

  // Subscriptions
  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _messageDeletedSub;
  StreamSubscription? _messageStatusSub;
  StreamSubscription? _userStatusSub;
  StreamSubscription? _conversationCreatedSub;
  StreamSubscription? _unreadCountUpdatedSub;
  StreamSubscription? _conversationUpdatedSub;
  StreamSubscription? _messageUpdatedSub; // Added for message edits
  StreamSubscription?
  _connectionEstablishedSub; // Prevents duplicate listeners on reconnect

  // ----------------------------------------------------------------
  // --- File/Folder Event Subscriptions ---
  // ----------------------------------------------------------------
  StreamSubscription? _folderCreatedSub;
  StreamSubscription? _folderRenamedSub;
  StreamSubscription? _folderDeletedSub;
  StreamSubscription? _fileRenamedSub;
  StreamSubscription? _fileDeletedSub;
  StreamSubscription? _itemsDeletedSub;
  StreamSubscription? _itemsMovedSub;
  StreamSubscription? _itemsCopiedSub;

  bool _isConnected = false;
  final String? currentUserId;

  // --- Callbacks ---

  // 1. Core Messaging
  final void Function(Map<String, dynamic>) onMessageReceived;
  final void Function(bool isTyping) onTypingReceived;

  // 2. New Event Callbacks
  final void Function(Map<String, dynamic>)? onMessageDeleted;
  final void Function(Map<String, dynamic>)? onMessageUpdated; // For edits
  final void Function(Map<String, dynamic>)?
  onMessageStatusUpdated; // For Read/Delivered status
  final void Function(Map<String, dynamic>)?
  onUserStatusChanged; // For Online/Offline
  final void Function(Map<String, dynamic>)?
  onConversationCreated; // For new chats
  final void Function(Map<String, dynamic>)?
  onGroupMemberAdded; // For group member added
  final void Function(Map<String, dynamic>)?
  onGroupMemberRemoved; // For group member removed
  final void Function(Map<String, dynamic>)?
  onConversationUpdated; // For group title/image/participants changes
  final void Function(Map<String, dynamic>)?
  onUnreadCountUpdated; // For total unread counter badges

  // 3. File Operation Callbacks
  final void Function(Map<String, dynamic>)? onFileOperation;

  final VoidCallback onConnected;

  ReverbSocketService({
    required this.onMessageReceived,
    required this.onTypingReceived,
    required this.onConnected,
    this.onMessageDeleted,
    this.onMessageUpdated,
    this.onMessageStatusUpdated,
    this.onUserStatusChanged,
    this.onConversationCreated,
    this.onGroupMemberAdded,
    this.onGroupMemberRemoved,
    this.onConversationUpdated,
    this.onUnreadCountUpdated,
    this.onFileOperation,
    this.currentUserId,
  });

  void _handleConnectionError(
    Object err,
    void Function() refresh,
    String source,
  ) {
    printData(title: source, data: err, e: true);
    final message = err.toString().toLowerCase();
    final isHostLookupFailure =
        message.contains('failed host lookup') ||
        message.contains('no address associated with hostname');

    _retryConnectTimer?.cancel();

    if (isHostLookupFailure) {
      _retryConnectTimer = Timer(const Duration(seconds: 4), () {
        refresh();
      });
      return;
    }

    refresh();
  }

  /// ----------------------------------------------------------------
  /// 1. CONNECT USER CHANNEL (Global Events)
  /// Listens for: 'conversation.created', 'message.sent' (notifications)
  /// ----------------------------------------------------------------
  void connectUserChannel({
    required String host,
    required int port,
    required String appKey,
    required String userId,
    required Uri authEndpoint,
    required Map<String, String> headers,
    required BuildContext context,
  }) {
    if (_isConnected) return;
    _isConnected = true;
    final options = PusherChannelsOptions.fromHost(
      scheme: 'wss',
      host: host,
      port: port,
      key: appKey,
    );
    _client = PusherChannelsClient.websocket(
      options: options,
      connectionErrorHandler: (err, stack, refresh) {
        _handleConnectionError(err, refresh, "Reverb User Error:");
      },
    );
    _connectionEstablishedSub?.cancel();
    _connectionEstablishedSub = _client.onConnectionEstablished.listen((_) {
      printData(title: "✅ Reverb User Channel Connected", data: "");
      final auth =
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: authEndpoint,
            headers: headers,
          );
      _userChannel = _client.privateChannel(
        "private-user.$userId",
        authorizationDelegate: auth,
      );

      // --- DISCOVERY & BROADCAST HANDLING ---
      // We use bindToAll() to catch everything, including the generic 'files.changed' event.
      _userChannel!.bindToAll().listen((event) {
        // 1. Log for debugging
        if (event.name != 'pusher:pong' && event.name != 'pusher_internal:subscription_succeeded') {
          printData(title: "🎈 REVERB EVENT:", data: "Name: ${event.name}, Data: ${event.data}");
        }

        // 2. Handle File System Mutations
        if (event.name == 'files.changed' || event.name == '.files.changed') {
          if (onFileOperation == null) return;
          final data = _safeJsonDecode(event.data);
          if (data != null) {
            final action = data['action'] ?? event.name;
            printData(
              title: '📁 FILE EVENT: ${action.toString().toUpperCase()}',
              data: data.toString(),
            );
            onFileOperation!(data);
          }
        }
      });

      // EVENT: conversation.created
      // Triggered when someone else starts a chat with this user
      _conversationCreatedSub = _userChannel!
          .bind('conversation.created')
          .listen((event) {
            if (onConversationCreated == null || !context.mounted) return;
            final data = _safeJsonDecode(event.data);

            if (data == null) return;
            final convoId = data['conversation_id'];

            if (convoId == null) return;
            final pro = getChatPro(context);

            final alreadyExists = pro.conversations.any(
              (c) => c.id == convoId && '${c.otherParticipants?.id}' == userId,
            );
            if (alreadyExists) return;

            logData(title: '🆕 CONVERSATION CREATED:', data: data.toString());
            onConversationCreated!(data);
          });

      // EVENT: unread.count.updated (total unread badge)
      _unreadCountUpdatedSub = _userChannel!
          .bind('unread.count.updated')
          .listen((event) {
            if (onUnreadCountUpdated == null || !context.mounted) return;
            final data = _safeJsonDecode(event.data);
            if (data == null) return;
            logData(title: '🔔 UNREAD COUNT UPDATED:', data: data.toString());
            onUnreadCountUpdated!(data);
          });

      // EVENT: group.member.added
      // Triggered when a member is added to a group
      _userChannel!.bind('group.member.added').listen((event) {
        if (onGroupMemberAdded == null || !context.mounted) return;
        final data = _safeJsonDecode(event.data);
        if (data == null) return;
        logData(title: '➕ GROUP MEMBER ADDED:', data: data.toString());
        onGroupMemberAdded!(data);
      });

      // EVENT: group.member.removed
      // Triggered when a member is removed from a group
      _userChannel!.bind('group.member.removed').listen((event) {
        if (onGroupMemberRemoved == null || !context.mounted) return;
        final data = _safeJsonDecode(event.data);
        if (data == null) return;
        logData(title: '➖ GROUP MEMBER REMOVED:', data: data.toString());
        onGroupMemberRemoved!(data);
      });

      // EVENT: conversation.updated
      // Triggered when a group title, image, or participants change
      _conversationUpdatedSub = _userChannel!
          .bind('conversation.updated')
          .listen((event) {
            if (onConversationUpdated == null || !context.mounted) return;
            final data = _safeJsonDecode(event.data);
            if (data == null) return;
            logData(title: '🔄 CONVERSATION UPDATED:', data: data.toString());
            onConversationUpdated!(data);
          });

      // EVENT: message.sent (Global Notification) //external chatlist
      // Optional: You might want to show a top-snackbar notification here
      _messageSub = _userChannel!.bind("message.sent").listen((event) {
        final data = _safeJsonDecode(event.data);
        if (data != null) {
          logData(title: '📩 MESSAGE SENT:', data: data.toString());
          printData(title: "📩 MESSAGE RECEIVED:", data: data);
          onMessageReceived(data);
        }
      });

      _messageDeletedSub = _userChannel!.bind("message.deleted").listen((
        event,
      ) {
        final data = _safeJsonDecode(event.data);
        if (data != null && onMessageDeleted != null) {
          printData(title: "MESSAGE DELETED (User Channel):", data: data);
          onMessageDeleted!(data);
        }
      });


      _userChannel!.subscribeIfNotUnsubscribed();
      onConnected();
    });
    _client.connect();
  }

  void connectConversationChannel({
    required String host,
    required int port,
    required String appKey,
    required String conversationId,
    required Uri authEndpoint,
    required Map<String, String> headers,
  }) {
    if (_conversationChannel != null) {
      return; // Already connected to this conversation
    }

    // Reuse existing client if user channel is already initialized
    if (_userChannel == null) {
      // Client not initialized yet, create it
      final options = PusherChannelsOptions.fromHost(
        scheme: 'wss',
        host: host,
        port: port,
        key: appKey,
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (err, stack, refresh) {
          _handleConnectionError(err, refresh, "Reverb Chat Error:");
        },
      );
      _client.connect();
    }

    // Wait for connection, then subscribe to conversation channel
    _client.onConnectionEstablished.listen((_) {
      printData(title: "✅ Reverb Conversation Channel Connected", data: "");

      final auth =
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
            authorizationEndpoint: authEndpoint,
            headers: headers,
          );
      _conversationChannel = _client.privateChannel(
        "private-conversation.$conversationId",
        authorizationDelegate: auth,
      );
      // 1. Message Sent internal chat
      _messageSub = _conversationChannel!.bind("message.sent").listen((event) {
        final data = _safeJsonDecode(event.data);
        if (data != null) {
          printData(title: "📩 REVERB MSG RECEIVED (Convo):", data: data);
          onMessageReceived(data);
        }
      });
      // 2. Message Deleted
      _messageDeletedSub = _conversationChannel!.bind("message.deleted").listen(
        (event) {
          final data = _safeJsonDecode(event.data);
          if (data != null && onMessageDeleted != null) {
            printData(title: "MESSAGE DELETED:", data: data);
            onMessageDeleted!(data);
          }
        },
      );
      // X. Message Updated
      _messageUpdatedSub = _conversationChannel!.bind("message.updated").listen(
        (event) {
          final data = _safeJsonDecode(event.data);
          if (data != null && onMessageUpdated != null) {
            printData(title: "MESSAGE UPDATED:", data: data);
            onMessageUpdated!(data);
          }
        },
      );
      // 3. Message Read Status (Read/Delivered)
      _messageStatusSub = _conversationChannel!.bind("message.status").listen((
        event,
      ) {
        final data = _safeJsonDecode(event.data);
        if (data != null && onMessageStatusUpdated != null) {
          printData(title: "MESSAGE STATUS UPDATE:", data: data);
          onMessageStatusUpdated!(data);
        }
      });
      // 4. User Status (Online/Offline)
      _userStatusSub = _conversationChannel!.bind("user.status").listen((
        event,
      ) {
        final data = _safeJsonDecode(event.data);
        if (data != null && onUserStatusChanged != null) {
          printData(title: "USER STATUS:", data: data);
          onUserStatusChanged!(data);
        }
      });
      // 5. User Typing
      _typingSub = _conversationChannel!.bind("user.typing").listen((event) {
        final data = _safeJsonDecode(event.data);
        if (data != null) {
          final senderId = data['user_id']?.toString();
          // Don't show typing indicator if it's me
          if (senderId == currentUserId) return;

          final isTyping =
              data['is_typing']?.toString() == 'true' ||
              data['is_typing'] == true;
          onTypingReceived(isTyping);
        }
      });

      _conversationChannel!.subscribeIfNotUnsubscribed();
      onConnected();
    });
  }

  /// Helper to safely decode JSON
  Map<String, dynamic>? _safeJsonDecode(String jsonString) {
    try {
      return jsonDecode(jsonString);
    } catch (e) {
      printData(title: "⚠️ JSON Parse Error:", data: e, e: true);
      return null;
    }
  }

  /// DISCONNECT SOCKET CLEANLY
  void disconnect() {
    printData(title: "🔌 Disconnecting Reverb socket", data: "");
    _retryConnectTimer?.cancel();
    _connectionEstablishedSub?.cancel();
    _messageSub?.cancel();
    _typingSub?.cancel();
    _messageDeletedSub?.cancel();
    _messageUpdatedSub?.cancel();
    _messageStatusSub?.cancel();
    _userStatusSub?.cancel();
    _conversationCreatedSub?.cancel();
    _unreadCountUpdatedSub?.cancel();
    _conversationUpdatedSub?.cancel();
    _folderCreatedSub?.cancel();
    _folderRenamedSub?.cancel();
    _folderDeletedSub?.cancel();
    _fileRenamedSub?.cancel();
    _fileDeletedSub?.cancel();
    _itemsDeletedSub?.cancel();
    _itemsMovedSub?.cancel();
    _itemsCopiedSub?.cancel();
    _conversationChannel?.unsubscribe();
    _userChannel?.unsubscribe();
    _conversationChannel = null;
    _userChannel = null;
    try {
      _client.dispose();
    } catch (_) {}
    _isConnected = false;
  }
}
