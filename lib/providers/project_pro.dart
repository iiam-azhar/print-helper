import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/projects_models.dart';
import '../models/client_option.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';
import '../widgets/toasts.dart';

class ProjectPro extends ChangeNotifier {
  bool projectLoad = false;
  bool projectDetailLoad = false;
  bool projectLabelsLoad = false;
  int currentPage = 1;
  int lastPage = 1;
  int perPage = 16;
  int totalCount = 0;

  final List<ProjectModel> _projects = [];
  final List<ProjectTaskModel> _tasks = [];
  final List<ProjectLabelModel> _projectLabels = [];
  final List<ProjectTaskTemplateModel> _taskTemplates = [];
  final List<ProjectTaskTemplateModel> _projectBlueprints = [];
  final List<Map<String, String>> _projectFilterProjectAssigneeOptions = [
    {'value': '', 'label': 'Select'},
  ];
  final List<Map<String, String>> _projectFilterTaskAssigneeOptions = [
    {'value': '', 'label': 'Select'},
  ];
  final List<Map<String, String>> _projectFilterProjectTaskAssigneeOptions = [
    {'value': '', 'label': 'Select'},
  ];
  final List<Map<String, String>> _projectSectionFilterOptions = [
    {'value': '', 'label': 'Select'},
  ];
  final List<Map<String, String>> _projectClientOptions = [];
  final List<Map<String, String>> _projectCustomerOptions = [
    {'id': '', 'client_id': '', 'label': 'Select'},
  ];
  final Map<String, String> _activeProjectFilters = {};
  final Map<String, String> _activeTaskFilters = {};
  
  // Paginated client fetch state
  final List<ClientOption> paginatedClientOptions = [];
  bool isFetchingPaginatedClients = false;
  bool isFetchingMorePaginatedClients = false;
  int paginatedClientsCurrentPage = 1;
  int paginatedClientsLastPage = 1;
  bool paginatedClientsHasMore = true;

  bool projectFilterProjectAssigneesLoad = false;
  bool projectFilterTaskAssigneesLoad = false;
  bool projectFilterProjectTaskAssigneesLoad = false;
  bool projectSectionFilterOptionsLoad = false;
  bool projectClientOptionsLoad = false;
  bool projectCustomerOptionsLoad = false;
  bool _hasLoadedProjectFilterProjectAssignees = false;
  bool _hasLoadedProjectFilterTaskAssignees = false;
  int? _loadedProjectTaskAssigneesForProjectId;
  bool _hasLoadedProjectSectionFilterOptions = false;
  bool _hasLoadedProjectClientOptions = false;
  bool _hasLoadedProjectCustomerOptions = false;
  final Map<int, ProjectDetailModel> _projectDetailsCache = {};
  List<ProjectModel> get projects => _projects;
  List<ProjectTaskModel> get tasks => _tasks;
  List<ProjectLabelModel> get projectLabels => _projectLabels;
  List<ProjectTaskTemplateModel> get taskTemplates => _taskTemplates;
  List<ProjectTaskTemplateModel> get projectBlueprints => _projectBlueprints;
  List<Map<String, String>> get projectFilterProjectAssigneeOptions =>
      List<Map<String, String>>.from(_projectFilterProjectAssigneeOptions);
  List<Map<String, String>> get projectFilterTaskAssigneeOptions =>
      List<Map<String, String>>.from(_projectFilterTaskAssigneeOptions);
  List<Map<String, String>> get projectFilterProjectTaskAssigneeOptions =>
      List<Map<String, String>>.from(_projectFilterProjectTaskAssigneeOptions);
  List<Map<String, String>> get projectSectionFilterOptions =>
      List<Map<String, String>>.from(_projectSectionFilterOptions);
  List<Map<String, String>> get projectClientOptions =>
      List<Map<String, String>>.from(_projectClientOptions);
  List<Map<String, String>> get projectCustomerOptions =>
      List<Map<String, String>>.from(_projectCustomerOptions);
  Map<String, String> get activeProjectFilters =>
      Map<String, String>.from(_activeProjectFilters);
  Map<String, String> get activeTaskFilters =>
      Map<String, String>.from(_activeTaskFilters);
  int get appliedProjectFilterCount {
    const ignoredKeys = {'status', 'per_page', 'page'};
    var count = 0;
    _activeProjectFilters.forEach((key, value) {
      if (ignoredKeys.contains(key)) return;
      if (value.trim().isEmpty) return;
      count++;
    });
    return count;
  }

  int get appliedTaskFilterCount {
    const ignoredKeys = {'per_page', 'page'};
    var count = 0;
    _activeTaskFilters.forEach((key, value) {
      if (ignoredKeys.contains(key)) return;
      if (value.trim().isEmpty) return;
      count++;
    });
    return count;
  }

  ProjectDetailModel? _activeProjectDetail;
  ProjectDetailModel? get activeProjectDetail => _activeProjectDetail;

  bool _isSuccess(Map<String, dynamic> data) =>
      data['success'] == true || data['status'] == true;

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Map<String, String> _sanitizeFilterMap(Map<String, String> input) {
    final sanitized = <String, String>{};
    for (final entry in input.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      sanitized[key] = value;
    }
    return sanitized;
  }

  Future<void> _refreshProjectDetailSilently(int projectId) async {
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectDetails(projectId),
        headers: await _headers(),
        showRes: false,
      );

      if (!_isSuccess(data)) return;

      final detail = ProjectDetailModel.fromJson(
        Map<String, dynamic>.from(data),
      );
      _projectDetailsCache[projectId] = detail;
      if (_activeProjectDetail?.project.numericId == projectId) {
        _activeProjectDetail = detail;
      }
    } catch (_) {
      // Best effort sync only; no toast needed.
    }
  }

  void _applyProjectsResponse(Map<String, dynamic> data) {
    final result = (data['data'] ?? data['projects']) as List<dynamic>?;
    final meta = data['meta'] as Map<String, dynamic>?;

    if (result != null) {
      _projects
        ..clear()
        ..addAll(projectsFromJson(result));
    }

    currentPage = _toInt(meta?['current_page'], fallback: 1);
    if (currentPage < 1) currentPage = 1;
    lastPage = _toInt(meta?['last_page'], fallback: 1);
    if (lastPage < 1) lastPage = 1;
    perPage = _toInt(meta?['per_page'], fallback: 16);
    if (perPage < 1) perPage = 16;
    totalCount = _toInt(meta?['total'], fallback: _projects.length);
  }

  Future<void> getProjects({
    required BuildContext ctx,
    int page = 1,
    Map<String, String>? filters,
    bool clearFilters = false,
  }) async {
    if (clearFilters) {
      _activeProjectFilters.clear();
    }

    if (filters != null) {
      _activeProjectFilters
        ..clear()
        ..addAll(_sanitizeFilterMap(filters));
    }

    projectLoad = true;
    notifyListeners();
    try {
      final query = <String, String>{
        'page': page.toString(),
        ..._activeProjectFilters,
      };
      final queryString = Uri(queryParameters: query).query;
      final apiPath = queryString.isEmpty
          ? ApiRoutes.projects
          : '${ApiRoutes.projects}?$queryString';

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        _applyProjectsResponse(Map<String, dynamic>.from(data));
      } else {
        showToast(
          message: data['message']?.toString() ?? 'Unable to load projects',
        );
      }
    } catch (e, st) {
      printData(title: "Project Load Error", data: "$e\n$st", e: true);
      showToast(message: 'Unable to load projects');
    } finally {
      projectLoad = false;
      notifyListeners();
    }
  }

  Future<void> getTasksList({
    required BuildContext ctx,
    int page = 1,
    Map<String, String>? filters,
    bool clearFilters = false,
  }) async {
    if (clearFilters) {
      _activeTaskFilters.clear();
    }

    if (filters != null) {
      _activeTaskFilters
        ..clear()
        ..addAll(_sanitizeFilterMap(filters));
    }

    projectLoad = true;
    notifyListeners();
    try {
      final query = <String, String>{
        'page': page.toString(),
        ..._activeTaskFilters,
      };
      final queryString = Uri(queryParameters: query).query;
      final apiPath = queryString.isEmpty
          ? ApiRoutes.projectTasks
          : '${ApiRoutes.projectTasks}?$queryString';

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final payload = Map<String, dynamic>.from(data['data'] ?? {});
        final result = payload['tasks'] as List<dynamic>?;
        final meta = payload['meta'] as Map<String, dynamic>?;

        if (result != null) {
          _tasks
            ..clear()
            ..addAll(taskModelsFromJson(result));
        }

        currentPage = _toInt(meta?['current_page'], fallback: 1);
        if (currentPage < 1) currentPage = 1;
        lastPage = _toInt(meta?['last_page'], fallback: 1);
        if (lastPage < 1) lastPage = 1;
        perPage = _toInt(meta?['per_page'], fallback: 20);
        if (perPage < 1) perPage = 20;
        totalCount = _toInt(meta?['total'], fallback: _tasks.length);
      } else {
        showToast(
          message: data['message']?.toString() ?? 'Unable to load tasks',
        );
      }
    } catch (e, st) {
      printData(title: 'Task List Load Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to load tasks');
    } finally {
      projectLoad = false;
      notifyListeners();
    }
  }

  void optimisticTaskMove({
    required int taskId,
    required int newSectionId,
    required String newSectionName,
  }) {
    // 1. Update global list
    final gIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (gIdx != -1) {
      _tasks[gIdx] = _tasks[gIdx].copyWith(
        projectSectionId: newSectionId,
        sectionName: newSectionName,
        status: newSectionName,
      );
    }

    // 2. Update active project & cache
    if (_activeProjectDetail != null) {
      final idx = _activeProjectDetail!.tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final newTasks = List<ProjectTaskModel>.from(
          _activeProjectDetail!.tasks,
        );
        newTasks[idx] = newTasks[idx].copyWith(
          projectSectionId: newSectionId,
          sectionName: newSectionName,
          status: newSectionName,
        );
        _activeProjectDetail = _activeProjectDetail!.copyWith(tasks: newTasks);
        _projectDetailsCache[_activeProjectDetail!.project.numericId] =
            _activeProjectDetail!;
      }
    }

    notifyListeners();
  }

  void optimisticUpdateTask({
    required int taskId,
    required ProjectTaskModel updatedTask,
  }) {
    // 1. Update global list
    final gIdx = _tasks.indexWhere((t) => t.id == taskId);
    if (gIdx != -1) {
      _tasks[gIdx] = updatedTask;
    }

    // 2. Update active project & cache
    if (_activeProjectDetail != null) {
      final idx = _activeProjectDetail!.tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        final newTasks = List<ProjectTaskModel>.from(
          _activeProjectDetail!.tasks,
        );
        newTasks[idx] = updatedTask;
        _activeProjectDetail = _activeProjectDetail!.copyWith(tasks: newTasks);
        _projectDetailsCache[_activeProjectDetail!.project.numericId] =
            _activeProjectDetail!;
      }
    }

    notifyListeners();
  }

  Future<void> getProjectBlueprintLibrary() async {
    projectLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectBlueprintLibrary,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final result = data['data'] as List<dynamic>?;
        if (result != null) {
          _projectBlueprints
            ..clear()
            ..addAll(taskTemplatesFromJson(result));
        }
      } else {
        showToast(
          message: data['message']?.toString() ?? 'Unable to load blueprints',
        );
      }
    } catch (e, st) {
      printData(title: 'Blueprints Load Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to load blueprints');
    } finally {
      projectLoad = false;
      notifyListeners();
    }
  }

  Future<void> getProjectLabels({required BuildContext ctx}) async {
    projectLabelsLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectLabels,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final result = data['data'] as List<dynamic>?;
        if (result != null) {
          _projectLabels
            ..clear()
            ..addAll(projectLabelModelsFromJson(result));
        }
      } else {
        showToast(
          message: data['message']?.toString() ?? 'Unable to load labels',
        );
      }
    } catch (e, st) {
      printData(title: 'Project Labels Load Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to load labels');
    } finally {
      projectLabelsLoad = false;
      notifyListeners();
    }
  }

  Future<ProjectLabelModel?> createProjectLabel({
    required String name,
    required String colorHex,
  }) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.projectLabels,
        headers: await _headers(),
        payload: {'name': name, 'color': colorHex},
        showRes: false,
      );

      if (_isSuccess(data)) {
        final labelJson = data['data'] as Map<String, dynamic>?;
        if (labelJson == null) {
          showToast(message: 'Unable to create label');
          return null;
        }

        final createdLabel = ProjectLabelModel.fromJson(labelJson);
        final existingIndex = _projectLabels.indexWhere(
          (item) => item.id == createdLabel.id,
        );

        if (existingIndex >= 0) {
          _projectLabels[existingIndex] = createdLabel;
        } else {
          _projectLabels.add(createdLabel);
        }

        notifyListeners();
        showToast(
          message: data['message']?.toString() ?? 'Label created successfully',
        );
        return createdLabel;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to create label',
      );
    } catch (e, st) {
      printData(title: 'Create Label Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to create label');
    }

    return null;
  }

  Future<ProjectSectionModel?> createProjectSection({
    required String name,
  }) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.projectSections,
        headers: await _headers(),
        payload: {'name': name},
        showRes: false,
      );

      if (_isSuccess(data)) {
        final sectionJson = data['data'] as Map<String, dynamic>?;
        if (sectionJson == null) {
          showToast(message: 'Unable to create status');
          return null;
        }

        final created = ProjectSectionModel.fromJson(sectionJson);

        // Append to the active detail's sections list
        if (_activeProjectDetail != null) {
          final updatedSections = [..._activeProjectDetail!.sections, created];

          ProjectTaskCreateContext? updatedContext =
              _activeProjectDetail!.taskCreateContext;
          if (updatedContext != null) {
            updatedContext = updatedContext.copyWith(
              sectionOptions: [...updatedContext.sectionOptions, created],
            );
          }

          _activeProjectDetail = _activeProjectDetail!.copyWith(
            sections: updatedSections,
            taskCreateContext: updatedContext,
          );
          // Keep cache in sync
          final pId = _activeProjectDetail!.project.numericId;
          _projectDetailsCache[pId] = _activeProjectDetail!;

          // Update filter options cache if it was already loaded
          if (_hasLoadedProjectSectionFilterOptions) {
            _projectSectionFilterOptions.add({
              'value': created.name,
              'label': created.name,
            });
          }
        }

        notifyListeners();
        showToast(
          message: data['message']?.toString() ?? 'Status created successfully',
        );
        return created;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to create status',
      );
    } catch (e, st) {
      printData(title: 'Create Section Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to create status');
    }

    return null;
  }

  Future<ProjectSectionModel?> updateProjectSection({
    required int sectionId,
    required String name,
  }) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.updateProjectSection(sectionId),
        headers: await _headers(),
        payload: {'name': name},
        showRes: false,
      );

      if (_isSuccess(data)) {
        final sectionJson = data['data'] as Map<String, dynamic>?;
        if (sectionJson == null) {
          showToast(message: 'Unable to update status');
          return null;
        }

        final updated = ProjectSectionModel.fromJson(sectionJson);

        // Update in active detail
        if (_activeProjectDetail != null) {
          final sections = List<ProjectSectionModel>.from(
            _activeProjectDetail!.sections,
          );
          final idx = sections.indexWhere((s) => s.id == sectionId);
          if (idx != -1) {
            sections[idx] = updated;

            ProjectTaskCreateContext? updatedContext =
                _activeProjectDetail!.taskCreateContext;
            if (updatedContext != null) {
              final contextSections = List<ProjectSectionModel>.from(
                updatedContext.sectionOptions,
              );
              final cIdx = contextSections.indexWhere((s) => s.id == sectionId);
              if (cIdx != -1) {
                contextSections[cIdx] = updated;
                updatedContext = updatedContext.copyWith(
                  sectionOptions: contextSections,
                );
              }
            }

            _activeProjectDetail = _activeProjectDetail!.copyWith(
              sections: sections,
              taskCreateContext: updatedContext,
            );
            _projectDetailsCache[_activeProjectDetail!.project.numericId] =
                _activeProjectDetail!;
          }
        }

        notifyListeners();
        showToast(message: 'Status updated successfully');
        return updated;
      }
    } catch (e, st) {
      printData(title: 'Update Section Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to update status');
    }
    return null;
  }

  Future<bool> deleteProjectLabel({required int labelId}) async {
    try {
      final data = await ApiService().postDataToApi(
        api: '${ApiRoutes.projectLabels}/$labelId',
        headers: await _headers(),
        isDelete: true,
        showRes: false,
      );

      if (_isSuccess(data)) {
        _projectLabels.removeWhere((item) => item.id == labelId);
        notifyListeners();
        showToast(
          message: data['message']?.toString() ?? 'Label deleted successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to delete label',
      );
    } catch (e, st) {
      printData(title: 'Delete Label Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to delete label');
    }

    return false;
  }

  Future<ProjectDetailModel?> getProjectDetail({
    required BuildContext ctx,
    required int projectId,
    bool forceRefresh = false,
    bool isSilent = false,
    Map<String, String>? filters,
  }) async {
    final hasFilters = filters != null && filters.isNotEmpty;

    if (!forceRefresh &&
        !hasFilters &&
        _projectDetailsCache.containsKey(projectId)) {
      _activeProjectDetail = _projectDetailsCache[projectId];
      notifyListeners();
      return _activeProjectDetail;
    }

    if (!isSilent) {
      projectDetailLoad = true;
      notifyListeners();
    }
    try {
      String apiPath = ApiRoutes.projectDetails(projectId);
      if (hasFilters) {
        final query = Uri(queryParameters: _sanitizeFilterMap(filters)).query;
        if (query.isNotEmpty) {
          apiPath = '$apiPath?$query';
        }
      }

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: true,
      );

      printData(title: 'Project Detail Response', data: data);

      if (_isSuccess(data)) {
        final detail = ProjectDetailModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        printData(
          title: 'Project Detail Parsed',
          data:
              'projectId=${detail.project.numericId}, tasks=${detail.tasks.length}, sections=${detail.sections.length}',
        );
        if (!hasFilters) {
          _projectDetailsCache[projectId] = detail;
        }
        _activeProjectDetail = detail;
        return detail;
      }

      showToast(
        message:
            data['message']?.toString() ?? 'Unable to load project details',
      );
    } catch (e, st) {
      printData(title: 'Project Detail Error', data: '$e\n$st', e: true);
      _activeProjectDetail = null;
      showToast(message: 'Unable to load project details');
    } finally {
      projectDetailLoad = false;
      notifyListeners();
    }

    return null;
  }

  Future<bool> deleteProject({required int projectId}) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.deleteProject(projectId),
        headers: await _headers(),
        isDelete: true,
        showRes: true,
      );

      if (_isSuccess(data)) {
        _projects.removeWhere((item) => item.numericId == projectId);
        _projectDetailsCache.remove(projectId);
        if (_activeProjectDetail?.project.numericId == projectId) {
          _activeProjectDetail = null;
        }
        notifyListeners();
        showToast(
          message:
              data['message']?.toString() ?? 'Project deleted successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to delete project',
      );
    } catch (e, st) {
      printData(title: 'Delete Project Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to delete project');
    }
    return false;
  }

  Future<bool> updateProjectTask({
    required int projectId,
    required int taskId,
    required Map<String, dynamic> payload,
    List<String> filePaths = const [],
    List<String> fileNames = const [],
    List<String> fileKeys = const [],
    ProjectTaskModel? fallbackTask,
  }) async {
    // Merge existing title/description if missing to satisfy server requirements (422 fixes)
    ProjectTaskModel? existing;
    try {
      existing = _activeProjectDetail?.tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      try {
        existing = _tasks.firstWhere((t) => t.id == taskId);
      } catch (_) {}
    }

    if (existing == null) {
      for (final cache in _projectDetailsCache.values) {
        try {
          existing = cache.tasks.firstWhere((t) => t.id == taskId);
          break;
        } catch (_) {}
      }
    }

    if (existing == null) {
      existing = fallbackTask;
    }

    if (existing != null) {
      if (!payload.containsKey('title')) payload['title'] = existing.title;
      if (!payload.containsKey('description')) {
        payload['description'] = existing.description;
      }
      if (!payload.containsKey('due_date') &&
          existing.dueDate.trim().isNotEmpty) {
        payload['due_date'] = existing.dueDate;
      }
      if (!payload.containsKey('assigned_members')) {
        payload['assigned_members'] =
            existing.members.map((m) => m.id).toList();
      }
      if (!payload.containsKey('label_ids')) {
        payload['label_ids'] = existing.labels.map((l) => l.id).toList();
      }
      if (!payload.containsKey('project_section_id') &&
          existing.projectSectionId > 0) {
        payload['project_section_id'] = existing.projectSectionId;
      }
    }

    // Debug logging to find the correct URL from context
    final ctxApi = _activeProjectDetail?.taskCreateContext?.api;
    if (ctxApi != null) {
      printData(
        title: 'Task context API DEBUG',
        data:
            'tasksUpdate: ${ctxApi.tasksUpdate}, tasksUpdatePost: ${ctxApi.tasksUpdatePost}',
      );
    }

    // Determine the base API path
    String apiPath = ApiRoutes.updateProjectTask(projectId, taskId);
    if (ctxApi != null && ctxApi.tasksUpdatePost.isNotEmpty) {
      // If the server provides a full URL, we extract the path portion or use it intelligently
      final fullUrl = ctxApi.tasksUpdatePost.replaceAll(
        '{taskId}',
        taskId.toString(),
      );
      if (fullUrl.contains('/api/')) {
        apiPath = fullUrl.split('/api/').last;
      }
    }

    printData(
      title: 'Update Task Payload (Body)',
      data: payload,
    );

    try {
      final data = await ApiService().postDataToApi(
        api: apiPath,
        headers: await _headers(),
        payload: payload,
        filePaths: filePaths,
        fileNames: fileNames,
        fileKeys: fileKeys,
        multipart: filePaths.isNotEmpty,
        showRes: true,
      );

      if (_isSuccess(data)) {
        List<ProjectTaskMember>? patchedMembers;
        if (payload.containsKey('assigned_members')) {
          final rawIds = payload['assigned_members'];
          if (rawIds is List) {
            final ids = rawIds.map(_toInt).where((id) => id > 0).toSet();
            final options =
                _activeProjectDetail?.taskCreateContext?.memberOptions ??
                const <ProjectTaskMember>[];
            final allMembersSource = <int, ProjectTaskMember>{};
            for (final m in options) {
              allMembersSource[m.id] = m;
            }
            if (existing != null) {
              for (final m in existing.members) {
                allMembersSource[m.id] = m;
              }
            }
            patchedMembers = ids
                .where((id) => allMembersSource.containsKey(id))
                .map((id) => allMembersSource[id]!)
                .toList();
          }
        }

        List<ProjectTaskLabel>? patchedLabels;
        if (payload.containsKey('label_ids')) {
          final rawIds = payload['label_ids'];
          if (rawIds is List) {
            final ids = rawIds.map(_toInt).where((id) => id > 0).toSet();
            final allLabelsSource = <int, ProjectTaskLabel>{};
            for (final l in _projectLabels) {
              allLabelsSource[l.id] = ProjectTaskLabel(id: l.id, name: l.name, color: l.color);
            }
            if (existing != null) {
              for (final l in existing.labels) {
                allLabelsSource[l.id] = l;
              }
            }
            patchedLabels = ids
                .where((id) => allLabelsSource.containsKey(id))
                .map((id) => allLabelsSource[id]!)
                .toList();
          }
        }

        String? patchedSectionName;
        int? patchedSectionId;
        if (payload.containsKey('project_section_id')) {
          patchedSectionId = _toInt(payload['project_section_id']);
          final section = _activeProjectDetail?.sections.firstWhere(
            (s) => s.id == patchedSectionId,
            orElse: () => const ProjectSectionModel(
              id: 0,
              name: '',
              sortOrder: 0,
              status: '',
            ),
          );
          if (section != null && section.id > 0) {
            patchedSectionName = section.name;
          }
        }

        // Find and update the local task representation cache:
        if (_activeProjectDetail?.project.numericId == projectId) {
          final idx = _activeProjectDetail!.tasks.indexWhere(
            (t) => t.id == taskId,
          );
          if (idx >= 0) {
            final existing = _activeProjectDetail!.tasks[idx];
            final newTasks = List<ProjectTaskModel>.from(
              _activeProjectDetail!.tasks,
            );

            // If the API returned a full task object, use it to ensure everything is correct
            final taskData = data['data'];
            if (taskData is Map) {
              try {
                final Map<String, dynamic> taskJson = Map<String, dynamic>.from(
                  taskData,
                );
                final fromServer = ProjectTaskModel.fromJson(taskJson);

                // Merge server response with existing data to prevent partial response data loss
                final updated = fromServer.copyWith(
                  title: fromServer.title.trim().isNotEmpty
                      ? fromServer.title
                      : existing.title,
                  status: fromServer.status.trim().isNotEmpty
                      ? fromServer.status
                      : existing.status,
                  sectionName: fromServer.sectionName.trim().isNotEmpty
                      ? fromServer.sectionName
                      : existing.sectionName,
                  projectSectionId: fromServer.projectSectionId > 0
                      ? fromServer.projectSectionId
                      : existing.projectSectionId,
                  dueDate: (fromServer.dueDate.trim().isNotEmpty && fromServer.dueDate != 'null')
                      ? fromServer.dueDate
                      : existing.dueDate,
                  description: fromServer.description.trim().isNotEmpty
                      ? fromServer.description
                      : existing.description,
                  members: taskJson.containsKey('members')
                      ? fromServer.members
                      : existing.members,
                  labels: taskJson.containsKey('labels')
                      ? fromServer.labels
                      : existing.labels,
                  attachments: taskJson.containsKey('attachments')
                      ? fromServer.attachments
                      : existing.attachments,
                  activities: taskJson.containsKey('activities')
                      ? fromServer.activities
                      : existing.activities,
                );

                newTasks[idx] = updated;
                _activeProjectDetail = _activeProjectDetail!.copyWith(
                  tasks: newTasks,
                );

                // Update global cache
                _projectDetailsCache[_activeProjectDetail!.project.numericId] =
                    _activeProjectDetail!;
                final globalIdx = _tasks.indexWhere((t) => t.id == taskId);
                if (globalIdx != -1) {
                  _tasks[globalIdx] = updated;
                }

                notifyListeners();
                return true;
              } catch (e) {
                printData(
                  title: 'Parse updated task error',
                  data: e.toString(),
                );
              }
            }

            // Fallback to manual patch if no full object or parse error
            final patched = existing.copyWith(
              title: payload['title'] as String? ?? existing.title,
              description:
                  payload['description'] as String? ?? existing.description,
              dueDate: payload['due_date'] as String? ?? existing.dueDate,
              members: patchedMembers ?? existing.members,
              labels: patchedLabels ?? existing.labels,
              projectSectionId: patchedSectionId ?? existing.projectSectionId,
              sectionName: patchedSectionName ?? existing.sectionName,
              status: patchedSectionName ?? existing.status,
            );
            newTasks[idx] = patched;
            _activeProjectDetail = _activeProjectDetail!.copyWith(
              tasks: newTasks,
            );

            // Update global cache
            _projectDetailsCache[_activeProjectDetail!.project.numericId] =
                _activeProjectDetail!;
            final globalIdx = _tasks.indexWhere((t) => t.id == taskId);
            if (globalIdx != -1) {
              _tasks[globalIdx] = patched;
            }

            notifyListeners();
          }
        }

        return true;
      }
    } catch (e, st) {
      printData(title: 'Update Task Error', data: '$e\n$st', e: true);
    }
    return false;
  }

  Future<bool> createProjectTask({
    required int projectId,
    required Map<String, dynamic> payload,
    List<String> filePaths = const [],
    List<String> fileNames = const [],
    List<String> fileKeys = const [],
  }) async {
    try {
      // Use the task_create_context API URL if available, otherwise fallback
      String apiPath = ApiRoutes.createProjectTask(projectId);
      final ctxApi = _activeProjectDetail?.taskCreateContext?.api;
      if (ctxApi != null && ctxApi.tasksStore.isNotEmpty) {
        final fullUrl = ctxApi.tasksStore;
        if (fullUrl.contains('/api/')) {
          apiPath = fullUrl.split('/api/').last;
        }
      }

      final data = await ApiService().postDataToApi(
        api: apiPath,
        headers: await _headers(),
        payload: payload,
        filePaths: filePaths,
        fileNames: fileNames,
        fileKeys: fileKeys,
        multipart: true, // Use multipart for form-data as per screenshot
        showRes: true,
      );

      if (_isSuccess(data)) {
        // Try to parse the created task from the response
        final taskJson = data['data'] as Map<String, dynamic>?;
        ProjectTaskModel? created;
        if (taskJson != null) {
          created = ProjectTaskModel.fromJson(taskJson);
          if (created.projectId == 0) {
            created = created.copyWith(projectId: projectId);
          }
        }

        // Keep active detail and task cache in sync immediately.
        if (_activeProjectDetail?.project.numericId == projectId) {
          if (created != null && created.id > 0) {
            final existingIdx = _activeProjectDetail!.tasks.indexWhere(
              (t) => t.id == created!.id,
            );
            if (existingIdx >= 0) {
              _activeProjectDetail!.tasks[existingIdx] = created;
            } else {
              _activeProjectDetail!.tasks.insert(0, created);
            }
            _projectDetailsCache[projectId] = _activeProjectDetail!;
          } else {
            // Some responses don't include the created task object.
            await _refreshProjectDetailSilently(projectId);
          }
        } else if (created == null) {
          await _refreshProjectDetailSilently(projectId);
        }

        if (created != null && created.id > 0) {
          final taskIdx = _tasks.indexWhere((t) => t.id == created!.id);
          if (taskIdx >= 0) {
            _tasks[taskIdx] = created;
          } else {
            _tasks.insert(0, created);
          }
        }

        notifyListeners();
        showToast(
          message: data['message']?.toString() ?? 'Task created successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to create task',
      );
    } catch (e, st) {
      printData(title: 'Create Task Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to create task');
    }

    return false;
  }

  Future<bool> deleteProjectTask({
    required int projectId,
    required int taskId,
  }) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.deleteProjectTask(projectId, taskId),
        headers: await _headers(),
        isDelete: true,
        showRes: true,
      );

      if (_isSuccess(data)) {
        // Remove from active project detail
        if (_activeProjectDetail?.project.numericId == projectId) {
          _activeProjectDetail?.tasks.removeWhere((t) => t.id == taskId);
        }

        // Remove from global tasks list
        _tasks.removeWhere((t) => t.id == taskId);

        notifyListeners();
        showToast(
          message: data['message']?.toString() ?? 'Task deleted successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to delete task',
      );
    } catch (e, st) {
      printData(title: 'Delete Task Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to delete task');
    }
    return false;
  }

  Future<bool> updateProject({
    required int projectId,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.updateProject(projectId),
        headers: await _headers(),
        payload: payload,
        showRes: true,
      );

      if (_isSuccess(data)) {
        // Sync activeProjectDetail
        if (_activeProjectDetail?.project.numericId == projectId) {
          _activeProjectDetail = _activeProjectDetail!.copyWith(
            project: _activeProjectDetail!.project.copyWith(
              name:
                  payload['name'] as String? ??
                  _activeProjectDetail!.project.name,
              cardDateText:
                  payload['date'] as String? ??
                  _activeProjectDetail!.project.cardDateText,
              cardTimeText:
                  payload['time'] as String? ??
                  _activeProjectDetail!.project.cardTimeText,
            ),
          );
        }

        // Sync in projects list
        final pIdx = _projects.indexWhere((p) => p.numericId == projectId);
        if (pIdx >= 0) {
          _projects[pIdx] = _projects[pIdx].copyWith(
            name: payload['name'] as String? ?? _projects[pIdx].name,
            cardDateText:
                payload['date'] as String? ?? _projects[pIdx].cardDateText,
            cardTimeText:
                payload['time'] as String? ?? _projects[pIdx].cardTimeText,
          );
        }

        notifyListeners();
        return true;
      }
    } catch (e, st) {
      printData(title: 'Update Project Error', data: '$e\n$st', e: true);
    }
    return false;
  }

  Future<bool> updateProjectCoreFields({
    required int projectId,
    required String name,
    required int clientId,
    required int customerId,
    String? clientName,
    String? customerName,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'client_id': clientId,
      'customer_id': customerId,
    };

    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.updateProject(projectId),
        headers: await _headers(),
        payload: payload,
        showRes: true,
      );

      if (_isSuccess(data)) {
        if (_activeProjectDetail?.project.numericId == projectId) {
          _activeProjectDetail = _activeProjectDetail!.copyWith(
            project: _activeProjectDetail!.project.copyWith(
              name: name,
              clientName: clientName?.trim().isNotEmpty == true
                  ? clientName!.trim()
                  : _activeProjectDetail!.project.clientName,
              customerName: customerName?.trim().isNotEmpty == true
                  ? customerName!.trim()
                  : _activeProjectDetail!.project.customerName,
            ),
          );
        }

        final pIdx = _projects.indexWhere((p) => p.numericId == projectId);
        if (pIdx >= 0) {
          _projects[pIdx] = _projects[pIdx].copyWith(
            name: name,
            clientName: clientName?.trim().isNotEmpty == true
                ? clientName!.trim()
                : _projects[pIdx].clientName,
            customerName: customerName?.trim().isNotEmpty == true
                ? customerName!.trim()
                : _projects[pIdx].customerName,
          );
        }

        notifyListeners();
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to update project',
      );
    } catch (e, st) {
      printData(
        title: 'Update Project Core Fields Error',
        data: '$e\n$st',
        e: true,
      );
      showToast(message: 'Unable to update project');
    }

    return false;
  }

  Future<bool> createProjectCoreFields({
    required String name,
    required int clientId,
    required int customerId,
    int? projectBlueprintId,
    int? conversationId,
    List<int>? excludedStaffIds,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'client_id': clientId,
      'customer_id': customerId,
      'project_blueprint_id': projectBlueprintId,
      'description': null,
      'priority': null,
      'status': null,
      'due_date': null,
      'conversation_id': conversationId,
      'excluded_staff_ids': excludedStaffIds,
    };

    printData(title: 'Create Project Payload', data: payload);

    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.projects,
        headers: await _headers(),
        payload: payload,
        showRes: true,
      );

      if (_isSuccess(data)) {
        showToast(
          message:
              data['message']?.toString() ?? 'Project created successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to create project',
      );
    } catch (e, st) {
      printData(title: 'Create Project Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to create project');
    }

    return false;
  }

  void removeProjectAt(int index) {
    if (index < 0 || index >= _projects.length) return;
    _projects.removeAt(index);
    notifyListeners();
  }

  Future<bool> saveProjectTemplate({
    required int projectId,
    required String name,
    required bool isPublic,
  }) async {
    // Determine the base API path as specified by the user: projects/{projectId}/blueprints
    String apiPath = 'projects/$projectId/blueprints';

    try {
      final data = await ApiService().postDataToApi(
        api: apiPath,
        headers: await _headers(),
        payload: {'name': name, 'is_public': isPublic},
        showRes: true,
      );

      if (_isSuccess(data)) {
        showToast(
          message: data['message']?.toString() ?? 'Template saved successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to save template',
      );
    } catch (e, st) {
      printData(title: 'Save Template Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to save template');
    }
    return false;
  }

  Future<bool> saveTaskAsTemplate({
    required int taskId,
    required String name,
    int? projectId,
    bool isPublic = true,
    String? title,
    String? description,
    String? activityComment,
    int? projectSectionId,
    String? dueDate,
    List<int>? memberIds,
    List<int>? labelIds,
    List<String>? newLabels,
    List<String>? newLabelColors,
    List<int>? templateAttachmentIds,
  }) async {
    final resolvedProjectId = projectId ?? _activeProjectDetail?.project.numericId;
    if (resolvedProjectId == null) {
      printData(title: 'Save Task Template Error', data: 'Project ID is null');
      return false;
    }

    try {
      final payload = <String, dynamic>{
        'name': name,
        'source_task_id': taskId,
        'is_public': isPublic,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (activityComment != null) 'activity_comment': activityComment,
        if (projectSectionId != null) 'project_section_id': projectSectionId,
        if (dueDate != null) 'due_date': dueDate,
        if (memberIds != null) 'member_ids': memberIds,
        if (labelIds != null) 'label_ids': labelIds,
        if (newLabels != null) 'new_labels': newLabels,
        if (newLabelColors != null) 'new_label_colors': newLabelColors,
        if (templateAttachmentIds != null) 'template_attachment_ids': templateAttachmentIds,
      };

      final data = await ApiService().postDataToApi(
        api: 'projects/$resolvedProjectId/task-templates',
        headers: await _headers(),
        payload: payload,
        showRes: true,
      );

      if (_isSuccess(data)) {
        await getTaskTemplates(forceRefresh: true);
        return true;
      }
    } catch (e, st) {
      printData(title: 'Save Task Template Error', data: '$e\n$st', e: true);
    }
    return false;
  }

  Future<List<ProjectTaskTemplateModel>> getTaskTemplates({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _taskTemplates.isNotEmpty) {
      return List<ProjectTaskTemplateModel>.from(_taskTemplates);
    }

    try {
      String apiPath = ApiRoutes.projectTaskTemplates;
      final ctxApi = _activeProjectDetail?.taskCreateContext?.api;
      if (ctxApi != null && ctxApi.taskTemplatesIndexGlobal.isNotEmpty) {
        final fullUrl = ctxApi.taskTemplatesIndexGlobal;
        if (fullUrl.contains('/api/')) {
          apiPath = fullUrl.split('/api/').last;
        }
      }

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final result = raw is List ? raw : <dynamic>[];
        _taskTemplates
          ..clear()
          ..addAll(taskTemplatesFromJson(result));
        notifyListeners();
        return List<ProjectTaskTemplateModel>.from(_taskTemplates);
      }
    } catch (e, st) {
      printData(title: 'Task Templates Load Error', data: '$e\n$st', e: true);
    }

    return List<ProjectTaskTemplateModel>.from(_taskTemplates);
  }

  Future<ProjectTaskTemplateDetailModel?> getTaskTemplateDetail({
    required int templateId,
  }) async {
    try {
      String apiPath = ApiRoutes.projectTaskTemplateDetail(templateId);
      final ctxApi = _activeProjectDetail?.taskCreateContext?.api;
      if (ctxApi != null && ctxApi.taskTemplatesShowGlobal.isNotEmpty) {
        var resolvedUrl = ctxApi.taskTemplatesShowGlobal;
        for (final token in [
          '{taskTemplateId}',
          '{templateId}',
          '%7BtaskTemplateId%7D',
          '%7BtemplateId%7D',
          '%7btaskTemplateId%7d',
          '%7btemplateId%7d',
        ]) {
          resolvedUrl = resolvedUrl.replaceAll(token, templateId.toString());
        }

        if (resolvedUrl.contains('/api/')) {
          apiPath = resolvedUrl.split('/api/').last;
        } else if (resolvedUrl.startsWith('http')) {
          final uri = Uri.tryParse(resolvedUrl);
          final path = uri?.path ?? '';
          apiPath = path.startsWith('/api/')
              ? path.replaceFirst('/api/', '')
              : path.replaceFirst('/', '');
        } else {
          apiPath = resolvedUrl.replaceFirst('/', '');
        }
      }

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final payload = data['data'];
        if (payload is Map) {
          return ProjectTaskTemplateDetailModel.fromJson(
            Map<String, dynamic>.from(payload),
          );
        }
      }
    } catch (e, st) {
      printData(title: 'Task Template Detail Error', data: '$e\n$st', e: true);
    }

    return null;
  }

  Future<void> getProjectFilterProjectAssignees({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasLoadedProjectFilterProjectAssignees) {
      return;
    }

    projectFilterProjectAssigneesLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectsFilterProjectAssignees,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'value': '', 'label': 'Select'},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final name = map['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            options.add({'value': name, 'label': name});
          }
        }

        _projectFilterProjectAssigneeOptions
          ..clear()
          ..addAll(options);
        _hasLoadedProjectFilterProjectAssignees = true;
      }
    } catch (e, st) {
      printData(
        title: 'Project Filter Project Assignee Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectFilterProjectAssigneesLoad = false;
      notifyListeners();
    }
  }

  Future<void> getProjectFilterTaskAssignees({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasLoadedProjectFilterTaskAssignees) {
      return;
    }

    projectFilterTaskAssigneesLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectsFilterTaskAssignees,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'value': '', 'label': 'Select'},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final name = map['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            options.add({'value': name, 'label': name});
          }
        }

        _projectFilterTaskAssigneeOptions
          ..clear()
          ..addAll(options);
        _hasLoadedProjectFilterTaskAssignees = true;
      }
    } catch (e, st) {
      printData(
        title: 'Project Filter Task Assignee Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectFilterTaskAssigneesLoad = false;
      notifyListeners();
    }
  }

  Future<void> getProjectFilterProjectTaskAssignees({
    required int projectId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _loadedProjectTaskAssigneesForProjectId == projectId) {
      return;
    }

    projectFilterProjectTaskAssigneesLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectFilterProjectAssigneesByProject(projectId),
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'value': '', 'label': 'Select'},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final name = map['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            options.add({'value': name, 'label': name});
          }
        }

        _projectFilterProjectTaskAssigneeOptions
          ..clear()
          ..addAll(options);
        _loadedProjectTaskAssigneesForProjectId = projectId;
      }
    } catch (e, st) {
      printData(
        title: 'Project Task Filter Assignee Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectFilterProjectTaskAssigneesLoad = false;
      notifyListeners();
    }
  }

  Future<void> getProjectSectionFilterOptions({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasLoadedProjectSectionFilterOptions) {
      return;
    }

    projectSectionFilterOptionsLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectSections,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'value': '', 'label': 'Select'},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final name = map['name']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            // Task filter endpoint expects section name in `status`.
            options.add({'value': name, 'label': name});
          }
        }

        _projectSectionFilterOptions
          ..clear()
          ..addAll(options);
        _hasLoadedProjectSectionFilterOptions = true;
      }
    } catch (e, st) {
      printData(
        title: 'Project Section Filter Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectSectionFilterOptionsLoad = false;
      notifyListeners();
    }
  }

  Future<void> getProjectClientOptions({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedProjectClientOptions) {
      return;
    }

    projectClientOptionsLoad = true;
    notifyListeners();
    try {
      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.projectsOptionClients,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'id': '', 'label': 'Select', 'image': ''},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString().trim() ?? '';
            final label = map['company_name']?.toString().trim() ?? '';
            if (id.isEmpty || label.isEmpty) continue;
            final assignedStaffRaw = map['assigned_staff'];
            final assignedStaff = <Map<String, dynamic>>[];
            if (assignedStaffRaw is List) {
              for (final member in assignedStaffRaw) {
                if (member is! Map) continue;
                final m = Map<String, dynamic>.from(member);
                assignedStaff.add({
                  'id': m['id'],
                  'name': m['name']?.toString() ?? '',
                  'image': m['image']?.toString() ?? '',
                });
              }
            }

            options.add({
              'id': id,
              'label': label,
              'image': map['image']?.toString() ?? '',
              'assigned_staff': jsonEncode(assignedStaff),
            });
          }
        }

        _projectClientOptions
          ..clear()
          ..addAll(options);
        _hasLoadedProjectClientOptions = true;
      }
    } catch (e, st) {
      printData(
        title: 'Project Client Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectClientOptionsLoad = false;
      notifyListeners();
    }
  }

  Future<void> getPaginatedProjectClientOptions({
    bool refresh = false,
    int? conversationId,
    String? searchQuery,
  }) async {
    if (refresh) {
      paginatedClientsCurrentPage = 1;
      paginatedClientsHasMore = true;
      paginatedClientOptions.clear();
      isFetchingPaginatedClients = true;
    } else {
      if (!paginatedClientsHasMore || isFetchingMorePaginatedClients) return;
      isFetchingMorePaginatedClients = true;
      paginatedClientsCurrentPage++;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final userToken = prefs.getString('token') ?? '';

    final response = await ApiService().fetchClientOptions(
      userToken: userToken,
      conversationId: conversationId,
      limit: 15,
      offset: (paginatedClientsCurrentPage - 1) * 15,
      searchQuery: searchQuery,
      includeAssignedStaff: true,
    );

    if (response != null && response.success) {
      printData(
        title: 'getPaginatedProjectClientOptions Success',
        data: 'Fetched ${response.data.length} clients. Clients: '
            '${response.data.map((c) => {
                  'id': c.id,
                  'companyName': c.companyName,
                  'assignedStaff': c.assignedStaff.map((s) => {'id': s.id, 'name': s.name}).toList()
                }).toList()}',
      );
      if (refresh) {
        paginatedClientOptions.clear();
      }
      paginatedClientOptions.addAll(response.data);
      paginatedClientsLastPage = response.lastPage;
      paginatedClientsHasMore = paginatedClientsCurrentPage < response.lastPage;
    } else {
      // Revert page increment on failure
      if (!refresh && paginatedClientsCurrentPage > 1) {
        paginatedClientsCurrentPage--;
      }
    }

    if (refresh) {
      isFetchingPaginatedClients = false;
    } else {
      isFetchingMorePaginatedClients = false;
    }
    notifyListeners();
  }

  Future<void> getProjectCustomerOptions({
    bool forceRefresh = false,
    int? clientId,
  }) async {
    if (!forceRefresh && clientId == null && _hasLoadedProjectCustomerOptions) {
      return;
    }

    projectCustomerOptionsLoad = true;
    notifyListeners();
    try {
      final apiPath = clientId != null
          ? '${ApiRoutes.projectsOptionCustomers}?client_id=$clientId'
          : ApiRoutes.projectsOptionCustomers;

      final data = await ApiService().getDataFromApi(
        api: apiPath,
        headers: await _headers(),
        showRes: false,
      );

      if (_isSuccess(data)) {
        final raw = data['data'];
        final options = <Map<String, String>>[
          {'id': '', 'client_id': '', 'label': 'Select', 'image': ''},
        ];

        if (raw is List) {
          for (final item in raw) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString().trim() ?? '';
            final clientId = map['client_id']?.toString().trim() ?? '';
            var label = map['company_name']?.toString().trim() ?? '';
            if (label.isEmpty) {
              label = 'Personal';
            }
            if (id.isEmpty) continue;
            options.add({
              'id': id,
              'client_id': clientId,
              'label': label,
              'image': map['image']?.toString() ?? '',
            });
          }
        }

        _projectCustomerOptions
          ..clear()
          ..addAll(options);
        _hasLoadedProjectCustomerOptions = true;
      }
    } catch (e, st) {
      printData(
        title: 'Project Customer Options Error',
        data: '$e\n$st',
        e: true,
      );
    } finally {
      projectCustomerOptionsLoad = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTaskTemplate({required int templateId}) async {
    try {
      final data = await ApiService().postDataToApi(
        api: ApiRoutes.projectTaskTemplateDetail(templateId),
        headers: await _headers(),
        isDelete: true,
        showRes: false,
      );

      if (_isSuccess(data)) {
        _taskTemplates.removeWhere((item) => item.id == templateId);
        notifyListeners();
        showToast(
          message:
              data['message']?.toString() ?? 'Template deleted successfully',
        );
        return true;
      }

      showToast(
        message: data['message']?.toString() ?? 'Unable to delete template',
      );
    } catch (e, st) {
      printData(title: 'Delete Task Template Error', data: '$e\n$st', e: true);
      showToast(message: 'Unable to delete template');
    }
    return false;
  }
}
