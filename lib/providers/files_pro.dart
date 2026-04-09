import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/filefolder_models.dart';
import '../admin/chat/service/reverb_service.dart';
import '../services/api_routes.dart';
import '../services/api_service.dart';
import '../utils/console_util.dart';
import '../widgets/loaders.dart';
import '../widgets/toasts.dart';

class FilesPro extends ChangeNotifier {
  bool filesLoad = false;

  ReverbSocketService? _filesSocket;

  // Track the context to use for automatic refreshes
  // (In a real app, we might use a global navigator or a better state management pattern,
  // but for now we follow the existing pattern of passing context to getFiles).
  BuildContext? _lastContext;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notifsInitialized = false;
  double _lastReportedUiProgress = 0;
  double _lastReportedNotifProgress = 0;

  final List<FolderModel> folders = [];
  final List<FileModel> files = [];

  String currentPath = 'files';
  String displayPath = '/';
  String homePath = 'files';
  bool recursive = false;
  String storageSummary = '';
  String storageUsed = '';
  String storageAvailable = '';
  String storageTotal = '';
  int storageUsedBytes = 0;
  int storageTotalBytes = 0;
  int storageAvailableBytes = 0;
  double usagePercent = 0;
  Map<String, dynamic> branding = {};
  Map<String, dynamic> folderColors = {};
  Map<String, dynamic> activeFilters = {};
  Map<String, String> appliedFilters = {};
  Map<String, dynamic> counts = {};
  bool filterOptionsLoad = false;
  List<Map<String, String>> sortByOptions = [
    {'value': '', 'label': 'Select'},
    {'value': 'newest', 'label': 'Newest first'},
    {'value': 'oldest', 'label': 'Oldest first'},
    {'value': 'name_asc', 'label': 'File name A-Z'},
    {'value': 'name_desc', 'label': 'File name Z-A'},
    {'value': 'extension_asc', 'label': 'Extension A-Z'},
    {'value': 'extension_desc', 'label': 'Extension Z-A'},
  ];

  int filesCurrentPage = 1;
  int filesLastPage = 1;
  int filesPerPage = 50;
  int filesTotal = 0;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  List<Map<String, String>> fileExtensionOptions = [
    {'value': 'png', 'label': '.png'},
    {'value': 'jpg', 'label': '.jpg'},
    {'value': 'pdf', 'label': '.pdf'},
    {'value': 'zip', 'label': '.zip'},
    {'value': 'doc', 'label': '.doc'},
  ];
  String sortByPlaceholder = 'Select';
  String fileExtensionPlaceholder = 'Select Extension';
  bool _hasLoadedFilterOptions = false;
  bool uploadInProgress = false;
  double uploadProgress = 0;
  double currentFileProgress = 0;
  String uploadStatus = '';
  String currentUploadFileName = '';
  String currentUploadFilePath = '';
  List<Map<String, dynamic>> uploadQueue = [];
  // Kept across failures so the retry button can re-run the same upload.
  List<String> _pendingRetryPaths = [];
  List<String> _pendingRetryNames = [];
  bool get hasFailedUpload =>
      !uploadInProgress &&
      uploadQueue.isNotEmpty &&
      uploadQueue.any((q) => q['status'] == 'failed');

  bool emailOptionsLoading = false;
  Map<String, dynamic>? emailShareOptions;

  bool get canGoBackFolder => currentPath != homePath;

  int get appliedFilterCount {
    int count = 0;
    activeFilters.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      count++;
    });
    return count;
  }

  bool get canShowFloatingActions {
    final normalized = currentPath.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final parts = normalized.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return false;

    final homeNormalized = homePath.trim().toLowerCase();
    if (normalized == homeNormalized) return false;

    return normalized.startsWith('$homeNormalized/');
  }

  /// --- REAL-TIME UPDATES ---

  Future<void> initFilesSocket({
    required String userId,
    required BuildContext context,
  }) async {
    if (_filesSocket != null) return;

    _lastContext = context;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";
    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    _filesSocket = ReverbSocketService(
      onMessageReceived: (_) {},
      onTypingReceived: (_) {},
      onConnected: () {
        printData(title: "✅ Files real-time socket connected", data: "");
      },
      onFileOperation: (data) {
        // When any file operation happens, refresh the current view
        printData(title: "🔄 Real-time file update received", data: data);
        if (_lastContext != null && _lastContext!.mounted) {
          getFiles(ctx: _lastContext!, path: currentPath);
        }
      },
    );

    _filesSocket!.connectUserChannel(
      host: ApiRoutes.socketHost,
      port: ApiRoutes.socketPort,
      appKey: ApiRoutes.appKey,
      userId: userId,
      authEndpoint: Uri.parse("${ApiRoutes.baseUrl}broadcasting/auth"),
      headers: headers,
      context: context,
    );
  }

  /// Handles real-time file system mutations by patching the local state.
  /// This avoids a full re-fetch and provides an "instant" UI update.
  Future<void> handleFileSystemMutation(Map<String, dynamic> payload) async {
    final action = payload['action']?.toString();
    final data = payload['data'] is Map
        ? payload['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    if (action == null) return;

    printData(title: "🛠️ PATCHING UI: $action", data: data);
    printData(title: "🔑 DATA KEYS:", data: data.keys.toList());

    bool changed = false;

    switch (action) {
      case 'folder.deleted':
      case 'file.deleted':
        final path = data['path']?.toString();
        if (path != null) {
          folders.removeWhere((f) => f.internalPath == path);
          files.removeWhere((f) => f.internalPath == path);
          changed = true;
        }
        break;

      case 'items.deleted':
        final deleted = data['deleted'] as List?;
        if (deleted != null) {
          final paths = deleted.map((e) => e.toString()).toSet();
          folders.removeWhere((f) => paths.contains(f.internalPath));
          files.removeWhere((f) => paths.contains(f.internalPath));
          changed = true;
        }
        break;

      case 'folder.renamed':
      case 'file.renamed':
        final oldPath =
            data['old_path']?.toString() ?? data['from_path']?.toString();
        final newPath =
            data['new_path']?.toString() ?? data['to_path']?.toString();
        final newName =
            data['new_name']?.toString() ??
            data['name']?.toString() ??
            (newPath != null && newPath.isNotEmpty
                ? newPath.split('/').last
                : null);

        if (oldPath != null && newPath != null && newPath.isNotEmpty) {
          // Update folders
          for (var i = 0; i < folders.length; i++) {
            if (folders[i].internalPath == oldPath) {
              final json = _folderToJson(folders[i]);
              json['internal_path'] = newPath;
              if (newName != null) json['name'] = newName;
              folders[i] = FolderModel.fromJson(json);
              changed = true;
              break;
            }
          }
          // Update files
          for (var i = 0; i < files.length; i++) {
            if (files[i].internalPath == oldPath) {
              final json = _fileToJson(files[i]);
              json['internal_path'] = newPath;
              if (newName != null) json['filename'] = newName;
              files[i] = FileModel.fromJson(json);
              changed = true;
              break;
            }
          }
        }
        break;

      case 'folder.created':
        final folderData = data['folder'] ?? data;
        if (folderData is Map && isCurrentPath(data['current_path'])) {
          final newFolder = FolderModel.fromJson(
            Map<String, dynamic>.from(folderData),
          );
          if (!folders.any((f) => f.id == newFolder.id)) {
            folders.insert(0, newFolder);
            changed = true;
          }
        }
        break;

      case 'file.uploaded':
      case 'file.created':
        final fileData = data['file'] ?? data;
        if (fileData is Map && isCurrentPath(data['current_path'])) {
          final newFile = FileModel.fromJson(
            Map<String, dynamic>.from(fileData),
          );
          if (!files.any((f) => f.id == newFile.id)) {
            files.insert(0, newFile);
            changed = true;
          }
        }
        break;
    }

    if (changed) {
      notifyListeners();
    } else {
      // If we couldn't patch it (e.g. unknown state), fallback to a refresh
      // but only if it's related to the current path to avoid unnecessary loads
      if (isCurrentPath(data['current_path'])) {
        printData(
          title: "⚠️ Patch failed, falling back to full refresh",
          data: "",
        );
        if (_lastContext != null && _lastContext!.mounted) {
          getFiles(ctx: _lastContext!, path: currentPath);
        }
      }
    }
  }

  bool isCurrentPath(dynamic eventPath) {
    if (eventPath == null) return true; // Assume relevant if not specified
    final p = eventPath.toString().trim();
    return p == currentPath || p == "/$currentPath";
  }

  Map<String, dynamic> _folderToJson(FolderModel f) {
    return {
      'id': f.id,
      'name': f.title,
      'icon': f.icon,
      'size': f.size,
      'created_at': f.createdAt,
      'internal_path': f.internalPath,
      'storage_path': f.storagePath,
      'can_delete': f.canDelete,
      'is_system': f.isSystem,
      'file_count': f.fileCount,
      'size_bytes': f.sizeBytes,
      'owner': {'name': f.ownerName.split(' ').first, 'image': f.ownerAvatar},
    };
  }

  Map<String, dynamic> _fileToJson(FileModel f) {
    return {
      'id': f.id,
      'filename': f.filename,
      'thumbnail': f.thumbnail,
      'type': f.type,
      'size': f.size,
      'created_at': f.createdAt,
      'internal_path': f.internalPath,
      'storage_path': f.storagePath,
      'owner': {'name': f.ownerName.split(' ').first, 'image': f.ownerAvatar},
    };
  }

  void disconnectFilesSocket() {
    if (_filesSocket != null) {
      _filesSocket!.disconnect();
      _filesSocket = null;
    }
  }

  String _readStorageValue(
    Map<String, dynamic> payload,
    Map<String, dynamic>? stats,
    List<String> keys,
  ) {
    for (final key in keys) {
      final statValue = stats?[key];
      if (statValue != null && statValue.toString().trim().isNotEmpty) {
        return statValue.toString().trim();
      }

      final payloadValue = payload[key];
      if (payloadValue != null && payloadValue.toString().trim().isNotEmpty) {
        return payloadValue.toString().trim();
      }
    }

    return '';
  }

  int _readStorageInt(
    Map<String, dynamic> payload,
    Map<String, dynamic>? stats,
    List<String> keys,
  ) {
    for (final key in keys) {
      final statValue = stats?[key];
      if (statValue is num) return statValue.toInt();
      final statParsed = int.tryParse(statValue?.toString() ?? '');
      if (statParsed != null) return statParsed;

      final payloadValue = payload[key];
      if (payloadValue is num) return payloadValue.toInt();
      final payloadParsed = int.tryParse(payloadValue?.toString() ?? '');
      if (payloadParsed != null) return payloadParsed;
    }

    return 0;
  }

  double? _parseStorageBytes(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    final compact = normalized.replaceAll(',', '').toUpperCase();
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([A-Z]+)?$').firstMatch(compact);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1) ?? '');
    if (amount == null) return null;

    final unit = (match.group(2) ?? 'B').trim();
    const factors = <String, double>{
      'B': 1,
      'BYTE': 1,
      'BYTES': 1,
      'KB': 1024,
      'K': 1024,
      'MB': 1024 * 1024,
      'M': 1024 * 1024,
      'GB': 1024 * 1024 * 1024,
      'G': 1024 * 1024 * 1024,
      'TB': 1024 * 1024 * 1024 * 1024,
      'T': 1024 * 1024 * 1024 * 1024,
    };

    final factor = factors[unit];
    if (factor == null) return null;
    return amount * factor;
  }

  String _formatStorageBytes(double bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes;
    var index = 0;

    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }

    final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(decimals)} ${units[index]}';
  }

  void _hydrateStorageFromSummary() {
    final summary = storageSummary.trim();
    if (summary.isEmpty) return;

    final slashMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*([KMGT]?B)\s*.*?\/\s*(\d+(?:\.\d+)?)\s*([KMGT]?B)',
      caseSensitive: false,
    ).firstMatch(summary);

    if (slashMatch != null) {
      storageUsed = storageUsed.trim().isEmpty
          ? '${slashMatch.group(1)} ${slashMatch.group(2)!.toUpperCase()}'
          : storageUsed;
      storageTotal = storageTotal.trim().isEmpty
          ? '${slashMatch.group(3)} ${slashMatch.group(4)!.toUpperCase()}'
          : storageTotal;
      return;
    }

    final ofMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s*([KMGT]?B)\s*.*?OF\s*(\d+(?:\.\d+)?)\s*([KMGT]?B)',
      caseSensitive: false,
    ).firstMatch(summary.toUpperCase());

    if (ofMatch != null) {
      storageUsed = storageUsed.trim().isEmpty
          ? '${ofMatch.group(1)} ${ofMatch.group(2)!.toUpperCase()}'
          : storageUsed;
      storageTotal = storageTotal.trim().isEmpty
          ? '${ofMatch.group(3)} ${ofMatch.group(4)!.toUpperCase()}'
          : storageTotal;
    }
  }

  void _resolveStorageBreakdown() {
    _hydrateStorageFromSummary();

    if (storageUsed.trim().isEmpty && storageUsedBytes > 0) {
      storageUsed = _formatStorageBytes(storageUsedBytes.toDouble());
    }

    if (storageTotal.trim().isEmpty && storageTotalBytes > 0) {
      storageTotal = _formatStorageBytes(storageTotalBytes.toDouble());
    }

    if (storageAvailable.trim().isEmpty && storageAvailableBytes > 0) {
      storageAvailable = _formatStorageBytes(storageAvailableBytes.toDouble());
    }

    final totalBytes = _parseStorageBytes(storageTotal);
    final usedBytes = _parseStorageBytes(storageUsed);
    final availableBytes = _parseStorageBytes(storageAvailable);

    if (storageAvailable.trim().isEmpty && totalBytes != null) {
      if (usedBytes != null) {
        final computed = (totalBytes - usedBytes)
            .clamp(0, totalBytes)
            .toDouble();
        storageAvailable = _formatStorageBytes(computed);
      } else if (usagePercent > 0) {
        final computed = totalBytes * (1 - (usagePercent.clamp(0, 100) / 100));
        storageAvailable = _formatStorageBytes(
          computed.clamp(0, totalBytes).toDouble(),
        );
      }
    }

    if (storageUsed.trim().isEmpty &&
        totalBytes != null &&
        availableBytes != null) {
      final computed = (totalBytes - availableBytes)
          .clamp(0, totalBytes)
          .toDouble();
      storageUsed = _formatStorageBytes(computed);
    }

    if (storageTotal.trim().isEmpty &&
        usedBytes != null &&
        availableBytes != null) {
      storageTotal = _formatStorageBytes(
        (usedBytes + availableBytes).clamp(0, double.infinity).toDouble(),
      );
    }
  }

  String _parentPath(String path) {
    final parts = path.split('/').where((e) => e.isNotEmpty).toList();
    if (parts.length <= 1) {
      return homePath;
    }
    parts.removeLast();
    return parts.join('/');
  }

  Future<bool> navigateToParentFolder({required BuildContext ctx}) async {
    if (!canGoBackFolder) return false;
    final parent = _parentPath(currentPath);
    await getFiles(ctx: ctx, path: parent);
    return true;
  }

  final Set<String> selected = {};
  List<Map<String, dynamic>> _copiedItems = [];
  String? _copiedFromPath;
  List<Map<String, dynamic>> _movedItems = [];
  String? _movedFromPath;

  bool get isSelecting => selected.isNotEmpty;
  bool get hasCopiedItems => _copiedItems.isNotEmpty;
  String? get copiedFromPath => _copiedFromPath;
  bool get hasMovedItems => _movedItems.isNotEmpty;

  void toggleSelect(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void toggleSelectAll(bool select) {
    if (select) {
      for (final folder in folders) {
        selected.add(folder.id);
      }
      for (final file in files) {
        selected.add(file.id);
      }
    } else {
      selected.clear();
    }
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> _buildSelectedItemsPayload() {
    final selectedIds = selected.toSet();
    final payloadItems = <Map<String, dynamic>>[];

    for (final file in files) {
      if (!selectedIds.contains(file.id)) continue;
      final path = file.storagePath.trim().isNotEmpty
          ? file.storagePath.trim()
          : file.thumbnail.trim();
      final internalPath = file.internalPath.trim();
      if (path.isEmpty && internalPath.isEmpty) continue;

      payloadItems.add({
        'type': 'file',
        'path': path.isNotEmpty ? path : internalPath,
        'internal_path': internalPath,
      });
    }

    for (final folder in folders) {
      if (!selectedIds.contains(folder.id)) continue;
      final folderPath = folder.internalPath.trim().isNotEmpty
          ? folder.internalPath.trim()
          : folder.storagePath.trim();
      if (folderPath.isEmpty) continue;

      payloadItems.add({'type': 'folder', 'path': folderPath});
    }

    return payloadItems;
  }

  int stageSelectedItemsForCopy() {
    final payloadItems = _buildSelectedItemsPayload();
    if (payloadItems.isEmpty) {
      showToast(message: 'No valid items selected for copy');
      return 0;
    }

    _copiedItems = payloadItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _copiedFromPath = currentPath;
    selected.clear();
    notifyListeners();
    return _copiedItems.length;
  }

  void clearCopiedItems() {
    _copiedItems = [];
    _copiedFromPath = null;
    notifyListeners();
  }

  int stageSelectedItemsForMove() {
    final payloadItems = _buildSelectedItemsPayload();
    if (payloadItems.isEmpty) {
      showToast(message: 'No valid items selected for move');
      return 0;
    }

    _movedItems = payloadItems
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _movedFromPath = currentPath;
    selected.clear();
    notifyListeners();
    return _movedItems.length;
  }

  void clearMovedItems() {
    _movedItems = [];
    _movedFromPath = null;
    notifyListeners();
  }

  Future<bool> _executeItemsTransfer({
    required String endpoint,
    required String sourcePath,
    required String destinationPath,
    required List<Map<String, dynamic>> items,
    required String successFallback,
    required String failFallback,
  }) async {
    if (items.isEmpty) {
      showToast(message: failFallback);
      return false;
    }

    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final payload = jsonEncode({
        'destination_path': destinationPath,
        'current_path': sourcePath,
        'items': items,
      });

      final data = await ApiService().postDataToApi(
        api: endpoint,
        payload: payload,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        showToast(message: (data['message'] ?? successFallback).toString());
        return true;
      }

      showToast(message: (data['message'] ?? failFallback).toString());
      return false;
    } catch (e, st) {
      printData(title: 'Files Transfer Error', data: '$e\n$st', e: true);
      showToast(message: failFallback);
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> pasteCopiedItems({
    required BuildContext ctx,
    String? destinationPath,
  }) async {
    if (_copiedItems.isEmpty || _copiedFromPath == null) {
      showToast(message: 'Nothing to paste');
      return false;
    }

    final targetPath = destinationPath ?? currentPath;
    final copied = await _executeItemsTransfer(
      endpoint: ApiRoutes.filesItemsCopy,
      sourcePath: _copiedFromPath!,
      destinationPath: targetPath,
      items: _copiedItems,
      successFallback: 'Items copied successfully',
      failFallback: 'Failed to copy items',
    );

    if (copied) {
      _copiedItems = [];
      _copiedFromPath = null;
      await getFiles(ctx: ctx, path: currentPath);
      notifyListeners();
    }

    return copied;
  }

  Future<bool> executeStagedMove({
    required BuildContext ctx,
    required String destinationPath,
  }) async {
    if (_movedItems.isEmpty || _movedFromPath == null) {
      showToast(message: 'Nothing to move');
      return false;
    }

    final moved = await _executeItemsTransfer(
      endpoint: ApiRoutes.filesItemsMove,
      sourcePath: _movedFromPath!,
      destinationPath: destinationPath,
      items: _movedItems,
      successFallback: 'Items moved successfully',
      failFallback: 'Failed to move items',
    );

    if (moved) {
      _movedItems = [];
      _movedFromPath = null;
      await getFiles(ctx: ctx, path: currentPath);
      notifyListeners();
    }

    return moved;
  }

  Map<String, dynamic>? buildItemPayloadById({
    required String itemId,
    required bool isFolder,
  }) {
    if (isFolder) {
      final idx = folders.indexWhere((e) => e.id == itemId);
      if (idx < 0) return null;
      final folder = folders[idx];
      final folderPath = folder.internalPath.trim().isNotEmpty
          ? folder.internalPath.trim()
          : folder.storagePath.trim();
      if (folderPath.isEmpty) return null;
      return {'type': 'folder', 'path': folderPath};
    }

    final idx = files.indexWhere((e) => e.id == itemId);
    if (idx < 0) return null;
    final file = files[idx];
    final path = file.storagePath.trim().isNotEmpty
        ? file.storagePath.trim()
        : file.thumbnail.trim();
    final internalPath = file.internalPath.trim();
    if (path.isEmpty && internalPath.isEmpty) return null;

    return {
      'type': 'file',
      'path': path.isNotEmpty ? path : internalPath,
      'internal_path': internalPath,
    };
  }

  Future<bool> deleteItem({
    required BuildContext ctx,
    required String itemId,
    required bool isFolder,
  }) async {
    final item = buildItemPayloadById(itemId: itemId, isFolder: isFolder);
    if (item == null) {
      showToast(message: 'Unable to identify selected item');
      return false;
    }

    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final payload = jsonEncode({
        'current_path': currentPath,
        'items': [item],
      });

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesItemsDelete,
        payload: payload,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        showToast(
          message: (data['message'] ?? 'Item deleted successfully').toString(),
        );
        Loaders.hide();
        await getFiles(ctx: ctx, path: currentPath);
        return true;
      }

      showToast(
        message: (data['message'] ?? 'Failed to delete item').toString(),
      );
      return false;
    } catch (e, st) {
      printData(title: 'Files Delete Error', data: '$e\n$st', e: true);
      showToast(message: 'Failed to delete item');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> deleteSelectedItems({required BuildContext ctx}) async {
    final items = _buildSelectedItemsPayload();
    if (items.isEmpty) {
      showToast(message: 'No valid items selected for delete');
      return false;
    }

    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final payload = jsonEncode({'current_path': currentPath, 'items': items});

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesItemsDelete,
        payload: payload,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        selected.clear();
        showToast(
          message: (data['message'] ?? 'Items deleted successfully').toString(),
        );
        Loaders.hide();
        await getFiles(ctx: ctx, path: currentPath);
        return true;
      }

      showToast(
        message: (data['message'] ?? 'Failed to delete selected items')
            .toString(),
      );
      return false;
    } catch (e, st) {
      printData(title: 'Files Bulk Delete Error', data: '$e\n$st', e: true);
      showToast(message: 'Failed to delete selected items');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> renameItem({
    required BuildContext ctx,
    required String itemId,
    required bool isFolder,
    required String newName,
  }) async {
    final item = buildItemPayloadById(itemId: itemId, isFolder: isFolder);
    if (item == null) {
      showToast(message: 'Unable to identify selected item');
      return false;
    }

    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      showToast(message: 'Please enter a valid name');
      return false;
    }

    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      String renamePath = '';
      if (isFolder) {
        final idx = folders.indexWhere((e) => e.id == itemId);
        if (idx >= 0) {
          renamePath = folders[idx].internalPath.trim();
        }
      } else {
        final idx = files.indexWhere((e) => e.id == itemId);
        if (idx >= 0) {
          renamePath = files[idx].internalPath.trim();
        }
      }

      if (renamePath.isEmpty) {
        final raw = (item['internal_path'] ?? item['path'] ?? '').toString();
        renamePath = raw.trim();
      }

      if (renamePath.isEmpty) {
        showToast(message: 'Unable to identify item path');
        return false;
      }

      final payload = jsonEncode({'path': renamePath, 'name': cleanName});

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesFoldersRename,
        payload: payload,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        showToast(
          message: (data['message'] ?? 'Item renamed successfully').toString(),
        );
        Loaders.hide();
        await getFiles(ctx: ctx, path: currentPath);
        return true;
      }

      showToast(
        message: (data['message'] ?? 'Failed to rename item').toString(),
      );
      return false;
    } catch (e, st) {
      printData(title: 'Files Rename Error', data: '$e\n$st', e: true);
      showToast(message: 'Failed to rename item');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  Future<bool> createFolder({
    required BuildContext ctx,
    required String name,
    String? parentPath,
    String? currentPathOverride,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      showToast(message: 'Please enter folder name');
      return false;
    }

    final resolvedCurrent = (currentPathOverride ?? currentPath).trim();
    final resolvedParent = (parentPath ?? resolvedCurrent).trim();

    Loaders.show();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final payload = jsonEncode({
        'name': cleanName,
        'parent_path': resolvedParent,
        'current_path': resolvedCurrent,
      });

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesFolders,
        payload: payload,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        showToast(
          message: (data['message'] ?? 'Folder created successfully')
              .toString(),
        );
        Loaders.hide();
        await getFiles(ctx: ctx, path: currentPath);
        return true;
      }

      showToast(
        message: (data['message'] ?? 'Failed to create folder').toString(),
      );
      return false;
    } catch (e, st) {
      printData(title: 'Create Folder Error', data: '$e\n$st', e: true);
      showToast(message: 'Failed to create folder');
      return false;
    } finally {
      Loaders.hide();
    }
  }

  bool _isSuccess(Map<String, dynamic> data) {
    if (data['success'] == true) return true;
    if (data['status'] == true && data['message'] == 'success') return true;
    return false;
  }

  List<Map<String, String>> _parseFilterOptions(dynamic rawOptions) {
    if (rawOptions is! List) return [];

    final parsed = <Map<String, String>>[];
    for (final item in rawOptions) {
      if (item is Map) {
        final value = (item['value'] ?? '').toString();
        final label = (item['label'] ?? value).toString();
        parsed.add({'value': value, 'label': label});
      }
    }
    return parsed;
  }

  Map<String, dynamic> _parseActiveFilters(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
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

  Map<String, String> _extractAppliedFilters(Map<String, dynamic> source) {
    final extracted = <String, String>{};
    for (final entry in source.entries) {
      final value = entry.value?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      extracted[entry.key] = value;
    }
    return extracted;
  }

  Future<void> getFileFilterOptions({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoadedFilterOptions) {
      return;
    }

    filterOptionsLoad = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final data = await ApiService().getDataFromApi(
        api: ApiRoutes.filesFilterOptions,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (_isSuccess(data)) {
        final payload = (data['data'] is Map<String, dynamic>)
            ? data['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        final sortByData = payload['sort_by'] as Map<String, dynamic>?;
        final extensionData =
            payload['file_extension'] as Map<String, dynamic>?;

        final parsedSortBy = _parseFilterOptions(sortByData?['options']);
        final parsedFileExtensions = _parseFilterOptions(
          extensionData?['options'],
        );

        if (parsedSortBy.isNotEmpty) {
          sortByOptions = parsedSortBy;
          sortByPlaceholder = (sortByData?['placeholder'] ?? sortByPlaceholder)
              .toString();
        }

        if (parsedFileExtensions.isNotEmpty) {
          fileExtensionOptions = parsedFileExtensions;
          fileExtensionPlaceholder =
              (extensionData?['placeholder'] ?? fileExtensionPlaceholder)
                  .toString();
        }

        _hasLoadedFilterOptions = true;
      }
    } catch (e, st) {
      printData(title: 'Filter Options Error', data: '$e\n$st', e: true);
    } finally {
      filterOptionsLoad = false;
      notifyListeners();
    }
  }

  Future<void> _initNotifs() async {
    if (_notifsInitialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _notifsInitialized = true;
  }

  void _showUploadNotification(int progress, {bool isDone = false}) {
    final androidDetails = AndroidNotificationDetails(
      'upload_channel',
      'Uploads',
      channelDescription: 'File Upload Progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: !isDone,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
      ongoing: !isDone,
    );

    _notifications.show(
      999, // Static ID for the overall upload notification
      isDone ? 'Upload Complete' : 'Uploading Files...',
      isDone ? 'All files uploaded successfully' : '$progress% complete',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> getFiles({
    required BuildContext ctx,
    String? path,
    Map<String, String>? filters,
    bool clearFilters = false,
    int? page,
    bool loadMore = false,
  }) async {
    _lastContext = ctx;
    if (loadMore) {
      _isLoadingMore = true;
    } else {
      filesLoad = true;
      filesCurrentPage = 1;
      filesLastPage = 1;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (clearFilters) {
        appliedFilters.clear();
      }
      if (filters != null) {
        appliedFilters = _sanitizeFilterMap(filters);
      }

      final query = <String, String>{};
      if (path != null && path.isNotEmpty) {
        query['path'] = path;
      }
      if (page != null) {
        query['page'] = page.toString();
      }
      query.addAll(appliedFilters);

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
        final stats = payload['storage_stats'] as Map<String, dynamic>?;

        final f1 = payload['folders'] as List<dynamic>?;
        final f2 = payload['files'] as List<dynamic>?;

        if (!loadMore) {
          folders.clear();
          files.clear();
        }

        if (f1 != null) folders.addAll(foldersFromJson(f1));
        if (f2 != null) files.addAll(filesFromJson(f2));

        // Parse Pagination
        final pagination = payload['pagination'] as Map<String, dynamic>?;
        if (pagination != null) {
          filesCurrentPage = pagination['current_page'] ?? 1;
          filesLastPage = pagination['last_page'] ?? 1;
          filesPerPage = pagination['per_page'] ?? 50;
          filesTotal = pagination['total'] ?? 0;
        }

        currentPath = (payload['current_path'] ?? path ?? 'files').toString();
        displayPath = (payload['display_path'] ?? '/').toString();
        homePath = (payload['home_path'] ?? 'files').toString();
        recursive = payload['recursive'] == true;
        branding = Map<String, dynamic>.from(
          (payload['branding'] as Map<String, dynamic>?) ?? {},
        );
        folderColors = Map<String, dynamic>.from(
          (payload['folder_colors'] as Map<String, dynamic>?) ?? {},
        );
        activeFilters = _parseActiveFilters(payload['active_filters']);
        appliedFilters = _extractAppliedFilters(activeFilters);
        counts = Map<String, dynamic>.from(
          (payload['counts'] as Map<String, dynamic>?) ?? {},
        );
        storageSummary = (payload['storage_summary'] ?? stats?['summary'] ?? '')
            .toString();

        storageUsed = _readStorageValue(payload, stats, [
          'used',
          'used_space',
          'used_storage',
          'used_size',
          'usage',
        ]);
        storageAvailable = _readStorageValue(payload, stats, [
          'remaining',
          'remaining_space',
          'available_space',
          'free_space',
          'available',
          'free',
        ]);
        storageTotal = _readStorageValue(payload, stats, [
          'limit',
          'limit_space',
          'total_space',
          'total_storage',
          'capacity',
          'total',
        ]);
        storageUsedBytes = _readStorageInt(payload, stats, ['used_bytes']);
        storageTotalBytes = _readStorageInt(payload, stats, [
          'limit_bytes',
          'total_bytes',
        ]);
        storageAvailableBytes = _readStorageInt(payload, stats, [
          'remaining_bytes',
          'available_bytes',
          'free_bytes',
        ]);

        final rawPercent = stats?['usage_percent'];
        usagePercent = rawPercent is num
            ? rawPercent.toDouble()
            : double.tryParse(rawPercent?.toString() ?? '0') ?? 0;

        _resolveStorageBreakdown();
      }
    } catch (e, st) {
      printData(title: "Files Load Error", data: "$e\n$st", e: true);
    } finally {
      filesLoad = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> uploadFile({
    required BuildContext ctx,
    required List<String> filePaths,
    required List<String> fileNames,
  }) async {
    if (filePaths.isEmpty) return false;
    // Remember for retry.
    _pendingRetryPaths = List<String>.from(filePaths);
    _pendingRetryNames = List<String>.from(fileNames);
    // Stable copies written to app documents dir to survive Android cache eviction.
    final stableCopies = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Preferred chunk size hint sent to server.
      // Server may override this (e.g. S3 requires ≥5 MB).
      const preferredChunkSize = 2 * 1024 * 1024;
      const uuid = Uuid();
      final resolvedFiles = <Map<String, dynamic>>[];
      final failedFiles = <String>[];
      var uploadedCount = 0;

      for (var i = 0; i < filePaths.length; i++) {
        final filePath = filePaths[i];
        final fallbackName = _extractFileName(filePath);
        final fileName = i < fileNames.length && fileNames[i].trim().isNotEmpty
            ? fileNames[i].trim()
            : fallbackName;
        final file = File(filePath);

        if (!await file.exists()) {
          failedFiles.add(fileName);
          continue;
        }

        final fileSize = await file.length();

        // If the source is inside the OS cache (e.g. file_picker temp dir),
        // copy it to a stable location that Android won't evict mid-upload.
        final stableFile = await _ensureStableFile(
          sourceFile: file,
          fileName: fileName,
          stableCopies: stableCopies,
        );

        resolvedFiles.add({
          'path': stableFile.path,
          'name': fileName,
          'file': stableFile,
          'size': fileSize,
        });
      }

      if (resolvedFiles.isEmpty) {
        showToast(message: 'No valid files selected');
        return false;
      }

      uploadQueue = resolvedFiles
          .map(
            (fileData) => {
              'name': fileData['name'],
              'path': fileData['path'],
              'progress': 0.0,
              'status': 'queued',
            },
          )
          .toList();

      uploadInProgress = true;
      uploadProgress = 0;
      currentFileProgress = 0;
      uploadStatus = 'Preparing upload...';
      currentUploadFileName = '';
      currentUploadFilePath = '';
      notifyListeners();

      // Track progress in bytes so we are not affected by per-file chunk count
      // differences between client and server.
      final totalBytesAll = resolvedFiles.fold<int>(
        0,
        (sum, f) => sum + (f['size'] as int),
      );
      var uploadedBytesAll = 0;

      for (var fileIndex = 0; fileIndex < resolvedFiles.length; fileIndex++) {
        final fileData = resolvedFiles[fileIndex];
        final filePath = fileData['path'] as String;
        final file = fileData['file'] as File;
        final fileName = fileData['name'] as String;
        final fileSize = fileData['size'] as int;
        final uploadKey = 'device-file-${uuid.v4()}';
        final mimeType = _extractMimeType(fileName);

        currentUploadFileName = fileName;
        currentUploadFilePath = filePath;
        currentFileProgress = 0;
        uploadQueue[fileIndex]['status'] = 'uploading';
        uploadQueue[fileIndex]['progress'] = 0.0;
        notifyListeners();

        // --- Init session ---
        final initPayload = jsonEncode({
          'name': fileName,
          'size': fileSize,
          'mime_type': mimeType,
          'path': currentPath,
          'chunk_size': preferredChunkSize,
          'upload_key': uploadKey,
        });

        final initData = await ApiService().postDataToApi(
          api: 'files/upload/chunk/init',
          payload: initPayload,
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

        if (!_isSuccess(initData)) {
          failedFiles.add(fileName);
          uploadQueue[fileIndex]['status'] = 'failed';
          final errorMessage = initData['message']?.toString();
          if (errorMessage != null && errorMessage.isNotEmpty) {
            showToast(message: errorMessage);
          }
          continue;
        }

        final uploadId = _resolveUploadId(initData);
        if (uploadId.isEmpty) {
          failedFiles.add(fileName);
          uploadQueue[fileIndex]['status'] = 'failed';
          continue;
        }

        // --- Use server-authoritative chunk_size and total_chunks ---
        final serverData = (initData['data'] as Map<String, dynamic>?) ?? {};
        final effectiveChunkSize =
            (serverData['chunk_size'] as num?)?.toInt() ?? preferredChunkSize;
        final totalChunks =
            (serverData['total_chunks'] as num?)?.toInt() ??
            (fileSize / effectiveChunkSize).ceil();

        printData(
          title: 'DEBUG',
          data:
              'Uploading $totalChunks chunks for $fileName '
              '(chunkSize=$effectiveChunkSize) uploadId=$uploadId',
        );

        var fileUploadFailed = false;
        var fileBytesUploaded = 0;

        // --- Chunk loop ---
        for (var chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          printData(
            title: 'DEBUG',
            data: 'Uploading chunk $chunkIndex for $fileName',
          );

          final start = chunkIndex * effectiveChunkSize;
          final end = min(start + effectiveChunkSize, fileSize);
          final chunkBytes = end - start;

          uploadStatus = 'Uploading $fileName (${chunkIndex + 1}/$totalChunks)';
          notifyListeners();

          final bytes = await file.openRead(start, end).fold<List<int>>([], (
            buffer,
            data,
          ) {
            buffer.addAll(data);
            return buffer;
          });

          final chunkUploaded = await _uploadChunkWithRetry(
            token: token,
            uploadId: uploadId,
            fileName: fileName,
            bytes: bytes,
            chunkIndex: chunkIndex,
          );

          if (!chunkUploaded) {
            failedFiles.add(fileName);
            fileUploadFailed = true;
            uploadQueue[fileIndex]['status'] = 'failed';
            break;
          }

          fileBytesUploaded += chunkBytes;
          uploadedBytesAll += chunkBytes;

          currentFileProgress = fileSize == 0
              ? 0
              : fileBytesUploaded / fileSize;
          uploadQueue[fileIndex]['progress'] = currentFileProgress;
          uploadProgress = totalBytesAll == 0
              ? 0
              : uploadedBytesAll / totalBytesAll;

          // Throttled UI & Notif Reporting
          final int uiPercent = (uploadProgress * 100).toInt();
          if (uploadProgress - _lastReportedUiProgress >= 0.03 ||
              uploadProgress >= 1.0) {
            _lastReportedUiProgress = uploadProgress;
            notifyListeners();
          }

          if (uploadProgress - _lastReportedNotifProgress >= 0.05 ||
              uploadProgress >= 1.0) {
            _lastReportedNotifProgress = uploadProgress;
            await _initNotifs();
            _showUploadNotification(uiPercent);
          }
        }

        if (fileUploadFailed) continue;

        // --- Complete session ---
        // S3 multipart finalization can take a long time for large files.
        // Use a 10-minute timeout instead of the global 30-second default.
        final completeData = await ApiService().postDataToApi(
          api: 'files/upload/chunk/$uploadId/complete',
          payload: '',
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          timeOut: 600,
        );

        if (!_isSuccess(completeData)) {
          failedFiles.add(fileName);
          uploadQueue[fileIndex]['status'] = 'failed';
          final errorMessage = completeData['message']?.toString();
          if (errorMessage != null && errorMessage.isNotEmpty) {
            showToast(message: errorMessage);
          }
          continue;
        }

        uploadedCount++;
        uploadQueue[fileIndex]['status'] = 'done';
        uploadQueue[fileIndex]['progress'] = 1.0;
        notifyListeners();
      }

      if (uploadedCount > 0) {
        if (failedFiles.isEmpty) {
          _showUploadNotification(100, isDone: true);
          showToast(message: 'Uploaded successfully');
        } else {
          showToast(
            message:
                'Uploaded $uploadedCount/${filePaths.length}. Failed: ${failedFiles.length}',
          );
        }
        await getFiles(ctx: ctx, path: currentPath);
        return failedFiles.isEmpty;
      }

      showToast(message: 'Failed to upload ${failedFiles.length} file(s)');
      return false;
    } catch (e, st) {
      printData(title: 'Upload Error', data: '$e\n$st', e: true);
      _notifications.cancel(999);
      showToast(message: 'Upload failed. Tap retry to try again.');
      return false;
    } finally {
      uploadInProgress = false;
      uploadProgress = 0;
      currentFileProgress = 0;
      uploadStatus = '';
      currentUploadFileName = '';
      currentUploadFilePath = '';
      // Clean up any stable copies we made.
      for (final p in stableCopies) {
        try {
          final f = File(p);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      // If there are no failed uploads, clear the queue immediately.
      // Otherwise, keep it visible so the user can see failures and tap Retry/Dismiss.
      final hasAnyFailure = uploadQueue.any((q) => q['status'] == 'failed');
      if (!hasAnyFailure) {
        uploadQueue = [];
        _pendingRetryPaths = [];
        _pendingRetryNames = [];
      }
      notifyListeners();
    }
  }

  /// Copies [sourceFile] to the app documents directory if it lives in a
  /// cache path that Android may evict. Returns the stable [File] reference
  /// and appends its path to [stableCopies] for later cleanup.
  Future<File> _ensureStableFile({
    required File sourceFile,
    required String fileName,
    required List<String> stableCopies,
  }) async {
    final sourcePath = sourceFile.path;
    // Android cache dirs that are subject to eviction.
    final isCachePath =
        sourcePath.contains('/cache/') ||
        sourcePath.contains('/file_picker/') ||
        sourcePath.contains('file_picker_cache');
    if (!isCachePath) return sourceFile; // Already stable.

    final docsDir = await getApplicationDocumentsDirectory();
    final uploadStageDir = Directory('${docsDir.path}/.upload_staging');
    if (!await uploadStageDir.exists()) {
      await uploadStageDir.create(recursive: true);
    }

    // Use a UUID prefix to avoid name collisions across concurrent uploads.
    final stablePath = '${uploadStageDir.path}/${const Uuid().v4()}_$fileName';
    printData(
      title: 'Upload Staging',
      data: 'Copying $sourcePath → $stablePath',
    );
    try {
      final stableFile = await sourceFile.copy(stablePath);
      stableCopies.add(stablePath);
      return stableFile;
    } catch (e) {
      printData(
        title: 'Upload Staging',
        data: 'Failed to copy to stable path, falling back to original: $e',
      );
      // Fallback to the original file if copy fails (e.g., out of disk space)
      return sourceFile;
    }
  }

  /// Re-run the last failed upload with the same files.
  Future<bool> retryUpload({required BuildContext ctx}) async {
    if (_pendingRetryPaths.isEmpty) return false;
    uploadQueue = [];
    notifyListeners();
    return uploadFile(
      ctx: ctx,
      filePaths: _pendingRetryPaths,
      fileNames: _pendingRetryNames,
    );
  }

  /// Dismiss the failed upload queue without retrying.
  void dismissUploadQueue() {
    uploadQueue = [];
    _pendingRetryPaths = [];
    _pendingRetryNames = [];
    notifyListeners();
  }

  String _extractFileName(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.isEmpty) return filePath;
    return parts.last;
  }

  String _extractMimeType(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'bin';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _resolveUploadId(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final id = (data['upload_id'] ?? data['id'] ?? data['uuid'] ?? '')
          .toString()
          .trim();
      if (id.isNotEmpty) return id;
    }

    final rootId =
        (response['upload_id'] ?? response['id'] ?? response['uuid'] ?? '')
            .toString()
            .trim();
    return rootId;
  }

  Future<bool> _uploadChunkWithRetry({
    required String token,
    required String uploadId,
    required String fileName,
    required List<int> bytes,
    required int chunkIndex,
  }) async {
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final chunkRequest = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiRoutes.baseUrl}files/upload/chunk/$uploadId'),
        );
        chunkRequest.headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        });
        chunkRequest.fields['chunk_index'] = '$chunkIndex';
        chunkRequest.files.add(
          http.MultipartFile.fromBytes('chunk', bytes, filename: fileName),
        );

        final chunkStream = await chunkRequest.send();
        final chunkResponse = await http.Response.fromStream(chunkStream);
        final chunkBody = chunkResponse.body.trim();

        if (chunkResponse.statusCode >= 200 && chunkResponse.statusCode < 300) {
          return true;
        }

        if (attempt == maxAttempts) {
          showToast(message: _extractChunkError(chunkBody));
          return false;
        }
      } catch (_) {
        if (attempt == maxAttempts) {
          showToast(message: 'Chunk upload failed');
          return false;
        }
      }

      await Future.delayed(Duration(milliseconds: attempt * 400));
    }

    return false;
  }

  String _extractChunkError(String chunkBody) {
    if (chunkBody.isEmpty) return 'Chunk upload failed';
    try {
      final decoded = jsonDecode(chunkBody);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? 'Chunk upload failed';
      }
    } catch (_) {}
    return 'Chunk upload failed';
  }

  String _normalizeStoragePath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('//')) {
      final uri = Uri.parse(value.startsWith('//') ? 'https:$value' : value);
      value = uri.path;
    }

    try {
      value = Uri.decodeFull(value);
    } catch (_) {
      // Keep original when malformed encoding is received.
    }

    value = value.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');

    if (value.startsWith('storage/')) {
      value = value.substring('storage/'.length);
    }

    for (final prefix in const [
      'files/',
      'dedup/',
      'users/',
      'group_images/',
    ]) {
      final index = value.indexOf(prefix);
      if (index >= 0) {
        value = value.substring(index);
        break;
      }
    }

    return value;
  }

  Future<bool> shareItemToChat({
    int? conversationId,
    int? userId,
    List<int>? conversationIds,
    List<int>? userIds,
    required String itemPath,
    required String itemName,
    required bool isFolder,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        showToast(message: 'Session expired. Please login again');
        return false;
      }

      final Map<String, dynamic> body = {};
      if (conversationIds != null && conversationIds.isNotEmpty) {
        body['conversation_ids'] = conversationIds;
      } else if (userIds != null && userIds.isNotEmpty) {
        body['user_ids'] = userIds;
      } else if (conversationId != null) {
        body['conversation_ids'] = [conversationId];
      } else if (userId != null) {
        body['user_ids'] = [userId];
      } else {
        return false;
      }

      final normalizedPath = _normalizeStoragePath(itemPath);
      if (normalizedPath.isEmpty) {
        showToast(message: 'Invalid file path for sharing');
        return false;
      }

      final Map<String, dynamic> item = {
        'type': isFolder ? 'folder' : 'file',
        'path': normalizedPath,
      };
      if (isFolder && itemName.trim().isNotEmpty) {
        item['name'] = itemName.trim();
      }
      body['items'] = [item];

      printData(title: 'shareItemToChat URL', data: ApiRoutes.filesShareToChat);
      printData(title: 'shareItemToChat Payload', data: jsonEncode(body));

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesShareToChat,
        payload: jsonEncode(body),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      printData(title: 'shareItemToChat Response', data: data);
      return _isSuccess(data);
    } catch (e, st) {
      printData(title: 'shareItemToChat Error', data: '$e\n$st', e: true);
      return false;
    }
  }

  Future<bool> shareSelectedToChat({
    int? conversationId,
    int? userId,
    List<int>? conversationIds,
    List<int>? userIds,
  }) async {
    final selectedIds = selected.toSet();
    final payloadItems = <Map<String, dynamic>>[];

    for (final file in files) {
      if (!selectedIds.contains(file.id)) continue;
      final path = file.storagePath.trim().isNotEmpty
          ? file.storagePath.trim()
          : file.thumbnail.trim();
      final normalized = _normalizeStoragePath(path.isNotEmpty ? path : file.internalPath);
      if (normalized.isEmpty) continue;

      payloadItems.add({
        'type': 'file',
        'path': normalized,
      });
    }

    for (final folder in folders) {
      if (!selectedIds.contains(folder.id)) continue;
      final folderPath = folder.internalPath.trim().isNotEmpty
          ? folder.internalPath.trim()
          : folder.storagePath.trim();
      final normalized = _normalizeStoragePath(folderPath);
      if (normalized.isEmpty) continue;

      payloadItems.add({
        'type': 'folder',
        'path': normalized,
        'name': folder.title.trim(),
      });
    }

    if (payloadItems.isEmpty) {
      showToast(message: 'No valid items selected for sharing');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        showToast(message: 'Session expired. Please login again');
        return false;
      }

      final Map<String, dynamic> body = {};
      if (conversationIds != null && conversationIds.isNotEmpty) {
        body['conversation_ids'] = conversationIds;
      } else if (userIds != null && userIds.isNotEmpty) {
        body['user_ids'] = userIds;
      } else if (conversationId != null) {
        body['conversation_ids'] = [conversationId];
      } else if (userId != null) {
        body['user_ids'] = [userId];
      } else {
        return false;
      }

      body['items'] = payloadItems;

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesShareToChat,
        payload: jsonEncode(body),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      bool success = _isSuccess(data);
      if (success) {
        selected.clear();
        notifyListeners();
      }
      return success;
    } catch (e, st) {
      printData(title: 'shareSelectedToChat Error', data: '$e\n$st', e: true);
      return false;
    }
  }

  Future<bool> shareItemToEmail({
    required String subject,
    required String message,
    required List<int> sentToUserIds,
    required List<String> sentToEmails,
    required List<int> replyToUserIds,
    required String? replyToEmail,
    required String itemPath,
    required String itemName,
    bool isFolder = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Map<String, dynamic> body = {
        'subject': subject,
        'message': message,
        'sent_to_user_ids': sentToUserIds,
        'sent_to_emails': sentToEmails,
        'reply_to_user_ids': replyToUserIds,
        'reply_to_email': replyToEmail ?? '',
        'items': [
          {
            'type': isFolder ? 'folder' : 'file',
            'path': itemPath,
            'name': itemName,
          },
        ],
      };

      printData(title: 'shareItemToEmail Payload', data: jsonEncode(body));

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesShareToEmail,
        payload: jsonEncode(body),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      printData(title: 'shareItemToEmail Response', data: data);
      return _isSuccess(data);
    } catch (e, st) {
      printData(title: 'shareItemToEmail Error', data: '$e\n$st', e: true);
      return false;
    }
  }

  Future<bool> shareItemsToEmail({
    required String subject,
    required String message,
    required List<int> sentToUserIds,
    required List<String> sentToEmails,
    required List<int> replyToUserIds,
    required String? replyToEmail,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Map<String, dynamic> body = {
        'subject': subject,
        'message': message,
        'sent_to_user_ids': sentToUserIds,
        'sent_to_emails': sentToEmails,
        'reply_to_user_ids': replyToUserIds,
        'reply_to_email': replyToEmail ?? '',
        'items': items,
      };

      printData(title: 'shareItemsToEmail Payload', data: jsonEncode(body));

      final data = await ApiService().postDataToApi(
        api: ApiRoutes.filesShareToEmail,
        payload: jsonEncode(body),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      printData(title: 'shareItemsToEmail Response', data: data);
      return _isSuccess(data);
    } catch (e, st) {
      printData(title: 'shareItemsToEmail Error', data: '$e\n$st', e: true);
      return false;
    }
  }

  Future<void> fetchEmailShareOptions() async {
    emailOptionsLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final data = await ApiService().getDataFromApi(
        api: 'files/share/email/options',
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (_isSuccess(data) && data['data'] != null) {
        emailShareOptions = data['data'];
      } else {
        emailShareOptions = null;
      }
    } catch (e, st) {
      printData(
        title: 'fetchEmailShareOptions Error',
        data: '$e\n$st',
        e: true,
      );
      emailShareOptions = null;
    } finally {
      emailOptionsLoading = false;
      notifyListeners();
    }
  }
}
