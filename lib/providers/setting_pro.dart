import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';
import '../utils/console_util.dart';

class SettingsPro extends ChangeNotifier {
  bool loading = false;
  bool fileSettingsSaving = false;
  final List<SettingsSection> _sections = [];
  FileSettingsConfig _fileSettings = FileSettingsConfig.defaults();
  List<SettingsSection> get sections => _sections;
  FileSettingsConfig get fileSettings => _fileSettings;

  void _setLoading(bool v) {
    loading = v;
    notifyListeners();
  }

  Future<void> loadSettings({required BuildContext ctx}) async {
    _setLoading(true);
    try {
      await loadFileSettings();

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final url = Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.settings}");

      final res = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _hydrateFileSettings(data);
        _sections.clear();
        final list = data["sections"] ?? [];
        _sections.addAll(
          (list as List<dynamic>)
              .map((e) => SettingsSection.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      if (!_sections.any((s) => s.title.toLowerCase().contains("language"))) {
        _sections.add(
          SettingsSection(
            id: 999,
            title: "Languages",
            items: [],
            expanded: true,
          ),
        );
      }
      if (!_sections.any((s) => s.title.toLowerCase().contains("ranks"))) {
        _sections.add(
          SettingsSection(id: 700, title: "Ranks", items: [], expanded: true),
        );
      }
      if (!_sections.any((s) => s.title.toLowerCase().contains("account"))) {
        _sections.add(
          SettingsSection(
            id: 200,
            title: "Account Types",
            items: [],
            expanded: true,
          ),
        );
      }
      if (!_sections.any(
        (s) => s.title.toLowerCase().contains("customer ranks"),
      )) {
        _sections.add(
          SettingsSection(
            id: 400,
            title: "Customer Ranks",
            items: [],
            expanded: true,
          ),
        );
      }
      if (!_sections.any((s) => s.title.toLowerCase().contains("skills"))) {
        _sections.add(
          SettingsSection(id: 500, title: "Skills", items: [], expanded: true),
        );
      }
      if (!_sections.any(
        (s) => s.title.toLowerCase().contains("client company"),
      )) {
        _sections.add(
          SettingsSection(
            id: 600,
            title: "Client Company Types",
            items: [],
            expanded: true,
          ),
        );
      }
      if (!_sections.any(
        (s) => s.title.toLowerCase().contains("customer company"),
      )) {
        _sections.add(
          SettingsSection(
            id: 300,
            title: "Customer Company Types",
            items: [],
            expanded: true,
          ),
        );
      }
      await getLanguages();
      await getAccountTypes();
      await getCustomerCompanyTypes();
      await getCustomerRanks();
      await getSkills();
      await getClientCompanyTypes();
      await getRanks();
    } catch (e, st) {
      printData(title: "LOAD SETTINGS ERROR:", data: "$e\n$st", e: true);
      showToast(message: "Failed to load settings");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}languages"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "LANGUAGE LIST:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("language"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      } else {
        printData(title: "LANG GET non-200:", data: res.statusCode, e: true);
      }
    } catch (e) {
      printData(title: "GET LANG ERROR:", data: e, e: true);
    }
  }

  Future<void> getAccountTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}account-types"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "ACCOUNT TYPES LIST:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("account"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      } else {
        printData(title: "ACCTYPE GET non-200:", data: res.statusCode, e: true);
      }
    } catch (e) {
      printData(title: "GET ACCTYPES ERROR:", data: e, e: true);
    }
  }

  Future<void> getCustomerCompanyTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}customer-company-types"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "CUSTOMER COMPANY TYPES:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("customer company"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      printData(title: "GET CUSTOMER COMPANY TYPES ERROR:", data: e, e: true);
    }
  }

  Future<void> getCustomerRanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}customer-ranks"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "CUSTOMER RANKS:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("customer ranks"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e as Map<String, dynamic>))
              .toList();

          notifyListeners();
        }
      }
    } catch (e) {
      printData(title: "GET CUSTOMER RANKS ERROR:", data: e, e: true);
    }
  }

  Future<void> getSkills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}skills"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "SKILLS LIST:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("skills"),
        );

        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e))
              .toList();

          notifyListeners();
        }
      }
    } catch (e) {
      printData(title: "GET SKILLS ERROR:", data: e, e: true);
    }
  }

  Future<void> getClientCompanyTypes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}client-company-types"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "CLIENT COMPANY TYPES:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("client company"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      printData(title: "GET CLIENT COMPANY TYPES ERROR:", data: e, e: true);
    }
  }

  Future<void> getRanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await http.get(
        Uri.parse("${ApiRoutes.baseUrl}ranks"),
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "RANKS LIST:", data: res.body);
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final idx = _sections.indexWhere(
          (s) => s.title.toLowerCase().contains("ranks"),
        );
        if (idx != -1) {
          _sections[idx].items = list
              .map((e) => SettingsItem.fromJson(e))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      printData(title: "GET RANKS ERROR:", data: e, e: true);
    }
  }

  Future<void> createRank({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "ranks",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      printData(title: "CREATE RANK RESPONSE:", data: response);
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(SettingsItem.fromJson(response));
          notifyListeners();
        }
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE RANK ERROR:", data: e, e: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createCustomerCompanyType({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "customer-company-types",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(SettingsItem.fromJson(response));
          notifyListeners();
        }
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE CUSTOMER COMPANY TYPE ERROR:", data: e, e: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createLanguage({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: ApiRoutes.language,
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      printData(title: "CREATE LANGUAGE RESPONSE:", data: response);
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(
            SettingsItem.fromJson(response as Map<String, dynamic>),
          );
          notifyListeners();
        }
      } else if (response != null &&
          response is Map &&
          response['errors'] != null) {
        final msg =
            (response['errors']['name'] as List<dynamic>?)?.first ??
            'Validation error';
        showToast(message: msg.toString());
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE LANGUAGE ERROR:", data: e, e: true);
      showToast(message: "Create failed");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createAccountType({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "account-types",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      printData(title: "CREATE ACCTYPE RESPONSE:", data: response);
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(
            SettingsItem.fromJson(response as Map<String, dynamic>),
          );
          notifyListeners();
        }
      } else if (response != null &&
          response is Map &&
          response['errors'] != null) {
        final msg =
            (response['errors']['name'] as List<dynamic>?)?.first ??
            'Validation error';
        showToast(message: msg.toString());
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE ACCTYPE ERROR:", data: e, e: true);
      showToast(message: "Create failed");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createCustomerRank({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "customer-ranks",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(SettingsItem.fromJson(response));
          notifyListeners();
        }
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE CUSTOMER RANK ERROR:", data: e, e: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createClientCompanyType({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "client-company-types",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      printData(title: "CREATE CLIENT COMPANY TYPE RESPONSE:", data: response);
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(SettingsItem.fromJson(response));
          notifyListeners();
        }
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE CLIENT COMPANY TYPE ERROR:", data: e, e: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createSkill({
    required int sectionId,
    required String name,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final response = await ApiService().postDataToApi(
        api: "skills",
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": name},
      );
      printData(title: "CREATE SKILL RESPONSE:", data: response);
      if (response != null && response['id'] != null) {
        final idx = _sections.indexWhere((s) => s.id == sectionId);
        if (idx != -1) {
          final removed = _sections[idx].items.indexWhere((i) => i.id == 0);
          if (removed != -1) _sections[idx].items.removeAt(removed);
          _sections[idx].items.add(SettingsItem.fromJson(response));
          notifyListeners();
        }
      } else {
        showToast(message: "Create failed");
      }
    } catch (e) {
      printData(title: "CREATE SKILL ERROR:", data: e, e: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateItem({
    required int sectionId,
    required int id,
    required String newName,
  }) async {
    _setLoading(true);
    try {
      final sIdx = _sections.indexWhere((s) => s.id == sectionId);
      if (sIdx == -1) return;
      final section = _sections[sIdx];
      final endpoint = section.title.toLowerCase().contains("account")
          ? ApiRoutes.accountType
          : section.title.toLowerCase().contains("customer company")
          ? ApiRoutes.custCmpnyType
          : section.title.toLowerCase().contains("customer ranks")
          ? ApiRoutes.custRank
          : section.title.toLowerCase().contains("skills")
          ? ApiRoutes.skill
          : section.title.toLowerCase().contains("client company")
          ? ApiRoutes.clientCmpnyType
          : section.title.toLowerCase().contains("ranks")
          ? ApiRoutes.rank
          : ApiRoutes.language;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final res = await ApiService().postDataToApi(
        api: "$endpoint/$id",
        isPut: true,
        headers: {"Authorization": "Bearer $token"},
        payload: {"name": newName},
      );
      printData(title: "UPDATE RESPONSE:", data: res);
      if (res != null && res is Map && res['errors'] != null) {
        final msg =
            (res['errors']['name'] as List<dynamic>?)?.first ??
            'Validation error';
        showToast(message: msg.toString());
        return;
      }
      final itIdx = _sections[sIdx].items.indexWhere((i) => i.id == id);
      if (itIdx != -1) {
        _sections[sIdx].items[itIdx].name = newName;
        notifyListeners();
      }
    } catch (e) {
      printData(title: "UPDATE ITEM ERROR:", data: e, e: true);
      showToast(message: "Update failed");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteItem(int sectionId, int itemId) async {
    _setLoading(true);
    try {
      final sIdx = _sections.indexWhere((s) => s.id == sectionId);
      if (sIdx == -1) return;
      final section = _sections[sIdx];
      if (itemId == 0) {
        _sections[sIdx].items.removeWhere((i) => i.id == 0);
        notifyListeners();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final endpoint = section.title.toLowerCase().contains("account")
          ? ApiRoutes.accountType
          : section.title.toLowerCase().contains("customer company")
          ? ApiRoutes.custCmpnyType
          : section.title.toLowerCase().contains("customer ranks")
          ? ApiRoutes.custRank
          : section.title.toLowerCase().contains("skills")
          ? ApiRoutes.skill
          : section.title.toLowerCase().contains("client company")
          ? ApiRoutes.clientCmpnyType
          : section.title.toLowerCase().contains("ranks")
          ? ApiRoutes.rank
          : ApiRoutes.language;

      final url = Uri.parse("${ApiRoutes.baseUrl}$endpoint/$itemId");
      final res = await http.delete(
        url,
        headers: {"Authorization": "Bearer $token"},
      );
      printData(title: "DELETE ($itemId) STATUS:", data: res.statusCode);
      if (res.statusCode == 204 || res.statusCode == 200) {
        _sections[sIdx].items.removeWhere((i) => i.id == itemId);
        notifyListeners();
      } else {
        printData(title: "DELETE failed body:", data: res.body, e: true);
        showToast(message: "Delete failed");
      }
    } catch (e) {
      printData(title: "DELETE ERROR:", data: e, e: true);
      showToast(message: "Delete failed");
    } finally {
      _setLoading(false);
    }
  }

  void toggleSection(int sectionId) {
    final idx = _sections.indexWhere((s) => s.id == sectionId);
    if (idx != -1) {
      _sections[idx].expanded = !_sections[idx].expanded;
      notifyListeners();
    }
  }

  void addItem(int sectionId) {
    final idx = _sections.indexWhere((s) => s.id == sectionId);
    if (idx == -1) return;
    final newItem = SettingsItem(id: 0, name: "", createdAt: "", updatedAt: "");
    _sections[idx].items.add(newItem);
  }

  void updateItemName(int sectionId, int itemId, String name) {
    final sIdx = _sections.indexWhere((s) => s.id == sectionId);
    if (sIdx == -1) return;
    final itIdx = _sections[sIdx].items.indexWhere((i) => i.id == itemId);
    if (itIdx == -1) return;
    _sections[sIdx].items[itIdx].name = name;
    notifyListeners();
  }

  void updateFileSettingsLocal(FileSettingsConfig config) {
    _fileSettings = config;
    notifyListeners();
  }

  Future<bool> saveFileSettings() async {
    fileSettingsSaving = true;
    notifyListeners();
    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final url = Uri.parse(
        "${ApiRoutes.baseUrl}${ApiRoutes.fileSettingsStore}",
      );

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json';

      // max_upload_size_mb
      request.fields['max_upload_size_mb'] = _fileSettings.maxUploadSizeMb
          .toString();

      // storage_limit_mb[roleId]
      _fileSettings.storageLimitsMb.forEach((roleId, limit) {
        request.fields['storage_limit_mb[$roleId]'] = limit.toString();
      });

      // allowed_extensions — JSON array of {"extension":"jpg"} objects
      final extList = _fileSettings.allowedExtensions
          .map((e) => {'extension': e.extension})
          .toList();
      request.fields['allowed_extensions'] = jsonEncode(extList);

      // icons[ext] — file parts for newly picked SVG files
      for (final ext in _fileSettings.allowedExtensions) {
        if (ext.localFilePath != null && ext.localFilePath!.isNotEmpty) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'icons[${ext.extension}]',
              ext.localFilePath!,
            ),
          );
        }
      }

      printData(title: "SAVE FILE SETTINGS URL:", data: url.toString());
      printData(title: "SAVE FILE SETTINGS fields:", data: request.fields);
      printData(
        title: "SAVE FILE SETTINGS files:",
        data: request.files.map((f) => f.field).toList(),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      printData(
        title: "SAVE FILE SETTINGS response [${response.statusCode}]:",
        data: response.body,
      );

      final ok = response.statusCode == 200 || response.statusCode == 201;
      if (ok) {
        _hydrateFileSettings(jsonDecode(response.body));
        showToast(message: "File settings saved successfully");
        return true;
      }

      printData(
        title: "SAVE FILE SETTINGS failed:",
        data: "${response.statusCode} ${response.body}",
        e: true,
      );
      showToast(message: "Failed to save file settings");
      return false;
    } catch (e, st) {
      printData(title: "SAVE FILE SETTINGS ERROR:", data: "$e\n$st", e: true);
      showToast(message: "Failed to save file settings");
      return false;
    } finally {
      Loaders.hide();
      fileSettingsSaving = false;
      notifyListeners();
    }
  }

  void _hydrateFileSettings(dynamic root) {
    Map<String, dynamic>? source;
    if (root is Map<String, dynamic>) {
      final dynamic dataNode = root['data'];
      final dynamic fileSettings =
          root['file_settings'] ??
          root['fileSettings'] ??
          (dataNode is Map<String, dynamic>
              ? dataNode['file_settings'] ?? dataNode['fileSettings']
              : null);

      if (fileSettings is Map<String, dynamic>) {
        source = fileSettings;
      } else {
        final hasFlatFields =
            root.containsKey('max_upload_size') ||
            root.containsKey('max_upload_size_mb') ||
            root.containsKey('storage_limit_mb') ||
            root.containsKey('storage_limits') ||
            root.containsKey('allowed_extensions');
        if (hasFlatFields) {
          source = root;
        }
      }

      if (source == null && dataNode is Map<String, dynamic>) {
        final hasFlatFieldsInData =
            dataNode.containsKey('max_upload_size') ||
            dataNode.containsKey('max_upload_size_mb') ||
            dataNode.containsKey('storage_limit_mb') ||
            dataNode.containsKey('storage_limits') ||
            dataNode.containsKey('allowed_extensions');
        if (hasFlatFieldsInData) {
          source = dataNode;
        }
      }
    }

    if (source == null) {
      _fileSettings = FileSettingsConfig.defaults();
      return;
    }

    _fileSettings = FileSettingsConfig.fromJson(source);
  }

  Future<void> loadFileSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";
      final url = Uri.parse("${ApiRoutes.baseUrl}${ApiRoutes.fileSettings}");

      final res = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (res.statusCode == 200) {
        _hydrateFileSettings(jsonDecode(res.body));
      } else {
        printData(
          title: "FILE SETTINGS GET non-200:",
          data: "${res.statusCode} ${res.body}",
          e: true,
        );
      }
    } catch (e, st) {
      printData(title: "LOAD FILE SETTINGS ERROR:", data: "$e\n$st", e: true);
    }
  }
}
