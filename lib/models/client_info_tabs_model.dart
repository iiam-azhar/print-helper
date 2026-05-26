class ClientInfoTabsModel {
  final List<ClientInfoModel> info;
  final List<ClientAgreementStandardsModel> agreementStandards;
  final List<ClientOnboardingChecklistModel> onboarding;
  final List<ClientOnboardingChecklistModel> training;
  final List<ClientInternalOpsContactModel> internalOps;

  const ClientInfoTabsModel({
    required this.info,
    required this.agreementStandards,
    required this.onboarding,
    required this.training,
    required this.internalOps,
  });

  factory ClientInfoTabsModel.fromJson(Map<String, dynamic> json) {
    // Handle tabs being nested or at root level
    final tabsData = json['tabs'] as Map<String, dynamic>? ?? json;
    // Debug logging
    final contactsList =
        (tabsData['internal_ops'] as Map<String, dynamic>?)?['contacts']
            as List<dynamic>? ??
        const [];

    return ClientInfoTabsModel(
      info: (json['info'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => ClientInfoModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      agreementStandards:
          (json['agreement_standards'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (e) => ClientAgreementStandardsModel.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
              .toList(),
      onboarding: (json['onboarding'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientOnboardingChecklistModel.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(),
      training: (json['training'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientOnboardingChecklistModel.fromJson(
              e.cast<String, dynamic>(),
            ),
          )
          .toList(),
      internalOps:
          ((tabsData['internal_ops'] as Map<String, dynamic>?)?['contacts']
                      as List<dynamic>? ??
                  const [])
              .whereType<Map>()
              .map(
                (e) => ClientInternalOpsContactModel.fromJson(
                  e.cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }
}

class ClientInternalOpsContactModel {
  final int id;
  final String name;
  final String lastName;
  final String displayName;
  final String initial;
  final bool isPrimary;
  final bool status;

  const ClientInternalOpsContactModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.displayName,
    required this.initial,
    required this.isPrimary,
    required this.status,
  });

  factory ClientInternalOpsContactModel.fromJson(Map<String, dynamic> json) {
    return ClientInternalOpsContactModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      initial: (json['initial'] ?? 'U').toString(),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      status: json['status'] == true || json['status'] == 1,
    );
  }
}

class ClientInfoModel {
  final int id;
  final String companyName;
  final String image;
  final bool status;
  final String startedAtLabel;
  final String companyType;
  final int? companyTypeId;
  final String clientRank;
  final int? clientRankId;
  final ClientBrandingModel branding;
  final ClientAddressModel address;
  final List<String> languages;
  final int customersCount;
  final List<ClientContactInfoModel> contacts;
  final List<ClientAssignedStaffModel> assignedStaff;
  final List<ClientSupportLineModel> companySupportLines;
  final List<ClientSupportLineModel> supportLines;

  const ClientInfoModel({
    required this.id,
    required this.companyName,
    required this.image,
    required this.status,
    required this.startedAtLabel,
    required this.companyType,
    this.companyTypeId,
    required this.clientRank,
    this.clientRankId,
    required this.branding,
    required this.address,
    required this.languages,
    required this.customersCount,
    required this.contacts,
    required this.assignedStaff,
    required this.companySupportLines,
    required this.supportLines,
  });

  factory ClientInfoModel.fromJson(Map<String, dynamic> json) {
    String formatFromCreatedAt(dynamic value) {
      final raw = (value ?? '').toString().trim();
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return '';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      return '$month $day, ${parsed.year}';
    }

    final companyTypeRaw = json['company_type'];
    final clientRankRaw = json['client_rank'];
    final startedFromCreatedAt = formatFromCreatedAt(json['created_at']);
    return ClientInfoModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      companyName: (json['company_name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      status: json['status'] == true || json['status'] == 1,
      startedAtLabel: startedFromCreatedAt.isNotEmpty
          ? startedFromCreatedAt
          : (json['client_since'] ??
                    json['started_at_label'] ??
                    json['created_at_label'] ??
                    '')
                .toString(),
      companyType: companyTypeRaw is Map
          ? (companyTypeRaw['name'] ?? '').toString()
          : (companyTypeRaw ?? '').toString(),
      companyTypeId: companyTypeRaw is Map
          ? (companyTypeRaw['id'] is int
              ? companyTypeRaw['id'] as int
              : int.tryParse('${companyTypeRaw['id'] ?? ''}'))
          : null,
      clientRank: clientRankRaw is Map
          ? (clientRankRaw['name'] ?? '').toString()
          : (clientRankRaw ?? '').toString(),
      clientRankId: clientRankRaw is Map
          ? (clientRankRaw['id'] is int
              ? clientRankRaw['id'] as int
              : int.tryParse('${clientRankRaw['id'] ?? ''}'))
          : null,
      branding: ClientBrandingModel.fromJson(
        (json['branding'] as Map?)?.cast<String, dynamic>() ?? const {},
        parent: json,
      ),
      address: ClientAddressModel.fromJson(
        (json['address'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      languages: (json['languages'] as List<dynamic>? ?? const []).map((e) {
        if (e is Map && e['name'] != null) return e['name'].toString();
        return e.toString();
      }).toList(),
      customersCount: (json['customers_count'] is int)
          ? json['customers_count'] as int
          : int.tryParse('${json['customers_count']}') ?? 0,
      contacts: (json['contacts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientContactInfoModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      assignedStaff: (json['assigned_staff'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientAssignedStaffModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      companySupportLines: (json['company_support_lines'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientSupportLineModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      supportLines: (json['support_lines'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientSupportLineModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class ClientBrandingModel {
  final String logo;
  final String favicon;
  final String primaryColor;
  final String secondaryColor;
  final String url;

  const ClientBrandingModel({
    required this.logo,
    required this.favicon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.url,
  });

  factory ClientBrandingModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? parent,
  }) {
    String firstNonEmpty(List<dynamic> values) {
      for (final v in values) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
      return '';
    }

    return ClientBrandingModel(
      logo: firstNonEmpty([
        json['logo'],
        json['branding_logo'],
        json['logo_url'],
        json['branding_logo_url'],
        parent?['image'],
        parent?['branding_logo'],
        parent?['logo'],
        parent?['logo_url'],
      ]),
      favicon: firstNonEmpty([
        json['favicon'],
        json['branding_favicon'],
        json['favicon_url'],
        json['branding_favicon_url'],
        parent?['favicon_image'],
        parent?['branding_favicon'],
        parent?['favicon'],
        parent?['favicon_url'],
      ]),
      primaryColor: (json['primary_color'] ?? '').toString(),
      secondaryColor: (json['secondary_color'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
    );
  }
}

class ClientAddressModel {
  final String address;
  final String address2;
  final int? stateId;
  final String state;
  final int? cityId;
  final String city;
  final String zipcode;

  const ClientAddressModel({
    required this.address,
    required this.address2,
    required this.stateId,
    required this.state,
    required this.cityId,
    required this.city,
    required this.zipcode,
  });

  factory ClientAddressModel.fromJson(Map<String, dynamic> json) {
    String parseLocation(dynamic value) {
      if (value is Map) {
        final map = value.cast<dynamic, dynamic>();
        final name = map['name'] ?? map['title'] ?? map['label'];
        return (name ?? '').toString();
      }
      return (value ?? '').toString();
    }

    int? parseLocationId(dynamic value) {
      if (value is Map) {
        final map = value.cast<dynamic, dynamic>();
        final rawId = map['id'];
        if (rawId is int) return rawId;
        return int.tryParse('${rawId ?? ''}');
      }
      return int.tryParse('${value ?? ''}');
    }

    return ClientAddressModel(
      address: (json['address'] ?? '').toString(),
      address2: (json['address_2'] ?? '').toString(),
      stateId: parseLocationId(json['state']),
      state: parseLocation(json['state']),
      cityId: parseLocationId(json['city']),
      city: parseLocation(json['city']),
      zipcode: (json['zipcode'] ?? '').toString(),
    );
  }
}

class ClientContactInfoModel {
  final int id;
  final String name;
  final String lastName;
  final String email;
  final String phone;
  final String image;
  final bool isPrimary;
  final bool status;
  final ClientContactDetailsModel contactDetails;

  const ClientContactInfoModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.image,
    required this.isPrimary,
    required this.status,
    required this.contactDetails,
  });

  factory ClientContactInfoModel.fromJson(Map<String, dynamic> json) {
    return ClientContactInfoModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      status: json['status'] == true || json['status'] == 1,
      contactDetails: ClientContactDetailsModel.fromJson(
        (json['contact_details'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class ClientContactDetailsModel {
  final List<ClientPhoneModel> phones;
  final List<String> emails;
  final List<String> languages;

  const ClientContactDetailsModel({
    required this.phones,
    required this.emails,
    required this.languages,
  });

  factory ClientContactDetailsModel.fromJson(Map<String, dynamic> json) {
    return ClientContactDetailsModel(
      phones: (json['phones'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => ClientPhoneModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      emails: (json['emails'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      languages: (json['languages'] as List<dynamic>? ?? const []).map((e) {
        if (e is Map && e['name'] != null) return e['name'].toString();
        return e.toString();
      }).toList(),
    );
  }
}

class ClientPhoneModel {
  final String type;
  final String number;

  const ClientPhoneModel({required this.type, required this.number});

  factory ClientPhoneModel.fromJson(Map<String, dynamic> json) {
    return ClientPhoneModel(
      type: (json['type'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
    );
  }
}

class ClientAgreementStandardsModel {
  final String id;
  final String signature;
  final bool canSign;
  final ClientAgreementTemplateModel template;
  final String content;
  final List<ClientStandardRuleModel> rules;
  final String signerName;
  final String signedAt;
  final String ipAddress;
  final String pdfUrl;

  bool get hasSigned {
    final sName = signerName.trim().toLowerCase();
    final sig = signature.trim().toLowerCase();

    final isSignerNameValid = sName.isNotEmpty &&
        sName != 'null' &&
        sName != '{}' &&
        sName != '[]';

    final isSignatureValid = sig.isNotEmpty &&
        sig != 'null' &&
        sig != '{}' &&
        sig != '[]';

    return isSignerNameValid || isSignatureValid;
  }

  const ClientAgreementStandardsModel({
    required this.id,
    required this.signature,
    required this.canSign,
    required this.template,
    required this.content,
    required this.rules,
    required this.signerName,
    required this.signedAt,
    required this.ipAddress,
    required this.pdfUrl,
  });

  factory ClientAgreementStandardsModel.fromJson(Map<String, dynamic> json) {
    final sig = json['signature'] is Map ? (json['signature'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    final signerName = (sig['signer_name'] ?? '').toString().trim();
    final signedAt = (sig['signed_at'] ?? '').toString().trim();
    final ipAddress = (sig['ip_address'] ?? '').toString().trim();
    final pdfUrl = (sig['pdf_url'] ?? sig['pdf_web_url'] ?? '').toString().trim();
    final signatureStr = signerName.isNotEmpty ? signerName : (json['signature'] ?? '').toString().trim();

    return ClientAgreementStandardsModel(
      id: (json['id'] ?? json['agreement_id'] ?? json['uuid'] ?? '').toString(),
      signature: signatureStr,
      canSign: json['can_sign'] == true || json['can_sign'] == 1 || json['can_sign'] == '1' || json['can_sign'] == 'true',
      template: ClientAgreementTemplateModel.fromJson(
        (json['template'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      content: (json['content'] ?? '').toString(),
      rules: (json['rules'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) => ClientStandardRuleModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      signerName: signerName,
      signedAt: signedAt,
      ipAddress: ipAddress,
      pdfUrl: pdfUrl,
    );
  }
}

class ClientAgreementTemplateModel {
  final int id;
  final String name;
  final String version;

  const ClientAgreementTemplateModel({
    required this.id,
    required this.name,
    required this.version,
  });

  factory ClientAgreementTemplateModel.fromJson(Map<String, dynamic> json) {
    return ClientAgreementTemplateModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
    );
  }
}

class ClientStandardRuleModel {
  final int id;
  final String title;
  final String description;
  final String icon;
  final String iconName;
  final String iconSvgUrl;
  final String iconColor;
  final String colorHex;
  final String categoryName;

  const ClientStandardRuleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconName,
    required this.iconSvgUrl,
    required this.iconColor,
    required this.colorHex,
    required this.categoryName,
  });

  factory ClientStandardRuleModel.fromJson(Map<String, dynamic> json) {
    final category =
        (json['category'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ClientStandardRuleModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      iconName: (json['icon_name'] ?? '').toString(),
      iconSvgUrl: (json['icon_svg_url'] ?? '').toString(),
      iconColor: (json['icon_color'] ?? '').toString(),
      colorHex: (json['color_hex'] ?? '').toString(),
      categoryName: (category['name'] ?? '').toString(),
    );
  }
}

class ClientOnboardingChecklistModel {
  final int id;
  final String name;
  final String listType;
  final String icon;
  final String iconName;
  final String iconSvgUrl;
  final String iconColor;
  final String colorHex;
  final List<ClientOnboardingItemModel> items;
  final int totalItems;
  final int completedItems;
  final String status;

  const ClientOnboardingChecklistModel({
    required this.id,
    required this.name,
    required this.listType,
    required this.icon,
    required this.iconName,
    required this.iconSvgUrl,
    required this.iconColor,
    required this.colorHex,
    required this.items,
    required this.totalItems,
    required this.completedItems,
    required this.status,
  });

  factory ClientOnboardingChecklistModel.fromJson(Map<String, dynamic> json) {
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ClientOnboardingChecklistModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      listType: (json['list_type'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      iconName: (json['icon_name'] ?? '').toString(),
      iconSvgUrl: (json['icon_svg_url'] ?? '').toString(),
      iconColor: (json['icon_color'] ?? '').toString(),
      colorHex: (json['color_hex'] ?? '').toString(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (e) =>
                ClientOnboardingItemModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
      totalItems: (stats['total_items'] is int)
          ? stats['total_items'] as int
          : int.tryParse('${stats['total_items']}') ?? 0,
      completedItems: (stats['completed_items'] is int)
          ? stats['completed_items'] as int
          : int.tryParse('${stats['completed_items']}') ?? 0,
      status: (stats['status'] ?? '').toString(),
    );
  }
}

class ClientOnboardingItemModel {
  final int index;
  final String text;
  final bool isCompleted;

  const ClientOnboardingItemModel({
    required this.index,
    required this.text,
    required this.isCompleted,
  });

  factory ClientOnboardingItemModel.fromJson(Map<String, dynamic> json) {
    return ClientOnboardingItemModel(
      index: (json['index'] is int)
          ? json['index'] as int
          : int.tryParse('${json['index']}') ?? 0,
      text: (json['text'] ?? '').toString(),
      isCompleted: json['is_completed'] == true || json['is_completed'] == 1 || json['is_completed'] == '1' || json['is_completed'] == 'true',
    );
  }
}

class ClientAssignedStaffModel {
  final int id;
  final String name;
  final String lastName;
  final String email;
  final String image;

  const ClientAssignedStaffModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.image,
  });

  factory ClientAssignedStaffModel.fromJson(Map<String, dynamic> json) {
    return ClientAssignedStaffModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}

class ClientSupportLineModel {
  final String label;
  final String number;
  final String image;

  const ClientSupportLineModel({
    required this.label,
    required this.number,
    required this.image,
  });

  factory ClientSupportLineModel.fromJson(Map<String, dynamic> json) {
    return ClientSupportLineModel(
      label: (json['label'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}
