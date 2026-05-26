// account_model.dart
import 'package:flutter/material.dart';

class AccountModel {
  final int id;
  final int? clientId;
  final int isPrimary;
  final String name;
  final String lastName;
  final String? email;

  final String username;
  final String? emailVerifiedAt;
  final String? image;
  final String? imageUrl;
  final String? language;
  final int role;
  final String? accountType;
  final bool status;
  final String createdAt;
  final String updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final int? customerId;
  final String? deletedAt;
  final String roleName;
  final String? createdByName;
  final List<PhoneItem> phones;
  final List<String> emails;
  final CreatorModel? creator;
  final StaffDetailsModel? staffDetails;

  AccountModel({
    required this.id,
    required this.clientId,
    required this.isPrimary,
    required this.name,
    required this.lastName,
    required this.email,
    required this.username,
    required this.emailVerifiedAt,
    required this.image,
    required this.imageUrl,
    required this.language,
    required this.role,
    required this.accountType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.customerId,
    required this.deletedAt,
    required this.roleName,
    required this.createdByName,
    required this.phones,
    required this.emails,
    required this.creator,
    required this.staffDetails,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final staff = json['staff_details'];

    return AccountModel(
      id: json['id'] ?? 0,
      clientId: json['client_id'],
      isPrimary: json['is_primary'] ?? 0,
      name: json['name'] ?? "",
      lastName: json['last_name'] ?? "",
      email: json['email'] ?? "",
      username: json['username'] ?? "",
      emailVerifiedAt: json['email_verified_at'],
      image: json['image'],
      imageUrl: json['image_url'],
      language: json['language'],
      role: json['role'] ?? 0,
      accountType: json['account_type'],
      status: json['status'] == true,
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      customerId: json['customer_id'],
      deletedAt: json['deleted_at'],
      roleName: json['account_type_name'] ?? "",
      createdByName: json['created_by_name'] ?? "",
      phones: staff != null
          ? (staff['phones'] as List<dynamic>? ?? [])
                .map((e) => PhoneItem.fromJson(e))
                .toList()
          : [],
      emails: staff != null
          ? (staff['emails'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList()
          : [],
      staffDetails: staff != null ? StaffDetailsModel.fromJson(staff) : null,
      creator: json['creator'] != null
          ? CreatorModel.fromJson(json['creator'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'is_primary': isPrimary,
      'name': name,
      'last_name': lastName,
      'email': email,
      'username': username,
      'email_verified_at': emailVerifiedAt,
      'image': image,
      'image_url': imageUrl,
      'language': language,
      'role': role,
      'account_type': accountType,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'customer_id': customerId,
      'deleted_at': deletedAt,
      'role_name': roleName,
      'created_by_name': createdByName,
      'phones': phones.map((e) => e.toJson()).toList(),
      'emails': emails.map((e) => e.toString()).toList(),
      'creator': creator?.toJson(),
      'staff_details': staffDetails?.toJson(),
    };
  }

  AccountModel copyWith({
    int? id,
    int? clientId,
    int? isPrimary,
    String? name,
    String? lastName,
    String? email,
    String? username,
    String? emailVerifiedAt,
    String? image,
    String? imageUrl,
    String? language,
    int? role,
    String? accountType,
    bool? status,
    String? createdAt,
    String? updatedAt,
    int? createdBy,
    int? updatedBy,
    int? customerId,
    String? deletedAt,
    String? roleName,
    String? createdByName,
    List<PhoneItem>? phones,
    List<String>? emails,
    CreatorModel? creator,
    StaffDetailsModel? staffDetails,
  }) {
    return AccountModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      isPrimary: isPrimary ?? this.isPrimary,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      username: username ?? this.username,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,

      image: image ?? this.image,
      imageUrl: imageUrl ?? this.imageUrl,
      language: language ?? this.language,
      role: role ?? this.role,
      accountType: accountType ?? this.accountType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      customerId: customerId ?? this.customerId,
      deletedAt: deletedAt ?? this.deletedAt,
      roleName: roleName ?? this.roleName,
      createdByName: createdByName ?? this.createdByName,
      phones: phones ?? this.phones,
      emails: emails ?? this.emails,
      creator: creator ?? this.creator,
      staffDetails: staffDetails ?? this.staffDetails,
    );
  }
}

class PhoneItem {
  final String type;
  final String number;

  PhoneItem({required this.type, required this.number});

  factory PhoneItem.fromJson(Map<String, dynamic> json) {
    return PhoneItem(type: json['type'] ?? "", number: json['number'] ?? "");
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'number': number};
  }
}

class CreatorModel {
  final int id;
  final int? clientId;
  final int isPrimary;
  final String name;
  final String lastName;
  final String email;
  final String username;
  final String? emailVerifiedAt;
  final String? phone;
  final String? personalPhone;
  final String? image;
  final String? language;
  final int role;
  final String? accountType;
  final bool status;
  final String createdAt;
  final String updatedAt;
  final int? createdBy;
  final int? updatedBy;
  final int? customerId;
  final String? deletedAt;

  CreatorModel({
    required this.id,
    required this.clientId,
    required this.isPrimary,
    required this.name,
    required this.lastName,
    required this.email,
    required this.username,
    required this.emailVerifiedAt,
    required this.phone,
    required this.personalPhone,
    required this.image,
    required this.language,
    required this.role,
    required this.accountType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    required this.customerId,
    required this.deletedAt,
  });

  factory CreatorModel.fromJson(Map<String, dynamic> json) {
    return CreatorModel(
      id: json['id'] ?? 0,
      clientId: json['client_id'],
      isPrimary: json['is_primary'] ?? 0,
      name: json['name'] ?? "",
      lastName: json['last_name'] ?? "",
      email: json['email'] ?? "",
      username: json['username'] ?? "",
      emailVerifiedAt: json['email_verified_at'],
      phone: json['phone'],
      personalPhone: json['personal_phone'],
      image: json['image'],
      language: json['language'],
      role: json['role'] ?? 0,
      accountType: json['account_type'],
      status: json['status'] == true,
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      customerId: json['customer_id'],
      deletedAt: json['deleted_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'is_primary': isPrimary,
      'name': name,
      'last_name': lastName,
      'email': email,
      'username': username,
      'email_verified_at': emailVerifiedAt,
      'phone': phone,
      'personal_phone': personalPhone,
      'image': image,
      'language': language,
      'role': role,
      'account_type': accountType,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'customer_id': customerId,
      'deleted_at': deletedAt,
    };
  }
}

class StaffDetailsModel {
  final int id;
  final int staffId;
  final List<PhoneItem> phones;
  final List<String> emails;
  final List<String> languages;
  final List<String> skills;
  final String createdAt;
  final String updatedAt;

  StaffDetailsModel({
    required this.id,
    required this.staffId,
    required this.phones,
    required this.emails,
    required this.languages,
    required this.skills,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffDetailsModel.fromJson(Map<String, dynamic> json) {
    return StaffDetailsModel(
      id: json['id'] ?? 0,
      staffId: json['staff_id'] ?? 0,
      phones: (json['phones'] as List<dynamic>? ?? [])
          .map((e) => PhoneItem.fromJson(e))
          .toList(),
      emails: (json['emails'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      languages: (json['languages'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      skills: (json['skills'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staff_id': staffId,
      'phones': phones.map((e) => e.toJson()).toList(),
      'emails': emails.map((e) => e.toString()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
class ContactModel {
  PhoneEmail phConnect;
  PhoneEmail personal;
  ContactModel({required this.phConnect, required this.personal});
  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    phConnect: PhoneEmail.fromJson(
      json['ph_connect'] as Map<String, dynamic>? ?? {"phone": "", "email": ""},
    ),
    personal: PhoneEmail.fromJson(
      json['personal'] as Map<String, dynamic>? ?? {"phone": "", "email": ""},
    ),
  );
  Map<String, dynamic> toJson() => {
    "ph_connect": phConnect.toJson(),
    "personal": personal.toJson(),
  };
}

class PhoneEmail {
  String phone;
  String email;
  PhoneEmail({required this.phone, required this.email});
  factory PhoneEmail.fromJson(Map<String, dynamic> json) => PhoneEmail(
    phone: json['phone']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
  );
  Map<String, dynamic> toJson() => {"phone": phone, "email": email};
}

class PhoneRow {
  final TextEditingController controller;
  IconData icon;
  String type;
  PhoneRow({String? type})
    : controller = TextEditingController(),
      icon = Icons.phone,
      type = type ?? 'mobile';
}

class PhoneType {
  final String label;
  final String image;
  final String apiValue;
  PhoneType(this.label, this.image, this.apiValue);
}

class PhoneField {
  TextEditingController controller;
  PhoneType type;

  PhoneField({required this.type, required this.controller});
}

class DropdownItem {
  final int id;
  final String name;
  DropdownItem({required this.id, required this.name});
  factory DropdownItem.fromJson(Map<String, dynamic> json) {
    return DropdownItem(id: json["id"], name: json["name"]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropdownItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AccountDetailModel {
  final AccountDetailHeader header;
  final AccountDetailRoleAssignment roleAssignment;
  final AccountDetailPersonal personal;
  final AccountDetailEarnings earnings;
  final AccountDetailTwilio twilio;

  AccountDetailModel({
    required this.header,
    required this.roleAssignment,
    required this.personal,
    required this.earnings,
    required this.twilio,
  });

  factory AccountDetailModel.fromJson(Map<String, dynamic> json) {
    final roleAssignmentMap = Map<String, dynamic>.from(json['role_assignment'] ?? {});
    if (json.containsKey('address')) {
      roleAssignmentMap['address'] = json['address'];
    }
    if (json.containsKey('address_2')) {
      roleAssignmentMap['address_2'] = json['address_2'];
    }

    return AccountDetailModel(
      header: AccountDetailHeader.fromJson(json['header'] ?? {}),
      roleAssignment: AccountDetailRoleAssignment.fromJson(roleAssignmentMap),
      personal: AccountDetailPersonal.fromJson(
        json['personal_information'] ?? {},
      ),
      earnings: AccountDetailEarnings.fromJson(json['earnings'] ?? {}),
      twilio: AccountDetailTwilio.fromJson(json['twilio'] ?? {}),
    );
  }
}

class AccountDetailTwilio {
  final List<TwilioLineItem> directLines;
  final List<TwilioLineItem> printHelpersLines;
  final List<TwilioClientCompanyItem> assignedClientCompanies;

  AccountDetailTwilio({
    required this.directLines,
    required this.printHelpersLines,
    required this.assignedClientCompanies,
  });

  factory AccountDetailTwilio.fromJson(Map<String, dynamic> json) {
    return AccountDetailTwilio(
      directLines: (json['direct_lines'] as List<dynamic>? ?? [])
          .map((e) => TwilioLineItem.fromJson(e))
          .toList(),
      printHelpersLines: (json['print_helpers_lines'] as List<dynamic>? ?? [])
          .map((e) => TwilioLineItem.fromJson(e))
          .toList(),
      assignedClientCompanies: (json['assigned_client_companies'] as List<dynamic>? ?? [])
          .map((e) => TwilioClientCompanyItem.fromJson(e))
          .toList(),
    );
  }
}

class TwilioLineItem {
  final String label;
  final String number;

  TwilioLineItem({required this.label, required this.number});

  factory TwilioLineItem.fromJson(Map<String, dynamic> json) {
    return TwilioLineItem(
      label: json['label'] ?? '',
      number: json['number'] ?? '',
    );
  }
}

class TwilioClientCompanyItem {
  final String name;
  final String image;
  final String number;
  final String type;

  TwilioClientCompanyItem({
    required this.name,
    required this.image,
    required this.number,
    required this.type,
  });

  factory TwilioClientCompanyItem.fromJson(Map<String, dynamic> json) {
    return TwilioClientCompanyItem(
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      number: json['number'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class AccountDetailHeader {
  final int id;
  final String name;
  final String lastName;
  final String fullName;
  final String initials;
  final String? imageUrl;
  final int status;
  final String statusLabel;
  final int role;
  final String roleName;
  final int accountTypeId;
  final String accountTypeName;
  final String startedAt;
  final String createdAt;

  AccountDetailHeader({
    required this.id,
    required this.name,
    required this.lastName,
    required this.fullName,
    required this.initials,
    this.imageUrl,
    required this.status,
    required this.statusLabel,
    required this.role,
    required this.roleName,
    required this.accountTypeId,
    required this.accountTypeName,
    required this.startedAt,
    required this.createdAt,
  });

  factory AccountDetailHeader.fromJson(Map<String, dynamic> json) {
    return AccountDetailHeader(
      id: json['id'] ?? 0,
      name: json['name'] ?? "",
      lastName: json['last_name'] ?? "",
      fullName: json['full_name'] ?? "",
      initials: json['initials'] ?? "",
      imageUrl: json['image_url'],
      status: json['status'] ?? 0,
      statusLabel: json['status_label'] ?? "",
      role: json['role'] ?? 0,
      roleName: json['role_name'] ?? "",
      accountTypeId: json['account_type_id'] ?? 0,
      accountTypeName: json['account_type_name'] ?? "",
      startedAt: json['started_at'] ?? "",
      createdAt: json['created_at'] ?? "",
    );
  }
}

class AccountDetailRoleAssignment {
  final int accountTypeId;
  final String accountTypeName;
  final int role;
  final String roleName;
  final String startDate;
  final String? timeDoctorId;
  final String? paymentMethod;
  final String? paymentAccount;
  final String? address;
  final String? address2;

  AccountDetailRoleAssignment({
    required this.accountTypeId,
    required this.accountTypeName,
    required this.role,
    required this.roleName,
    required this.startDate,
    this.timeDoctorId,
    this.paymentMethod,
    this.paymentAccount,
    this.address,
    this.address2,
  });

  factory AccountDetailRoleAssignment.fromJson(Map<String, dynamic> json) {
    return AccountDetailRoleAssignment(
      accountTypeId: json['account_type_id'] ?? 0,
      accountTypeName: json['account_type_name'] ?? "",
      role: json['role'] ?? 0,
      roleName: json['role_name'] ?? "",
      startDate: json['start_date'] ?? "",
      timeDoctorId: json['time_doctor_id'],
      paymentMethod: json['payment_method'],
      paymentAccount: json['payment_account'],
      address: json['address'],
      address2: json['address_2'] ?? json['address2'],
    );
  }
}

class AccountDetailPersonal {
  final String name;
  final String lastName;
  final String username;
  final List<int> languageIds;
  final List<String> languageNames;
  final List<int> skillIds;
  final List<String> skillNames;
  final List<PhoneItem> phones;
  final List<String> emails;

  AccountDetailPersonal({
    required this.name,
    required this.lastName,
    required this.username,
    required this.languageIds,
    required this.languageNames,
    required this.skillIds,
    required this.skillNames,
    required this.phones,
    required this.emails,
  });

  factory AccountDetailPersonal.fromJson(Map<String, dynamic> json) {
    final langs = json['languages'] ?? {};
    final skills = json['skills'] ?? {};
    return AccountDetailPersonal(
      name: json['name'] ?? "",
      lastName: json['last_name'] ?? "",
      username: json['username'] ?? "",
      languageIds: (langs['ids'] as List<dynamic>? ?? []).cast<int>(),
      languageNames: (langs['names'] as List<dynamic>? ?? []).cast<String>(),
      skillIds: (skills['ids'] as List<dynamic>? ?? []).cast<int>(),
      skillNames: (skills['names'] as List<dynamic>? ?? []).cast<String>(),
      phones:
          (json['phones'] as List<dynamic>? ?? [])
              .map((e) => PhoneItem.fromJson(e))
              .toList(),
      emails: (json['emails'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}

class AccountDetailEarnings {
  final double thisWeek;
  final String thisWeekLabel;

  AccountDetailEarnings({required this.thisWeek, required this.thisWeekLabel});

  factory AccountDetailEarnings.fromJson(Map<String, dynamic> json) {
    return AccountDetailEarnings(
      thisWeek: (json['this_week'] ?? 0).toDouble(),
      thisWeekLabel: json['this_week_label'] ?? "\$0.00",
    );
  }
}

class OnboardingTrainingModel {
  final int accountId;
  final String userType;
  final List<ChecklistData> onboarding;
  final List<ChecklistData> training;

  OnboardingTrainingModel({
    required this.accountId,
    required this.userType,
    required this.onboarding,
    required this.training,
  });

  factory OnboardingTrainingModel.fromJson(Map<String, dynamic> json) {
    return OnboardingTrainingModel(
      accountId: json['account_id'] ?? 0,
      userType: json['user_type'] ?? "",
      onboarding:
          (json['onboarding'] as List<dynamic>? ?? [])
              .map((e) => ChecklistData.fromJson(e))
              .toList(),
      training:
          (json['training'] as List<dynamic>? ?? [])
              .map((e) => ChecklistData.fromJson(e))
              .toList(),
    );
  }
}

class ChecklistData {
  final int id;
  final String name;
  final String? iconSvgUrl;
  final String? colorHex;
  final List<ChecklistItemData> items;
  final String progressLabel;
  final String statusLabel;

  ChecklistData({
    required this.id,
    required this.name,
    this.iconSvgUrl,
    this.colorHex,
    required this.items,
    required this.progressLabel,
    required this.statusLabel,
  });

  factory ChecklistData.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    final status = json['status'] ?? {};
    return ChecklistData(
      id: json['id'] ?? 0,
      name: json['name'] ?? "",
      iconSvgUrl: json['icon_svg_url'],
      colorHex: json['color_hex'],
      items:
          (json['items'] as List<dynamic>? ?? [])
              .map((e) => ChecklistItemData.fromJson(e))
              .toList(),
      progressLabel: stats['progress_label'] ?? "",
      statusLabel: status['label'] ?? "",
    );
  }
}

class ChecklistItemData {
  final int index;
  final String text;
  final bool isCompleted;
  final String completedAtLabel;

  ChecklistItemData({
    required this.index,
    required this.text,
    required this.isCompleted,
    required this.completedAtLabel,
  });

  factory ChecklistItemData.fromJson(Map<String, dynamic> json) {
    return ChecklistItemData(
      index: json['index'] ?? 0,
      text: json['text'] ?? "",
      isCompleted: json['is_completed'] ?? false,
      completedAtLabel: json['completed_at_label'] ?? "pending",
    );
  }
}
