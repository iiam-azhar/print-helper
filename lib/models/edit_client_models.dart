class EditClientModel {
  final int id;
  final String companyName;
  final String? image;
  final String? companyType;
  final int? companyTypeId;
  final EditClientRank? clientRank;
  final int? clientRankId;
  final String? brandingLogo;
  final String brandingPrimaryColor;
  final String brandingSecondaryColor;
  final String? brandingUrl;
  final String address;
  final String? address2;
  final EditStateModel? state;
  final EditCityModel? city;
  final String zipcode;
  final List<EditLanguageModel> languages;
  final bool status;
  final int customersCount;
  final List<EditContactModel> contacts;
  final List<dynamic> assignedStaff;
  final EditCreatedBy createdBy;
  final EditCreatedBy updatedBy;
  final String createdAt;
  final String updatedAt;

  EditClientModel({
    required this.id,
    required this.companyName,
    this.image,
    this.companyType,
    this.companyTypeId,
    this.clientRank,
    this.clientRankId,
    this.brandingLogo,
    required this.brandingPrimaryColor,
    required this.brandingSecondaryColor,
    this.brandingUrl,
    required this.address,
    this.address2,
    this.state,
    this.city,
    required this.zipcode,
    required this.languages,
    required this.status,
    required this.customersCount,
    required this.contacts,
    required this.assignedStaff,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });
  factory EditClientModel.fromJson(Map<String, dynamic> json) {
    // company_type may be null, object or primitive - normalize to string id
    String? companyTypeStr;
    final rawCompanyType = json['company_type'];
    if (rawCompanyType == null) {
      companyTypeStr = null;
    } else if (rawCompanyType is Map && rawCompanyType.containsKey('id')) {
      companyTypeStr = rawCompanyType['id'].toString();
    } else {
      companyTypeStr = rawCompanyType.toString();
    }

    // assigned_staff may be [] or list of objects or list of ints
    final rawAssigned = json['assigned_staff'] as List? ?? [];
    final parsedAssigned = rawAssigned
        .map((e) {
          if (e is int) return e;
          if (e is Map && e.containsKey('id')) {
            return e['id'] is int
                ? e['id']
                : int.tryParse(e['id'].toString()) ?? 0;
          }
          if (e is String) return int.tryParse(e) ?? 0;
          return 0;
        })
        .where((v) => v != 0)
        .toList();

    return EditClientModel(
      id: json['id'],
      companyName: json['company_name'] ?? "",
      image: json['image'],
      companyType: companyTypeStr,
      companyTypeId: rawCompanyType is Map
          ? (rawCompanyType['id'] is int
              ? rawCompanyType['id'] as int
              : int.tryParse('${rawCompanyType['id'] ?? ''}'))
          : (int.tryParse(companyTypeStr ?? '')),
      clientRank: json['client_rank'] != null
          ? EditClientRank.fromJson(json['client_rank'])
          : null,
      clientRankId: json['client_rank'] != null && json['client_rank'] is Map
          ? (json['client_rank']['id'] is int
              ? json['client_rank']['id'] as int
              : int.tryParse('${json['client_rank']['id'] ?? ''}'))
          : null,
      brandingLogo: json['branding_logo'],
      brandingPrimaryColor: json['branding_primary_color'] ?? "#000000",
      brandingSecondaryColor: json['branding_secondary_color'] ?? "#000000",
      brandingUrl: json['branding_url'],
      address: json['address'] ?? "",
      address2: json['address_2'],
      state: json['state'] != null
          ? EditStateModel.fromJson(json['state'])
          : null,
      city: json['city'] != null ? EditCityModel.fromJson(json['city']) : null,
      zipcode: json['zipcode'] ?? "",
      languages: (json['languages'] as List? ?? [])
          .map((e) => EditLanguageModel.fromJson(e))
          .toList(),
      status: json['status'] ?? false,
      customersCount: json['customers_count'] ?? 0,
      contacts: (json['contacts'] as List? ?? [])
          .map((e) => EditContactModel.fromJson(e))
          .toList(),
      assignedStaff: parsedAssigned,
      createdBy: EditCreatedBy.fromJson(json['created_by']),
      updatedBy: EditCreatedBy.fromJson(json['updated_by']),
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}

class EditClientRank {
  final int id;
  final String name;
  EditClientRank({required this.id, required this.name});
  factory EditClientRank.fromJson(Map<String, dynamic> json) =>
      EditClientRank(id: json['id'], name: json['name']);
}

class EditStateModel {
  final int id;
  final String name;
  EditStateModel({required this.id, required this.name});
  factory EditStateModel.fromJson(Map<String, dynamic> json) =>
      EditStateModel(id: json['id'], name: json['name']);
}

class EditCityModel {
  final int id;
  final String name;
  EditCityModel({required this.id, required this.name});
  factory EditCityModel.fromJson(Map<String, dynamic> json) =>
      EditCityModel(id: json['id'], name: json['name']);
}

class EditLanguageModel {
  final int id;
  final String name;
  final String? code;
  EditLanguageModel({required this.id, required this.name, this.code});
  factory EditLanguageModel.fromJson(Map<String, dynamic> json) =>
      EditLanguageModel(id: json['id'], name: json['name'], code: json['code']);
}

class EditContactModel {
  final int id;
  final String? email;
  final String? username;
  final String? name;
  final String? lastName;

  final String? phone;
  final String? image;
  final int isPrimary;
  final bool status;
  final EditContactDetails contactDetails;

  EditContactModel({
    required this.id,
    this.name,
    this.lastName,
    this.email,
    this.username,
    this.phone,
    this.image,
    required this.isPrimary,
    required this.status,
    required this.contactDetails,
  });

  factory EditContactModel.fromJson(Map<String, dynamic> json) {
    return EditContactModel(
      id: json['id'],
      email: json['email'] ?? "",
      username: json['username'] ?? "",
      name: json['name'] ?? "",
      lastName: json['last_name'] ?? "",
      phone: json['phone'],
      image: json['image'],
      isPrimary: json['is_primary'] ?? 0,
      status: json['status'] ?? false,
      contactDetails: EditContactDetails.fromJson(
        json['contact_details'] ?? {},
      ),
    );
  }
}

class EditContactDetails {
  final List<EditPhoneNumber> phones;
  final List<String> emails;
  final List<EditLanguageModel> languages;
  EditContactDetails({
    required this.phones,
    required this.emails,
    required this.languages,
  });

  factory EditContactDetails.fromJson(Map<String, dynamic> json) {
    final phonesRaw = json['phones'] as List? ?? [];
    final emailsRaw = json['emails'] as List? ?? [];
    final langsRaw = json['languages'] as List? ?? [];
    return EditContactDetails(
      phones: phonesRaw.map((e) => EditPhoneNumber.fromJson(e)).toList(),
      emails: emailsRaw.map((e) => e.toString()).toList(),
      languages: langsRaw.map((e) => EditLanguageModel.fromJson(e)).toList(),
    );
  }
}

class EditPhoneNumber {
  final String type;
  final String number;
  EditPhoneNumber({required this.type, required this.number});
  factory EditPhoneNumber.fromJson(Map<String, dynamic> json) =>
      EditPhoneNumber(type: json['type'] ?? '', number: json['number'] ?? '');
}

class EditCreatedBy {
  final int id;
  final String name;
  final String? email;

  EditCreatedBy({required this.id, required this.name, this.email});

  factory EditCreatedBy.fromJson(Map<String, dynamic> json) => EditCreatedBy(
    id: json['id'] ?? 0,
    name: json['name'] ?? "",
    email: json['email'] ?? "",
  );
}
