import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/accounts_models.dart';
import '../models/staff_payments/staff_payments_tabs_model.dart';
import '../models/states_models.dart';
import '../models/account_contract_rules_model.dart';
import '../models/contract_template_model.dart';
import '../models/standard_rule_model.dart';
import '../models/contracts_models.dart';
import '../models/checklist_model.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;

import '../widgets/loaders.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AdminPro extends ChangeNotifier {
  List<StateModel> get states => statesList;
  // State/City dropdown logic for Account Info
  List<StateModel> statesList = [];
  List<DropdownItem> stateDropdown = [];
  List<DropdownItem> cityDropdown = [];
  int? selectedStateId;
  int? selectedCityId;

  List<DropdownItem> get citiesForSelectedState => cityDropdown;

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

  void setSelectedState(int stateId) {
    selectedStateId = stateId;
    selectedCityId = null;
    final state = statesList.firstWhere(
      (e) => e.id == stateId,
      orElse: () => StateModel(id: stateId, name: '', cities: []),
    );
    cityDropdown = state.cities
        .map((c) => DropdownItem(id: c.id, name: c.name))
        .toList();
    notifyListeners();
  }

  void setSelectedCity(int cityId) {
    selectedCityId = cityId;
    notifyListeners();
  }

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
  AccountDetailModel? currentAccountDetail;
  bool accountDetailLoad = false;
  OnboardingTrainingModel? currentOnboardingTraining;
  bool onboardingTrainingLoad = false;
  AccountContractRulesModel? currentAccountContractRules;
  bool accountContractRulesLoad = false;
  int? accountContractRulesForAccountId;

  bool contractsLoad = false;
  bool isContractsLoadingMore = false;
  final List<ContractAgreementModel> _contracts = [];
  List<ContractAgreementModel> get contracts => _contracts;
  int contractsCurrentPage = 1;
  int contractsLastPage = 1;
  int contractsTotal = 0;
  String contractsSearch = '';
  int _activeContractsRequest = 0;

  int clientTotal = 0;
  int clientAgreementsSigned = 0;
  int specialistTotal = 0;
  int specialistContractsSigned = 0;
  int totalUnsigned = 0;
  String oldestUnsignedText = '';

  // Templates
  bool templatesLoad = false;
  ContractTemplateModel? clientTemplate;
  ContractTemplateModel? staffTemplate;

  // Rules (Standards)
  bool specialistRulesLoad = false;
  bool clientRulesLoad = false;
  List<StandardRuleModel> specialistRules = [];
  List<StandardRuleModel> clientRules = [];

  // Checklists
  bool checklistsLoad = false;
  List<ChecklistModel> checklists = [];

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

  Future<void> getAccountInfo(int accountId) async {
    accountDetailLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: ApiRoutes.accountInfo(accountId),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response["success"] == true) {
        currentAccountDetail = AccountDetailModel.fromJson(response["data"]);
      }
    } catch (e) {
      printData(title: "Account Info Error:", data: e, e: true);
    }
    accountDetailLoad = false;
    notifyListeners();
  }

  Future<void> getOnboardingTraining(int accountId) async {
    onboardingTrainingLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: ApiRoutes.onboardingTraining(accountId),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response["success"] == true) {
        currentOnboardingTraining = OnboardingTrainingModel.fromJson(
          response["data"],
        );
      }
    } catch (e) {
      printData(title: "Onboarding Training Error:", data: e, e: true);
    }
    onboardingTrainingLoad = false;
    notifyListeners();
  }

  Future<bool> toggleAccountChecklistItem({
    required int accountId,
    required int checklistId,
    required int itemIndex,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: ApiRoutes.accountChecklistItemToggle(
          accountId,
          checklistId,
          itemIndex,
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response is Map && response["success"] == true) {
        await getOnboardingTraining(accountId);
        return true;
      }

      showToast(message: response?["message"] ?? "Failed to update checklist");
      return false;
    } catch (e) {
      printData(title: "Checklist Toggle Error:", data: e, e: true);
      showToast(message: "Error updating checklist");
      return false;
    }
  }

  Future<void> getAccountContractRules(int accountId) async {
    accountContractRulesLoad = true;
    accountContractRulesForAccountId = accountId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().getDataFromApi(
        api: ApiRoutes.accountContractRules(accountId),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response["success"] == true &&
          response["data"] is Map<String, dynamic>) {
        currentAccountContractRules = AccountContractRulesModel.fromJson(
          response["data"] as Map<String, dynamic>,
        );
      } else {
        currentAccountContractRules = null;
      }
    } catch (e) {
      printData(title: "Contract Rules Error:", data: e, e: true);
      currentAccountContractRules = null;
    }
    accountContractRulesLoad = false;
    notifyListeners();
  }

  StaffPaymentResponseModel? currentPaymentResponse;
  bool paymentCompensationLoad = false;

  Future<void> getStaffPaymentCompensation(
    int accountId, {
    String? day,
    int? wholesaleRetailPage,
    int? paymentPage,
    String? type,
    String? dayFilter,
    String? status,
    String? search,
  }) async {
    paymentCompensationLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final Map<String, String> queryParams = {};
      if (day != null) queryParams['day'] = day;
      if (wholesaleRetailPage != null) {
        queryParams['page'] = wholesaleRetailPage.toString();
        queryParams['wholesale_retail_page'] = wholesaleRetailPage.toString();
      }
      if (paymentPage != null) queryParams['payment_page'] = paymentPage.toString();
      if (type != null) queryParams['type'] = type;
      if (dayFilter != null) queryParams['day_filter'] = dayFilter;
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;

      final uri = Uri.parse(ApiRoutes.accountPaymentsCompensation(accountId));
      final finalUri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...queryParams,
      });

      final response = await ApiService().getDataFromApi(
        api: finalUri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response["success"] == true) {
        currentPaymentResponse = StaffPaymentResponseModel.fromJson(response);
      } else {
        currentPaymentResponse = null;
      }
    } catch (e) {
      printData(title: "Compensation Error:", data: e, e: true);
      currentPaymentResponse = null;
    }
    paymentCompensationLoad = false;
    notifyListeners();
  }

  Future<bool> signAccountAgreement({
    required int accountId,
    required String signerName,
    required String signedDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final response = await ApiService().postDataToApi(
        api: ApiRoutes.signAccountAgreement(accountId),
        payload: {"signer_name": signerName},
        headers: {"Authorization": "Bearer $token"},
      );

      if (response["success"] == true) {
        // Refresh the contract rules to get updated agreement status
        await getAccountContractRules(accountId);
        showToast(message: "Agreement signed successfully!");
        return true;
      } else {
        showToast(message: response["message"] ?? "Failed to sign agreement");
        return false;
      }
    } catch (e) {
      printData(title: "Sign Agreement Error:", data: e, e: true);
      showToast(message: "Error signing agreement");
      return false;
    }
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
    String? level,
    String? password,
    String? paymentMethod,
    String? paymentAccount,
    String? address,
    String? address2,
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
      if (level != null && level.isNotEmpty) {
        request.fields["role"] = level;
        request.fields["level"] = level;
        request.fields["role_name"] = level;
      } else {
        request.fields["role"] = 2.toString();
      }
      request.fields["account_type"] = type.toString();
      if (paymentMethod != null) {
        request.fields["payment_method"] = paymentMethod;
      }
      if (paymentAccount != null) {
        request.fields["payment_account"] = paymentAccount;
      }
      if (address != null) {
        request.fields["address"] = address;
      }
      if (address2 != null) {
        request.fields["address_2"] = address2;
      }
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
      if (password != null && password.isNotEmpty) {
        request.fields["password"] = password;
        request.fields["password_confirmation"] = password;
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

  Future<void> getContracts({
    required BuildContext ctx,
    int page = 1,
    bool loadMore = false,
    String? search,
  }) async {
    if (search != null && !loadMore) {
      contractsSearch = search.trim();
      page = 1;
    }

    final requestId = ++_activeContractsRequest;

    if (loadMore) {
      if (isContractsLoadingMore || contractsCurrentPage >= contractsLastPage) {
        return;
      }
      isContractsLoadingMore = true;
    } else {
      contractsLoad = true;
      contractsCurrentPage = 1;
      contractsLastPage = 1;
      _contracts.clear();
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final query = <String, String>{'page': page.toString()};
      if (contractsSearch.isNotEmpty) {
        query['search'] = contractsSearch;
      }

      final uri = Uri.parse(
        ApiRoutes.contracts,
      ).replace(queryParameters: query);
      debugPrint("GET CONTRACTS URL: $uri");

      final response = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {"Authorization": "Bearer $token"},
      );

      // Concurrency check: discard if a newer request has started
      if (requestId != _activeContractsRequest) {
        debugPrint("Discarding stale contracts response (ID: $requestId)");
        return;
      }

      debugPrint("GET CONTRACTS RESPONSE: $response");

      if (response is Map<String, dynamic> && response['success'] == true) {
        final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
        final agreements = (data['agreements'] as List?) ?? [];
        final meta =
            (response['meta'] as Map?)?.cast<String, dynamic>() ??
            (data['meta'] as Map?)?.cast<String, dynamic>() ??
            {};

        contractsCurrentPage = (meta['current_page'] ?? page) is int
            ? (meta['current_page'] ?? page) as int
            : int.tryParse('${meta['current_page'] ?? page}') ?? page;
        contractsLastPage = (meta['last_page'] ?? 1) is int
            ? (meta['last_page'] ?? 1) as int
            : int.tryParse('${meta['last_page'] ?? 1}') ?? 1;
        contractsTotal = (meta['total'] ?? agreements.length) is int
            ? (meta['total'] ?? agreements.length) as int
            : int.tryParse('${meta['total'] ?? agreements.length}') ??
                  agreements.length;

        debugPrint(
          "CONTRACTS PAGINATION: Page $contractsCurrentPage of $contractsLastPage (Total: $contractsTotal)",
        );

        clientTotal = (data['clientTotal'] ?? 0) is int
            ? (data['clientTotal'] ?? 0) as int
            : int.tryParse('${data['clientTotal'] ?? 0}') ?? 0;
        clientAgreementsSigned = (data['clientAgreementsSigned'] ?? 0) is int
            ? (data['clientAgreementsSigned'] ?? 0) as int
            : int.tryParse('${data['clientAgreementsSigned'] ?? 0}') ?? 0;
        specialistTotal = (data['specialistTotal'] ?? 0) is int
            ? (data['specialistTotal'] ?? 0) as int
            : int.tryParse('${data['specialistTotal'] ?? 0}') ?? 0;
        specialistContractsSigned =
            (data['specialistContractsSigned'] ?? 0) is int
            ? (data['specialistContractsSigned'] ?? 0) as int
            : int.tryParse('${data['specialistContractsSigned'] ?? 0}') ?? 0;
        totalUnsigned = (data['totalUnsigned'] ?? 0) is int
            ? (data['totalUnsigned'] ?? 0) as int
            : int.tryParse('${data['totalUnsigned'] ?? 0}') ?? 0;
        oldestUnsignedText = (data['oldestUnsignedText'] ?? '').toString();

        for (final item in agreements) {
          if (item is Map<String, dynamic>) {
            _contracts.add(ContractAgreementModel.fromJson(item));
          }
        }
      }
    } catch (e) {
      printData(title: 'Contracts API Error:', data: e, e: true);
      showToast(message: 'Unable to load contracts at the moment');
    }

    contractsLoad = false;
    isContractsLoadingMore = false;
    notifyListeners();
  }

  Future<void> getTemplates() async {
    templatesLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final response = await ApiService().getDataFromApi(
        api: ApiRoutes.templates,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response is Map<String, dynamic> && response['success'] == true) {
        final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
        if (data['client'] != null) {
          clientTemplate = ContractTemplateModel.fromJson(
            (data['client'] as Map).cast<String, dynamic>(),
          );
        }
        if (data['staff'] != null) {
          staffTemplate = ContractTemplateModel.fromJson(
            (data['staff'] as Map).cast<String, dynamic>(),
          );
        }
      }
    } catch (e) {
      printData(title: 'Templates API Error:', data: e, e: true);
      showToast(message: 'Unable to load templates');
    } finally {
      templatesLoad = false;
      notifyListeners();
    }
  }

  Future<void> saveTemplate({
    required String type,
    required String name,
    required String version,
    required String content,
  }) async {
    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final api = '${ApiRoutes.templates}/$type';
      final payload = {'name': name, 'version': version, 'content': content};
      printData(title: 'Update Template API:', data: api);
      printData(title: 'Update Template Body:', data: payload);
      final response = await ApiService().postDataToApi(
        api: api,
        isPut: true,
        headers: {'Authorization': 'Bearer $token'},
        payload: payload,
      );
      if (response is Map<String, dynamic> && response['success'] == true) {
        showToast(message: 'Template saved successfully');
        await getTemplates();
      } else {
        showToast(message: 'Failed to save template');
      }
    } catch (e) {
      printData(title: 'Save Template Error:', data: e, e: true);
      showToast(message: 'Failed to save template');
    } finally {
      Loaders.hide();
    }
  }

  Future<void> getRules({required String type}) async {
    final isSpecialist = type == 'specialist';
    if (isSpecialist) {
      specialistRulesLoad = true;
    } else {
      clientRulesLoad = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final data = await ApiService().getDataFromApi(
        api: '${ApiRoutes.rules}?type=$type',
        headers: {'Authorization': 'Bearer $token'},
      );
      if (data is Map<String, dynamic> && data['success'] == true) {
        final rawList = (data['rules'] as List<dynamic>?) ?? [];
        final parsed = rawList
            .map((e) => StandardRuleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (isSpecialist) {
          specialistRules = parsed;
        } else {
          clientRules = parsed;
        }
      }
    } catch (e) {
      printData(title: 'Get Rules Error ($type):', data: e, e: true);
    } finally {
      if (isSpecialist) {
        specialistRulesLoad = false;
      } else {
        clientRulesLoad = false;
      }
      notifyListeners();
    }
  }

  Future<void> toggleRuleStatus({
    required int ruleId,
    required bool newStatus,
    required String type,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final body = {"is_active": newStatus};

      final response = await ApiService().postDataToApi(
        api: "rules/$ruleId/toggle",
        isPut: true,
        headers: {
          "Content-type": "application/json",
          "Authorization": "Bearer $token",
        },
        payload: body,
      );

      if (response is Map && response["success"] == true) {
        if (type == 'specialist') {
          int index = specialistRules.indexWhere((r) => r.id == ruleId);
          if (index != -1) {
            specialistRules[index] = specialistRules[index].copyWith(
              isActive: newStatus,
            );
          }
        } else {
          int index = clientRules.indexWhere((r) => r.id == ruleId);
          if (index != -1) {
            clientRules[index] = clientRules[index].copyWith(
              isActive: newStatus,
            );
          }
        }
        showToast(message: response["message"] ?? "Status updated");
        notifyListeners();
      } else {
        showToast(message: response["message"] ?? "Failed to update status");
      }
    } catch (e) {
      printData(title: "TOGGLE RULE ERROR:", data: e, e: true);
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> deleteRule(int ruleId, String type) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final response = await ApiService().postDataToApi(
        api: "rules/$ruleId",
        isDelete: true,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response is Map && response["success"] == true) {
        if (type == 'specialist') {
          specialistRules.removeWhere((r) => r.id == ruleId);
        } else {
          clientRules.removeWhere((r) => r.id == ruleId);
        }
        showToast(message: response["message"] ?? "Rule deleted");
        notifyListeners();
        return true;
      } else {
        showToast(message: response["message"] ?? "Failed to delete rule");
        return false;
      }
    } catch (e) {
      printData(title: "DELETE RULE ERROR:", data: e, e: true);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> getChecklists() async {
    checklistsLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.checklists,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (data is Map<String, dynamic> && data['success'] == true) {
        final rawList = (data['checklists'] as List<dynamic>?) ?? [];
        checklists = rawList
            .map((e) => ChecklistModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      printData(title: 'Get Checklists Error:', data: e, e: true);
    } finally {
      checklistsLoad = false;
      notifyListeners();
    }
  }

  Future<bool> deleteChecklist(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final data = await ApiService().postDataToApi(
        api: 'checklists/$id',
        isDelete: true,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (data != null && data['success'] == true) {
        showToast(message: 'Checklist deleted successfully');
        return true;
      }
      showToast(message: data?['message'] ?? 'Failed to delete checklist');
    } catch (e) {
      debugPrint('Delete Checklist Error: $e');
    }
    return false;
  }

  Future<bool> sendContractReminder(String agreementId) async {
    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final payload = {"agreement_id": agreementId};
      debugPrint("SEND REMINDER BODY: $payload");

      final response = await ApiService().postDataToApi(
        api: ApiRoutes.contractsSendReminder,
        headers: {'Authorization': 'Bearer $token'},
        payload: payload,
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        showToast(message: response['message'] ?? 'Reminder sent successfully');
        return true;
      }
      showToast(message: response?['message'] ?? 'Failed to send reminder');
      return false;
    } catch (e) {
      debugPrint('Send Reminder Error: $e');
      showToast(message: 'Error sending reminder');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<void> downloadContractPdf({
    required String url,
    required String fileName,
  }) async {
    Loaders.show();
    try {
      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final extStatus = await Permission.manageExternalStorage.request();
          if (!extStatus.isGranted) {
            showToast(message: 'Storage permission denied');
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download/Printhelper');
      } else {
        directory = await getDownloadsDirectory();
        if (directory != null) {
          directory = Directory('${directory.path}/Printhelper');
        }
      }

      directory ??= await getApplicationDocumentsDirectory();

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = "${directory.path}/$fileName.pdf";

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
        ),
      );

      showToast(message: 'PDF saved to: $filePath');
      debugPrint('PDF downloaded to: $filePath');
    } catch (e) {
      debugPrint('Download Error: $e');
      showToast(message: 'Failed to download PDF');
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> savePerformanceMetric(
    int accountId, {
    required String day,
    required String metric,
    // missed_interactions
    int? hours,
    int? minutes,
    // average_reply_time_minutes
    String? fromTime,
    String? toTime,
  }) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Map<String, dynamic> body = {'day': day, 'metric': metric};
      if (metric == 'missed_interactions') {
        body['hours'] = hours ?? 0;
        body['minutes'] = minutes ?? 0;
      } else if (metric == 'average_reply_time_minutes') {
        body['from_time'] = fromTime ?? '';
        body['to_time'] = toTime ?? '';
      }

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/performance-metric',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: body,
      );

      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Saved successfully');
        // Refresh compensation data with the same day
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to save');
        return false;
      }
    } catch (e) {
      printData(title: 'Save Performance Metric Error:', data: e, e: true);
      showToast(message: 'An error occurred');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> closeDay(int accountId, String day) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/close-day',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: {'day': day},
      );

      Loaders.hide();

      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Day closed successfully');
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to close day');
        return false;
      }
    } catch (e) {
      Loaders.hide();
      printData(title: 'Close Day Error:', data: e, e: true);
      showToast(message: 'An error occurred while closing the day');
      return false;
    }
  }

  Future<bool> openDay(int accountId, String day) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/open-day',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: {'day': day},
      );

      Loaders.hide();

      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Day opened successfully');
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to open day');
        return false;
      }
    } catch (e) {
      Loaders.hide();
      printData(title: 'Open Day Error:', data: e, e: true);
      showToast(message: 'An error occurred while opening the day');
      return false;
    }
  }

  Future<bool> claimEntry(int accountId, int entryId, String day) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/claims/$entryId',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      Loaders.hide();

      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Claimed successfully');
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to claim');
        return false;
      }
    } catch (e) {
      Loaders.hide();
      printData(title: 'Claim Error:', data: e, e: true);
      showToast(message: 'An error occurred while claiming');
      return false;
    }
  }

  Future<bool> unclaimEntry(int accountId, int entryId, String day) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/claims/$entryId',
        isDelete: true,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      Loaders.hide();
      printData(title: 'Undo Claim Response:', data: response);


      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Claim undone successfully');
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to undo claim');
        return false;
      }
    } catch (e) {
      Loaders.hide();
      printData(title: 'Undo Claim Error:', data: e, e: true);
      showToast(message: 'An error occurred while undoing claim');
      return false;
    }
  }

  Future<bool> claimEntriesBulk(int accountId, List<int> entryIds, String day) async {
    try {
      Loaders.show();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await ApiService().postDataToApi(
        api: 'accounts/$accountId/payments/claims/bulk',
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        payload: {
          'entry_ids': entryIds,
        },
      );

      Loaders.hide();

      if (response != null && response['success'] == true) {
        showToast(message: response['message'] ?? 'Bulk claims registered successfully');
        await getStaffPaymentCompensation(accountId, day: day);
        return true;
      } else {
        showToast(message: response?['message'] ?? 'Failed to register bulk claims');
        return false;
      }
    } catch (e) {
      Loaders.hide();
      printData(title: 'Bulk Claim Error:', data: e, e: true);
      showToast(message: 'An error occurred while bulk claiming');
      return false;
    }
  }
}
