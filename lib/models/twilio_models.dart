// twilio_models.dart

class TwilioCredential {
  final int id;
  final String phoneNumber;
  List<ClientContact> assignedClients;
  List<AssignedAccount> assignedAccounts;
  final dynamic client; // Can be null or client object
  bool isSelected; // For selecting which numbers to assign to
  int? selectedClientId; // Store selected client per phone number
  List<int> selectedContactIds; // Store selected contacts per phone number

  TwilioCredential({
    required this.id,
    required this.phoneNumber,
    required this.assignedClients,
    required this.assignedAccounts,
    this.client,
    this.isSelected = false,
    this.selectedClientId,
    this.selectedContactIds = const [],
  });

  factory TwilioCredential.fromJson(Map<String, dynamic> json) {
    return TwilioCredential(
      id: json['id'] ?? 0,
      phoneNumber: json['number'] ?? json['phone_number'] ?? '',
      client: json['client'],
      assignedClients: (json['contacts'] as List<dynamic>? ?? [])
          .map((e) => ClientContact.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignedAccounts: (json['accounts'] as List<dynamic>? ?? [])
          .map((e) => AssignedAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': phoneNumber,
    'phone_number': phoneNumber,
    'client': client,
    'contacts': assignedClients.map((e) => e.toJson()).toList(),
    'accounts': assignedAccounts.map((e) => e.toJson()).toList(),
    'isSelected': isSelected,
    'selectedClientId': selectedClientId,
    'selectedContactIds': selectedContactIds,
  };
}

class ClientContact {
  final int id;
  final String name;
  final String companyName;
  bool isSelected;

  ClientContact({
    required this.id,
    required this.name,
    required this.companyName,
    this.isSelected = false,
  });

  factory ClientContact.fromJson(Map<String, dynamic> json) {
    return ClientContact(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      companyName: json['company_name'] ?? '',
      isSelected: json['is_selected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'company_name': companyName,
    'is_selected': isSelected,
  };
}

class AssignedAccount {
  final int id;
  final String accountName;
  final String? image;
  bool isSelected;

  AssignedAccount({
    required this.id,
    required this.accountName,
    this.image,
    this.isSelected = false,
  });

  factory AssignedAccount.fromJson(Map<String, dynamic> json) {
    return AssignedAccount(
      id: json['id'] ?? 0,
      accountName: json['account_name'] ?? json['name'] ?? '',
      image: json['image'],
      isSelected: json['is_selected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'account_name': accountName,
    'image': image,
    'is_selected': isSelected,
  };

  AssignedAccount copyWith({
    int? id,
    String? accountName,
    String? image,
    bool? isSelected,
  }) {
    return AssignedAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      image: image ?? this.image,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

// Models for clients with contacts API response
class TwilioClient {
  final int id;
  final String name;
  final String? image;
  final bool isCompany;
  List<TwilioContact> contacts;
  bool isExpanded; // For UI expand/collapse state

  TwilioClient({
    required this.id,
    required this.name,
    this.image,
    required this.isCompany,
    required this.contacts,
    this.isExpanded = false,
  });

  factory TwilioClient.fromJson(Map<String, dynamic> json) {
    return TwilioClient(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'],
      isCompany: json['isCompany'] ?? false,
      contacts: (json['contacts'] as List<dynamic>? ?? [])
          .map((e) => TwilioContact.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'isCompany': isCompany,
    'contacts': contacts.map((e) => e.toJson()).toList(),
  };
}

class TwilioContact {
  final int id;
  final String name;
  final String? image;
  final bool isCompany;
  final int clientId;

  TwilioContact({
    required this.id,
    required this.name,
    this.image,
    required this.isCompany,
    required this.clientId,
  });

  factory TwilioContact.fromJson(Map<String, dynamic> json) {
    return TwilioContact(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      image: json['image'],
      isCompany: json['isCompany'] ?? false,
      clientId: json['clientId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'image': image,
    'isCompany': isCompany,
    'clientId': clientId,
  };
}

class TwilioApiCredentials {
  final int id;
  final String accountSid;
  final String apiKeySid;
  final String apiKeySecret;
  final String twimlAppSid;

  TwilioApiCredentials({
    required this.id,
    required this.accountSid,
    required this.apiKeySid,
    required this.apiKeySecret,
    required this.twimlAppSid,
  });

  factory TwilioApiCredentials.fromJson(Map<String, dynamic> json) {
    return TwilioApiCredentials(
      id: json['id'] ?? 0,
      accountSid: json['account_sid'] ?? '',
      apiKeySid: json['api_key_sid'] ?? '',
      apiKeySecret: json['api_key_secret'] ?? '',
      twimlAppSid: json['twiml_app_sid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'account_sid': accountSid,
    'api_key_sid': apiKeySid,
    'api_key_secret': apiKeySecret,
    'twiml_app_sid': twimlAppSid,
  };
}
