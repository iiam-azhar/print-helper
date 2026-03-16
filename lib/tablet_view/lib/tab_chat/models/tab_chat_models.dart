DateTime parseDateLocal(String? dateString) {
  if (dateString == null || dateString.isEmpty) return DateTime.now();
  String dateStr = dateString.toString();
  if (!dateStr.endsWith('Z') &&
      !dateStr.contains(RegExp(r'[+-]\d{2}:\d{2}$'))) {
    if (!dateStr.contains('T')) {
      dateStr = dateStr.replaceAll(' ', 'T');
    }
    dateStr += 'Z';
  }
  return DateTime.parse(dateStr).toLocal();
}

class ChatConversation {
  final int id;
  final String type; // private | group
  final String title;
  final String image;
  final List<ChatParticipant> participants;
  final ChatLatestMessage? latestMessage;
  int unreadCount;
  final int? totalUnreadCount;
  final DateTime updatedAt;
  final bool isDefault;
  final OtherParticipant? otherParticipants;

  ChatConversation({
    required this.id,
    required this.type,
    required this.title,
    required this.participants,
    this.latestMessage,
    required this.image,
    this.otherParticipants,
    this.totalUnreadCount,
    required this.unreadCount,
    required this.updatedAt,
    required this.isDefault,
  });

  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    int? totalUnreadCount,
  }) {
    return ChatConversation(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: json['type'] ?? 'private',
      title: json['title'] ?? '',
      participants: (json['participants'] as List? ?? [])
          .map((e) => ChatParticipant.fromJson(e))
          .toList(),
      latestMessage: json['latest_message'] != null
          ? ChatLatestMessage.fromJson(json['latest_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
      totalUnreadCount: totalUnreadCount,
      otherParticipants: json['other_participant'] != null
          ? OtherParticipant.fromJson(json['other_participant'])
          : null,
      image: json['image'] ?? '',
      updatedAt: json['updated_at'] != null
          ? parseDateLocal(json['updated_at'])
          : DateTime.now(),
      isDefault: json['is_default'] ?? false,
    );
  }
}

class ChatParticipant {
  final int? id;
  final String name;
  final String username;
  final String lastName;
  final String? image;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? phone;
  final String? personalPhone;
  final List<String> phoneNumbers;

  ChatParticipant({
    this.id,
    required this.name,
    required this.username,
    required this.lastName,
    this.image,
    required this.isOnline,
    this.lastSeenAt,
    this.phone,
    this.personalPhone,
    required this.phoneNumbers,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'],
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      lastName: json['last_name'] ?? '',
      image: json['image'],
      isOnline: json['is_online'] ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? parseDateLocal(json['last_seen_at'])
          : null,
      phone: json['phone'],
      personalPhone: json['personal_phone'],
      phoneNumbers: (json['phone_numbers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class OtherParticipant {
  final int? id; // Can be null if user is deleted
  final String name;
  final String username;

  OtherParticipant({
    required this.id,
    required this.name,
    required this.username,
  });
  factory OtherParticipant.fromJson(Map<String, dynamic> json) {
    return OtherParticipant(
      id: json['id'],
      name: json['name'] ?? '',
      username: json['username'] ?? '',
    );
  }
}

class ChatLatestMessage {
  final int id;
  final String message;
  final String type;
  final DateTime createdAt;

  final int? userId;
  final String? userName;
  final String? userLastName;

  ChatLatestMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.userId,
    this.userName,
    this.userLastName,
  });

  factory ChatLatestMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    return ChatLatestMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      message: json['message'] ?? '',
      type: json['type'] ?? 'text',
      createdAt: parseDateLocal(json['created_at']),
      userId: user != null && user['id'] != null ? user['id'] as int : null,
      userName: user != null ? user['name'] : null,
      userLastName: user != null ? user['last_name'] : null,
    );
  }
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int? senderId;
  final String message;

  final String type; // text | image | audio | call | video
  final String? audioUrl; // voice message URL
  final int? audioDuration; // seconds (optional)
  final Map<String, dynamic>? callAttachments; // call-specific data

  // Video-type fields
  final String? videoUrl; // video message URL
  final int? videoDuration; // seconds
  final int? videoSize; // bytes
  final String? videoMimeType; // video/mp4 etc.
  final bool
  isVideoCallRecording; // true when video msg has is_video_call_recording

  final DateTime createdAt;
  final bool isMe;
  final String? senderName; // NEW
  final String? senderAvatar; // NEW

  final bool? isRead;
  final bool? isDelivered;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.message,
    required this.createdAt,
    required this.isMe,
    this.type = 'text',
    this.audioUrl,
    this.audioDuration,
    this.callAttachments,
    this.isRead,
    this.isDelivered,
    this.deliveredAt,
    this.readAt,
    this.senderName,
    this.senderAvatar,
    this.videoUrl,
    this.videoDuration,
    this.videoSize,
    this.videoMimeType,
    this.isVideoCallRecording = false,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final user = json['user'];
    final userId = user != null ? user['id'] : json['user_id'];

    return ChatMessage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      conversationId: json['conversation_id'] is int
          ? json['conversation_id']
          : int.tryParse(json['conversation_id'].toString()) ?? 0,
      senderId: userId is int ? userId : int.tryParse(userId.toString()),
      message: json['message'] ?? '',
      createdAt: parseDateLocal(json['created_at']),
      isMe: userId != null && userId == currentUserId,
      senderName: user != null
          ? "${user['name'] ?? ''} ${user['last_name'] ?? ''}".trim()
          : null,
      senderAvatar: user != null ? user['image'] : null,
      isRead: json['is_read'],
      isDelivered: json['is_delivered'],
      deliveredAt: json['delivered_at'] != null
          ? parseDateLocal(json['delivered_at'])
          : null,
      readAt: json['read_at'] != null ? parseDateLocal(json['read_at']) : null,
      type: json['type'] ?? 'text',
      audioUrl: _extractVoiceUrl(json),
      audioDuration: json['voice_duration'],
      callAttachments: json['type'] == 'call' && json['attachments'] is Map
          ? Map<String, dynamic>.from(json['attachments'])
          : null,
      videoUrl: _extractVideoUrl(json),
      videoDuration: _extractVideoDuration(json),
      videoSize: _extractVideoSize(json),
      videoMimeType: _extractVideoMimeType(json),
      isVideoCallRecording: _isVideoCallRecording(json),
    );
  }

  /// Helper to extract voice URL with multiple fallback options
  static String? _extractVoiceUrl(Map<String, dynamic> json) {
    if (json['type'] != 'voice') return null;

    // Try 1: Direct audio_url field
    if (json['audio_url'] != null) {
      return json['audio_url'];
    }

    // Try 2: Attachments as list with voice_url
    if (json['attachments'] is List && json['attachments'].isNotEmpty) {
      final attachment = json['attachments'][0];
      if (attachment is Map && attachment['voice_url'] != null) {
        return attachment['voice_url'];
      }
    }

    // Try 3: Attachments as map (in case backend returns it differently)
    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      if (attachments['voice_url'] != null) {
        return attachments['voice_url'];
      }
    }

    // Try 4: Check for file or url field in attachments
    if (json['attachments'] is List && json['attachments'].isNotEmpty) {
      final attachment = json['attachments'][0];
      if (attachment is Map) {
        return attachment['file'] ?? attachment['url'];
      }
    }

    return null;
  }

  /// Helper to extract video URL from attachments
  static String? _extractVideoUrl(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      if (attachments['video_url'] != null) {
        return attachments['video_url'];
      }
    }

    return null;
  }

  /// Helper to extract video duration from attachments
  static int? _extractVideoDuration(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      if (attachments['duration'] != null) {
        return int.tryParse(attachments['duration'].toString());
      }
    }

    return null;
  }

  /// Helper to extract video size from attachments
  static int? _extractVideoSize(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      if (attachments['size'] != null) {
        return int.tryParse(attachments['size'].toString());
      }
    }

    return null;
  }

  /// Helper to extract video mime type from attachments
  static String? _extractVideoMimeType(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      if (attachments['mime_type'] != null) {
        return attachments['mime_type'];
      }
    }

    return null;
  }

  /// Whether this is a video call recording
  static bool _isVideoCallRecording(Map<String, dynamic> json) {
    if (json['type'] != 'video') return false;

    if (json['attachments'] is Map) {
      final attachments = json['attachments'] as Map;
      return attachments['is_video_call_recording'] == true;
    }

    return false;
  }

  /// Getter for voice call recording compatibility
  bool get isCallRecording {
    if (type != 'voice') return false;
    if (callAttachments != null &&
        callAttachments!['is_call_recording'] == true) {
      return true;
    }
    return false;
  }

  /// Getter to extract to_users from call attachments
  List<Map<String, dynamic>>? get toUsers {
    if (type != 'call' || callAttachments == null) return null;
    if (callAttachments!['to_users'] is List) {
      return (callAttachments!['to_users'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return null;
  }

  /// Getter for call from number
  String? get callFromNumber {
    if (type != 'call' || callAttachments == null) return null;
    return callAttachments!['from_number']?.toString();
  }

  /// Getter for call to number
  String? get callToNumber {
    if (type != 'call' || callAttachments == null) return null;
    return callAttachments!['to_number']?.toString();
  }

  ChatMessage copyWith({
    String? message,
    bool? isRead,
    bool? isDelivered,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      message: message ?? this.message,
      type: type,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      callAttachments: callAttachments,
      createdAt: createdAt,
      isMe: isMe,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      videoUrl: videoUrl,
      videoDuration: videoDuration,
      videoSize: videoSize,
      videoMimeType: videoMimeType,
      isVideoCallRecording: isVideoCallRecording,
    );
  }
}
