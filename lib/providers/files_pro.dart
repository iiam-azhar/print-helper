import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/filefolder_models.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';

class FilesPro extends ChangeNotifier {
  bool filesLoad = false;

  final List<FolderModel> folders = [];
  final List<FileModel> files = [];

  String currentPath = 'files';
  String displayPath = '/';
  String homePath = 'files';
  String storageSummary = '';
  double usagePercent = 0;

  final Set<String> selected = {};

  bool get isSelecting => selected.isNotEmpty;

  void toggleSelect(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  bool _isSuccess(Map<String, dynamic> data) {
    if (data['success'] == true) return true;
    if (data['status'] == true && data['message'] == 'success') return true;
    return false;
  }

  Future<void> getFiles({required BuildContext ctx, String? path}) async {
    filesLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final query = <String, String>{};
      if (path != null && path.isNotEmpty) {
        query['path'] = path;
      }

      final uri = Uri.parse(ApiRoutes.files).replace(queryParameters: query);
      final data = await ApiService().getDataFromApi(
        api: uri.toString(),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        final payload = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : data;

        final f1 = payload['folders'] as List<dynamic>?;
        final f2 = payload['files'] as List<dynamic>?;

        folders.clear();
        files.clear();

        if (f1 != null) folders.addAll(foldersFromJson(f1));
        if (f2 != null) files.addAll(filesFromJson(f2));

        currentPath = (payload['current_path'] ?? path ?? 'files').toString();
        displayPath = (payload['display_path'] ?? '/').toString();
        homePath = (payload['home_path'] ?? 'files').toString();
        storageSummary =
            (payload['storage_summary'] ?? payload['storage_stats']?['summary'] ?? '')
                .toString();

        final rawPercent = payload['storage_stats']?['usage_percent'];
        usagePercent = rawPercent is num
            ? rawPercent.toDouble()
            : double.tryParse(rawPercent?.toString() ?? '0') ?? 0;
      }
    } catch (e, st) {
      printData(title: "Files Load Error", data: "$e\n$st", e: true);
    } finally {
      filesLoad = false;
      notifyListeners();
    }
  }
}
