import '../utils/console_util.dart';

class ClientModel {
  final int id;
  final String companyName;
  final String? logo;

  final String companyType;
  final String primaryColor;
  final String secondaryColor;

  final String createdDate;
  final String createdTime;
  final int customersCount;
  bool status;
  final List<String> clientLanguages;
  final List<ContactModel> contacts;

  ClientModel({
    required this.id,
    required this.companyName,
    required this.logo,
    required this.companyType,
    required this.createdDate,
    required this.createdTime,
    required this.primaryColor,
    required this.secondaryColor,
    required this.customersCount,
    required this.status,
    required this.clientLanguages,
    required this.contacts,
  });

  ClientModel copyWith({
    int? id,
    String? companyName,
    String? logo,
    String? companyType,
    String? createdDate,
    String? createdTime,
    String? primaryColor,
    String? secondaryColor,
    int? customersCount,
    bool? status,
    List<String>? clientLanguages,
    List<ContactModel>? contacts,
  }) {
    return ClientModel(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      logo: logo ?? this.logo,
      companyType: companyType ?? this.companyType,
      createdDate: createdDate ?? this.createdDate,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      createdTime: createdTime ?? this.createdTime,
      customersCount: customersCount ?? this.customersCount,
      status: status ?? this.status,
      clientLanguages: clientLanguages ?? this.clientLanguages,
      contacts: contacts ?? this.contacts,
    );
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    final createdAt = json["created_at"] ?? "";
    String formattedDate = "";
    String formattedTime = "";

    if (createdAt.isNotEmpty && createdAt.contains("T")) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        formattedDate =
            "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year % 100}";
        final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? "pm" : "am";
        formattedTime = "$hour:$minute$period";
      } catch (e) {
        printData(title: "Date parse error:", data: e, e: true);
      }
    }

    return ClientModel(
      id: json["id"] ?? 0,
      companyName: json["company_name"] ?? "",
      logo: json["image"],
      companyType: json["company_type"]?["name"] ?? "N/A",
      createdDate: formattedDate,
      createdTime: formattedTime,
      customersCount: json["customers_count"] ?? 0,
      primaryColor: json["branding_primary_color"] ?? "",
      secondaryColor: json["branding_secondary_color"] ?? "",
      status: (json["status"] == 1 || json["status"] == true),
      clientLanguages: (json["languages"] as List<dynamic>? ?? [])
          .map((lang) => lang["name"].toString())
          .toList(),
      contacts: (json["contacts"] as List<dynamic>? ?? [])
          .map((c) => ContactModel.fromJson(c))
          .toList(),
    );
  }
}

class ContactModel {
  final int contactId;
  final String name;
  final String avatar;
  final List<String> phones;
  final List<String> emails;
  final List<String> languages;
  bool status;
  ContactModel({
    required this.contactId,
    required this.name,
    required this.avatar,
    required this.phones,
    required this.emails,
    required this.languages,
    required this.status,
  });

  ContactModel copyWith({
    int? contactId,
    String? name,
    String? avatar,
    List<String>? phones,
    List<String>? emails,
    List<String>? languages,
    bool? status,
  }) {
    return ContactModel(
      contactId: contactId ?? this.contactId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      languages: languages ?? this.languages,
      status: status ?? this.status,
    );
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    final details = json["contact_details"] ?? {};
    return ContactModel(
      contactId: json["id"] ?? 0,
      name: json["name"] ?? "",
      avatar: json["image"] ?? "",
      phones: (details["phones"] as List<dynamic>? ?? [])
          .map((e) => e["number"].toString())
          .toList(),
      emails: (details["emails"] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      languages: (details["languages"] as List<dynamic>? ?? [])
          .map((e) => e["name"].toString())
          .toList(),
      status: (json["status"] == 1 || json["status"] == true),
    );
  }
}

class StaffModel {
  final int id;
  final String name;

  StaffModel({required this.id, required this.name});

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(id: json["id"], name: json["name"] ?? "");
  }
}
