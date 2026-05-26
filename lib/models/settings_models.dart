import 'package:flutter/foundation.dart';
import '../utils/formatter.dart';

class SettingsItem {
  int id;
  String name;
  String createdAt;
  String updatedAt;
  final String localKey;

  SettingsItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    String? localKey,
  }) : localKey = localKey ?? UniqueKey().toString();

  factory SettingsItem.fromJson(Map<String, dynamic> json) => SettingsItem(
    id: json['id'] is int
        ? json['id']
        : int.tryParse(json['id'].toString()) ?? 0,
    name: json['name'] ?? '',
    createdAt: formatDateTime(json['created_at'] ?? ''),
    updatedAt: formatDateTime(json['updated_at'] ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class SettingsSection {
  int id;
  String title;
  List<SettingsItem> items;
  bool expanded;

  SettingsSection({
    required this.id,
    required this.title,
    required this.items,
    this.expanded = false,
  });

  factory SettingsSection.fromJson(Map<String, dynamic> json) =>
      SettingsSection(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id'].toString()) ?? 0,
        title: json['title'] ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => SettingsItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        expanded: json['expanded'] ?? false,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'items': items.map((e) => e.toJson()).toList(),
    'expanded': expanded,
  };
}

class FileSettingsConfig {
  int maxUploadSizeMb;
  Map<String, int> storageLimitsMb;
  List<FileExtensionItem> allowedExtensions;

  FileSettingsConfig({
    required this.maxUploadSizeMb,
    required this.storageLimitsMb,
    required this.allowedExtensions,
  });

  factory FileSettingsConfig.defaults() => FileSettingsConfig(
    maxUploadSizeMb: 0,
    storageLimitsMb: {},
    allowedExtensions: [],
  );

  factory FileSettingsConfig.fromJson(Map<String, dynamic> json) {
    final defaults = FileSettingsConfig.defaults();

    int parseInt(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value.toString()) ?? fallback;
    }

    final storageSource =
        (json['storage_limit_mb'] ??
                json['storage_limits'] ??
                json['storage_limit'] ??
                json['storageLimits'] ??
                json['limits'])
            as Map<String, dynamic>?;

    final storage = <String, int>{};
    if (storageSource != null) {
      storage['1'] = parseInt(storageSource['1'] ?? storageSource['admin'], 0);
      storage['2'] = parseInt(storageSource['2'] ?? storageSource['staff'], 0);
      storage['4'] = parseInt(storageSource['4'] ?? storageSource['client'], 0);
      storage['5'] = parseInt(
        storageSource['5'] ?? storageSource['customer'],
        0,
      );

      for (final entry in storageSource.entries) {
        storage[entry.key.toString()] = parseInt(entry.value, 0);
      }
    }

    final rawExt =
        (json['allowed_extensions'] ??
                json['extensions'] ??
                json['allowedExtensions'])
            as List<dynamic>?;

    final exts = <FileExtensionItem>[];
    if (rawExt != null) {
      for (final entry in rawExt) {
        final item = FileExtensionItem.fromAny(entry);
        if (item.extension.isEmpty) {
          continue;
        }
        final alreadyExists = exts.any((e) => e.extension == item.extension);
        if (!alreadyExists) {
          exts.add(item);
        }
      }
    }

    return FileSettingsConfig(
      maxUploadSizeMb: parseInt(
        json['max_upload_size'] ??
            json['max_upload_size_mb'] ??
            json['maxUploadSize'],
        defaults.maxUploadSizeMb,
      ),
      storageLimitsMb: storage,
      allowedExtensions: exts,
    );
  }

  FileSettingsConfig copyWith({
    int? maxUploadSizeMb,
    Map<String, int>? storageLimitsMb,
    List<FileExtensionItem>? allowedExtensions,
  }) {
    return FileSettingsConfig(
      maxUploadSizeMb: maxUploadSizeMb ?? this.maxUploadSizeMb,
      storageLimitsMb:
          storageLimitsMb ?? Map<String, int>.from(this.storageLimitsMb),
      allowedExtensions:
          allowedExtensions ??
          this.allowedExtensions.map((e) => e.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'max_upload_size_mb': maxUploadSizeMb,
    'storage_limit_mb': storageLimitsMb,
    'allowed_extensions': allowedExtensions.map((e) => e.toJson()).toList(),
  };

  static String _normalizeExtension(String raw) {
    var ext = raw.trim().toLowerCase();
    if (ext.startsWith('.')) {
      ext = ext.substring(1);
    }
    return ext;
  }
}

class FileExtensionItem {
  final String extension;
  final String? icon;

  /// Local file path of a newly picked SVG — only set on the client side,
  /// never serialised back to the API.
  final String? localFilePath;

  const FileExtensionItem({
    required this.extension,
    this.icon,
    this.localFilePath,
  });

  factory FileExtensionItem.fromAny(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final ext = FileSettingsConfig._normalizeExtension(
        raw['extension']?.toString() ?? '',
      );
      final icon = raw['icon']?.toString();
      return FileExtensionItem(extension: ext, icon: icon);
    }

    final ext = FileSettingsConfig._normalizeExtension(raw.toString());
    return FileExtensionItem(extension: ext);
  }

  FileExtensionItem copyWith({
    String? extension,
    String? icon,
    String? localFilePath,
  }) {
    return FileExtensionItem(
      extension: extension ?? this.extension,
      icon: icon ?? this.icon,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() => {'extension': extension};
}
