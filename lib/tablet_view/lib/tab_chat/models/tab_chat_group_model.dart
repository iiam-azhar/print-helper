import 'package:print_helper/admin/chat/models/group_participants_model.dart';
import 'package:print_helper/models/search_modals.dart';

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
  final GroupParticipantsData participants;
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
      participants: GroupParticipantsData.fromJson(json['participants'] ?? {}),
      participantsCount: json['participants_count'] ?? 0,
    );
  }
}

class GroupParticipantsData {
  final List<SearchUsers> selectedStaff;
  final List<ClientCompanyModel> selectedClients;
  final List<SearchUsers> availableStaff;
  final List<ClientCompanyModel> availableClients;

  GroupParticipantsData({
    required this.selectedStaff,
    required this.selectedClients,
    required this.availableStaff,
    required this.availableClients,
  });

  factory GroupParticipantsData.fromJson(Map<String, dynamic> json) {
    final selected = json['selected'] ?? {};
    final available = json['available'] ?? {};

    return GroupParticipantsData(
      selectedStaff: (selected['staff'] as List? ?? []).map((e) {
        e['userType'] = 'STAFF';
        return SearchUsers.fromJson(e);
      }).toList(),
      selectedClients: (selected['clients'] as List? ?? [])
          .map((e) => ClientCompanyModel.fromJson(e))
          .toList(),
      availableStaff: (available['staff'] as List? ?? []).map((e) {
        e['userType'] = 'STAFF';
        return SearchUsers.fromJson(e);
      }).toList(),
      availableClients: (available['clients'] as List? ?? [])
          .map((e) => ClientCompanyModel.fromJson(e))
          .toList(),
    );
  }

  /// Returns a flat list of all selected participants (staff + client members)
  List<SearchUsers> get allSelectedParticipants {
    final Map<int, SearchUsers> deduplicated = {};

    for (var u in selectedStaff) {
      deduplicated[u.id] = u;
    }

    for (var client in selectedClients) {
      for (var u in client.contacts) {
        deduplicated[u.id] = u;
      }
      for (var u in client.customers) {
        deduplicated[u.id] = u;
      }
    }

    return deduplicated.values.toList();
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
