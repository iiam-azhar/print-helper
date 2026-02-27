import 'package:flutter/material.dart';

import '../dummy_json.dart';
import '../models/projects_models.dart';
import '../services/helpers.dart';
import '../utils/console_util.dart';

class ProjectPro extends ChangeNotifier {
  bool projectLoad = false;

  final List<ProjectModel> _projects = [];
  List<ProjectModel> get projects => _projects;

  bool _isSuccess(Map<String, dynamic> data) =>
      data['status'] == true && data['message'] == 'success';

  Future<void> getProjects({required BuildContext ctx}) async {
    projectLoad = true;
    notifyListeners();
    try {
      await delayed(millisec: 1000);
      final data = projectsJson;
      if (_isSuccess(data)) {
        printData(title: '0000', data: '');
        final result = data['projects'] as List<dynamic>?;
        printData(title: '111111', data: '');
        if (result != null) {
          printData(title: '2222', data: '');
          _projects.clear();
          _projects.addAll(projectsFromJson(result));
          printData(title: '3333', data: '');
          printData(title: 'Project ID:', data: _projects.first.id);
        }
      }
      printData(title: '4444', data: '');
    } catch (e, st) {
      printData(title: "Project Load Error", data: "$e\n$st", e: true);
    } finally {
      projectLoad = false;
      notifyListeners();
    }
  }
}
