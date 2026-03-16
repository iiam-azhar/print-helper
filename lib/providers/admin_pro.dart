import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/accounts_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

import '../widgets/loaders.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';

class AdminPro extends ChangeNotifier {
  bool accountsLoad = false;
  List<DropdownItem> languages = [];
  List<DropdownItem> accountTypes = [];
  List<DropdownItem> skills = [];
  List<DropdownItem> clientCmpnyType = [];
  List<DropdownItem> custCmpnyType = [];
  List<DropdownItem> clientRank = [];
  List<DropdownItem> customerRank = [];

  final List<AccountModel> _accounts = [];
  List<AccountModel> get accounts => _accounts;
  int currentPage = 1;
  int lastPage = 1;
  int totalAccounts = 0;
  bool isLoadingMore = false;

  //SEARCH
  Map<String, dynamic> accountFilters = {};
  String search = '';

  Future<void> getAccounts({
    required BuildContext ctx,
    int page = 1,
    bool loadMore = false,
  }) async {
    if (loadMore) {
      if (isLoadingMore || currentPage > lastPage) return;
      isLoadingMore = true;
    } else {
      accountsLoad = true;
      currentPage = 1;
      _accounts.clear();
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final uri = Uri.parse(ApiRoutes.account).replace(
        queryParameters: {
          "page": page.toString(),
          ...accountFilters.map((k, v) => MapEntry(k, v.toString())),
        },
      );
      final response = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );
      // final response = await ApiService().getDataFromApi(
      //   api: "${ApiRoutes.account}?page=$page",
      //   headers: {"Authorization": "Bearer $token"},
      // );
      if (response["success"] == true) {
        final List<dynamic> dataList = response["data"];
        currentPage = response["meta"]["current_page"];

        lastPage = response["meta"]["last_page"];
        totalAccounts = response["meta"]["total"];
        for (var item in dataList) {
          _accounts.add(AccountModel.fromJson(item));
        }
      }
    } catch (e) {
      printData(title: "Pagination Error:", data: e, e: true);
    }
    accountsLoad = false;
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> fetchAllDropdownData(BuildContext context) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final results = await Future.wait([
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.language}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.skill}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.accountType}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.rank}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.clientCmpnyType}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.custCmpnyType}"),
          headers: {"Authorization": "Bearer $token"},
        ),
        http.get(
          Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.custRank}"),
          headers: {"Authorization": "Bearer $token"},
        ),
      ]);
      final langRes = results[0];
      if (langRes.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(langRes.body);
        languages = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final skillRes = results[1];
      if (skillRes.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(skillRes.body);
        skills = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final acRes = results[2];
      if (acRes.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(acRes.body);
        accountTypes = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final cliRank = results[3];
      if (cliRank.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(cliRank.body);
        clientRank = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final cliCmpnyType = results[4];
      if (cliCmpnyType.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(cliCmpnyType.body);
        clientCmpnyType = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final cusCmpnyType = results[5];
      if (cusCmpnyType.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(cusCmpnyType.body);
        custCmpnyType = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      final cusRank = results[6];
      if (cusRank.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(cusRank.body);
        customerRank = decoded.map((e) => DropdownItem.fromJson(e)).toList();
      }
      notifyListeners();
    } catch (e) {
      printData(title: "FETCH ALL DROPDOWNS ERROR:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> storeAccount({
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required List<Map<String, dynamic>> phones,
    required List<String> emails,
    required int type,
    required List<int> languages,
    required List<int> skills,
    required String? imagePath,
    required BuildContext context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final request = http.MultipartRequest(
        "POST",
        Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.account}'),
      );
      printData(title: 'Request URL:', data: request.url);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      phones.asMap().forEach((i, p) {
        printData(title: 'phones[$i][type] =', data: p['type']);
        printData(title: 'phones[$i][number] =', data: p['value']);
      });
      emails.asMap().forEach((i, e) {
        printData(title: 'emails[$i] =', data: e);
      });
      request.fields["name"] = firstName;
      request.fields["last_name"] = lastName;

      request.fields["username"] = username;
      request.fields["password"] = password;
      request.fields["password_confirmation"] = password;
      request.fields["email"] = emails.isNotEmpty ? emails[0] : "";
      request.fields["account_type"] = type.toString();
      request.fields["status"] = "1";
      for (int i = 0; i < phones.length; i++) {
        request.fields["phones[$i][type]"] = phones[i]["type"];
        request.fields["phones[$i][number]"] = phones[i]["value"];
      }
      for (int i = 1; i < emails.length; i++) {
        request.fields["emails[${i - 1}]"] = emails[i];
      }
      for (int i = 0; i < languages.length; i++) {
        request.fields["languages[$i]"] = languages[i].toString();
      }

      for (int i = 0; i < skills.length; i++) {
        request.fields["skills[$i]"] = skills[i].toString();
      }

      if (imagePath != null && imagePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath("image", imagePath),
        );
      }
      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      printData(title: "STATUS:", data: response.statusCode);

      printData(title: "BODY:", data: response.body);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      printData(title: "API ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> updateAccount({
    required int id,
    required String firstName,
    required String lastName,
    required String username,
    required List<Map<String, dynamic>> phones,
    required List<String> emails,
    required int type,
    required List<int> languages,
    required List<int> skills,
    required String? imagePath,
    required BuildContext context,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final request = http.MultipartRequest(
        "POST",
        Uri.parse('${ApiRoutes.baseUrl}${ApiRoutes.account}/$id/update'),
      );
      printData(title: 'Request URL:', data: request.url);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });
      printData(title: 'Prepare keys', data: '');
      request.fields["name"] = firstName;
      request.fields["last_name"] = lastName;
      request.fields["username"] = username;
      request.fields["role"] = 2.toString();
      request.fields["account_type"] = type.toString();
      for (int i = 0; i < phones.length; i++) {
        request.fields["phones[$i][type]"] = phones[i]["type"];
        request.fields["phones[$i][number]"] = phones[i]["value"];
      }
      for (int i = 0; i < languages.length; i++) {
        request.fields["languages[$i]"] = languages[i].toString();
      }
      for (int i = 0; i < skills.length; i++) {
        request.fields["skills[$i]"] = skills[i].toString();
      }
      printData(title: 'Keys Prepared', data: '');
      for (int i = 0; i < emails.length; i++) {
        request.fields["emails[$i]"] = emails[i];
      }
      if (imagePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath("image", imagePath),
        );
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final res = jsonDecode(response.body);
      printData(title: "UPDATE RESPONSE:", data: response.body);
      return res["success"] == true || res["success"] == "true";
    } catch (e) {
      printData(title: "UPDATE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> deleteAccount(int id, BuildContext context) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final data = await ApiService().postDataToApi(
        api: '${ApiRoutes.account}/$id',
        isDelete: true,
        headers: {"Authorization": "Bearer $token"},
      );
      if (data is Map<String, dynamic> && data["success"] == true) {
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

  Future<void> toggleStatus(
    int accountId,
    bool newStatus,
    BuildContext context,
  ) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final body = {"status": newStatus ? "1" : "0"};
      final response = await ApiService().postDataToApi(
        api: "${ApiRoutes.account}/$accountId/toggle",
        headers: {"Authorization": "Bearer $token"},
        payload: body,
      );
      if (response is Map && response["success"] == true) {
        int index = _accounts.indexWhere((a) => a.id == accountId);
        if (index != -1) {
          _accounts[index] = _accounts[index].copyWith(status: newStatus);
        }
        showToast(message: response["message"]);
        notifyListeners();
      } else {
        showToast(message: response["message"] ?? "Failed to update status");
      }
    } catch (e) {
      printData(title: "TOGGLE ERROR:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  void applyAccountFilters(Map<String, dynamic> filters, BuildContext context) {
    accountFilters.clear();
    if (filters["status"] == "active") {
      accountFilters["status"] = 1;
    } else if (filters["status"] == "inactive") {
      accountFilters["status"] = 0;
    }
    if ((filters["c"] ?? "").toString().isNotEmpty) {
      accountFilters["name"] = filters["first_name"].toString().trim();
    }
    if ((filters["first_name"] ?? "").toString().isNotEmpty) {
      accountFilters["name"] = filters["first_name"].toString().trim();
    }
    if ((filters["last_name"] ?? "").toString().isNotEmpty) {
      accountFilters["last_name"] = filters["last_name"].toString().trim();
    }
    if ((filters["email"] ?? "").toString().isNotEmpty) {
      accountFilters["email"] = filters["email"].toString().trim();
    }
    if ((filters["phone"] ?? "").toString().isNotEmpty) {
      accountFilters["phone"] = filters["phone"].toString().trim();
    }
    if ((filters["date"] ?? "").toString().isNotEmpty) {
      final parts = filters["date"].split("-");
      if (parts.length == 3) {
        accountFilters["created_date"] = "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    }
    getAccounts(ctx: context); // Reload accounts with filters
  }

  int get appliedFilterCount {
    int count = 0;
    accountFilters.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      // ignore page param if ever added
      if (key == 'page') return;
      count++;
    });
    return count;
  }

  void clearAccountFilters(BuildContext context) {
    accountFilters.clear();
    notifyListeners();
    getAccounts(ctx: context);
  }
}
