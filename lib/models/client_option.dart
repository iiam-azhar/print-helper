class ClientOptionsResponse {
  final bool success;
  final String? message;
  final List<ClientOption> data;
  final int currentPage;
  final int lastPage;
  final int total;

  ClientOptionsResponse({
    required this.success,
    this.message,
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  factory ClientOptionsResponse.fromJson(Map<String, dynamic> json) {
    bool success = json['success'] ?? false;
    String? message = json['message']?.toString();
    List<ClientOption> dataList = [];
    int currentPage = 1;
    int lastPage = 1;
    int total = 0;

    if (json['data'] != null) {
      if (json['data'] is List) {
        // Unpaginated response
        var list = json['data'] as List;
        dataList = list.map((v) => ClientOption.fromJson(v)).toList();
      } else if (json['data'] is Map) {
        // Paginated response
        var dataMap = json['data'] as Map<String, dynamic>;
        if (dataMap['data'] != null && dataMap['data'] is List) {
          var list = dataMap['data'] as List;
          dataList = list.map((v) => ClientOption.fromJson(v)).toList();
        }
        currentPage = dataMap['current_page'] ?? 1;
        lastPage = dataMap['last_page'] ?? 1;
        total = dataMap['total'] ?? 0;
      }
    }

    return ClientOptionsResponse(
      success: success,
      message: message,
      data: dataList,
      currentPage: currentPage,
      lastPage: lastPage,
      total: total,
    );
  }
}

class ClientOption {
  final int? id;
  final String companyName;
  final String? image;
  final List<AssignedStaff> assignedStaff;

  ClientOption({
    this.id,
    required this.companyName,
    this.image,
    required this.assignedStaff,
  });

  factory ClientOption.fromJson(Map<String, dynamic> json) {
    List<AssignedStaff> staffList = [];
    if (json['assigned_staff'] != null && json['assigned_staff'] is List) {
      staffList = (json['assigned_staff'] as List)
          .map((v) => AssignedStaff.fromJson(v))
          .toList();
    }

    return ClientOption(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      companyName: json['company_name']?.toString() ?? json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      assignedStaff: staffList,
    );
  }
}

class AssignedStaff {
  final int? id;
  final String name;
  final String? image;

  AssignedStaff({
    this.id,
    required this.name,
    this.image,
  });

  factory AssignedStaff.fromJson(Map<String, dynamic> json) {
    return AssignedStaff(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
    );
  }
}
