String _cleanUrl(String? url) {
  if (url == null) return '';
  return url.trim().replaceAll('`', '').trim();
}

class FileModel {
  final String id;
  final String filename;
  final String thumbnail;
  final List<String> uploadedBy;
  final String type;
  final String size;
  final String createdAt;
  final String internalPath;
  final String storagePath;
  final String ownerName;
  final String ownerAvatar;

  FileModel({
    required this.id,
    required this.filename,
    required this.thumbnail,
    required this.uploadedBy,
    required this.type,
    required this.size,
    required this.createdAt,
    required this.internalPath,
    required this.storagePath,
    required this.ownerName,
    required this.ownerAvatar,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final ownerImage = (owner?['image'] ?? '').toString();
    final ownerName =
        '${(owner?['name'] ?? '').toString()} ${(owner?['last_name'] ?? '').toString()}'
            .trim();

    final List<String> uploadedBy =
        (json['uploadedBy'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    if (uploadedBy.isEmpty) {
      uploadedBy.add(ownerImage);
    }

    final filename = (json['filename'] ?? json['name'] ?? json['title'] ?? '')
        .toString();
    final extension = (json['extension'] ?? '').toString().toLowerCase();
    final rawType = (json['type'] ?? '').toString().toLowerCase();
    final resolvedType = rawType.isNotEmpty
        ? rawType
        : (extension.isNotEmpty
              ? extension
              : (filename.contains('.')
                    ? filename.split('.').last.toLowerCase()
                    : 'file'));

    return FileModel(
      id: (json['id'] ?? json['internal_path'] ?? json['path'] ?? filename)
          .toString(),
      filename: filename,
      thumbnail: _cleanUrl(
        (json['thumbnail_url'] ??
                json['thumbnail'] ??
                json['preview_url'] ??
                json['path'] ??
                json['storage_path'] ??
                '')
            .toString(),
      ),
      uploadedBy: uploadedBy,
      type: resolvedType,
      size: (json['size'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      internalPath: _cleanUrl((json['internal_path'] ?? '').toString()),
      storagePath: _cleanUrl(
        (json['storage_path'] ?? json['path'] ?? '').toString(),
      ),
      ownerName: ownerName,
      ownerAvatar: _cleanUrl(ownerImage),
    );
  }
}

List<FileModel> filesFromJson(List list) =>
    list.map((e) => FileModel.fromJson(e as Map<String, dynamic>)).toList();

class FolderModel {
  final String id;
  final String title;
  final String icon;
  final String size;
  final String createdAt;
  final String internalPath;
  final String storagePath;
  final bool canDelete;
  final bool isSystem;
  final String ownerName;
  final String ownerAvatar;
  final int fileCount;
  final int sizeBytes;

  FolderModel({
    required this.title,
    required this.icon,
    required this.id,
    required this.size,
    required this.createdAt,
    required this.internalPath,
    required this.storagePath,
    required this.canDelete,
    required this.isSystem,
    required this.ownerName,
    required this.ownerAvatar,
    required this.fileCount,
    required this.sizeBytes,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    final title = (json['title'] ?? json['name'] ?? '').toString();
    return FolderModel(
      id: (json['id'] ?? json['internal_path'] ?? json['path'] ?? title)
          .toString(),
      title: title,
      icon: (json['icon'] ?? 'folder').toString(),
      size: (json['size'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      internalPath: (json['internal_path'] ?? '').toString(),
      storagePath: (json['storage_path'] ?? json['path'] ?? '').toString(),
      canDelete: json['can_delete'] == true,
      isSystem: json['is_system'] == true,
      ownerName:
          '${(owner?['name'] ?? '').toString()} ${(owner?['last_name'] ?? '').toString()}'
              .trim(),
      ownerAvatar: (owner?['image'] ?? '').toString(),
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

List<FolderModel> foldersFromJson(List<dynamic> list) =>
    list.map((e) => FolderModel.fromJson(e as Map<String, dynamic>)).toList();
