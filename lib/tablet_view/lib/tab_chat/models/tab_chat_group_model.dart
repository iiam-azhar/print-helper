class GroupDetail {
  final int id;
  final String title;
  final String type;
  final String? image;
  final bool isSystem;
  final int createdBy;
  final List<int> adminIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GroupParticipant> participants;
  final int participantsCount;

  GroupDetail({
    required this.id,
    required this.title,
    required this.type,
    this.image,
    required this.isSystem,
    required this.createdBy,
    required this.adminIds,
    required this.createdAt,
    required this.updatedAt,
    required this.participants,
    required this.participantsCount,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    return GroupDetail(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      image: json['image'],
      isSystem: json['is_system'] ?? false,
      createdBy: json['created_by'],
      adminIds: List<int>.from(json['admin_ids'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      participants: (json['participants'] as List)
          .map((e) => GroupParticipant.fromJson(e))
          .toList(),
      participantsCount: json['participants_count'] ?? 0,
    );
  }
}
class GroupParticipant {
  final int id;
  final String name;
  final String lastName;
  final String username;
  final String? email;
  final List<String> emails;
  final String? phone;
  final List<String> phones;
  final String? image;
  final int role;
  final bool isOnline;
  final DateTime? lastSeenAt;

  GroupParticipant({
    required this.id,
    required this.name,
    required this.lastName,
    required this.username,
    this.email,
    required this.emails,
    this.phone,
    required this.phones,
    this.image,
    required this.role,
    required this.isOnline,
    this.lastSeenAt,
  });

  factory GroupParticipant.fromJson(Map<String, dynamic> json) {
    return GroupParticipant(
      id: json['id'],
      name: json['name'],
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      emails: List<String>.from(json['emails'] ?? []),
      phone: json['phone'],
      phones: List<String>.from(json['phones'] ?? []),
      image: json['image'],
      role: json['role'],
      isOnline: json['is_online'] ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
    );
  }

  String get fullName => "$name $lastName".trim();
}
