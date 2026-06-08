import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../constants/paths.dart';
import '../../../../models/projects_models.dart';
import '../../../../providers/project_pro.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/loaders.dart';
import '../../tab_widgets/tab_toasts.dart';
import '../../../../admin/projects/widgets/task_label_editor.dart';

class TabletTaskPreviewPopup {
  static Future<void> show(BuildContext context, ProjectTaskModel task) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Task preview',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        return _TabletTaskDialog(task: task);
      },
    );
  }
}

class _TabletTaskDialog extends StatefulWidget {
  final ProjectTaskModel task;

  const _TabletTaskDialog({required this.task});

  @override
  State<_TabletTaskDialog> createState() => _TabletTaskDialogState();
}

class _TabletTaskDialogState extends State<_TabletTaskDialog> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late ProjectTaskModel _task;
  Timer? _debounceTimer;
  bool _isRefreshing = false;
  bool _isSaving = false;
  ProjectModel? _projectInfo;

  bool get _isCreate => _task.id == 0;

  late String _selectedStatus;
  int? _selectedSectionId;
  DateTime? _selectedDueDate;
  Set<int> _selectedMemberIds = {};
  List<ProjectTaskMember> _availableMembers = [];
  List<TaskDraftLabel> _editableLabels = [];
  Set<int> _selectedLabelIds = {};

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _titleController.text = _task.title;
    _descriptionController.text = _task.description;

    _initData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isCreate) {
        _refreshTaskDetail();
        context.read<ProjectPro>().getTaskTemplates();
        context.read<ProjectPro>().getProjectBlueprintLibrary();
      }
    });
  }

  void _initData() {
    _selectedDueDate = _task.dueDateParsed;
    _selectedSectionId = _task.projectSectionId == 0
        ? null
        : _task.projectSectionId;
    _selectedStatus = _task.sectionName.trim().isEmpty
        ? _task.status
        : _task.sectionName;

    final pro = context.read<ProjectPro>();
    _availableMembers =
        pro.activeProjectDetail?.taskCreateContext?.memberOptions ??
        _task.members;

    if (_isCreate && _task.members.isEmpty) {
      final contextSelectedIds =
          pro.activeProjectDetail?.taskCreateContext?.selectedMemberIds ?? [];
      if (contextSelectedIds.isNotEmpty) {
        _selectedMemberIds = contextSelectedIds.toSet();
      } else {
        // Default to all available project members if no specific ones are suggested
        _selectedMemberIds = _availableMembers.map((m) => m.id).toSet();
      }
      // Sync local _task.members for UI immediate update
      _task = _task.copyWith(
        members: _availableMembers
            .where((m) => _selectedMemberIds.contains(m.id))
            .toList(),
      );
    } else {
      _selectedMemberIds = _task.members.map((m) => m.id).toSet();
    }

    _editableLabels = buildInitialTaskDraftLabels(
      projectLabels: pro.projectLabels,
      taskLabels: _task.labels,
    );
    _selectedLabelIds = _task.labels.map((l) => l.id).toSet();

    // Populate project info for the info popup
    final activeProject = pro.activeProjectDetail?.project;
    if (activeProject != null && activeProject.numericId == _task.projectId) {
      _projectInfo = activeProject;
    } else {
      for (final p in pro.projects) {
        if (p.numericId == _task.projectId) {
          _projectInfo = p;
          break;
        }
      }
    }
  }

  Future<void> _refreshTaskDetail() async {
    setState(() => _isRefreshing = true);
    try {
      final detail = await context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: _task.projectId,
        forceRefresh: true,
      );
      if (detail != null) {
        _projectInfo = detail.project;
        for (final item in detail.tasks) {
          if (item.id == _task.id) {
            _task = item;
            break;
          }
        }
        if (mounted) {
          setState(() {
            _titleController.text = _task.title;
            _descriptionController.text = _task.description;
            _initData();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _commentController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _immediateUpdate(Map<String, dynamic> payload) async {
    // Auto-save disabled during form editing; changes are saved only on close.
  }

  Future<void> _showMemberPicker(Offset offset) async {
    final options = _availableMembers;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // We use showMenu for simplicity, but with custom items to match design
    final selectedId = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        overlay.size.width - offset.dx,
        overlay.size.height - offset.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        PopupMenuItem<int>(
          value: -1, // Unassigned
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E8EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove,
                  size: 16,
                  color: Color(0xFF8C96A6),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Unassigned',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B4657),
                  ),
                ),
              ),
              if (_selectedMemberIds.isEmpty)
                const Icon(Icons.check, size: 18, color: Color(0xFFF8C906)),
            ],
          ),
        ),
        ...options.map((m) {
          final isSelected = _selectedMemberIds.contains(m.id);
          return PopupMenuItem<int>(
            value: m.id,
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: ImageWidget(
                      image: m.image.isEmpty ? Paths.user : m.image,
                      fit: BoxFit.cover,
                      showLoad: false,
                      errorWidget: ImageWidget(
                        image: Paths.user,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B4657),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 18, color: Color(0xFFF8C906)),
              ],
            ),
          );
        }),
      ],
    );

    if (selectedId != null && mounted) {
      setState(() {
        if (selectedId == -1) {
          _selectedMemberIds.clear();
        } else {
          if (_selectedMemberIds.contains(selectedId)) {
            _selectedMemberIds.remove(selectedId);
          } else {
            _selectedMemberIds.add(selectedId);
          }
        }

        // Sync local _task.members for UI immediate update
        _task = _task.copyWith(
          members: options
              .where((m) => _selectedMemberIds.contains(m.id))
              .toList(),
        );
      });

      await _immediateUpdate({'assigned_members': _selectedMemberIds.toList()});
    }
  }

  Future<bool> _handleSave({bool pop = true}) async {
    if (_isSaving) return false;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showToast(message: 'Please enter a task name');
      return false;
    }

    final formattedDueDate = _selectedDueDate != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDueDate!)
        : _task.dueDate;

    final payload = <String, dynamic>{
      'title': title,
      'description': _descriptionController.text.trim(),
      'project_section_id': _selectedSectionId,
      'due_date': formattedDueDate,
      'assigned_members': _selectedMemberIds.toList(),
      'label_ids': _selectedLabelIds.toList(),
    };

    final pro = context.read<ProjectPro>();

    // Optimistically update the task in the provider before the API call
    if (!_isCreate) {
      pro.optimisticUpdateTask(
        taskId: _task.id,
        updatedTask: _task.copyWith(
          title: payload['title'],
          description: payload['description'],
          dueDate: payload['due_date'],
          projectSectionId: payload['project_section_id'],
          sectionName: _selectedStatus,
          status: _selectedStatus,
        ),
      );
    }

    if (mounted) setState(() => _isSaving = true);

    bool success = false;
    if (_isCreate) {
      success = await pro.createProjectTask(
        projectId: _task.projectId,
        payload: payload,
      );
    } else {
      success = await pro.updateProjectTask(
        projectId: _task.projectId,
        taskId: _task.id,
        payload: payload,
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        await _refreshTaskDetail();
        if (pop && mounted) Navigator.of(context).pop();
      }
    }
    return success;
  }

  void _onFieldChanged() {
    // Intermediate saves disabled; changes are committed on form close.
  }

  Future<void> _onClose() async {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showProjectInfoPopup(
    BuildContext ctx,
    ProjectModel project, {
    required Offset anchor,
  }) async {
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
    const popupWidth = 310.0;
    final left = (anchor.dx - popupWidth + 22)
        .clamp(12.0, overlay.size.width - popupWidth - 12);
    final top = (anchor.dy + 8).clamp(12.0, overlay.size.height - 260);

    final progressPercent = project.displayProgressPercent;
    final progressValue = (progressPercent.clamp(0, 100)) / 100.0;
    final progressState = project.displayStatus.toUpperCase();

    await showGeneralDialog<void>(
      context: ctx,
      barrierLabel: 'Project info',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, __) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: SizedBox(
                  width: popupWidth,
                  child: _buildProjectInfoCard(
                    dialogContext,
                    project,
                    progressPercent: progressPercent,
                    progressValue: progressValue,
                    progressState: progressState,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectInfoCard(
    BuildContext dialogContext,
    ProjectModel project, {
    required int progressPercent,
    required double progressValue,
    required String progressState,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF202226),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.popupMetaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A8D95),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 20, color: Color(0xFF2C2D30)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoChip(
                            'Customer: ${project.customerDisplayName}',
                            background: const Color(0xFFFFF3CC),
                            foreground: const Color(0xFFC28A00),
                          ),
                          const SizedBox(height: 10),
                          _infoChip(
                            'Client: ${project.clientDisplayName}',
                            background: const Color(0xFFE9F1FF),
                            foreground: const Color(0xFF0C58D6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _buildAvatarRow(project.avatars),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE9E9ED),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF28A2E)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$progressPercent% $progressState',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF28A2E),
                            ),
                          ),
                          const Text('|', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD2D3D8))),
                          Text(
                            'Late tasks ${project.lateTasksCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE45843),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _metricBadge(Icons.checklist_rounded, project.tasksCount),
                    const SizedBox(width: 12),
                    _metricBadge(Icons.chat_bubble_outline, project.commentsCount),
                    const SizedBox(width: 12),
                    _metricBadge(Icons.attach_file, project.attachmentsCount),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String label, {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: foreground)),
    );
  }

  Widget _buildAvatarRow(List<String> avatars) {
    const size = 28.0;
    const overlap = 12.0;
    const maxVisible = 5;
    final visible = avatars.take(maxVisible).toList();
    final extra = avatars.length - maxVisible;
    final totalWidth = size + (visible.length - 1) * (size - overlap) + (extra > 0 ? (size - overlap) : 0);
    return SizedBox(
      height: size,
      width: totalWidth,
      child: Stack(
        children: [
          ...List.generate(visible.length, (i) {
            final url = visible[i];
            return Positioned(
              left: i * (size - overlap),
              child: CircleAvatar(
                radius: size / 2,
                backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
                backgroundColor: const Color(0xFFE0E2E8),
                child: url.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.grey) : null,
              ),
            );
          }),
          if (extra > 0)
            Positioned(
              left: visible.length * (size - overlap),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: const Color(0xFFE0E2E8),
                child: Text('+$extra', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF555B6E))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricBadge(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8F9199)),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555B6E))),
      ],
    );
  }


  Future<void> _showTemplatePicker(Offset globalPosition) async {
    final pro = context.read<ProjectPro>();
    final templates = await pro.getTaskTemplates(forceRefresh: true);
    if (templates.isEmpty) {
      showToast(message: 'No templates found');
      return;
    }

    if (!mounted) return;

    final selected = await showGeneralDialog<ProjectTaskTemplateModel>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Template Picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return _TemplatePickerPopup(
          templates: templates,
          position: globalPosition,
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _titleController.text = selected.name;
      });
      _onFieldChanged();
    }
  }

  Future<void> _showLabelPicker(Offset globalPosition) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Label Picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return _LabelPickerPopup(
          position: globalPosition,
          labels: _editableLabels,
          selectedLabelIds: _selectedLabelIds,
          onChanged: () async {
            final newLabels = _editableLabels
                .where((l) => _selectedLabelIds.contains(l.id))
                .map(
                  (l) => ProjectTaskLabel(
                    id: l.id,
                    name: l.name,
                    color: l.colorHex,
                  ),
                )
                .toList();
            setState(() {
              _task = _task.copyWith(labels: newLabels);
            });
            await _immediateUpdate({'label_ids': _selectedLabelIds.toList()});
          },
        );
      },
    );
  }

  Future<void> _saveAsTemplate() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showToast(message: 'Please enter a task name');
      return;
    }

    Loaders.show();
    final success = await context.read<ProjectPro>().saveTaskAsTemplate(
      taskId: _task.id,
      name: title,
    );
    Loaders.hide();

    if (success) {
      showToast(message: 'Task saved as template');
      if (mounted) {
        setState(() {
          _task = _task.copyWith(isTaskSavedAsTemplate: true);
        });
      }
    } else {
      showToast(message: 'Failed to save template');
    }
  }

  Future<void> _onDeleteTask() async {
    final pro = context.read<ProjectPro>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      Loaders.show();
      final success = await pro.deleteProjectTask(
        projectId: _task.projectId,
        taskId: _task.id,
      );
      Loaders.hide();

      if (success && mounted) {
        Navigator.pop(context);
        pro.getProjectDetail(
          ctx: context,
          projectId: _task.projectId,
          forceRefresh: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.68).clamp(700.0, 980.0);
    final dialogHeight = (size.height * 0.78).clamp(480.0, 620.0);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {},
      child: SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                  const Divider(height: 1, color: Color(0xFFE7E9EE)),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(flex: 6, child: _buildLeftPane()),
                        const VerticalDivider(
                          width: 1,
                          color: Color(0xFFE7E9EE),
                        ),
                        Expanded(flex: 5, child: _buildRightPane()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final pro = context.watch<ProjectPro>();
    final isAlreadyTemplate =
        _task.isTaskSavedAsTemplate ||
        pro.taskTemplates.any((t) => t.sourceTaskId == _task.id) ||
        pro.projectBlueprints.any((t) => t.sourceTaskId == _task.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          const Text(
            'Status:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202735),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTapDown: (details) async {
              final sections =
                  context.read<ProjectPro>().activeProjectDetail?.sections ??
                  [];
              if (sections.isEmpty) return;

              final selected = await showMenu<ProjectSectionModel>(
                context: context,
                color: Colors.white,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                position: RelativeRect.fromLTRB(
                  details.globalPosition.dx,
                  details.globalPosition.dy + 20,
                  details.globalPosition.dx,
                  details.globalPosition.dy + 20,
                ),
                items: sections
                    .map(
                      (s) => PopupMenuItem(
                        value: s,
                        child: Text(
                          s.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
              );

              if (selected != null && mounted) {
                setState(() {
                  _selectedSectionId = selected.id;
                  _selectedStatus = selected.name;
                });
                await _immediateUpdate({'project_section_id': selected.id});
              }
            },
            child: Row(
              children: [
                Text(
                  _selectedStatus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Color(0xFF8C96A6),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_isCreate) ...[
            _buildTemplateButton(
              icon: Icons.assignment_outlined,
              label: 'Template',
              onTap: (pos) => _showTemplatePicker(pos),
            ),
            const SizedBox(width: 10),
          ],
          if (!isAlreadyTemplate && !_isCreate) ...[
            _buildTemplateButton(
              icon: Icons.save_outlined,
              label: 'Save as Template',
              onTap: (_) => _saveAsTemplate(),
              isPrimary: true,
            ),
            const SizedBox(width: 10),
          ],

          if (!_isCreate) ...[
            InkWell(
              onTap: _onDeleteTask,
              child: Image.asset(
                Paths.delete,
                width: 15,
                height: 15,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 10),
          ],
          GestureDetector(
            onTapDown: (details) {
              final project = _projectInfo;
              if (project == null) return;
              _showProjectInfoPopup(context, project, anchor: details.globalPosition);
            },
            child: const Icon(Icons.info_outline, size: 18, color: Color(0xFF1F2733)),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _isSaving ? null : () async {
              final success = await _handleSave(pop: false);
              if (success && mounted) {
                showToast(message: 'Task saved successfully');
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _isSaving ? const Color(0xFF2563EB).withValues(alpha: 0.7) : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPane() {
    final dueText = _selectedDueDate == null
        ? 'No due date'
        : DateFormat(
            'MMM d, yyyy | h:mma',
          ).format(_selectedDueDate!).toLowerCase();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151C2A),
            ),
            onChanged: (v) => _onFieldChanged(),
            decoration: const InputDecoration(
              hintText: 'Task Name',
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC1C7D0),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4C5565),
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: '* ',
                            style: TextStyle(color: Color(0xFFEA4335)),
                          ),
                          TextSpan(text: 'Members'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MembersRow(
                      members: _task.members,
                      onAddTap: _showMemberPicker,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4C5565),
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: '* ',
                            style: TextStyle(color: Color(0xFFEA4335)),
                          ),
                          TextSpan(text: 'Due Date'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _selectedDueDate ?? DateTime.now(),
                            ),
                          );
                          if (time != null && mounted) {
                            final finalDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            setState(() => _selectedDueDate = finalDate);
                            if (!_isCreate) {
                              final formattedForApi =
                                  '${finalDate.day.toString().padLeft(2, '0')}-${finalDate.month.toString().padLeft(2, '0')}-${finalDate.year}';
                              await _immediateUpdate({
                                'due_date': formattedForApi,
                              });
                            }
                          }
                        }
                      },
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: const Color(0xFFD4D9E2)),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_outlined,
                              color: Color(0xFF6C778A),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dueText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5D6B80),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Color(0xFF6C778A),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2C3240),
              ),
              children: [
                TextSpan(text: 'Description '),
                TextSpan(
                  text: '(optional)',
                  style: TextStyle(
                    color: Color(0xFF8A95A7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD4D9E2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: null,
              onChanged: (v) => _onFieldChanged(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4D5361),
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '-',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3240),
                  ),
                  children: [
                    TextSpan(text: 'Label '),
                    TextSpan(
                      text: '(optional)',
                      style: TextStyle(
                        color: Color(0xFF8A95A7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _task.labels
                      .map(
                        (label) => _LabelChip(
                          label: label,
                          onRemove: () async {
                            _selectedLabelIds.remove(label.id);
                            setState(() {
                              _task = _task.copyWith(
                                labels: _task.labels
                                    .where((l) => l.id != label.id)
                                    .toList(),
                              );
                            });
                            await _immediateUpdate({
                              'label_ids': _selectedLabelIds.toList(),
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              GestureDetector(
                onTapDown: (details) =>
                    _showLabelPicker(details.globalPosition),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6E8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFF5D6B80),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              const Icon(Icons.attach_file, color: Color(0xFF8A95A7), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C3240),
                ),
              ),
              if (_isRefreshing) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2D6DE8),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final pro = context.read<ProjectPro>();
                  final res = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                  );
                  if (res == null || res.files.isEmpty) return;

                  final filePaths = res.files
                      .map((f) => f.path ?? '')
                      .where((p) => p.isNotEmpty)
                      .toList();
                  final fileNames = res.files.map((f) => f.name).toList();

                  if (filePaths.isNotEmpty) {
                    Loaders.show();
                    await pro.updateProjectTask(
                      projectId: _task.projectId,
                      taskId: _task.id,
                      payload: {},
                      filePaths: filePaths,
                      fileNames: fileNames,
                      fileKeys: List.generate(
                        filePaths.length,
                        (_) => 'attachments[]',
                      ),
                    );
                    Loaders.hide();
                    _refreshTaskDetail();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D6DE8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AttachmentList(
            attachments: _task.attachments,
            isRefreshing: _isRefreshing,
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 20, 14),
      child: Column(
        children: [
          TextField(
            controller: _commentController,
            minLines: 3,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: const TextStyle(
                color: Color(0xFF8A95A7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE2EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE2EB)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                final comment = _commentController.text.trim();
                if (comment.isEmpty) return;

                Loaders.show();
                final didSave = await context
                    .read<ProjectPro>()
                    .updateProjectTask(
                      projectId: _task.projectId,
                      taskId: _task.id,
                      payload: {'activity_comment': comment},
                    );
                Loaders.hide();
                if (didSave) {
                  _commentController.clear();
                  _refreshTaskDetail();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6DE8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE8EAF0)),
          const SizedBox(height: 10),
          Expanded(
            child: _task.activities.isEmpty
                ? const Center(
                    child: Text(
                      'No activity yet',
                      style: TextStyle(
                        color: Color(0xFF9199A8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _task.activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _task.activities[index];
                      return _ActivityTile(activity: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateButton({
    required IconData icon,
    required String label,
    required Function(Offset) onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (details) => onTap(details.globalPosition),
        onTap: () {}, // Trigger splash
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF5C59E8)
                : const Color(0xFFF3F4F7),
            borderRadius: BorderRadius.circular(8),
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFE1E3E8)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? Colors.white : const Color(0xFF4D5361),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : const Color(0xFF4D5361),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersRow extends StatelessWidget {
  final List<ProjectTaskMember> members;
  final Function(Offset) onAddTap;

  const _MembersRow({required this.members, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    final shown = members.take(4).toList();
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: i * 20, child: _avatar(shown[i])),
          Positioned(
            left:
                (shown.length * 20.0).clamp(0.0, 80.0) +
                (shown.isEmpty ? 0 : 2),
            child: GestureDetector(
              onTapDown: (details) => onAddTap(details.globalPosition),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8C906),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.add, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(ProjectTaskMember member) {
    final url = member.image.trim();
    return Container(
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF8C906), width: 1.4),
      ),
      child: ClipOval(
        child: ImageWidget(
          image: (url.isEmpty || url.toLowerCase() == 'null')
              ? Paths.user
              : url,
          fit: BoxFit.cover,
          showLoad: false,
          errorWidget: ImageWidget(image: Paths.user, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final ProjectTaskLabel label;
  final VoidCallback? onRemove;

  const _LabelChip({required this.label, this.onRemove});

  @override
  Widget build(BuildContext context) {
    Color chipColor = const Color(0xFF7F8A9C);
    if (label.color.isNotEmpty) {
      final buffer = StringBuffer();
      if (label.color.length == 6 || label.color.length == 7) {
        buffer.write('ff');
      }
      buffer.write(label.color.replaceFirst('#', ''));
      final val = int.tryParse(buffer.toString(), radix: 16);
      if (val != null) chipColor = Color(val);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  final List<ProjectTaskAttachment> attachments;
  final bool isRefreshing;

  const _AttachmentList({
    required this.attachments,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      if (isRefreshing) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDE2EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D6DE8)),
              ),
            ),
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE2EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No attachments',
            style: TextStyle(
              color: Color(0xFF9199A8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      children: attachments.map((item) => _buildItem(item)).toList(),
    );
  }

  Widget _buildItem(ProjectTaskAttachment item) {
    final imageUrl = item.previewImageUrl;
    final hasImagePreview = item.hasImagePreview && imageUrl.trim().isNotEmpty;
    final metaLabel = item.displayMeta;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF1F3F5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: hasImagePreview
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ImageWidget(
                      image: imageUrl,
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      showLoad: false,
                    ),
                  )
                : ImageWidget(
                    image: _fileIconPath(item.name),
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    showLoad: false,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C3240),
                  ),
                ),
                if (metaLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A95A7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.more_vert,
              size: 16,
              color: Color(0xFF383C43),
            ),
          ),
        ],
      ),
    );
  }

  String _fileIconPath(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.psd')) return Paths.psd;
    if (lower.endsWith('.pdf')) return Paths.pdf;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Paths.docx;
    if (lower.endsWith('.txt')) return Paths.txt;
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return Paths.zip;
    if (lower.contains('folder')) return Paths.folder;
    return Paths.foldr;
  }
}

class _ActivityTile extends StatelessWidget {
  final ProjectTaskActivity activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final hasAvatar = activity.userImage.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: SizedBox(
            width: 30,
            height: 30,
            child: ImageWidget(
              image: hasAvatar ? activity.userImage.trim() : Paths.user,
              fit: BoxFit.cover,
              showLoad: false,
              errorWidget: ImageWidget(image: Paths.user, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3B4657),
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: activity.userName.trim().isEmpty
                          ? 'User'
                          : activity.userName.trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF202A38),
                      ),
                    ),
                    TextSpan(text: ' ${activity.content.trim()}'),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activity.createdAt.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9199A8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TemplatePickerPopup extends StatefulWidget {
  final List<ProjectTaskTemplateModel> templates;
  final Offset position;

  const _TemplatePickerPopup({required this.templates, required this.position});

  @override
  State<_TemplatePickerPopup> createState() => _TemplatePickerPopupState();
}

class _TemplatePickerPopupState extends State<_TemplatePickerPopup> {
  String _searchQuery = '';
  late List<ProjectTaskTemplateModel> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.templates;
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q.toLowerCase();
      _filtered = widget.templates.where((t) {
        return t.name.toLowerCase().contains(_searchQuery) ||
            t.projectName.toLowerCase().contains(_searchQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomInset = viewInsets.bottom;
    final size = MediaQuery.of(context).size;

    // Position the popup relative to the tap position, but keeping it within bounds
    double left = widget.position.dx - 230;
    if (left < 20) left = 10;

    double top = widget.position.dy + 10;
    const estimatedHeight = 240.0;

    // Shift up if keyboard is open and obscures the popup
    if (top + estimatedHeight > size.height - bottomInset) {
      top = size.height - bottomInset - estimatedHeight - 10;
    }
    if (top < 10) top = 10;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      onChanged: _onSearch,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search templates...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2D6DE8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2D6DE8),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No results',
                              style: TextStyle(color: Color(0xFF9CA3AF)),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              itemCount: _filtered.length,
                              separatorBuilder: (ctx, i) => const Divider(
                                height: 1,
                                color: Color(0xFFF9FAFB),
                              ),
                              itemBuilder: (ctx, i) {
                                final t = _filtered[i];
                                return InkWell(
                                  onTap: () => Navigator.pop(context, t),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                t.name,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                t.projectName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9CA3AF),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            // Edit template logic
                                            showToast(message: 'Edit template');
                                          },
                                          child: Image.asset(
                                            Paths.edit,
                                            width: 15,
                                            height: 15,
                                            color: const Color(0xFF6B7280),
                                          ),
                                        ),

                                        IconButton(
                                          onPressed: () async {
                                            final ok = await context
                                                .read<ProjectPro>()
                                                .deleteTaskTemplate(
                                                  templateId: t.id,
                                                );
                                            if (ok) {
                                              setState(() {
                                                widget.templates.removeWhere(
                                                  (item) => item.id == t.id,
                                                );
                                                _onSearch(_searchQuery);
                                              });
                                            }
                                          },
                                          icon: Image.asset(
                                            Paths.delete,
                                            width: 15,
                                            height: 15,
                                            color: const Color(0xFFEF4444),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabelPickerPopup extends StatefulWidget {
  final Offset position;
  final List<TaskDraftLabel> labels;
  final Set<int> selectedLabelIds;
  final VoidCallback onChanged;

  const _LabelPickerPopup({
    required this.position,
    required this.labels,
    required this.selectedLabelIds,
    required this.onChanged,
  });

  @override
  State<_LabelPickerPopup> createState() => _LabelPickerPopupState();
}

class _LabelPickerPopupState extends State<_LabelPickerPopup> {
  final TextEditingController _controller = TextEditingController();
  String _selectedColorHex = '#EF4444';
  bool _isCreating = false;

  final List<String> _colors = [
    '#EF4444', // Red
    '#F59E0B', // Orange
    '#FBBF24', // Yellow
    '#10B981', // Green
    '#3B82F6', // Blue
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#6B7280', // Grey
  ];

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomInset = viewInsets.bottom;
    final size = MediaQuery.of(context).size;

    double left = widget.position.dx - 260;
    if (left < 10) left = 10;

    double top = widget.position.dy + 10;
    const estimatedHeight = 320.0;

    // Shift up if keyboard is open and obscures the popup
    if (top + estimatedHeight > size.height - bottomInset) {
      top = size.height - bottomInset - estimatedHeight - 10;
    }
    if (top < 10) top = 10;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: widget.labels.length,
                      itemBuilder: (ctx, i) {
                        final l = widget.labels[i];
                        final isSelected = widget.selectedLabelIds.contains(
                          l.id,
                        );
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                widget.selectedLabelIds.remove(l.id);
                              } else {
                                widget.selectedLabelIds.add(l.id);
                              }
                            });
                            widget.onChanged();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _colorFromHex(l.colorHex),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Color(0xFF2D6DE8),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colors.map((hex) {
                        final isSelected = _selectedColorHex == hex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColorHex = hex),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _colorFromHex(hex),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'New label',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isCreating
                              ? null
                              : () async {
                                  final name = _controller.text.trim();
                                  if (name.isEmpty) return;
                                  setState(() => _isCreating = true);
                                  final created = await context
                                      .read<ProjectPro>()
                                      .createProjectLabel(
                                        name: name,
                                        colorHex: _selectedColorHex,
                                      );
                                  if (created != null && mounted) {
                                    final newLabel = TaskDraftLabel(
                                      id: created.id,
                                      name: created.name,
                                      colorHex: created.color,
                                    );
                                    widget.labels.add(newLabel);
                                    widget.selectedLabelIds.add(created.id);
                                    _controller.clear();
                                    widget.onChanged();
                                  }
                                  if (mounted) {
                                    setState(() => _isCreating = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: const Color(0xFF1F2937),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF1F2937),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
