import '../../../models/search_modals.dart';

class ClientCompanyModel {
  final int id;
  final String companyName;
  final String? email;
  final String? image;
  final List<SearchUsers> contacts;
  final List<SearchUsers> customers;

  ClientCompanyModel({
    required this.id,
    required this.companyName,
    this.email,
    this.image,
    required this.contacts,
    required this.customers,
  });

  factory ClientCompanyModel.fromJson(Map<String, dynamic> json) {
    var rawContacts = json['contacts'] as List? ?? [];
    var rawCustomers = json['customers'] as List? ?? [];

    return ClientCompanyModel(
      id: json['id'],
      companyName: json['company_name'] ?? '',
      email: json['email'],
      image: json['image'],
      contacts: rawContacts.map((e) {
        // Inject userType to distinguish them in the UI
        e['userType'] = 'CONTACT';
        return SearchUsers.fromJson(Map<String, dynamic>.from(e));
      }).toList(),
      customers: rawCustomers.map((e) {
        // Inject userType to distinguish them in the UI
        e['userType'] = 'CUSTOMER';
        return SearchUsers.fromJson(Map<String, dynamic>.from(e));
      }).toList(),
    );
  }
}

class GroupParticipantsResponse {
  final List<SearchUsers> staff;
  final List<ClientCompanyModel> clients;

  GroupParticipantsResponse({
    required this.staff,
    required this.clients,
  });

  factory GroupParticipantsResponse.fromJson(Map<String, dynamic> json) {
    var rawStaff = json['staff'] as List? ?? [];
    var rawClients = json['clients'] as List? ?? [];

    return GroupParticipantsResponse(
      staff: rawStaff.map((e) {
        e['userType'] = 'STAFF';
        return SearchUsers.fromJson(Map<String, dynamic>.from(e));
      }).toList(),
      clients: rawClients.map((e) => ClientCompanyModel.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}
