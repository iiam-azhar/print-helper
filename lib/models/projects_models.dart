import 'package:flutter/material.dart';

class ProjectModel {
  final int numericId;
  final String id;
  final String uuid;
  final String name;
  final String code;
  final String status;
  final String clientName;
  final String customerName;
  final String ownerName;
  final String clientImage;
  final String customerImage;
  final String ownerImage;
  final String cardDateText;
  final String cardTimeText;
  final String createdAt;
  final String cardCode;
  final int progress;
  final int lateTasksCount;
  final int tasksCount;
  final int commentsCount;
  final int attachmentsCount;
  final String progressState;
  final List<String> avatars;
  final bool isProjectSavedAsTemplate;
  final int clientId;
  final int customerId;

  ProjectModel({
    required this.numericId,
    required this.id,
    required this.uuid,
    required this.name,
    required this.code,
    required this.status,
    required this.clientName,
    required this.customerName,
    required this.ownerName,
    required this.clientImage,
    required this.customerImage,
    required this.ownerImage,
    required this.cardDateText,
    required this.cardTimeText,
    required this.createdAt,
    required this.cardCode,
    required this.progress,
    required this.lateTasksCount,
    required this.tasksCount,
    required this.commentsCount,
    required this.attachmentsCount,
    required this.progressState,
    required this.avatars,
    required this.clientId,
    required this.customerId,
    this.isProjectSavedAsTemplate = false,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final client = _asMap(json['client']);
    final customer = _asMap(json['customer']);
    final owner = _asMap(json['owner']);
    final cardAvatars = _asList(json['card_avatars']);
    final detailContacts = _asList(json['detail_contacts']);
    final legacyAvatars = _asList(json['avatars']);

    return ProjectModel(
      numericId: _asInt(json['numeric_id'] ?? json['id']),
      id: _asString(
        json['card_code'] ?? json['code'] ?? json['uuid'] ?? json['id'],
      ),
      uuid: _asString(json['uuid']),
      name: _asString(json['name']),
      code: _asString(json['code'] ?? json['card_code']),
      status: _asString(json['status']),
      clientName: _asString(
        client['company_name'] ?? json['client_name'] ?? json['company'],
      ),
      customerName: _asString(
        customer['company_name'] ?? json['customer_name'],
      ),
      ownerName: _asString(owner['name'] ?? json['owner_name']),
      clientImage: _asString(client['image']),
      customerImage: _asString(customer['image']),
      ownerImage: _asString(owner['image']),
      cardDateText: _asString(json['card_date_text'] ?? json['date']),
      cardTimeText: _asString(json['card_time_text']),
      createdAt: _asString(json['created_at'] ?? json['createdAt']),
      cardCode: _asString(json['card_code'] ?? json['code'] ?? json['id']),
      progress: _asInt(
        json['card_progress_percent'] ??
            json['progress_percent'] ??
            json['progress'],
      ),
      lateTasksCount: _asInt(
        json['card_late_tasks_count'] ?? json['late_tasks_count'],
      ),
      tasksCount: _asInt(
        json['card_tasks_count'] ?? json['tasks_count'] ?? json['files'],
      ),
      commentsCount: _asInt(
        json['card_comments_count'] ??
            json['comments_count'] ??
            json['comments'],
      ),
      attachmentsCount: _asInt(
        json['card_attachments_count'] ??
            json['attachments_count'] ??
            json['files'],
      ),
      progressState: _asString(
        json['card_progress_state'] ?? json['progress_state'] ?? json['status'],
      ),
      avatars: cardAvatars.isNotEmpty
          ? cardAvatars
                .whereType<Map>()
                .map((item) => _asString(item['src']))
                .where((item) => item.isNotEmpty)
                .toList()
          : detailContacts.isNotEmpty
          ? detailContacts
                .whereType<Map>()
                .map((item) => _asString(item['src']))
                .where((item) => item.isNotEmpty)
                .toList()
          : List<String>.from(legacyAvatars.whereType<String>()),
      isProjectSavedAsTemplate: _asBool(json['is_project_saved_as_template']),
      clientId: _asInt(client['id'] ?? json['client_id']),
      customerId: _asInt(customer['id'] ?? json['customer_id']),
    );
  }

  ProjectModel copyWith({
    int? numericId,
    String? id,
    String? uuid,
    String? name,
    String? code,
    String? status,
    String? clientName,
    String? customerName,
    String? ownerName,
    String? clientImage,
    String? customerImage,
    String? ownerImage,
    String? cardDateText,
    String? cardTimeText,
    String? createdAt,
    String? cardCode,
    int? progress,
    int? lateTasksCount,
    int? tasksCount,
    int? commentsCount,
    int? attachmentsCount,
    String? progressState,
    List<String>? avatars,
    bool? isProjectSavedAsTemplate,
    int? clientId,
    int? customerId,
  }) {
    return ProjectModel(
      numericId: numericId ?? this.numericId,
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      code: code ?? this.code,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      customerName: customerName ?? this.customerName,
      ownerName: ownerName ?? this.ownerName,
      clientImage: clientImage ?? this.clientImage,
      customerImage: customerImage ?? this.customerImage,
      ownerImage: ownerImage ?? this.ownerImage,
      cardDateText: cardDateText ?? this.cardDateText,
      cardTimeText: cardTimeText ?? this.cardTimeText,
      createdAt: createdAt ?? this.createdAt,
      cardCode: cardCode ?? this.cardCode,
      progress: progress ?? this.progress,
      lateTasksCount: lateTasksCount ?? this.lateTasksCount,
      tasksCount: tasksCount ?? this.tasksCount,
      commentsCount: commentsCount ?? this.commentsCount,
      attachmentsCount: attachmentsCount ?? this.attachmentsCount,
      progressState: progressState ?? this.progressState,
      avatars: avatars ?? this.avatars,
      isProjectSavedAsTemplate:
          isProjectSavedAsTemplate ?? this.isProjectSavedAsTemplate,
      clientId: clientId ?? this.clientId,
      customerId: customerId ?? this.customerId,
    );
  }

  String get company => clientName.isNotEmpty ? clientName : customerName;
  String get date => [
    cardDateText,
    cardTimeText,
  ].where((item) => item.trim().isNotEmpty).join(' • ');
  int get comments => commentsCount;
  int get files => attachmentsCount;
  int get displayProgressPercent {
    final safeProgress = progress.clamp(0, 100);
    if (safeProgress > 0) return safeProgress;
    if (isCompleted) return 100;
    if (isInProgress) return 45;
    return 0;
  }

  bool get isCompleted =>
      progress >= 100 ||
      _normalizedProgressState == 'done' ||
      _normalizedStatus == 'completed';
  bool get isInProgress =>
      !isCompleted &&
      (progress > 0 || _normalizedProgressState == 'in_progress');

  String get clientDisplayName => clientName.isNotEmpty ? clientName : 'Client';
  String get customerDisplayName =>
      customerName.isNotEmpty ? customerName : 'Customer';
  String get ownerDisplayName =>
      ownerName.isNotEmpty ? ownerName : 'Unassigned';
  String get cardCodeLabel => cardCode.isNotEmpty ? cardCode : id;
  String get popupMetaText {
    final explicit = [
      cardCodeLabel,
      cardDateText,
      cardTimeText,
    ].where((item) => item.trim().isNotEmpty).join('  ·  ');

    if (explicit.trim().isNotEmpty && explicit.trim() != cardCodeLabel) {
      return explicit;
    }

    final createdDateTime = _tryParseDateTime(createdAt);
    if (createdDateTime != null) {
      return [
        cardCodeLabel,
        _formatShortDate(createdDateTime),
        _formatShortTime(createdDateTime),
      ].join('  ·  ');
    }

    final combinedDate = date.trim();
    if (combinedDate.isNotEmpty) {
      return [cardCodeLabel, combinedDate].join('  ·  ');
    }

    final header = cardHeaderText.replaceAll('•', '·').trim();
    return header.isNotEmpty ? header : cardCodeLabel;
  }

  String get cardHeaderText =>
      date.isNotEmpty ? '$cardCodeLabel  •  $date' : cardCodeLabel;
  String get displayStatus {
    if (isCompleted) return 'Completed';
    if (isInProgress) return 'In Progress';
    if (lateTasksCount > 0) return 'Todo';
    return _titleCase(status.isNotEmpty ? status : progressState);
  }

  String get _normalizedStatus => status.trim().toLowerCase();
  String get _normalizedProgressState => progressState.trim().toLowerCase();
}

List<ProjectModel> projectsFromJson(List list) => list
    .whereType<Map>()
    .map((item) => _asMap(item))
    .where((item) => item.isNotEmpty)
    .map(ProjectModel.fromJson)
    .toList();

List<ProjectTaskModel> taskModelsFromJson(List list) => list
    .whereType<Map>()
    .map((item) => _asMap(item))
    .where((item) => item.isNotEmpty)
    .map(ProjectTaskModel.fromJson)
    .where((item) => item.id > 0)
    .toList();

List<ProjectTaskTemplateModel> taskTemplatesFromJson(List list) => list
    .whereType<Map>()
    .map((item) => _asMap(item))
    .where((item) => item.isNotEmpty)
    .map(ProjectTaskTemplateModel.fromJson)
    .where((item) => item.id > 0)
    .toList();

class ProjectTaskTemplateModel {
  final int id;
  final String name;
  final bool isPublic;
  final bool canManage;
  final int? sourceTaskId;
  final String updatedAt;
  final int projectId;
  final String projectName;

  const ProjectTaskTemplateModel({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.canManage,
    required this.sourceTaskId,
    required this.updatedAt,
    required this.projectId,
    required this.projectName,
  });

  factory ProjectTaskTemplateModel.fromJson(Map<String, dynamic> json) {
    final sourceTaskRaw = json['source_task_id'] ??
        json['original_task_id'] ??
        json['task_id'] ??
        (json['source_task'] is Map ? json['source_task']['id'] : null) ??
        json['sourceTask'] ??
        json['sourceTaskId'];
    final parsedSourceTaskId = sourceTaskRaw == null ? null : _asInt(sourceTaskRaw);

    return ProjectTaskTemplateModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      isPublic: json['is_public'] == true,
      canManage: json['can_manage'] == true,
      sourceTaskId: parsedSourceTaskId,
      updatedAt: _asString(json['updated_at']),
      projectId: _asInt(json['project_id'] ?? json['source_project_id']),
      projectName: _asString(
        json['project_name'] ?? json['source_project_name'],
      ),
    );
  }

  String get subtitle {
    final project = projectName.trim();
    final updated = updatedAt.trim();
    if (project.isNotEmpty && updated.isNotEmpty) return '$project - $updated';
    if (project.isNotEmpty) return project;
    return updated;
  }
}

class ProjectTaskTemplateDetailModel {
  final int id;
  final String name;
  final bool isPublic;
  final int? sourceTaskId;
  final String title;
  final String description;
  final String commentText;
  final int projectSectionId;
  final String sectionName;
  final String dueDateInput;
  final List<int> memberIds;
  final List<ProjectTaskLabel> labels;

  const ProjectTaskTemplateDetailModel({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.sourceTaskId,
    required this.title,
    required this.description,
    required this.commentText,
    required this.projectSectionId,
    required this.sectionName,
    required this.dueDateInput,
    required this.memberIds,
    required this.labels,
  });

  factory ProjectTaskTemplateDetailModel.fromJson(Map<String, dynamic> json) {
    final sourceTaskRaw = json['source_task_id'];
    final parsedSourceTaskId = sourceTaskRaw == null
        ? null
        : _asInt(sourceTaskRaw);

    return ProjectTaskTemplateDetailModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      isPublic: json['is_public'] == true,
      sourceTaskId: parsedSourceTaskId,
      title: _asString(json['title']),
      description: _asString(json['description']),
      commentText: _asString(json['comment_text']),
      projectSectionId: _asInt(json['project_section_id']),
      sectionName: _asString(json['section_name']),
      dueDateInput: _asString(json['due_date_input']),
      memberIds: _asList(
        json['member_ids'],
      ).map(_asInt).where((item) => item > 0).toList(),
      labels: _listFromJson(json['labels'], ProjectTaskLabel.fromJson),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

String _normalizeRemoteUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) {
    return 'https:$value';
  }
  if (value.startsWith('/')) {
    return 'https://staging.printhelpers.com$value';
  }
  return 'https://staging.printhelpers.com/$value';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  return <dynamic>[];
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    return lower == 'true' || lower == '1';
  }
  return false;
}

String _titleCase(String value) {
  if (value.trim().isEmpty) return '';
  return value
      .split(RegExp(r'[\s_]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

DateTime? _tryParseDateTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) return direct.toLocal();

  final normalizedIso = trimmed.contains('T')
      ? trimmed
      : trimmed.replaceFirst(' ', 'T');
  final isoTry = DateTime.tryParse(normalizedIso);
  if (isoTry != null) return isoTry.toLocal();

  final text = trimmed.replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ');
  final match = RegExp(
    r'^([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})\s+(\d{1,2}):(\d{2})(am|pm)$',
    caseSensitive: false,
  ).firstMatch(text);

  if (match != null) {
    const monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final monthName = match.group(1)!.toLowerCase().substring(0, 3);
    final month = monthMap[monthName];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    var hour = int.tryParse(match.group(4)!) ?? 0;
    final minute = int.tryParse(match.group(5)!) ?? 0;
    final meridian = match.group(6)!.toLowerCase();

    if (month != null && day != null && year != null) {
      if (meridian == 'pm' && hour < 12) hour += 12;
      if (meridian == 'am' && hour == 12) hour = 0;
      return DateTime(year, month, day, hour, minute);
    }
  }

  final matchDateOnly = RegExp(
    r'^([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})$',
    caseSensitive: false,
  ).firstMatch(text);

  if (matchDateOnly != null) {
    const monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final monthName = matchDateOnly.group(1)!.toLowerCase().substring(0, 3);
    final month = monthMap[monthName];
    final day = int.tryParse(matchDateOnly.group(2)!);
    final year = int.tryParse(matchDateOnly.group(3)!);
    if (month != null && day != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}

String _formatShortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final year = (value.year % 100).toString().padLeft(2, '0');
  return '$month/$day/$year';
}

String _formatShortTime(DateTime value) {
  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'pm' : 'am';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute$period';
}

String _formatAttachmentDate(DateTime value) {
  const monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final month = monthAbbr[value.month - 1];
  final day = value.day.toString().padLeft(2, '0');
  return '$month $day, ${value.year}';
}

String _formatAttachmentTime(DateTime value) {
  final hour24 = value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'pm' : 'am';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final hour = hour12.toString().padLeft(2, '0');
  return '$hour:$minute$period';
}

class ProjectSectionModel {
  final int id;
  final String name;
  final int sortOrder;
  final String status;

  const ProjectSectionModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.status,
  });

  factory ProjectSectionModel.fromJson(Map<String, dynamic> json) {
    return ProjectSectionModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      sortOrder: _asInt(json['sort_order']),
      status: _asString(json['status']),
    );
  }
}

class ProjectTaskMember {
  final int id;
  final String name;
  final String image;

  const ProjectTaskMember({
    required this.id,
    required this.name,
    required this.image,
  });

  factory ProjectTaskMember.fromJson(Map<String, dynamic> json) {
    return ProjectTaskMember(
      id: _asInt(json['id'] ?? json['user_id']),
      name: _asString(json['name'] ?? json['title']),
      image: _asString(json['image'] ?? json['src']),
    );
  }
}

class ProjectTaskLabel {
  final int id;
  final String name;
  final String color;

  const ProjectTaskLabel({
    required this.id,
    required this.name,
    required this.color,
  });

  factory ProjectTaskLabel.fromJson(Map<String, dynamic> json) {
    return ProjectTaskLabel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      color: _asString(json['color']),
    );
  }

  Color get parsedColor {
    try {
      String c = color.replaceAll('#', '');
      if (c.length == 6) c = 'FF$c';
      return Color(int.parse(c, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class ProjectLabelModel {
  final int id;
  final String name;
  final String color;
  final int tasksCount;

  const ProjectLabelModel({
    required this.id,
    required this.name,
    required this.color,
    required this.tasksCount,
  });

  factory ProjectLabelModel.fromJson(Map<String, dynamic> json) {
    return ProjectLabelModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      color: _asString(json['color']),
      tasksCount: _asInt(json['tasks_count']),
    );
  }
}

List<ProjectLabelModel> projectLabelModelsFromJson(List list) => list
    .whereType<Map>()
    .map((item) => _asMap(item))
    .where((item) => item.isNotEmpty)
    .map(ProjectLabelModel.fromJson)
    .toList();

class ProjectTaskAttachment {
  final int id;
  final String name;
  final String url;
  final String thumbnailUrl;
  final String iconUrl;
  final bool isImage;
  final String createdAt;
  final String sizeText;
  final String uploadedByName;

  const ProjectTaskAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.thumbnailUrl,
    required this.iconUrl,
    required this.isImage,
    required this.createdAt,
    required this.sizeText,
    required this.uploadedByName,
  });

  factory ProjectTaskAttachment.fromJson(Map<String, dynamic> json) {
    final uploadedBy = _asMap(json['uploaded_by']);
    final uploader = _asMap(json['uploader']);
    final user = _asMap(json['user']);
    final createdBy = _asMap(json['created_by']);
    final owner = _asMap(json['owner']);

    return ProjectTaskAttachment(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      url: _asString(json['url']),
      thumbnailUrl: _asString(
        json['thumbnail_url'] ?? json['thumb_url'] ?? json['thumbnail'],
      ),
      iconUrl: _asString(json['icon_url'] ?? json['url']),
      isImage: json['is_image'] == true,
      createdAt: _asString(
        json['created_at'] ??
            json['uploaded_at'] ??
            json['date_time'] ??
            json['timestamp'],
      ),
      sizeText: _asString(json['size_text'] ?? json['size']),
      uploadedByName: _asString(
        json['uploaded_by_name'] ??
            json['user_name'] ??
            json['created_by_name'] ??
            json['owner_name'] ??
            uploadedBy['name'] ??
            uploadedBy['title'] ??
            uploader['name'] ??
            uploader['title'] ??
            user['name'] ??
            user['title'] ??
            createdBy['name'] ??
            createdBy['title'] ??
            owner['name'] ??
            owner['title'],
      ),
    );
  }

  String get displayMeta {
    String metaLabel = '';
    if (sizeText.trim().isNotEmpty) {
      metaLabel += sizeText.trim();
    }

    if (uploadedByName.trim().isNotEmpty) {
      if (metaLabel.isNotEmpty) metaLabel += ' | ';
      metaLabel += uploadedByName.trim();
    }

    final createdDateTime = _tryParseDateTime(createdAt);
    if (createdDateTime != null) {
      final date = _formatAttachmentDate(createdDateTime);
      final time = _formatAttachmentTime(createdDateTime);
      if (metaLabel.isNotEmpty) metaLabel += ' | ';
      metaLabel += '$date $time';
    } else if (createdAt.trim().isNotEmpty) {
      if (metaLabel.isNotEmpty) metaLabel += ' | ';
      metaLabel += createdAt.trim();
    }

    if (metaLabel.isEmpty) {
      return '15 mb | System Admin | Jan 21, 2026 12:00pm';
    }
    return metaLabel;
  }

  String get previewImageUrl {
    final preferred = thumbnailUrl.trim().isNotEmpty
        ? thumbnailUrl
        : iconUrl.trim().isNotEmpty
        ? iconUrl
        : url;
    return _normalizeRemoteUrl(preferred);
  }

  bool get hasImagePreview {
    if (isImage) return previewImageUrl.isNotEmpty;

    final source =
        '${name.toLowerCase()} ${thumbnailUrl.toLowerCase()} ${iconUrl.toLowerCase()} ${url.toLowerCase()}';
    return RegExp(
      r'\.(jpg|jpeg|png|gif|webp|bmp|heic|heif|svg)(\?|$)',
      caseSensitive: false,
    ).hasMatch(source);
  }
}

class ProjectTaskActivity {
  final String type;
  final String content;
  final String userName;
  final String userImage;
  final String createdAt;

  const ProjectTaskActivity({
    required this.type,
    required this.content,
    required this.userName,
    required this.userImage,
    required this.createdAt,
  });

  factory ProjectTaskActivity.fromJson(Map<String, dynamic> json) {
    return ProjectTaskActivity(
      type: _asString(json['type']),
      content: _asString(json['content']),
      userName: _asString(json['user_name']),
      userImage: _asString(json['user_image']),
      createdAt: _asString(json['created_at']),
    );
  }
}

class ProjectTaskModel {
  final int id;
  final int projectId;
  final String projectName;
  final String title;
  final String description;
  final String status;
  final String sectionName;
  final String statusKey;
  final int projectSectionId;
  final String dueDate;
  final int apiCommentsCount;
  final int apiAttachmentsCount;
  final List<ProjectTaskMember> members;
  final List<ProjectTaskLabel> labels;
  final List<ProjectTaskActivity> activities;
  final List<ProjectTaskAttachment> attachments;
  final bool isTaskSavedAsTemplate;

  const ProjectTaskModel({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.title,
    required this.description,
    required this.status,
    required this.sectionName,
    required this.statusKey,
    required this.projectSectionId,
    required this.dueDate,
    required this.apiCommentsCount,
    required this.apiAttachmentsCount,
    required this.members,
    required this.labels,
    required this.activities,
    required this.attachments,
    this.isTaskSavedAsTemplate = false,
  });

  factory ProjectTaskModel.fromJson(Map<String, dynamic> json) {
    final section = _asMap(json['section']);
    final project = _asMap(json['project']);
    return ProjectTaskModel(
      id: _asInt(json['id']),
      projectId: _asInt(
        json['project_id'] ?? project['numeric_id'] ?? project['id'],
      ),
      projectName: _asString(
        json['project_name'] ??
            json['projectName'] ??
            project['name'] ??
            project['project_name'] ??
            project['title'],
      ),
      title: _asString(json['title']),
      description: _asString(json['description']),
      status: _asString(json['status']),
      sectionName: _asString(section['name']),
      statusKey: _asString(json['status_key']),
      projectSectionId: _asInt(json['project_section_id']),
      dueDate: _asString(json['due_date']),
      apiCommentsCount: _asInt(json['comments_count']),
      apiAttachmentsCount: _asInt(json['attachments_count']),
      members: _listFromJson(
        json['members'],
        (item) => ProjectTaskMember.fromJson(item),
      ),
      labels: _listFromJson(
        json['labels'],
        (item) => ProjectTaskLabel.fromJson(item),
      ),
      activities: _listFromJson(
        json['activities'],
        (item) => ProjectTaskActivity.fromJson(item),
      ),
      attachments: _listFromJson(
        json['attachments'],
        (item) => ProjectTaskAttachment.fromJson(item),
      ),
      isTaskSavedAsTemplate: _asBool(
        json['is_task_saved_as_template'] ??
            json['is_saved_as_template'] ??
            json['is_template'] ??
            json['isTaskTemplate'] ??
            json['isSavedAsTemplate'],
      ),
    );
  }

  ProjectTaskModel copyWith({
    int? id,
    int? projectId,
    String? projectName,
    String? title,
    String? description,
    String? status,
    String? sectionName,
    String? statusKey,
    int? projectSectionId,
    String? dueDate,
    int? apiCommentsCount,
    int? apiAttachmentsCount,
    List<ProjectTaskMember>? members,
    List<ProjectTaskLabel>? labels,
    List<ProjectTaskActivity>? activities,
    List<ProjectTaskAttachment>? attachments,
    bool? isTaskSavedAsTemplate,
  }) {
    return ProjectTaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      sectionName: sectionName ?? this.sectionName,
      statusKey: statusKey ?? this.statusKey,
      projectSectionId: projectSectionId ?? this.projectSectionId,
      dueDate: dueDate ?? this.dueDate,
      apiCommentsCount: apiCommentsCount ?? this.apiCommentsCount,
      apiAttachmentsCount: apiAttachmentsCount ?? this.apiAttachmentsCount,
      members: members ?? this.members,
      labels: labels ?? this.labels,
      activities: activities ?? this.activities,
      attachments: attachments ?? this.attachments,
      isTaskSavedAsTemplate: isTaskSavedAsTemplate ?? this.isTaskSavedAsTemplate,
    );
  }

  int get commentsCount {
    final derived = activities
        .where((item) => item.type.trim().toLowerCase() == 'comment')
        .length;
    return apiCommentsCount > 0 ? apiCommentsCount : derived;
  }

  int get attachmentsCount {
    final derived = attachments.length;
    return apiAttachmentsCount > 0 ? apiAttachmentsCount : derived;
  }

  String get shortDescription =>
      description.trim().isNotEmpty ? description : title;

  DateTime? get dueDateParsed => _tryParseDateTime(dueDate);
}

class ProjectTaskCreateApiModel {
  final String tasksStore;
  final String tasksUpdate;
  final String tasksUpdatePost;
  final String taskTemplatesIndexGlobal;
  final String taskTemplatesShowGlobal;
  final String taskTemplatesIndexProject;
  final String taskTemplatesStoreProject;

  const ProjectTaskCreateApiModel({
    required this.tasksStore,
    required this.tasksUpdate,
    required this.tasksUpdatePost,
    required this.taskTemplatesIndexGlobal,
    required this.taskTemplatesShowGlobal,
    required this.taskTemplatesIndexProject,
    required this.taskTemplatesStoreProject,
  });

  factory ProjectTaskCreateApiModel.fromJson(Map<String, dynamic> json) {
    return ProjectTaskCreateApiModel(
      tasksStore: _asString(json['tasks_store']),
      tasksUpdate: _asString(json['tasks_update']),
      tasksUpdatePost: _asString(json['tasks_update_post']),
      taskTemplatesIndexGlobal: _asString(json['task_templates_index_global']),
      taskTemplatesShowGlobal: _asString(json['task_templates_show_global']),
      taskTemplatesIndexProject: _asString(
        json['task_templates_index_project'],
      ),
      taskTemplatesStoreProject: _asString(
        json['task_templates_store_project'],
      ),
    );
  }
}

class ProjectTaskCreateContext {
  final int projectId;
  final String projectName;
  final List<ProjectSectionModel> sectionOptions;
  final int selectedSectionId;
  final String selectedSectionName;
  final List<ProjectTaskMember> memberOptions;
  final List<int> selectedMemberIds;
  final List<ProjectTaskLabel> labelOptions;
  final List<ProjectTaskLabel> defaultLabels;
  final ProjectTaskCreateApiModel? api;

  const ProjectTaskCreateContext({
    required this.projectId,
    required this.projectName,
    required this.sectionOptions,
    required this.selectedSectionId,
    required this.selectedSectionName,
    required this.memberOptions,
    required this.selectedMemberIds,
    required this.labelOptions,
    required this.defaultLabels,
    required this.api,
  });

  ProjectTaskCreateContext copyWith({
    int? projectId,
    String? projectName,
    List<ProjectSectionModel>? sectionOptions,
    int? selectedSectionId,
    String? selectedSectionName,
    List<ProjectTaskMember>? memberOptions,
    List<int>? selectedMemberIds,
    List<ProjectTaskLabel>? labelOptions,
    List<ProjectTaskLabel>? defaultLabels,
    ProjectTaskCreateApiModel? api,
  }) {
    return ProjectTaskCreateContext(
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      sectionOptions: sectionOptions ?? this.sectionOptions,
      selectedSectionId: selectedSectionId ?? this.selectedSectionId,
      selectedSectionName: selectedSectionName ?? this.selectedSectionName,
      memberOptions: memberOptions ?? this.memberOptions,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      labelOptions: labelOptions ?? this.labelOptions,
      defaultLabels: defaultLabels ?? this.defaultLabels,
      api: api ?? this.api,
    );
  }

  factory ProjectTaskCreateContext.fromJson(Map<String, dynamic> json) {
    final apiJson = _asMap(json['api']);
    return ProjectTaskCreateContext(
      projectId: _asInt(json['projectId'] ?? json['project_id']),
      projectName: _asString(json['projectName'] ?? json['project_name']),
      sectionOptions: _listFromJson(
        json['sectionOptions'] ?? json['section_options'],
        ProjectSectionModel.fromJson,
      ),
      selectedSectionId: _asInt(
        json['selectedSectionId'] ?? json['selected_section_id'],
      ),
      selectedSectionName: _asString(
        json['selectedSectionName'] ?? json['selected_section_name'],
      ),
      memberOptions: _listFromJson(
        json['memberOptions'] ?? json['member_options'],
        ProjectTaskMember.fromJson,
      ),
      selectedMemberIds: _asList(
        json['selectedMemberIds'] ?? json['selected_member_ids'],
      ).map(_asInt).where((item) => item > 0).toList(),
      labelOptions: _listFromJson(
        json['labelOptions'] ?? json['label_options'],
        ProjectTaskLabel.fromJson,
      ),
      defaultLabels: _listFromJson(
        json['defaultLabels'] ?? json['default_labels'],
        ProjectTaskLabel.fromJson,
      ),
      api: apiJson.isEmpty ? null : ProjectTaskCreateApiModel.fromJson(apiJson),
    );
  }
}

class ProjectDetailModel {
  final ProjectModel project;
  final List<ProjectTaskModel> tasks;
  final List<ProjectSectionModel> sections;
  final ProjectTaskCreateContext? taskCreateContext;

  const ProjectDetailModel({
    required this.project,
    required this.tasks,
    required this.sections,
    this.taskCreateContext,
  });

  ProjectDetailModel copyWith({
    ProjectModel? project,
    List<ProjectTaskModel>? tasks,
    List<ProjectSectionModel>? sections,
    ProjectTaskCreateContext? taskCreateContext,
  }) {
    return ProjectDetailModel(
      project: project ?? this.project,
      tasks: tasks ?? this.tasks,
      sections: sections ?? this.sections,
      taskCreateContext: taskCreateContext ?? this.taskCreateContext,
    );
  }

  factory ProjectDetailModel.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']).isNotEmpty ? _asMap(json['data']) : json;
    final projectJson = _asMap(data['project']);
    final taskDetailsRaw = data['task_details'];
    final taskCreateContextJson = _asMap(data['task_create_context']);
    final sectionOptions = _asList(data['section_options']).isNotEmpty
        ? _asList(data['section_options'])
        : _asList(taskCreateContextJson['sectionOptions']).isNotEmpty
        ? _asList(taskCreateContextJson['sectionOptions'])
        : _asList(projectJson['sections']);

    final project = ProjectModel.fromJson(projectJson);
    final pId = project.numericId;

    final tasksRaw = _taskModelsFromRaw(data['tasks']).isNotEmpty
        ? _taskModelsFromRaw(data['tasks'])
        : _taskModelsFromRaw(taskDetailsRaw).isNotEmpty
        ? _taskModelsFromRaw(taskDetailsRaw)
        : _taskModelsFromRaw(projectJson['task_details']).isNotEmpty
        ? _taskModelsFromRaw(projectJson['task_details'])
        : _taskModelsFromRaw(projectJson['tasks']);

    final tasks = tasksRaw
        .map((t) => t.projectId == 0 ? t.copyWith(projectId: pId) : t)
        .toList();

    return ProjectDetailModel(
      project: project,
      tasks: tasks,
      sections: sectionOptions
          .whereType<Map>()
          .map((item) => _asMap(item))
          .where((item) => item.isNotEmpty)
          .map(ProjectSectionModel.fromJson)
          .toList(),
      taskCreateContext: taskCreateContextJson.isEmpty
          ? null
          : ProjectTaskCreateContext.fromJson(taskCreateContextJson),
    );
  }
}

List<T> _listFromJson<T>(
  dynamic raw,
  T Function(Map<String, dynamic> item) mapper,
) {
  return _asList(raw)
      .whereType<Map>()
      .map((item) => _asMap(item))
      .where((item) => item.isNotEmpty)
      .map(mapper)
      .toList();
}

List<ProjectTaskModel> _taskModelsFromRaw(dynamic raw) {
  final items = <Map<String, dynamic>>[];

  void collect(dynamic value) {
    if (value is List) {
      for (final item in value) {
        collect(item);
      }
      return;
    }

    if (value is! Map) return;

    final normalized = _asMap(value);
    if (normalized.isEmpty) return;

    final hasTaskFields =
        normalized['id'] != null &&
        (normalized['title'] != null || normalized['name'] != null);

    if (hasTaskFields) {
      items.add(normalized);
      return;
    }

    for (final nestedValue in normalized.values) {
      collect(nestedValue);
    }
  }

  collect(raw);

  return items
      .map(ProjectTaskModel.fromJson)
      .where((item) => item.id > 0)
      .toList();
}
