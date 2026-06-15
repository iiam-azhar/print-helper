import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_form_models.dart';
import '../models/customer_models.dart';
import '../models/edit_customer_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';

class CustomerPro extends ChangeNotifier {
  bool customersLoad = false;
  bool isLoadingMore = false;
  bool myNetworkLoad = false;

  int currentPage = 1;
  int lastPage = 1;
  int totalCustomers = 0;

  final List<CustomerModel> _customers = [];
  List<CustomerModel> get customers => _customers;
  CustomerModel? get topCustomer =>
      _customers.isNotEmpty ? _customers.first : null;

  ClientModelCust? _client;
  ClientModelCust? get client => _client;

  CustomerModel? _myCustomer;
  CustomerModel? get myCustomer => _myCustomer;

  // final List<ContactResponseModel> _contacts = [];
  // List<ContactResponseModel> get contacts => _contacts;

  Map<String, dynamic> customerFilters = {};
  String search = '';

  Map<String, dynamic> _myNetworkTabs = {};
  Map<String, dynamic> get myNetworkTabs => _myNetworkTabs;

  Future<void> getMyNetworkTabs({
    required BuildContext ctx,
    required int clientId,
  }) async {
    myNetworkLoad = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: ApiRoutes.clientMyNetworkTabs(clientId),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response is Map<String, dynamic> && response["success"] == true) {
        final data = response["data"];
        printData(
          title: "myNetwork data type",
          data: data.runtimeType.toString(),
        );
        if (data is Map<String, dynamic>) {
          printData(title: "myNetwork data keys", data: data.keys.toList());
          final nested = data["data"];
          if (nested is Map<String, dynamic>) {
            printData(
              title: "myNetwork nested data keys",
              data: nested.keys.toList(),
            );
          }
        }
        if (data is Map<String, dynamic>) {
          _myNetworkTabs = data;
          if (data["client"] is Map<String, dynamic>) {
            _client = ClientModelCust.fromJson(
              data["client"] as Map<String, dynamic>,
            );
          }
        } else if (data is List) {
          _myNetworkTabs = {"tabs": data};
        } else {
          _myNetworkTabs = {};
        }
      } else if (response is Map<String, dynamic>) {
        showToast(
          message:
              response["message"]?.toString() ?? 'Failed to load network tabs',
        );
      }
    } catch (e, st) {
      printData(
        title: "Error loading my network tabs",
        data: "$e\n$st",
        e: true,
      );
    } finally {
      myNetworkLoad = false;
      notifyListeners();
    }
  }

  Future<void> getCustomers({
    required BuildContext ctx,
    required int clientId,
    int page = 1,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (isLoadingMore || currentPage >= lastPage) return;
      isLoadingMore = true;
    } else {
      customersLoad = true;
      currentPage = 1;
      // DO NOT clear totalCustomers here if you want to keep showing the old count until new data arrives?
      // Actually, standard behavior is to reset if it's a fresh load, but we might want to keep it to avoid UI flicker.
      // Let's reset it if it's a completely new filter search, but maybe not on refresh.
      // For now, let's just leave it or reset it.
      // _customers.clear(); // Handled below
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final uri = Uri.parse(ApiRoutes.customers).replace(
        queryParameters: {
          "client_id": clientId.toString(),
          "page": page.toString(),
          ...customerFilters.map((k, v) => MapEntry(k, v.toString())),
        },
      );
      final response = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response["success"] == true) {
        final data = response["data"];
        if (!loadMore) {
          customers.clear();
        }
        _myCustomer = null;
        if (data["client"] != null) {
          _client = ClientModelCust.fromJson(data["client"]);
        } else {
          showToast(message: data["message"]);
        }
        final customersBlock = data["customers"];
        final pagination = customersBlock is Map<String, dynamic>
            ? (customersBlock["pagination"] as Map<String, dynamic>? ??
                  customersBlock)
            : null;

        if (pagination != null) {
          currentPage =
              int.tryParse(pagination["current_page"]?.toString() ?? "1") ?? 1;
          lastPage =
              int.tryParse(pagination["last_page"]?.toString() ?? "1") ?? 1;
          totalCustomers =
              int.tryParse(pagination["total"]?.toString() ?? "0") ?? 0;
        }

        final List<dynamic> list = customersBlock is Map<String, dynamic>
            ? (customersBlock["data"] as List<dynamic>? ??
                  customersBlock["items"] as List<dynamic>? ??
                  [])
            : (customersBlock as List<dynamic>? ?? []);
        for (var item in list) {
          _customers.add(CustomerModel.fromJson(item));
        }
        if (pagination == null || totalCustomers == 0) {
          totalCustomers = _customers.length;
        }
        printData(title: "success:", data: response["success"]);
        printData(title: "data keys:", data: response["data"].keys);
        printData(title: "customers length raw:", data: list.length);
        for (var item in list) {
          printData(title: "item keys:", data: (item as Map).keys);
        }
      }
    } catch (e, st) {
      printData(title: "Error loading customers", data: "$e\n$st", e: true);
    } finally {
      customersLoad = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> createCust({
    required int clientId,
    required String companyName,
    required int categoryType,
    required int custRank,
    required String companyType,
    required List<int> clientLanguages,
    required int status,
    required List<ContactFormModel> contacts,
    File? custImage,
    required dynamic context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final uri = Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.customers}');
      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["client_id"] = clientId.toString();
      request.fields["company_name"] = companyName;
      request.fields["status"] = status.toString();
      request.fields["company_category"] = categoryType.toString();
      request.fields["customer_rank"] = custRank.toString();
      request.fields["company_type"] = companyType.toString();

      for (int i = 0; i < contacts.length; i++) {
        final c = contacts[i];
        request.fields["contacts[$i][name]"] = c.firstName.text;
        request.fields["contacts[$i][last_name]"] = c.lastName.text;
        request.fields["contacts[$i][username]"] = c.username.text;
        request.fields["contacts[$i][password]"] = c.password.text;
        request.fields["contacts[$i][password_confirmation]"] =
            c.confirmPassword.text;
        for (int j = 0; j < c.selectedLanguageIds.length; j++) {
          request.fields["contacts[$i][languages][$j]"] = c
              .selectedLanguageIds[j]
              .toString();
        }
        for (int p = 0; p < c.phoneFields.length; p++) {
          request.fields["contacts[$i][phones][$p][type]"] =
              c.phoneFields[p].type.apiValue;
          request.fields["contacts[$i][phones][$p][number]"] = c
              .phoneFields[p]
              .controller
              .text
              .trim();
        }
        for (int e = 0; e < c.emails.length; e++) {
          request.fields["contacts[$i][emails][$e]"] = c.emails[e].text.trim();
        }
        if (c.image != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              "contacts[$i][image]",
              c.image!.path,
            ),
          );
        }
      }
      if (custImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("client_image", custImage.path),
        );
      }
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      printData(title: "STATUS:", data: res.statusCode);
      printData(title: "BODY:", data: res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await getCustomers(ctx: context, clientId: clientId);
        return true;
      } else {
        String errorMessage = "Failed to create customer";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['message'] != null) {
              errorMessage = decoded['message'].toString();
            }
            if (decoded['errors'] != null && decoded['errors'] is Map) {
              final errorsMap = decoded['errors'] as Map;
              final firstErrorList = errorsMap.values.firstOrNull;
              if (firstErrorList is List && firstErrorList.isNotEmpty) {
                errorMessage = firstErrorList.first.toString();
              }
            }
          }
        } catch (_) {
          if (res.statusCode == 413) {
            errorMessage = "The uploaded file is too large. Please upload an image smaller than 2MB.";
          } else {
            errorMessage = "Server error (${res.statusCode}): Failed to create customer";
          }
        }
        showToast(message: errorMessage);
      }
      return false;
    } catch (e) {
      printData(title: "CLIENT CREATE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> editCust({
    required int clientId,
    required int custId,
    required String companyName,
    required int categoryType,
    required int custRank,
    required String companyType,
    required List<int> clientLanguages,
    required int status,
    required List<ContactFormModel> contacts,
    File? custImage,
    required dynamic context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final uri = Uri.parse(
        '${ApiRoutes.baseUrl}${ApiRoutes.clients}/$custId/update',
      );
      printData(title: 'URI:', data: uri.toString());
      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

      printData(title: "custId:", data: custId);
      printData(title: "clientId:", data: clientId);
      printData(title: "companyName:", data: companyName);

      request.fields["client_id"] = clientId.toString();
      request.fields["company_name"] = companyName;

      request.fields["status"] = status.toString();
      request.fields["company_category"] = categoryType.toString();
      request.fields["customer_rank"] = custRank.toString();
      request.fields["company_type"] = companyType.toString();

      for (int i = 0; i < contacts.length; i++) {
        final c = contacts[i];
        if (c.existingId != null && c.existingId != 0) {
          request.fields["contacts[$i][id]"] = c.existingId.toString();
        }
        request.fields["contacts[$i][name]"] = c.firstName.text;
        request.fields["contacts[$i][last_name]"] = c.lastName.text;
        request.fields["contacts[$i][username]"] = c.username.text;
        request.fields["contacts[$i][password]"] = c.password.text;
        request.fields["contacts[$i][password_confirmation]"] =
            c.confirmPassword.text;
        for (int j = 0; j < c.selectedLanguageIds.length; j++) {
          request.fields["contacts[$i][languages][$j]"] = c
              .selectedLanguageIds[j]
              .toString();
        }
        for (int p = 0; p < c.phoneFields.length; p++) {
          request.fields["contacts[$i][phones][$p][type]"] =
              c.phoneFields[p].type.apiValue;
          request.fields["contacts[$i][phones][$p][number]"] = c
              .phoneFields[p]
              .controller
              .text
              .trim();
        }
        for (int e = 0; e < c.emails.length; e++) {
          request.fields["contacts[$i][emails][$e]"] = c.emails[e].text.trim();
        }
        if (c.image != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              "contacts[$i][image]",
              c.image!.path,
            ),
          );
        }
      }
      if (custImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("client_image", custImage.path),
        );
      }

      printData(title: "FIELDS:", data: request.fields);
      printData(
        title: "FILES:",
        data: request.files.map((e) => e.field).toList(),
      );

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);

      printData(title: "STATUS:", data: res.statusCode);
      printData(title: "BODY:", data: res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await getCustomers(ctx: context, clientId: clientId);
        return true;
      } else {
        String errorMessage = "Failed to update customer";
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['message'] != null) {
              errorMessage = decoded['message'].toString();
            }
            if (decoded['errors'] != null && decoded['errors'] is Map) {
              final errorsMap = decoded['errors'] as Map;
              final firstErrorList = errorsMap.values.firstOrNull;
              if (firstErrorList is List && firstErrorList.isNotEmpty) {
                errorMessage = firstErrorList.first.toString();
              }
            }
          }
        } catch (_) {
          if (res.statusCode == 413) {
            errorMessage = "The uploaded file is too large. Please upload an image smaller than 2MB.";
          } else {
            errorMessage = "Server error (${res.statusCode}): Failed to update customer";
          }
        }
        showToast(message: errorMessage);
      }
      return false;
    } catch (e) {
      printData(title: "CLIENT CREATE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> saveClientContact({
    required int clientId,
    int? contactId,
    required ContactFormModel contact,
    required BuildContext context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      // Construct URL:
      // Adding: .../clients/$clientId/contacts
      // Updating: .../clients/$clientId/contacts/$contactId
      String url = contactId == null || contactId == 0
          ? '${ApiRoutes.baseUrl}${ApiRoutes.clients}/$clientId/contacts'
          : '${ApiRoutes.baseUrl}${ApiRoutes.clients}/$clientId/contacts/$contactId';

      final request = http.MultipartRequest("POST", Uri.parse(url));
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

      request.fields["name"] = contact.firstName.text.trim();
      request.fields["last_name"] = contact.lastName.text.trim();
      request.fields["username"] = contact.username.text.trim();
      if (contact.password.text.isNotEmpty) {
        request.fields["password"] = contact.password.text.trim();
        request.fields["password_confirmation"] = contact.confirmPassword.text
            .trim();
      }

      // indexed emails: emails[0]
      for (int i = 0; i < contact.emails.length; i++) {
        final email = contact.emails[i].text.trim();
        if (email.isNotEmpty) {
          request.fields["emails[$i]"] = email;
        }
      }

      // indexed phones: phones[0][type], phones[0][number]
      for (int i = 0; i < contact.phoneFields.length; i++) {
        final number = contact.phoneFields[i].controller.text.trim();
        if (number.isNotEmpty) {
          request.fields["phones[$i][type]"] =
              contact.phoneFields[i].type.apiValue;
          request.fields["phones[$i][number]"] = number;
        }
      }

      // indexed languages: languages[0]
      for (int i = 0; i < contact.selectedLanguageIds.length; i++) {
        request.fields["languages[$i]"] = contact.selectedLanguageIds[i]
            .toString();
      }

      if (contact.image != null) {
        request.files.add(
          await http.MultipartFile.fromPath("image", contact.image!.path),
        );
      }

      printData(title: "SAVE CONTACT URL:", data: url);
      printData(title: "FIELDS:", data: request.fields);
      printData(
        title: "FILES:",
        data: request.files.map((e) => e.field).toList(),
      );

      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      printData(title: "RESPONSE:", data: res.body);

      final decoded = jsonDecode(res.body);
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          decoded['success'] == true ||
          decoded['success'] == "true") {
        return true;
      } else {
        showToast(message: decoded['message'] ?? "Failed to save contact");
        return false;
      }
    } catch (e) {
      printData(title: "SAVE CONTACT ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<EditCustomerModel?> getCustomerDetails(int customerId) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.customers}/$customerId",
      );
      printData(title: "CUSTOMER URL:", data: url);
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );
      printData(title: "STATUS CODE:", data: response.statusCode);
      if (response.statusCode == 200) {
        final jsonBody = jsonDecode(response.body);
        printData(title: "CUSTOMER BODY:", data: jsonBody);
        return EditCustomerModel.fromJson(jsonBody['data']['customer']);
      } else {
        printData(title: "Customer Fetch Error:", data: response.body, e: true);
        return null;
      }
    } catch (e, st) {
      printData(
        title: "ERROR in getCustomerDetails:",
        data: "$e\n$st",
        e: true,
      );
      return null;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> toggleStatus({
    required int clientId,
    required int custId,
    required bool newStatus,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.customers}/$custId/toggle",
        headers: {"Authorization": "Bearer $token"},
        payload: {"status": newStatus ? "1" : "0"},
      );
      if (response["success"] == true) {
        final index = _customers.indexWhere((c) => c.id == custId);
        if (index != -1) {
          _customers[index] = _customers[index].copyWith(status: newStatus);
        }
        notifyListeners();
      }
    } catch (e) {
      printData(title: "Toggle Customer Error:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<void> toggleCustContact({
    required int clientId, // CUSTOMER ID
    required int custId, // CONTACT ID
    required bool newStatus,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final body = {"status": newStatus ? "1" : "0"};
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.account}/$custId/toggle",
        headers: {"Authorization": "Bearer $token"},
        payload: body,
      );
      if (response["success"] == true) {
        final customerIndex = _customers.indexWhere((c) => c.id == clientId);
        if (customerIndex != -1) {
          final contactIndex = _customers[customerIndex].contacts.indexWhere(
            (c) => c.contactId == custId,
          );
          if (contactIndex != -1) {
            final updatedContact = _customers[customerIndex]
                .contacts[contactIndex]
                .copyWith(status: newStatus);

            _customers[customerIndex].contacts[contactIndex] = updatedContact;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      printData(title: "Toggle Contact Error:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> deleteCust(int id, BuildContext context) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.customers}/$id",
        isDelete: true,
        headers: {"Authorization": "Bearer $token"},
      );
      if (response is Map<String, dynamic> && response["success"] == true) {
        showToast(message: response["message"]);
        return true;
      }
      return false;
    } catch (e) {
      printData(title: "DELETE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  void toggleCompanyStatus(int id) {
    final index = _customers.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _customers[index].status = !_customers[index].status;
    notifyListeners();
  }

  void toggleContactStatus2(int customerId, int contactId) {
    final cIndex = _customers.indexWhere((c) => c.id == customerId);
    if (cIndex == -1) return;

    final ctIndex = _customers[cIndex].contacts.indexWhere(
      (ct) => ct.contactId == contactId,
    );
    if (ctIndex == -1) return;

    _customers[cIndex].contacts[ctIndex].status =
        !_customers[cIndex].contacts[ctIndex].status;
    notifyListeners();
  }

  void applyCustFilters(
    Map<String, dynamic> filters,
    BuildContext context,
    int clientId,
  ) {
    customerFilters.clear();
    if (filters["status"] == "active") {
      customerFilters["status"] = 1;
    } else if (filters["status"] == "inactive") {
      customerFilters["status"] = 0;
    }
    if ((filters["company_name"] ?? "").toString().isNotEmpty) {
      customerFilters["company_name"] = filters["company_name"]
          .toString()
          .trim();
    }
    if ((filters["first_name"] ?? "").toString().isNotEmpty) {
      customerFilters["first_name"] = filters["first_name"].toString().trim();
    }
    if ((filters["last_name"] ?? "").toString().isNotEmpty) {
      customerFilters["last_name"] = filters["last_name"].toString().trim();
    }
    if ((filters["email"] ?? "").toString().isNotEmpty) {
      customerFilters["email"] = filters["email"].toString().trim();
    }
    if ((filters["phone"] ?? "").toString().isNotEmpty) {
      customerFilters["phone"] = filters["phone"].toString().trim();
    }
    if ((filters["date"] ?? "").toString().isNotEmpty) {
      final parts = filters["date"].split("-");
      if (parts.length == 3) {
        customerFilters["created_date"] = "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    }
    getCustomers(ctx: context, clientId: clientId);
  }

  int get appliedFilterCount {
    int count = 0;
    customerFilters.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (key == 'page' || key == 'client_id') return;
      count++;
    });
    return count;
  }

  void clearCustFilters(BuildContext context) {
    customerFilters.clear();
    notifyListeners();
    getCustomers(ctx: context, clientId: client?.id ?? 0);
  }

  // Future<void> getSingleCustomer({
  //   required BuildContext ctx,
  //   required int clientId,
  //   int page = 1,
  //   bool loadMore = false,
  // }) async {
  //   if (loadMore) {
  //     if (isLoadingMore || currentPage >= lastPage) return;
  //     isLoadingMore = true;
  //   } else {
  //     customersLoad = true;
  //     currentPage = 1;
  //     _customers.clear();
  //   }
  //   notifyListeners();
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString("token") ?? "";
  //     final loggedInCustId = prefs.getInt("customer_id");

  //     final uri = Uri.parse(ApiRoutes.customers).replace(
  //       queryParameters: {
  //         "client_id": clientId.toString(),
  //         "page": page.toString(),
  //         ...customerFilters.map((k, v) => MapEntry(k, v.toString())),
  //       },
  //     );
  //     final response = await ApiService().getDataFromApi(
  //       api: uri.toString(),
  //       headers: {"Authorization": "Bearer $token"},
  //     );
  //     if (response["success"] == true) {
  //       final data = response["data"];
  //       customers.clear();
  //       _myCustomer = null;

  //       if (data["client"] != null) {
  //         _client = ClientModelCust.fromJson(data["client"]);
  //       } else {
  //         showToast(message: data["message"]);
  //       }
  //       currentPage = data["meta"]["current_page"];
  //       lastPage = data["meta"]["last_page"];
  //       List<dynamic> list = data["customers"] ?? [];
  //       for (var item in list) {
  //         final customer = CustomerModel.fromJson(item);
  //         if (customer.id == loggedInCustId) {
  //           _myCustomer = customer;
  //           _customers.add(customer);
  //           break;
  //         }
  //       }
  //       debugPrint("success: ${response["success"]}");
  //       debugPrint("data keys: ${response["data"].keys}");
  //       debugPrint(
  //         "customers length raw: ${(response["data"]["customers"] as List).length}",
  //       );
  //       for (var item in list) {
  //         debugPrint("item keys: ${(item as Map).keys}");
  //       }
  //     }
  //   } catch (e, st) {
  //     debugPrint("Error loading customers $e\n$st");
  //   } finally {
  //     customersLoad = false;
  //     isLoadingMore = false;
  //     notifyListeners();
  //   }
  // }

  // Future<void> getSingleCustomer({
  //   required BuildContext ctx,
  //   required int clientId,
  //   int page = 1,
  //   bool loadMore = false,
  // }) async {
  //   if (loadMore) {
  //     if (isLoadingMore || currentPage >= lastPage) return;
  //     isLoadingMore = true;
  //   } else {
  //     customersLoad = true;
  //     currentPage = 1;
  //     _customers.clear();
  //   }
  //   notifyListeners();
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString("token") ?? "";
  //     final loggedInCustId = prefs.getInt("customer_id");

  //     final uri = Uri.parse(ApiRoutes.customers).replace(
  //       queryParameters: {
  //         "client_id": clientId.toString(),
  //         "page": page.toString(),
  //         ...customerFilters.map((k, v) => MapEntry(k, v.toString())),
  //       },
  //     );
  //     final response = await ApiService().getDataFromApi(
  //       api: uri.toString(),
  //       headers: {"Authorization": "Bearer $token"},
  //     );
  //     if (response["success"] == true) {
  //       final data = response["data"];
  //       customers.clear();
  //       _myCustomer = null;
  //       if (data["client"] != null) {
  //         _client = ClientModelCust.fromJson(data["client"]);
  //       } else {
  //         showToast(message: data["message"]);
  //       }
  //       currentPage = data["meta"]["current_page"];
  //       lastPage = data["meta"]["last_page"];
  //       List<dynamic> list = data["customers"] ?? [];
  //       for (var item in list) {
  //         final customer = CustomerModel.fromJson(item);
  //         if (customer.id == loggedInCustId) {
  //           _myCustomer = customer;
  //           _customers.add(customer);
  //           break;
  //         }
  //       }
  //       debugPrint("success: ${response["success"]}");
  //       debugPrint("data keys: ${response["data"].keys}");
  //       debugPrint(
  //         "customers length raw: ${(response["data"]["customers"] as List).length}",
  //       );
  //       for (var item in list) {
  //         debugPrint("item keys: ${(item as Map).keys}");
  //       }
  //     }
  //   } catch (e, st) {
  //     debugPrint("Error loading customers $e\n$st");
  //   } finally {
  //     customersLoad = false;
  //     isLoadingMore = false;
  //     notifyListeners();
  //   }
  // }

  // Future<void> getSingleCustomer({
  //   required BuildContext ctx,
  //   required int customerId,
  //   int page = 1,
  //   bool loadMore = false,
  // }) async {
  //   if (loadMore) {
  //     if (isLoadingMore || currentPage >= lastPage) return;
  //     isLoadingMore = true;
  //   } else {
  //     customersLoad = true;
  //     currentPage = 1;
  //     _contacts.clear(); // Now this will work
  //   }
  //   notifyListeners();

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString("token") ?? "";

  //     final uri = Uri.parse(ApiRoutes.contacts).replace(
  //       queryParameters: {
  //         "customer_id": customerId.toString(),
  //         "page": page.toString(),
  //       },
  //     );

  //     final response = await ApiService().getDataFromApi(
  //       api: uri.toString(),
  //       headers: {"Authorization": "Bearer $token"},
  //     );

  //     if (response["success"] == true) {
  //       final List<dynamic> dataList = response["data"] ?? [];
  //       final meta = response["meta"];

  //       currentPage = meta["current_page"];
  //       lastPage = meta["last_page"];

  //       if (!loadMore) {
  //         _contacts.clear();
  //       }

  //       for (var item in dataList) {
  //         final contact = ContactResponseModel.fromJson(item);
  //         _contacts.add(contact);
  //       }

  //       debugPrint("Contacts loaded: ${_contacts.length}");
  //     } else {
  //       showToast(message: response["message"] ?? "Failed to load contacts");
  //     }
  //   } catch (e, st) {
  //     debugPrint("Error loading contacts: $e\n$st");
  //     showToast(message: "Error loading contacts");
  //   } finally {
  //     customersLoad = false;
  //     isLoadingMore = false;
  //     notifyListeners();
  //   }
  // }

  Future<void> getSingleCustomer({
    required BuildContext ctx,
    required int clientId,
    int page = 1,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (isLoadingMore || currentPage >= lastPage) return;
      isLoadingMore = true;
    } else {
      customersLoad = true;
      currentPage = 1;
      _customers.clear();
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      // CUSTOMER ID
      final int? loggedCustomerId = prefs.getInt("customer_id");

      // CLIENT ID (string or int safe)
      final dynamic rawClientId = prefs.get("cust_client_id");
      int? loggedClientId;
      if (rawClientId is int) {
        loggedClientId = rawClientId;
      } else if (rawClientId is String) {
        loggedClientId = int.tryParse(rawClientId);
      }

      final int effectiveClientId = loggedClientId ?? clientId;

      printData(
        title: "getSingleCustomer client_id =>",
        data: effectiveClientId,
      );

      final uri = Uri.parse(ApiRoutes.customers).replace(
        queryParameters: {
          "client_id": effectiveClientId.toString(),
          "page": page.toString(),
          ...customerFilters.map((k, v) => MapEntry(k, v.toString())),
        },
      );

      final response = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response["success"] == true) {
        final data = response["data"];

        if (data["client"] != null) {
          _client = ClientModelCust.fromJson(data["client"]);
        }

        final customersBlock = data["customers"];
        final pagination = customersBlock is Map<String, dynamic>
            ? customersBlock["pagination"] as Map<String, dynamic>?
            : null;

        if (pagination != null) {
          currentPage =
              int.tryParse(pagination["current_page"]?.toString() ?? "1") ?? 1;
          lastPage =
              int.tryParse(pagination["last_page"]?.toString() ?? "1") ?? 1;
          totalCustomers =
              int.tryParse(pagination["total"]?.toString() ?? "0") ?? 0;
        }

        final List<dynamic> list = customersBlock is Map<String, dynamic>
            ? (customersBlock["items"] as List<dynamic>? ?? [])
            : (customersBlock as List<dynamic>? ?? []);

        if (list.isNotEmpty) {
          for (final item in list) {
            _customers.add(CustomerModel.fromJson(item));
          }
        } else if (loggedCustomerId != null && _client != null) {
          _customers.add(
            CustomerModel.fromClientModel(_client!, loggedCustomerId),
          );
        }
        if (pagination == null || totalCustomers == 0) {
          totalCustomers = _customers.length;
        }
      }
    } catch (e, st) {
      printData(title: "Error loading customers", data: "$e\n$st", e: true);
    } finally {
      customersLoad = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
