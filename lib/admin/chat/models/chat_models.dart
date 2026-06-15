import 'dart:convert';

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

String _cleanUrl(String? url) {
  if (url == null) return '';
  return url.trim().replaceAll('`', '').trim();
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

  /// Participant role inside a group conversation: 'member' | 'observer'
  final String? role;
  final String? accountTypeName;
  final String? clientCompanyName;
  final String? customerCompanyName;
  final String? customerClientCompanyName;

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
    this.role,
    this.accountTypeName,
    this.clientCompanyName,
    this.customerCompanyName,
    this.customerClientCompanyName,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['id'],
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      lastName: json['last_name'] ?? '',
      image: _cleanUrl(json['image']?.toString()),
      isOnline: json['is_online'] ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? parseDateLocal(json['last_seen_at'])
          : null,
      phone: json['phone']?.toString(),
      personalPhone: json['personal_phone']?.toString(),
      phoneNumbers: (json['phone_numbers'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      role: json['participant_role']?.toString() ?? json['role']?.toString(),
      accountTypeName: json['account_type_name']?.toString(),
      clientCompanyName: json['client_company_name']?.toString(),
      customerCompanyName: json['customer_company_name']?.toString(),
      customerClientCompanyName: json['customer_client_company_name']
          ?.toString(),
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
  final bool
  isCallRecording; // true when voice latest message is a call recording
  final String? callOutcome; // 'attended', 'missed', 'no-answer', etc.
  final List<Map<String, dynamic>>? toUsers; // list of {id, name, image}
  final String? attachmentName;
  final String? attachmentMimeType;
  final bool isAttachmentMoved;

  ChatLatestMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.createdAt,
    this.userId,
    this.userName,
    this.userLastName,
    this.isCallRecording = false,
    this.callOutcome,
    this.toUsers,
    this.attachmentName,
    this.attachmentMimeType,
    this.isAttachmentMoved = false,
  });

  factory ChatLatestMessage.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final type = json['type'] ?? 'text';
    String message = (json['message'] ?? '').toString();

    // If message is a JSON string (reminder or system card), extract a human-readable title/text
    if (message.trim().startsWith('{') && message.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map) {
          final title = decoded['title']?.toString().trim() ?? '';
          final description = decoded['description']?.toString().trim() ?? '';
          if (title.isNotEmpty && description.isNotEmpty) {
            message = '$title - $description';
          } else if (title.isNotEmpty) {
            message = title;
          } else if (description.isNotEmpty) {
            message = description;
          } else if (decoded['event'] != null) {
            message = decoded['event'].toString();
          } else if (decoded['text'] != null) {
            message = decoded['text'].toString();
          }
        }
      } catch (_) {}
    }

    // Parse attachments for call data
    bool isCallRecording = false;
    String? callOutcome;
    List<Map<String, dynamic>>? toUsers;
    if (type == 'voice' || type == 'call' || type == 'video_call') {
      var att = json['attachments'];
      Map<String, dynamic>? attMap;
      if (att is Map<String, dynamic>) {
        attMap = att;
      } else if (att is Map) {
        attMap = Map<String, dynamic>.from(att);
      }
      if (attMap != null) {
        isCallRecording = attMap['is_call_recording'] == true;
        callOutcome = attMap['call_outcome']?.toString();
        if (attMap['to_users'] is List) {
          toUsers = (attMap['to_users'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      callOutcome ??= _deriveCallOutcomeFromMessage(message);
    }

    final latestAttachment = _getAttachmentsMap(json);

    return ChatLatestMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      message: message,
      type: type,
      createdAt: parseDateLocal(json['created_at']),
      userId: user != null && user['id'] != null ? user['id'] as int : null,
      userName: user != null ? user['name'] : null,
      userLastName: user != null ? user['last_name'] : null,
      isCallRecording: isCallRecording,
      callOutcome: callOutcome,
      toUsers: toUsers,
      attachmentName:
          latestAttachment?['name']?.toString() ??
          latestAttachment?['file_name']?.toString() ??
          latestAttachment?['filename']?.toString() ??
          latestAttachment?['original_name']?.toString(),
      attachmentMimeType:
          latestAttachment?['mime_type']?.toString() ??
          latestAttachment?['file_mime_type']?.toString(),
      isAttachmentMoved: latestAttachment?['is_moved'] == true,
    );
  }

  static Map<String, dynamic>? _getAttachmentsMap(Map<String, dynamic> json) {
    final attachments = json['attachments'];
    if (attachments == null) return null;
    if (attachments is Map<String, dynamic>) return attachments;
    if (attachments is Map) return Map<String, dynamic>.from(attachments);
    if (attachments is List && attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static String? _deriveCallOutcomeFromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('declined') || lower.contains('rejected')) {
      return 'rejected';
    }
    if (lower.contains('missed') || lower.contains('no answer')) {
      return 'no-answer';
    }
    if (lower.contains('canceled') || lower.contains('cancelled')) {
      return 'canceled';
    }
    if (lower.contains('attended') || lower.contains('answered')) {
      return 'attended';
    }
    return null;
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
  final ChatSystemCard? systemCard;

  final String type; // text | image | audio | video
  final String? channel; // app | sms
  final String? audioUrl; // voice message URL
  final int? audioDuration; // seconds (optional)
  final List<double>? voiceWaveform; // wave data

  // Generic image/file attachment fields
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final String? attachmentMimeType;
  final String? thumbnailUrl;
  final double? expiresInDays;
  final bool isExpired;
  final bool isMoved;
  final DateTime? movedAt;
  final String? movedByName;

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
    this.systemCard,
    required this.createdAt,
    required this.isMe,
    this.type = 'text',
    this.channel,
    this.audioUrl,
    this.audioDuration,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentMimeType,
    this.thumbnailUrl,
    this.expiresInDays,
    this.isExpired = false,
    this.isMoved = false,
    this.movedAt,
    this.movedByName,
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
    this.videoUrl,
    this.videoDuration,
    this.videoSize,
    this.videoMimeType,
    this.isVideoCallRecording = false,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    final user = json['user'];
    final userId = user != null ? user['id'] : json['user_id'];
    final parsedSystemCard = _parseSystemCard(json['message']);
    final parsedMessage = _extractMessageText(
      json['message'],
      parsedSystemCard,
    );

    final msg = ChatMessage(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      conversationId: json['conversation_id'] is int
          ? json['conversation_id']
          : int.tryParse(json['conversation_id'].toString()) ?? 0,
      senderId: userId is int ? userId : int.tryParse(userId.toString()),
      message: parsedMessage,
      systemCard: parsedSystemCard,
      createdAt: parseDateLocal(json['created_at']),
      isMe: userId != null && userId == currentUserId,
      senderName: user != null
          ? "${user['name'] ?? ''} ${user['last_name'] ?? ''}".trim()
          : null,
      senderAvatar: user != null ? _cleanUrl(user['image']?.toString()) : null,
      isRead: json['is_read'],
      isDelivered: json['is_delivered'],
      deliveredAt: json['delivered_at'] != null
          ? parseDateLocal(json['delivered_at'])
          : null,
      readAt: json['read_at'] != null ? parseDateLocal(json['read_at']) : null,
      type: json['type'] ?? 'text',
      channel: _extractChannel(json),
      audioUrl: _cleanUrl(_extractVoiceUrl(json)),
      audioDuration: json['voice_duration'],
      attachmentUrl: _cleanUrl(_extractAttachmentUrl(json)),
      attachmentName: _extractAttachmentName(json),
      attachmentSize: _extractAttachmentSize(json),
      attachmentMimeType: _extractAttachmentMimeType(json),
      thumbnailUrl: _cleanUrl(_extractThumbnailUrl(json)),
      expiresInDays: _extractExpiresInDays(json),
      isExpired: _isExpired(json),
      isMoved: _isMoved(json),
      movedAt: _extractMovedAt(json),
      movedByName: _extractMovedByName(json),
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
      videoUrl: _extractVideoUrl(json),
      videoDuration: _extractVideoDuration(json),
      videoSize: _extractVideoSize(json),
      videoMimeType: _extractVideoMimeType(json),
      isVideoCallRecording: _isVideoCallRecording(json),
    );

    // Normalize: If it's a system card and has no attachment URL,
    // use the first attachment from the card if available.
    if (msg.systemCard != null &&
        (msg.attachmentUrl == null || msg.attachmentUrl!.isEmpty)) {
      final items = msg.systemCard!.attachmentItems;
      if (items.isNotEmpty) {
        return msg.copyWith(
          attachmentUrl: _cleanUrl(items.first.url),
          attachmentName: items.first.name,
          attachmentMimeType: items.first.mime,
        );
      }
    }

    return msg;
  }

  static String? _extractChannel(Map<String, dynamic> json) {
    final attachments = json['attachments'];
    Map<String, dynamic>? map;
    if (attachments is Map<String, dynamic>) {
      map = attachments;
    } else if (attachments is Map) {
      map = Map<String, dynamic>.from(attachments);
    }
    if (map != null && map.containsKey('twilio_sms')) return 'sms';
    return null;
  }

  static String _extractMessageText(dynamic raw, ChatSystemCard? card) {
    if (raw == null) return '';

    // First try to format the system card if we have one
    if (card != null) {
      final title = card.title?.trim() ?? '';
      final description = card.description?.trim() ?? '';
      if (title.isNotEmpty && description.isNotEmpty) {
        return '$title - $description';
      }
      if (title.isNotEmpty) return title;
      if (description.isNotEmpty) return description;

      final event = card.event.trim();
      final project = card.project?.trim() ?? '';
      if (event.isNotEmpty && project.isNotEmpty) {
        return '$event: $project';
      }
      if (event.isNotEmpty) return event;
      if (card.text.isNotEmpty) return card.text;
    }

    // If raw is a Map, try to extract the text or format system card fields
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final text = map['text']?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;

      final title = map['title']?.toString().trim() ?? '';
      final description = map['description']?.toString().trim() ?? '';
      if (title.isNotEmpty && description.isNotEmpty) {
        return '$title - $description';
      }
      if (title.isNotEmpty) return title;
      if (description.isNotEmpty) return description;

      final event = map['event']?.toString().trim() ?? '';
      if (event.isNotEmpty) return event;

      return jsonEncode(map);
    }

    // If raw is a String, check if it is JSON representing a system card
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            final title = decoded['title']?.toString().trim() ?? '';
            final description = decoded['description']?.toString().trim() ?? '';
            if (title.isNotEmpty && description.isNotEmpty) {
              return '$title - $description';
            }
            if (title.isNotEmpty) return title;
            if (description.isNotEmpty) return description;

            final event = decoded['event']?.toString().trim() ?? '';
            if (event.isNotEmpty) return event;

            final text = decoded['text']?.toString().trim() ?? '';
            if (text.isNotEmpty) return text;
          }
        } catch (_) {}
      }
      return raw;
    }

    return raw.toString();
  }

  static ChatSystemCard? _parseSystemCard(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        map = null;
      }
    }

    if (map == null) return null;
    if ((map['kind']?.toString().trim().toLowerCase() ?? '') != 'system_card') {
      return null;
    }

    return ChatSystemCard.fromJson(map);
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
    if (json['type'] == 'call' || json['type'] == 'video_call') return true;
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

  static String? _extractAttachmentUrl(Map<String, dynamic> json) {
    if (json['type'] != 'image' && json['type'] != 'file') return null;

    final att = _getAttachmentsMap(json);
    if (att == null) return null;

    return att['file_url']?.toString() ??
        att['image_url']?.toString() ??
        att['url']?.toString() ??
        att['file']?.toString() ??
        att['path']?.toString();
  }

  static String? _extractAttachmentName(Map<String, dynamic> json) {
    if (json['type'] != 'image' && json['type'] != 'file') return null;

    final att = _getAttachmentsMap(json);
    if (att == null) return null;

    return att['name']?.toString() ??
        att['file_name']?.toString() ??
        att['filename']?.toString() ??
        att['original_name']?.toString();
  }

  static int? _extractAttachmentSize(Map<String, dynamic> json) {
    if (json['type'] != 'image' && json['type'] != 'file') return null;

    final att = _getAttachmentsMap(json);
    if (att == null || att['size'] == null) return null;
    return int.tryParse(att['size'].toString());
  }

  static String? _extractAttachmentMimeType(Map<String, dynamic> json) {
    if (json['type'] != 'image' && json['type'] != 'file') return null;

    final att = _getAttachmentsMap(json);
    if (att == null) return null;
    return att['mime_type']?.toString() ?? att['file_mime_type']?.toString();
  }

  static String? _extractThumbnailUrl(Map<String, dynamic> json) {
    if (json['type'] != 'image' && json['type'] != 'file') return null;

    final att = _getAttachmentsMap(json);
    if (att == null) return null;
    return att['thumbnail_url']?.toString() ??
        att['thumbnail']?.toString() ??
        att['preview_url']?.toString();
  }

  static double? _extractExpiresInDays(Map<String, dynamic> json) {
    final att = _getAttachmentsMap(json);
    if (att == null || att['expires_in_days'] == null) return null;
    return double.tryParse(att['expires_in_days'].toString());
  }

  static bool _isExpired(Map<String, dynamic> json) {
    final att = _getAttachmentsMap(json);
    return att != null && att['is_expired'] == true;
  }

  static bool _isMoved(Map<String, dynamic> json) {
    final att = _getAttachmentsMap(json);
    return att != null && att['is_moved'] == true;
  }

  static DateTime? _extractMovedAt(Map<String, dynamic> json) {
    final att = _getAttachmentsMap(json);
    if (att == null || att['moved_at'] == null) return null;
    return parseDateLocal(att['moved_at']?.toString());
  }

  static String? _extractMovedByName(Map<String, dynamic> json) {
    final att = _getAttachmentsMap(json);
    if (att == null) return null;
    return att['moved_by_name']?.toString();
  }

  /// Helper to extract video URL from attachments
  static String? _extractVideoUrl(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    final att = _getAttachmentsMap(json);
    if (att != null) {
      return att['video_url'];
    }

    return null;
  }

  /// Helper to extract video duration from attachments
  static int? _extractVideoDuration(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    final att = _getAttachmentsMap(json);
    if (att != null && att['duration'] != null) {
      return int.tryParse(att['duration'].toString());
    }

    return null;
  }

  /// Helper to extract video size from attachments
  static int? _extractVideoSize(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    final att = _getAttachmentsMap(json);
    if (att != null && att['size'] != null) {
      return int.tryParse(att['size'].toString());
    }

    return null;
  }

  /// Helper to extract video mime type from attachments
  static String? _extractVideoMimeType(Map<String, dynamic> json) {
    if (json['type'] != 'video') return null;

    final att = _getAttachmentsMap(json);
    if (att != null) {
      return att['mime_type'];
    }

    return null;
  }

  /// Whether this is a video call recording
  static bool _isVideoCallRecording(Map<String, dynamic> json) {
    if (json['type'] != 'video') return false;
    final att = _getAttachmentsMap(json);
    return att != null && att['is_video_call_recording'] == true;
  }

  ChatMessage copyWith({
    String? message,
    bool? isRead,
    bool? isDelivered,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      message: message ?? this.message,
      systemCard: systemCard,
      type: type,
      channel: channel,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      thumbnailUrl: thumbnailUrl,
      expiresInDays: expiresInDays,
      isExpired: isExpired,
      isMoved: isMoved,
      movedAt: movedAt,
      movedByName: movedByName,
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
      voiceWaveform: voiceWaveform ?? voiceWaveform,
      videoUrl: videoUrl,
      videoDuration: videoDuration,
      videoSize: videoSize,
      videoMimeType: videoMimeType,
      isVideoCallRecording: isVideoCallRecording,
    );
  }
}

class ChatSystemCard {
  final String kind;
  final String event;
  final String? task;
  final String? project;
  final String? comment;
  final List<String> files;
  final List<String> attachments;
  final List<ChatSystemCardAttachment> attachmentItems;
  final String text;
  final String? title;
  final String? description;
  final String? buttonLabel;
  final String? buttonUrl;

  const ChatSystemCard({
    required this.kind,
    required this.event,
    required this.task,
    required this.project,
    required this.comment,
    required this.files,
    required this.attachments,
    required this.attachmentItems,
    required this.text,
    this.title,
    this.description,
    this.buttonLabel,
    this.buttonUrl,
  });

  factory ChatSystemCard.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      final values = <String>[];
      for (final item in raw) {
        if (item == null) continue;
        if (item is String) {
          final v = item.trim();
          if (v.isNotEmpty) values.add(v);
          continue;
        }
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final name =
              map['name']?.toString().trim() ??
              map['file_name']?.toString().trim() ??
              map['filename']?.toString().trim() ??
              map['original_name']?.toString().trim() ??
              map['title']?.toString().trim() ??
              '';
          if (name.isNotEmpty) values.add(name);
          continue;
        }
        final value = item.toString().trim();
        if (value.isNotEmpty) values.add(value);
      }
      return values;
    }

    List<ChatSystemCardAttachment> parseAttachmentItems(dynamic raw) {
      if (raw is! List) return const <ChatSystemCardAttachment>[];
      final values = <ChatSystemCardAttachment>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        values.add(ChatSystemCardAttachment.fromJson(map));
      }
      return values;
    }

    final parsedFiles = parseStringList(json['files']);
    final parsedAttachmentItems = parseAttachmentItems(json['attachments']);
    final parsedAttachments = <String>{
      ...parsedAttachmentItems
          .map((item) => item.name.trim())
          .where((item) => item.isNotEmpty),
      ...parseStringList(json['attachments']),
    }.toList();

    return ChatSystemCard(
      kind: json['kind']?.toString() ?? 'system_card',
      event: json['event']?.toString().trim() ?? '',
      task: json['task']?.toString(),
      project: json['project']?.toString(),
      comment: json['comment']?.toString(),
      files: parsedFiles,
      attachments: parsedAttachments,
      attachmentItems: parsedAttachmentItems,
      text: json['text']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      buttonLabel: json['button_label']?.toString(),
      buttonUrl: json['button_url']?.toString(),
    );
  }
}

class ChatSystemCardAttachment {
  final String name;
  final String url;
  final String mime;

  const ChatSystemCardAttachment({
    required this.name,
    required this.url,
    required this.mime,
  });

  factory ChatSystemCardAttachment.fromJson(Map<String, dynamic> json) {
    return ChatSystemCardAttachment(
      name:
          json['name']?.toString() ??
          json['file_name']?.toString() ??
          json['filename']?.toString() ??
          '',
      url:
          json['url']?.toString() ??
          json['file_url']?.toString() ??
          json['path']?.toString() ??
          '',
      mime:
          json['mime']?.toString() ??
          json['mime_type']?.toString() ??
          json['file_mime_type']?.toString() ??
          '',
    );
  }
}
