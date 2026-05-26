import re
import sys

def main():
    path = r"d:\Development Projects\GITHUB\printHelper\lib\tablet_view\lib\tab_projects\widgets\tablet_task_preview_popup.dart"
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # 1. Imports
    text = text.replace("import 'package:flutter/material.dart';\nimport 'package:intl/intl.dart';", 
"""import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../../providers/project_pro.dart';
import '../../../../widgets/loaders.dart';
import '../../../../widgets/toasts.dart';
import '../../../../admin/projects/widgets/task_label_editor.dart';""")

    # 2. State definition and init
    old_state = """class _TabletTaskDialogState extends State<_TabletTaskDialog> {
  final TextEditingController _commentController = TextEditingController();
  late final String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.sectionName.trim().isEmpty
        ? widget.task.status
        : widget.task.sectionName;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }"""
    
    new_state = """class _TabletTaskDialogState extends State<_TabletTaskDialog> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late ProjectTaskModel _task;
  Timer? _debounceTimer;

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
      if (mounted) _refreshTaskDetail();
    });
  }

  void _initData() {
    _selectedDueDate = _parseDueDate(_task.dueDate);
    _selectedSectionId = _task.projectSectionId == 0 ? null : _task.projectSectionId;
    _selectedStatus = _task.sectionName.trim().isEmpty ? _task.status : _task.sectionName;
    _selectedMemberIds = _task.members.map((m) => m.id).toSet();
    
    final pro = context.read<ProjectPro>();
    _availableMembers = pro.activeProjectDetail?.taskCreateContext?.memberOptions ?? _task.members;
    _editableLabels = buildInitialTaskDraftLabels(
      projectLabels: pro.projectLabels,
      taskLabels: _task.labels,
    );
    _selectedLabelIds = _task.labels.map((l) => l.id).toSet();
  }

  Future<void> _refreshTaskDetail() async {
    try {
      final detail = await context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: _task.projectId,
        forceRefresh: true,
      );
      if (detail != null) {
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
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _commentController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _debouncedUpdate(Map<String, dynamic> payload) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        context.read<ProjectPro>().updateProjectTask(
          projectId: _task.projectId,
          taskId: _task.id,
          payload: payload,
        );
      }
    });
  }
  
  Future<void> _immediateUpdate(Map<String, dynamic> payload) async {
    await context.read<ProjectPro>().updateProjectTask(
      projectId: _task.projectId,
      taskId: _task.id,
      payload: payload,
    );
  }"""
    text = text.replace(old_state, new_state)

    # 3. Header _buildHeader
    text = text.replace("""          Row(
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
              const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF8C96A6)),
            ],
          ),""", """          GestureDetector(
            onTapDown: (details) async {
              final sections = context.read<ProjectPro>().activeProjectDetail?.sections ?? [];
              if (sections.isEmpty) return;

              final selected = await showMenu<ProjectSectionModel>(
                context: context,
                position: RelativeRect.fromLTRB(
                    details.globalPosition.dx, details.globalPosition.dy + 20, 100, 100),
                items: sections.map((s) => PopupMenuItem(
                  value: s,
                  child: Text(s.name, style: const TextStyle(fontSize: 14)),
                )).toList(),
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
                const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF8C96A6)),
              ],
            ),
          ),""")

    text = text.replace("""          const SizedBox(width: 14),
          const Icon(Icons.delete_outline, size: 18, color: Color(0xFF1F2733)),""", """          const SizedBox(width: 14),
          GestureDetector(
            onTap: () async {
              Loaders.show();
              final success = await context.read<ProjectPro>().deleteProjectTask(
                projectId: _task.projectId,
                taskId: _task.id,
              );
              Loaders.hide();
              if (success && mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF1F2733)),
          ),""")

    # 4. _buildLeftPane
    text = text.replace("""  Widget _buildLeftPane() {
    final dueText = _formatDueDate(widget.task.dueDate);""", """  Widget _buildLeftPane() {
    final dueText = _selectedDueDate == null 
        ? 'No due date' 
        : DateFormat('MMM d, yyyy | h:mma').format(_selectedDueDate!).toLowerCase();""")

    text = text.replace("""          Text(
            widget.task.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151C2A),
            ),
          ),""", """          TextField(
            controller: _titleController,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF151C2A),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) {
              if (val.trim() != _task.title) {
                _debouncedUpdate({'title': val.trim()});
              }
            },
          ),""")

    text = text.replace("""_MembersRow(members: widget.task.members)""", """_MembersRow(members: _task.members)""")

    text = text.replace("""                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD4D9E2)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(""", """                    GestureDetector(
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
                            initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? DateTime.now()),
                          );
                          if (time != null && mounted) {
                            final finalDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            setState(() => _selectedDueDate = finalDate);
                            final formattedForApi = '${finalDate.day.toString().padLeft(2, '0')}-${finalDate.month.toString().padLeft(2, '0')}-${finalDate.year}';
                            await _immediateUpdate({'due_date': formattedForApi, 'assigned_members': _selectedMemberIds.toList()});
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
                        child: Row(""")
    
    text = text.replace("""                          const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6C778A)),
                        ],
                      ),
                    ),
                  ],""", """                          const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6C778A)),
                        ],
                      ),
                    ),
                    ),
                  ],""")

    text = text.replace("""            child: Text(
              widget.task.description.trim().isEmpty
                  ? '-'
                  : widget.task.description.trim(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222B38),
              ),
            ),""", """            child: TextField(
              controller: _descriptionController,
              maxLines: null,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222B38),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '-',
              ),
              onChanged: (val) {
                if (val.trim() != _task.description) {
                  _debouncedUpdate({'description': val.trim()});
                }
              },
            ),""")

    text = text.replace("""                  children: widget.task.labels
                      .map((label) => _LabelChip(label: label))
                      .toList(),""", """                  children: _task.labels
                      .map((label) => _LabelChip(
                            label: label, 
                            onRemove: () async {
                              _selectedLabelIds.remove(label.id);
                              setState(() {
                                _task = _task.copyWith(
                                  labels: _task.labels.where((l) => l.id != label.id).toList(),
                                );
                              });
                              await _immediateUpdate({'label_ids': _selectedLabelIds.toList()});
                            }
                          ))
                      .toList(),""")

    text = text.replace("""              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6E8EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 16, color: Color(0xFF5D6B80)),
              ),""", """              GestureDetector(
                onTap: () async {
                  await showTaskLabelEditorDialog(
                    context: context,
                    labels: _editableLabels,
                    selectedLabelIds: _selectedLabelIds,
                    onChanged: () async {
                      final newLabels = _editableLabels
                          .where((l) => _selectedLabelIds.contains(l.id))
                          .map((l) => ProjectTaskLabel(id: l.id, name: l.name, color: l.colorHex))
                          .toList();
                      setState(() {
                        _task = _task.copyWith(labels: newLabels);
                      });
                      await _immediateUpdate({'label_ids': _selectedLabelIds.toList()});
                    },
                    colorFromHex: (hex) {
                      final buffer = StringBuffer();
                      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
                      buffer.write(hex.replaceFirst('#', ''));
                      return Color(int.parse(buffer.toString(), radix: 16));
                    },
                    onCreateLabel: (name, colorHex) async {
                      final created = await context.read<ProjectPro>().createProjectLabel(name: name, colorHex: colorHex);
                      if (created == null) return null;
                      return TaskDraftLabel(id: created.id, name: created.name, colorHex: created.color);
                    },
                    onDeleteLabel: (labelId) async {
                      return context.read<ProjectPro>().deleteProjectLabel(labelId: labelId);
                    },
                  );
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6E8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Color(0xFF5D6B80)),
                ),
              ),""")

    text = text.replace("""              Container(
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
              ),""", """              GestureDetector(
                onTap: () async {
                  final res = await FilePicker.platform.pickFiles(allowMultiple: true);
                  if (res == null || res.files.isEmpty) return;
                  
                  final filePaths = res.files.map((f) => f.path ?? '').where((p) => p.isNotEmpty).toList();
                  final fileNames = res.files.map((f) => f.name).toList();
                  
                  if (filePaths.isNotEmpty) {
                    Loaders.show();
                    await context.read<ProjectPro>().updateProjectTask(
                      projectId: _task.projectId,
                      taskId: _task.id,
                      payload: {},
                      filePaths: filePaths,
                      fileNames: fileNames,
                      fileKeys: List.generate(filePaths.length, (_) => 'attachments[]'),
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
              ),""")

    text = text.replace("_AttachmentList(attachments: widget.task.attachments)", "_AttachmentList(attachments: _task.attachments)")

    # 5. Right pane saves
    text = text.replace("""          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
          ),""", """          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                final comment = _commentController.text.trim();
                if (comment.isEmpty) return;
                
                Loaders.show();
                final didSave = await context.read<ProjectPro>().updateProjectTask(
                  projectId: _task.projectId,
                  taskId: _task.id,
                  payload: { 'activity_comment': comment },
                );
                Loaders.hide();
                if (didSave) {
                  _commentController.clear();
                  _refreshTaskDetail();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
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
          ),""")

    text = text.replace("""widget.task.activities.isEmpty""", """_task.activities.isEmpty""")
    text = text.replace("""widget.task.activities.length""", """_task.activities.length""")
    text = text.replace("""widget.task.activities[index]""", """_task.activities[index]""")

    # 6. Parse Due Date function overwrite
    text = text.replace("""  String _formatDueDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return value.trim().isEmpty ? 'No due date' : value;
    return DateFormat('MMM d, yyyy | h:mma').format(parsed).toLowerCase();
  }""", """  DateTime? _parseDueDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct.toLocal();
    final normalizedIso = value.contains('T') ? value : value.replaceFirst(' ', 'T');
    final isoTry = DateTime.tryParse(normalizedIso);
    if (isoTry != null) return isoTry.toLocal();
    return null;
  }""")

    # 7. Add onRemove to LabelChip
    text = text.replace("""class _LabelChip extends StatelessWidget {
  final ProjectTaskLabel label;

  const _LabelChip({required this.label});""", """class _LabelChip extends StatelessWidget {
  final ProjectTaskLabel label;
  final VoidCallback? onRemove;

  const _LabelChip({required this.label, this.onRemove});""")
    
    text = text.replace("""          const Icon(Icons.close, size: 12, color: Colors.white),""", """          GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 12, color: Colors.white)),""")


    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

if __name__ == "__main__":
    main()
