import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:print_helper/services/api_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/accounts_models.dart';
import '../models/client_models.dart';
import '../models/contact_form_models.dart';
import '../models/edit_client_models.dart';
import '../models/states_models.dart';
import '../widgets/loaders.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';
import '../widgets/toasts.dart';

class ClientPro extends ChangeNotifier {
  bool clientsLoad = false;
  bool isLoadingMore = false;
  int totalClients = 0;
  int get totalLoadedClients => _clients.length;
  final List<ClientModel> _clients = [];
  List<ClientModel> get clients => _clients;
  List<StateModel> statesList = [];
  List<DropdownItem> stateDropdown = [];
  List<DropdownItem> cityDropdown = [];
  List<StaffModel> staffList = [];
  Map<String, dynamic> clientFilters = {};
  String search = '';
  int currentPage = 1;
  int lastPage = 1;
  ClientModel? _selectedClient;
  ClientModel? get selectedClient => _selectedClient;

  void selectClientById(int clientId) {
    try {
      _selectedClient = _clients.firstWhere((c) => c.id == clientId);
      notifyListeners();
    } catch (e) {
      printData(title: "Client not found with id", data: clientId, e: true);
    }
  }

  Future<void> fetchStates() async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: "states",
        headers: {"Authorization": "Bearer $token"},
      );
      final List list = response["data"];
      statesList = list.map((e) => StateModel.fromJson(e)).toList();
      stateDropdown = statesList
          .map((s) => DropdownItem(id: s.id, name: s.name))
          .toList();
      notifyListeners();
    } catch (e) {
      printData(title: "State API Error:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<void> fetchStaff() async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: "accounts/list",
        headers: {"Authorization": "Bearer $token"},
      );
      final List list = response["data"];
      staffList = list.map((e) => StaffModel.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      printData(title: "Staff API error:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  void loadCities(int stateId) {
    final state = statesList.firstWhere((e) => e.id == stateId);
    cityDropdown = state.cities
        .map((c) => DropdownItem(id: c.id, name: c.name))
        .toList();
    notifyListeners();
  }

  Future<void> getClients({
    required BuildContext ctx,
    int page = 1,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (isLoadingMore || currentPage > lastPage) return;
      isLoadingMore = true;
    } else {
      clientsLoad = true;
      currentPage = 1;
      _clients.clear();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final uri = Uri.parse(ApiRoutes.clients).replace(
        queryParameters: {
          "page": page.toString(),
          ...clientFilters.map((k, v) => MapEntry(k, v.toString())),
        },
      );
      final response = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response["success"] == true) {
        totalClients = response["meta"]?["total"] ?? 0;
        final List<dynamic> dataList = response["data"] ?? [];
        currentPage = response["meta"]?["current_page"] ?? page;
        lastPage = response["meta"]?["last_page"] ?? 1;
        for (var item in dataList) {
          _clients.add(ClientModel.fromJson(item));
        }
      }
    } catch (e, st) {
      printData(title: "Client Pagination Error", data: "$e\n$st", e: true);
    }
    clientsLoad = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<bool> createClient({
    required String companyName,
    required String address,
    required String address2,
    required String state,
    required String city,
    required String zipcode,
    required List<int> clientLanguages,
    required int status,
    required List<int> assignedStaff,
    required List<ContactFormModel> contacts,
    required int companyType,
    required int clientRank,
    required String brandingPrimary,
    required String brandingSecondary,
    required String brandingUrl,
    File? clientImage,
    File? brandLogo,
    required dynamic context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final uri = Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.clients}');
      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["company_name"] = companyName;
      request.fields["address"] = address;
      request.fields["address_2"] = address2;
      request.fields["state"] = state;
      request.fields["city"] = city;
      request.fields["zipcode"] = zipcode;
      request.fields["status"] = status.toString();
      request.fields["company_type"] = companyType.toString();
      request.fields["client_rank"] = clientRank.toString();
      request.fields["branding_primary_color"] = brandingPrimary;
      request.fields["branding_secondary_color"] = brandingSecondary;
      request.fields["branding_url"] = brandingUrl;
      for (int i = 0; i < clientLanguages.length; i++) {
        request.fields["client_languages[$i]"] = clientLanguages[i].toString();
      }
      for (int i = 0; i < assignedStaff.length; i++) {
        request.fields["assigned_staff[$i]"] = assignedStaff[i].toString();
      }
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
      if (clientImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("client_image", clientImage.path),
        );
      }
      if (brandLogo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            "branding_logo_file",
            brandLogo.path,
          ),
        );
      }
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      printData(title: "STATUS:", data: res.statusCode);
      printData(title: "BODY:", data: res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        await getClients(ctx: context);
        return true;
      } else {
        _handleApiErrors(res);
      }
      return false;
    } catch (e) {
      printData(title: "CLIENT CREATE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> updateClient({
    required int clientId,
    required String companyName,
    required String address,
    required String address2,
    required String state,
    required String city,
    required String zipcode,
    required List<int> clientLanguages,
    required int status,
    required List<int> assignedStaff,
    required List<ContactFormModel> contacts,
    required int companyType,
    required int clientRank,
    required String brandingPrimary,
    required String brandingSecondary,
    required String brandingUrl,
    File? brandinglogo,
    File? clientImage,
    required dynamic context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final uri = Uri.parse('${ApiRoutes.baseUrl}clients/$clientId/update');
      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      request.fields["company_name"] = companyName;
      request.fields["address"] = address;
      request.fields["address_2"] = address2;
      request.fields["state"] = state;
      request.fields["city"] = city;
      request.fields["zipcode"] = zipcode;
      request.fields["status"] = status.toString();
      printData(title: "company_type =>", data: companyType);
      printData(title: "client_rank =>", data: clientRank);
      request.fields["company_type"] = '$companyType';
      request.fields["client_rank"] = '$clientRank';
      request.fields["branding_primary_color"] = brandingPrimary;
      request.fields["branding_secondary_color"] = brandingSecondary;
      request.fields["branding_url"] = brandingUrl;
      for (int i = 0; i < clientLanguages.length; i++) {
        request.fields["client_languages[$i]"] = clientLanguages[i].toString();
      }
      for (int i = 0; i < assignedStaff.length; i++) {
        request.fields["assigned_staff[$i]"] = assignedStaff[i].toString();
      }
      for (int i = 0; i < contacts.length; i++) {
        final c = contacts[i];
        if (c.existingId != null) {
          request.fields["contacts[$i][id]"] = c.existingId.toString();
          printData(
            title: "Contact $i → Sending existing ID:",
            data: c.existingId,
          );
        } else {
          printData(title: "Contact $i →", data: "New Contact (no ID)");
        }
        request.fields["contacts[$i][name]"] = c.firstName.text.trim();
        request.fields["contacts[$i][last_name]"] = c.lastName.text.trim();
        request.fields["contacts[$i][username]"] = c.username.text.trim();
        if (c.password.text.trim().isNotEmpty) {
          request.fields["contacts[$i][password]"] = c.password.text;
          request.fields["contacts[$i][password_confirmation]"] =
              c.confirmPassword.text;
        }
        for (int li = 0; li < c.selectedLanguageIds.length; li++) {
          request.fields["contacts[$i][languages][$li]"] = c
              .selectedLanguageIds[li]
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
          final em = c.emails[e].text.trim();
          if (em.isNotEmpty) {
            request.fields["contacts[$i][emails][$e]"] = em;
          }
        }
        if (c.image != null) {
          printData(
            title: "Contact $i → Uploading new image:",
            data: c.image!.path,
          );
          request.files.add(
            await http.MultipartFile.fromPath(
              "contacts[$i][image]",
              c.image!.path,
            ),
          );
        } else {
          printData(title: "Contact $i →", data: "No new image uploaded");
        }
      }
      if (clientImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath("client_image", clientImage.path),
        );
      }
      if (brandinglogo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            "branding_logo_file",
            brandinglogo.path,
          ),
        );
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      printData(title: "UPDATE CLIENT STATUS:", data: response.statusCode);
      printData(title: "UPDATE CLIENT BODY:", data: response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body["success"] == true || body["success"] == "true") {
          await getClients(ctx: context);
          return true;
        } else {
          _handleApiErrors(response);
          return false;
        }
      } else {
        _handleApiErrors(response);
        return false;
      }
    } catch (e, st) {
      printData(title: "UPDATE CLIENT ERROR:", data: "$e\n$st", e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<EditClientModel?> getClientDetails(int clientId) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.clients}/$clientId",
      );
      printData(title: "CLIENT URL:", data: url);
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
        printData(title: "CLIENT BODY:", data: jsonBody);
        return EditClientModel.fromJson(jsonBody['data']);
      } else {
        printData(title: "Client Fetch Error:", data: response.body, e: true);
        return null;
      }
    } catch (e, st) {
      printData(title: "ERROR in getClientDetails:", data: "$e $st", e: true);
      return null;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> toggleStatus(
    int id,
    bool newStatus,
    BuildContext context,
  ) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final body = {"status": newStatus ? "1" : "0"};
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.clients}/$id/toggle",
        headers: {"Authorization": "Bearer $token"},
        payload: body,
      );
      if (response is Map && response["success"] == true) {
        final index = _clients.indexWhere((c) => c.id == id);
        if (index != -1) {
          _clients[index] = _clients[index].copyWith(status: newStatus);
        }
        showToast(message: response["message"]);
        notifyListeners();
      } else {
        showToast(message: response["message"] ?? "Status update failed");
      }
    } catch (e) {
      printData(title: "TOGGLE ERROR:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<void> toggleContactStatus({
    required int clientId,
    required int contactId,
    required bool newStatus,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final body = {"status": newStatus ? "1" : "0"};
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.account}/$contactId/toggle",
        headers: {"Authorization": "Bearer $token"},
        payload: body,
      );
      if (response["success"] == true) {
        final cIndex = _clients.indexWhere((c) => c.id == clientId);
        if (cIndex != -1) {
          final conIndex = _clients[cIndex].contacts.indexWhere(
            (c) => c.contactId == contactId,
          );

          if (conIndex != -1) {
            final updated = _clients[cIndex].contacts[conIndex].copyWith(
              status: newStatus,
            );

            _clients[cIndex].contacts[conIndex] = updated;
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

  Future<bool> deleteClient(int id, BuildContext context) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.clients}/$id",
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

  void applyClientFilters(Map<String, dynamic> filters, BuildContext context) {
    clientFilters.clear();
    if (filters["status"] == "active") {
      clientFilters["status"] = 1;
    } else if (filters["status"] == "inactive") {
      clientFilters["status"] = 0;
    }

    if ((filters["company_name"] ?? "").toString().isNotEmpty) {
      clientFilters["company_name"] = filters["company_name"].toString().trim();
    }

    if ((filters["first_name"] ?? "").toString().isNotEmpty) {
      clientFilters["name"] = filters["first_name"].toString().trim();
    }
    if ((filters["last_name"] ?? "").toString().isNotEmpty) {
      clientFilters["last_name"] = filters["last_name"].toString().trim();
    }
    if ((filters["email"] ?? "").toString().isNotEmpty) {
      clientFilters["email"] = filters["email"].toString().trim();
    }
    if ((filters["phone"] ?? "").toString().isNotEmpty) {
      clientFilters["phone"] = filters["phone"].toString().trim();
    }
    if ((filters["date"] ?? "").toString().isNotEmpty) {
      final parts = filters["date"].split("-");
      if (parts.length == 3) {
        clientFilters["created_date"] = "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    }
    getClients(ctx: context);
  }

  int get appliedFilterCount {
    int count = 0;
    clientFilters.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (key == 'page') return;
      count++;
    });
    return count;
  }

  void clearClientFilters(BuildContext context) {
    clientFilters.clear();
    notifyListeners();
    getClients(ctx: context);
  }

  void _handleApiErrors(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('errors')) {
        final Map<String, dynamic> errors = body['errors'];
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            showToast(message: value[0]);
          }
        });
      } else if (body is Map && body.containsKey('message')) {
        showToast(message: body['message']);
      }
    } catch (e) {
      showToast(message: "An error occurred. Please try again.");
    }
  }
}
