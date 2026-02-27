import 'dart:convert';

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
          ? DateTime.parse(json['updated_at'])
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
          ? DateTime.parse(json['last_seen_at'])
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

  // Call-related fields (from attachments)
  final String? callOutcome; // 'attended', 'missed', 'no-answer', etc.
  final List<Map<String, dynamic>>? toUsers; // list of {id, name, image}

  ChatLatestMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.userId,
    this.userName,
    this.userLastName,
    this.callOutcome,
    this.toUsers,
  });

  factory ChatLatestMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];

    // Parse attachments for call data
    String? callOutcome;
    List<Map<String, dynamic>>? toUsers;
    final type = json['type'] ?? 'text';
    if (type == 'voice' || type == 'call') {
      var att = json['attachments'];
      Map<String, dynamic>? attMap;
      if (att is Map<String, dynamic>) {
        attMap = att;
      } else if (att is Map) {
        attMap = Map<String, dynamic>.from(att);
      }
      if (attMap != null) {
        callOutcome = attMap['call_outcome']?.toString();
        if (attMap['to_users'] is List) {
          toUsers = (attMap['to_users'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    }

    return ChatLatestMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      message: json['message'] ?? '',
      type: type,
      createdAt: DateTime.parse(json['created_at']),
      userId: user != null && user['id'] != null ? user['id'] as int : null,
      userName: user != null ? user['name'] : null,
      userLastName: user != null ? user['last_name'] : null,
      callOutcome: callOutcome,
      toUsers: toUsers,
    );
  }
}

class CallFromNumber {
  final String number;
  final String label;
  final String? context;
  final String? type;
  final bool isTwilio;
  final String? display;
  final String? lineType;
  final String? logo;

  CallFromNumber({
    required this.number,
    required this.label,
    this.context,
    this.type,
    required this.isTwilio,
    this.display,
    this.lineType,
    this.logo,
  });

  factory CallFromNumber.fromJson(Map<String, dynamic> json) {
    return CallFromNumber(
      number: json['number']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      context: json['context']?.toString(),
      type: json['type']?.toString(),
      isTwilio: json['is_twilio'] == true,
      display: json['display']?.toString(),
      lineType: json['line_type']?.toString(),
      logo: json['logo']?.toString(),
    );
  }
}

/// Represents a target user with their callable numbers
class CallTarget {
  final CallTargetUser user;
  final List<CallFromNumber> numbers;

  CallTarget({required this.user, required this.numbers});

  factory CallTarget.fromJson(Map<String, dynamic> json) {
    return CallTarget(
      user: CallTargetUser.fromJson(json['user'] as Map<String, dynamic>),
      numbers: (json['numbers'] as List<dynamic>? ?? [])
          .map((e) => CallFromNumber.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// User info inside a call target
class CallTargetUser {
  final int id;
  final String name;
  final String? lastName;
  final String? image;
  final int? role;
  final bool isOnline;

  CallTargetUser({
    required this.id,
    required this.name,
    this.lastName,
    this.image,
    this.role,
    this.isOnline = false,
  });

  String get fullName =>
      '$name${lastName != null && lastName!.isNotEmpty ? ' $lastName' : ''}';

  factory CallTargetUser.fromJson(Map<String, dynamic> json) {
    return CallTargetUser(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      lastName: json['last_name']?.toString(),
      image: json['image']?.toString(),
      role: json['role'],
      isOnline: json['is_online'] == true,
    );
  }
}

/// Full response from chat/call-popup-data API
class CallPopupData {
  final int conversationId;
  final String type; // 'private' | 'group'
  final List<CallFromNumber> callFromNumbers;
  final int? callFromUserId;
  final List<CallTarget> targets;

  CallPopupData({
    required this.conversationId,
    required this.type,
    required this.callFromNumbers,
    this.callFromUserId,
    required this.targets,
  });

  factory CallPopupData.fromJson(Map<String, dynamic> json) {
    final callFrom = json['call_from'] as Map<String, dynamic>? ?? {};
    return CallPopupData(
      conversationId: json['conversation_id'] ?? 0,
      type: json['type']?.toString() ?? 'private',
      callFromUserId: callFrom['user_id'],
      callFromNumbers: (callFrom['numbers'] as List<dynamic>? ?? [])
          .map((e) => CallFromNumber.fromJson(e as Map<String, dynamic>))
          .toList(),
      targets: (json['targets'] as List<dynamic>? ?? [])
          .map((e) => CallTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int? senderId;
  final String message;

  final String type; // text | image | audio
  final String? audioUrl; // voice message URL
  final int? audioDuration; // seconds (optional)
  final List<double>? voiceWaveform; // wave data

  final DateTime createdAt;
  final bool isMe;
  final String? senderName; // NEW
  final String? senderAvatar; // NEW

  final bool? isRead;
  final bool? isDelivered;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  // Call-type fields (also used for call recordings in voice messages)
  final bool isCallRecording; // true when voice msg has is_call_recording
  final String? callOutcome; // missed, completed, no-answer, etc.
  final bool? isMissedCall;
  final String? callDirection; // incoming, outgoing
  final String? callFromNumber;
  final String? callToNumber;
  final String? callStatus; // no-answer, completed, busy, etc.
  final List<Map<String, dynamic>>? callerUsers;
  final List<Map<String, dynamic>>? toUsers;

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
    this.isRead,
    this.isDelivered,
    this.deliveredAt,
    this.readAt,
    this.senderName,
    this.senderAvatar,
    this.isCallRecording = false,
    this.callOutcome,
    this.isMissedCall,
    this.callDirection,
    this.callFromNumber,
    this.callToNumber,
    this.callStatus,
    this.callerUsers,
    this.toUsers,
    this.voiceWaveform,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final user = json['user'];
    final userId = user != null ? user['id'] : json['user_id'];

    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: userId,
      message: json['message'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isMe: userId != null && userId == currentUserId,
      senderName: user != null
          ? "${user['name'] ?? ''} ${user['last_name'] ?? ''}".trim()
          : null,
      senderAvatar: user != null ? user['image'] : null,
      isRead: json['is_read'],
      isDelivered: json['is_delivered'],
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'])
          : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      type: json['type'] ?? 'text',
      audioUrl: _extractVoiceUrl(json),
      audioDuration: json['voice_duration'],
      isCallRecording: _isCallRecording(json),
      callOutcome: _callOrRecordingField(json, 'call_outcome'),
      isMissedCall: _isCallOrRecording(json)
          ? (_getAttachmentsMap(json)?['is_missed'] == true)
          : null,
      callDirection: _callOrRecordingField(json, 'direction'),
      callFromNumber: _callOrRecordingField(json, 'from_number'),
      callToNumber: _callOrRecordingField(json, 'to_number'),
      callStatus: _callOrRecordingField(json, 'call_status'),
      callerUsers: _callOrRecordingListField(json, 'caller_users'),
      toUsers: _callOrRecordingListField(json, 'to_users'),
      voiceWaveform: _extractVoiceWaveform(json),
    );
  }

  static List<double>? _extractVoiceWaveform(Map<String, dynamic> json) {
    if (json['voice_waveform'] != null &&
        json['voice_waveform']['waveform_data'] != null) {
      final data = json['voice_waveform']['waveform_data'];
      if (data is List) {
        return data.map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
      }
    }
    return null;
  }

  static Map<String, dynamic>? _getAttachmentsMap(Map<String, dynamic> json) {
    var att = json['attachments'];
    if (att == null) return null;
    if (att is Map<String, dynamic>) return att;
    if (att is Map) return Map<String, dynamic>.from(att);
    if (att is List && att.isNotEmpty) {
      final first = att[0];
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    if (att is String && att.isNotEmpty) {
      try {
        final decoded = jsonDecode(att);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        } else if (decoded is List && decoded.isNotEmpty) {
          final first = decoded[0];
          if (first is Map) return Map<String, dynamic>.from(first);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Whether this JSON represents a call-type OR voice call-recording message
  static bool _isCallOrRecording(Map<String, dynamic> json) {
    if (json['type'] == 'call') return true;
    if (json['type'] == 'voice') {
      final att = _getAttachmentsMap(json);
      if (att != null && att['is_call_recording'] == true) return true;
    }
    return false;
  }

  /// Whether this is specifically a call recording (voice msg with recording)
  static bool _isCallRecording(Map<String, dynamic> json) {
    if (json['type'] != 'voice') return false;
    final att = _getAttachmentsMap(json);
    return att != null && att['is_call_recording'] == true;
  }

  static String? _callOrRecordingField(Map<String, dynamic> json, String key) {
    if (!_isCallOrRecording(json)) return null;
    final att = _getAttachmentsMap(json);
    if (att != null) return att[key]?.toString();
    return null;
  }

  static List<Map<String, dynamic>>? _callOrRecordingListField(
    Map<String, dynamic> json,
    String key,
  ) {
    if (!_isCallOrRecording(json)) return null;
    final att = _getAttachmentsMap(json);
    if (att != null && att[key] is List) {
      return (att[key] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return null;
  }

  /// Helper to extract voice URL with multiple fallback options
  static String? _extractVoiceUrl(Map<String, dynamic> json) {
    if (json['type'] != 'voice') return null;

    // Try 1: Direct audio_url field
    if (json['audio_url'] != null) {
      return json['audio_url'];
    }

    final att = _getAttachmentsMap(json);
    if (att != null) {
      return att['voice_url'] ?? att['file'] ?? att['url'];
    }

    return null;
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
      createdAt: createdAt,
      isMe: isMe,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      isCallRecording: isCallRecording,
      callOutcome: callOutcome,
      isMissedCall: isMissedCall,
      callDirection: callDirection,
      callFromNumber: callFromNumber,
      callToNumber: callToNumber,
      callStatus: callStatus,
      callerUsers: callerUsers,
      toUsers: toUsers,
      voiceWaveform: voiceWaveform ?? this.voiceWaveform,
    );
  }
}
