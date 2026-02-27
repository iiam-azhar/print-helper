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
    final participants = (json['participants'] as List)
        .map((e) => GroupParticipant.fromJson(e))
        .toList();

    // Collect admin IDs from top-level array OR from each participant's pivot
    final topLevelAdminIds = List<int>.from(json['admin_ids'] ?? []);
    final pivotAdminIds = participants
        .where((p) => p.isAdmin)
        .map((p) => p.id)
        .toList();
    final allAdminIds = {...topLevelAdminIds, ...pivotAdminIds}.toList();

    return GroupDetail(
      id: json['id'],
      title: json['title'],
      type: json['type'],
      image: json['image'],
      isSystem: json['is_system'] ?? false,
      createdBy: json['created_by'],
      adminIds: allAdminIds,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      participants: participants,
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

  /// True if the API marks this participant as an admin via pivot data
  final bool isAdmin;

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
    this.isAdmin = false,
  });

  factory GroupParticipant.fromJson(Map<String, dynamic> json) {
    // Check pivot object for admin role (Laravel pivot table pattern)
    final pivot = json['pivot'] as Map<String, dynamic>?;
    final pivotRole = pivot?['role']?.toString() ?? '';
    final pivotIsAdmin = pivot?['is_admin'];
    final isAdmin =
        pivotRole == 'admin' ||
        pivotIsAdmin == true ||
        pivotIsAdmin == 1 ||
        pivotIsAdmin == '1';

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
      isAdmin: isAdmin,
    );
  }

  String get fullName => "$name $lastName".trim();
}
