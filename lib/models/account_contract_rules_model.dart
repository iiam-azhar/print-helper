class AccountContractRulesModel {
  final AccountContractRulesAccount account;
  final AccountContractRulesAgreement agreement;
  final AccountContractRulesTemplate template;
  final List<AccountRuleCategoryModel> rules;

  const AccountContractRulesModel({
    required this.account,
    required this.agreement,
    required this.template,
    required this.rules,
  });

  factory AccountContractRulesModel.fromJson(Map<String, dynamic> json) {
    final accountMap = Map<String, dynamic>.from(
      (json['account'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    // Copy address fields from root if not present in the account block
    if (!accountMap.containsKey('address') && json.containsKey('address')) {
      accountMap['address'] = json['address'];
    }
    if (!accountMap.containsKey('address_2') && json.containsKey('address_2')) {
      accountMap['address_2'] = json['address_2'];
    }
    if (!accountMap.containsKey('address2') && json.containsKey('address2')) {
      accountMap['address2'] = json['address2'];
    }

    return AccountContractRulesModel(
      account: AccountContractRulesAccount.fromJson(accountMap),
      agreement: AccountContractRulesAgreement.fromJson(
        (json['agreement'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      template: AccountContractRulesTemplate.fromJson(
        (json['template'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      rules: (json['rules'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (e) => AccountRuleCategoryModel.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class AccountContractRulesAccount {
  final int id;
  final String name;
  final String lastName;
  final String fullName;
  final String email;
  final String accountType;
  final String address;
  final String address2;

  const AccountContractRulesAccount({
    required this.id,
    required this.name,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.accountType,
    required this.address,
    required this.address2,
  });

  factory AccountContractRulesAccount.fromJson(Map<String, dynamic> json) {
    return AccountContractRulesAccount(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      accountType: (json['account_type'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      address2: (json['address_2'] ?? json['address2'] ?? '').toString(),
    );
  }
}

class AccountContractRulesAgreement {
  final String type;
  final bool isSigned;
  final String signerName;
  final String signedAt;
  final String signedAtLabel;
  final String pdfUrl;
  final String pdfWebUrl;
  final String ipAddress;
  final bool canSign;
  final String expectedSignerName;
  final bool clientAgreementExists;

  const AccountContractRulesAgreement({
    required this.type,
    required this.isSigned,
    required this.signerName,
    required this.signedAt,
    required this.signedAtLabel,
    required this.pdfUrl,
    required this.pdfWebUrl,
    required this.ipAddress,
    required this.canSign,
    required this.expectedSignerName,
    required this.clientAgreementExists,
  });

  factory AccountContractRulesAgreement.fromJson(Map<String, dynamic> json) {
    return AccountContractRulesAgreement(
      type: (json['type'] ?? '').toString(),
      isSigned: json['is_signed'] == true || json['is_signed'] == 1 || json['is_signed'] == '1' || json['is_signed'] == 'true',
      signerName: (json['signer_name'] ?? '').toString(),
      signedAt: (json['signed_at'] ?? '').toString(),
      signedAtLabel: (json['signed_at_label'] ?? '').toString(),
      pdfUrl: (json['pdf_url'] ?? '').toString(),
      pdfWebUrl: (json['pdf_web_url'] ?? '').toString(),
      ipAddress: (json['ip_address'] ?? '').toString(),
      canSign: json['can_sign'] == true || json['can_sign'] == 1 || json['can_sign'] == '1' || json['can_sign'] == 'true',
      expectedSignerName: (json['expected_signer_name'] ?? '').toString(),
      clientAgreementExists: json['client_agreement_exists'] == true || json['client_agreement_exists'] == 1 || json['client_agreement_exists'] == '1' || json['client_agreement_exists'] == 'true',
    );
  }
}

class AccountContractRulesTemplate {
  final int id;
  final String name;
  final String version;
  final String content;

  const AccountContractRulesTemplate({
    required this.id,
    required this.name,
    required this.version,
    required this.content,
  });

  factory AccountContractRulesTemplate.fromJson(Map<String, dynamic> json) {
    return AccountContractRulesTemplate(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }
}

class AccountRuleCategoryModel {
  final String category;
  final List<AccountRuleItemModel> items;

  const AccountRuleCategoryModel({required this.category, required this.items});

  factory AccountRuleCategoryModel.fromJson(Map<String, dynamic> json) {
    return AccountRuleCategoryModel(
      category: (json['category'] ?? '').toString(),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => AccountRuleItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class AccountRuleItemModel {
  final int id;
  final String title;
  final String description;
  final String icon;
  final String iconName;
  final String iconSvgUrl;
  final String iconColor;
  final String colorHex;

  const AccountRuleItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconName,
    required this.iconSvgUrl,
    required this.iconColor,
    required this.colorHex,
  });

  factory AccountRuleItemModel.fromJson(Map<String, dynamic> json) {
    final color = (json['color'] as Map?)?.cast<String, dynamic>() ?? {};
    return AccountRuleItemModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      iconName: (json['icon_name'] ?? '').toString(),
      iconSvgUrl: (json['icon_svg_url'] ?? '').toString(),
      iconColor: (json['icon_color'] ?? '').toString(),
      colorHex: (json['color_hex'] ?? color['hex'] ?? '').toString(),
    );
  }
}
