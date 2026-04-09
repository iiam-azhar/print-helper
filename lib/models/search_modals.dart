class SearchUsers {
  final int id;
  final String name;
  final String lastName;
  final String? email;
  final String? image;
  final int role;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String userType;

  SearchUsers({
    required this.id,
    required this.name,
    required this.lastName,
    this.email,
    this.image,
    required this.role,
    this.isOnline = false,
    this.lastSeenAt,
    this.userType = 'STAFF',
  });

  factory SearchUsers.fromJson(Map<String, dynamic> json) {
    return SearchUsers(
      id: json['id'],
      name: json['name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      image: json['image'],
      role: json['role'] ?? 0,
      isOnline: json['is_online'] ?? false,
      userType: json['userType'] ?? 'STAFF',
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
    );
  }

  String get fullName => '$name $lastName'.trim();
}
