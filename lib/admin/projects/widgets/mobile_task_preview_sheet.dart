import 'dart:async';

import 'package:flutter/cupertino.dart'; // DEBUG
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../constants/paths.dart';
import '../../../models/projects_models.dart';
import '../../../providers/project_pro.dart';
import '../../../widgets/loaders.dart';
import '../../../widgets/image_widget.dart';
import '../../../widgets/toasts.dart';
import 'package:file_picker/file_picker.dart';
import 'task_label_editor.dart';
import '../../../services/download_service.dart';

enum _TaskPreviewTab { details, comments }

class MobileTaskPreviewSheet {
  static Future<void> show(
    BuildContext context,
    ProjectTaskModel initialTask,
  ) async {
    var task = initialTask;
    ProjectModel? projectInfo;

    final activeProject = context
        .read<ProjectPro>()
        .activeProjectDetail
        ?.project;
    if (activeProject != null && activeProject.numericId == task.projectId) {
      projectInfo = activeProject;
    }

    if (projectInfo == null) {
      for (final project in context.read<ProjectPro>().projects) {
        if (project.numericId == task.projectId) {
          projectInfo = project;
          break;
        }
      }
    }

    final commentController = TextEditingController();
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    Timer? debounceTimer;

    bool isRefreshing = true;
    bool refreshStarted = false;
    bool isSaving = false;
    _TaskPreviewTab selectedTab = _TaskPreviewTab.details;
    DateTime? selectedDueDate = _parseDueDate(task.dueDate);
    int? selectedSectionId = task.projectSectionId == 0
        ? null
        : task.projectSectionId;
    String selectedStatus = _taskStatusText(task);
    final selectedMemberIds = <int>{
      for (final member in task.members) member.id,
    };
    List<ProjectTaskMember> availableMembers =
        context
            .read<ProjectPro>()
            .activeProjectDetail
            ?.taskCreateContext
            ?.memberOptions ??
        task.members;
    List<TaskDraftLabel> editableLabels = buildInitialTaskDraftLabels(
      projectLabels: context.read<ProjectPro>().projectLabels,
      taskLabels: task.labels,
    );
    final selectedLabelIds = <int>{for (final label in task.labels) label.id};

    Future<void> refreshTaskDetail(StateSetter setSheetState) async {
      setSheetState(() => isRefreshing = true);

      try {
        final detail = await context.read<ProjectPro>().getProjectDetail(
          ctx: context,
          projectId: initialTask.projectId,
          forceRefresh: true,
        );

        if (detail != null) {
          projectInfo = detail.project;

          for (final item in detail.tasks) {
            if (item.id == initialTask.id) {
              task = item;
              break;
            }
          }

          titleController.text = task.title;
          descriptionController.text = task.description;
          selectedDueDate = _parseDueDate(task.dueDate);
          selectedSectionId = task.projectSectionId == 0
              ? null
              : task.projectSectionId;
          selectedStatus = _taskStatusText(task);

          selectedMemberIds
            ..clear()
            ..addAll(task.members.map((member) => member.id));

          availableMembers =
              context
                  .read<ProjectPro>()
                  .activeProjectDetail
                  ?.taskCreateContext
                  ?.memberOptions ??
              task.members;

          editableLabels = buildInitialTaskDraftLabels(
            projectLabels: context.read<ProjectPro>().projectLabels,
            taskLabels: task.labels,
          );

          selectedLabelIds
            ..clear()
            ..addAll(task.labels.map((label) => label.id));
        }
      } catch (_) {
        // Keep fallback to the tapped snapshot when refresh fails.
      }

      if (context.mounted) {
        setSheetState(() => isRefreshing = false);
      }
    }

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Task preview',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                if (!refreshStarted) {
                  refreshStarted = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (dialogContext.mounted) {
                      refreshTaskDetail(setSheetState);
                    }
                  });
                }

                return Material(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.only(top: 2.h),
                        width: MediaQuery.of(context).size.width - 18.w,
                        constraints: BoxConstraints(maxWidth: 410.w),
                        child: SizedBox(
                          height:
                              MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              10.h,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(
                                    8.w,
                                    8.h,
                                    8.w,
                                    8.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14.w),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          14.w,
                                          12.h,
                                          14.w,
                                          8.h,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: titleController,
                                                maxLines: null,
                                                style: TextStyle(
                                                  fontSize: 14.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF1D1F24,
                                                  ),
                                                  height: 1.2,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                                onChanged: (text) {
                                                  debounceTimer?.cancel();
                                                  debounceTimer = Timer(
                                                    const Duration(
                                                      milliseconds: 1500,
                                                    ),
                                                    () {
                                                      if (text.trim() !=
                                                          task.title) {
                                                        context
                                                            .read<ProjectPro>()
                                                            .updateProjectTask(
                                                              projectId: task
                                                                  .projectId,
                                                              taskId: task.id,
                                                              payload: {
                                                                'title': text
                                                                    .trim(),
                                                              },
                                                            );
                                                      }
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                final shouldDelete = await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) =>
                                                      AlertDialog(
                                                        backgroundColor:
                                                            Colors.white,
                                                        surfaceTintColor:
                                                            Colors.transparent,
                                                        title: const Text(
                                                          'Delete task',
                                                        ),
                                                        content: const Text(
                                                          'Are you sure you want to delete this task? This action cannot be undone.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(false),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  dialogContext,
                                                                ).pop(true),
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color: Color(
                                                                  0xFFE45B45,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );

                                                if (shouldDelete == true) {
                                                  Loaders.show();
                                                  final success = await context
                                                      .read<ProjectPro>()
                                                      .deleteProjectTask(
                                                        projectId:
                                                            task.projectId,
                                                        taskId: task.id,
                                                      );
                                                  Loaders.hide();
                                                  if (success) {
                                                    debounceTimer?.cancel();
                                                    if (dialogContext.mounted) {
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();
                                                    }
                                                  }
                                                }
                                              },
                                              child: Container(
                                                width: 20.w,
                                                height: 20.h,
                                                alignment: Alignment.center,
                                                child: ImageWidget(
                                                  image: Paths.delete,
                                                  width: 14,
                                                  height: 14,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            GestureDetector(
                                              onTapDown: (details) {
                                                final project = projectInfo ??
                                                    context.read<ProjectPro>().activeProjectDetail?.project;
                                                if (project == null) return;
                                                _showProjectInfoPopup(
                                                  context,
                                                  project,
                                                  anchor: details.globalPosition,
                                                );
                                              },
                                              child: _buildTaskPreviewSheetIcon(
                                                CupertinoIcons.info,
                                                const Color(0xFF22252B),
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            // Save Button
                                            GestureDetector(
                                              onTap: isSaving ? null : () async {
                                                final title = titleController.text.trim();
                                                if (title.isEmpty) {
                                                  showToast(message: 'Please enter a task name');
                                                  return;
                                                }
                                                final payload = <String, dynamic>{
                                                  'title': title,
                                                  'description': descriptionController.text.trim(),
                                                  'project_section_id': selectedSectionId,
                                                  'assigned_members': selectedMemberIds.toList(),
                                                };
                                                setSheetState(() => isSaving = true);
                                                try {
                                                  final pro = dialogContext.read<ProjectPro>();
                                                  final isCreate = task.id == 0;
                                                  bool success = false;
                                                  if (isCreate) {
                                                    success = await pro.createProjectTask(
                                                      projectId: task.projectId,
                                                      payload: payload,
                                                    );
                                                  } else {
                                                    success = await pro.updateProjectTask(
                                                      projectId: task.projectId,
                                                      taskId: task.id,
                                                      payload: payload,
                                                    );
                                                  }
                                                  if (success) {
                                                    debounceTimer?.cancel();
                                                    showToast(message: 'Task saved successfully');
                                                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                                  }
                                                } finally {
                                                  if (dialogContext.mounted) setSheetState(() => isSaving = false);
                                                }
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                                decoration: BoxDecoration(
                                                  color: isSaving
                                                      ? const Color(0xFF2563EB).withValues(alpha: 0.7)
                                                      : const Color(0xFF2563EB),
                                                  borderRadius: BorderRadius.circular(7.w),
                                                ),
                                                child: isSaving
                                                    ? SizedBox(
                                                        width: 12.w,
                                                        height: 12.h,
                                                        child: const CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : Text(
                                                        'Save',
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16.h),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Status:',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF2F3138),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                GestureDetector(
                                                  onTapDown: (details) async {
                                                    final sections =
                                                        dialogContext
                                                            .read<ProjectPro>()
                                                            .activeProjectDetail
                                                            ?.sections ??
                                                        const <
                                                          ProjectSectionModel
                                                        >[];
                                                    if (sections.isEmpty) return;

                                                    await _showSectionPicker(
                                                      context,
                                                      sections,
                                                      selectedSectionId,
                                                      details.globalPosition,
                                                      (section) {
                                                        if (!dialogContext
                                                            .mounted) {
                                                          return;
                                                        }
                                                        setSheetState(() {
                                                          selectedSectionId =
                                                              section.id;
                                                          selectedStatus =
                                                              section.name;
                                                          // Optimistically update the task model
                                                          task = task.copyWith(
                                                            projectSectionId:
                                                                section.id,
                                                            sectionName:
                                                                section.name,
                                                          );
                                                        });
                                                        dialogContext
                                                            .read<ProjectPro>()
                                                            .updateProjectTask(
                                                              projectId:
                                                                  task.projectId,
                                                              taskId: task.id,
                                                              payload: {
                                                                'project_section_id':
                                                                    section.id,
                                                              },
                                                            );
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 24.h,
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 10.w,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999.w,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFE0E2E8,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          selectedStatus,
                                                          style: TextStyle(
                                                            fontSize: 11.sp,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: const Color(
                                                              0xFF232731,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(width: 5.w),
                                                        Icon(
                                                          CupertinoIcons
                                                              .chevron_down,
                                                          size: 10.sp,
                                                          color: const Color(
                                                            0xFF737985,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Builder(
                                                  builder: (context) {
                                                    final pro = context.watch<ProjectPro>();
                                                    final isAlreadyTemplate = task.isTaskSavedAsTemplate ||
                                                        pro.taskTemplates.any((t) => t.sourceTaskId == task.id) ||
                                                    pro.projectBlueprints.any((t) => t.sourceTaskId == task.id);
                                                    if (task.id > 0 && !isAlreadyTemplate) {
                                                      return Padding(
                                                        padding: EdgeInsets.only(left: 8.w),
                                                        child: InkWell(
                                                          onTap: () {
                                                            _showSaveTaskTemplateDialog(
                                                              context: context,
                                                              task: task,
                                                              baseTitle: titleController.text.trim(),
                                                              onTaskUpdated: (updatedTask) {
                                                                setSheetState(() {
                                                                  task = updatedTask;
                                                                });
                                                              },
                                                            );
                                                          },
                                                          borderRadius: BorderRadius.circular(8.w),
                                                          child: Container(
                                                            padding: EdgeInsets.symmetric(
                                                              horizontal: 10.w,
                                                              vertical: 6.h,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF4C4AE8),
                                                              borderRadius: BorderRadius.circular(8.w),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  CupertinoIcons.doc_on_clipboard,
                                                                  size: 11.sp,
                                                                  color: Colors.white,
                                                                ),
                                                                SizedBox(width: 5.w),
                                                                Text(
                                                                  'Save as Template',
                                                                  style: TextStyle(
                                                                    fontSize: 10.sp,
                                                                    fontWeight: FontWeight.w700,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: 6.h),
                                      Expanded(
                                        child:
                                            selectedTab ==
                                                _TaskPreviewTab.details
                                            ? Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  14.w,
                                                  0,
                                                  14.w,
                                                  10.h,
                                                ),
                                                child: _buildTaskPreviewDetailsContent(
                                                  task,
                                                  dialogContext: dialogContext,
                                                  setSheetState: setSheetState,
                                                  onTaskUpdated: (updatedTask) {
                                                    setSheetState(() {
                                                      task = updatedTask;
                                                    });
                                                  },
                                                  onAddAttachment: () async {
                                                    final pickedFiles =
                                                        await _pickAttachmentFiles();
                                                    if (pickedFiles.isEmpty) {
                                                      return;
                                                    }

                                                    final filePaths =
                                                        <String>[];
                                                    final fileNames =
                                                        <String>[];
                                                    for (final file
                                                        in pickedFiles) {
                                                      final path =
                                                          file.path?.trim() ??
                                                          '';
                                                      if (path.isEmpty) {
                                                        continue;
                                                      }
                                                      filePaths.add(path);
                                                      fileNames.add(file.name);
                                                    }

                                                    if (filePaths.isEmpty) {
                                                      showToast(
                                                        message:
                                                            'Unable to access selected file paths',
                                                      );
                                                      return;
                                                    }

                                                    Loaders.show();
                                                    try {
                                                      final didUpload =
                                                          await dialogContext
                                                              .read<
                                                                ProjectPro
                                                              >()
                                                              .updateProjectTask(
                                                                projectId: task
                                                                    .projectId,
                                                                taskId: task.id,
                                                                payload: {},
                                                                filePaths:
                                                                    filePaths,
                                                                fileNames:
                                                                    fileNames,
                                                                fileKeys: List.generate(
                                                                  filePaths
                                                                      .length,
                                                                  (_) =>
                                                                      'attachments[]',
                                                                ),
                                                              );
                                                      if (didUpload) {
                                                        final detail =
                                                            await dialogContext
                                                                .read<
                                                                  ProjectPro
                                                                >()
                                                                .getProjectDetail(
                                                                  ctx:
                                                                      dialogContext,
                                                                  projectId: task
                                                                      .projectId,
                                                                  forceRefresh:
                                                                      true,
                                                                );
                                                        if (detail != null) {
                                                          final refreshedTask =
                                                              detail.tasks
                                                                  .where(
                                                                    (item) =>
                                                                        item.id ==
                                                                        task.id,
                                                                  )
                                                                  .firstOrNull;
                                                          if (refreshedTask !=
                                                              null) {
                                                            if (!dialogContext
                                                                .mounted) {
                                                              return;
                                                            }
                                                            setSheetState(
                                                              () => task =
                                                                  refreshedTask,
                                                            );
                                                          }
                                                        }
                                                      }
                                                    } finally {
                                                      Loaders.hide();
                                                    }
                                                  },
                                                  dueText: _formatDueDateText(
                                                    selectedDueDate,
                                                  ),
                                                  labels: editableLabels,
                                                  selectedLabelIds:
                                                      selectedLabelIds,
                                                  selectedMemberIds:
                                                      selectedMemberIds,
                                                  availableMembers:
                                                      availableMembers,
                                                  selectedDueDate:
                                                      selectedDueDate,
                                                  onDueDateChanged: (date) {
                                                    setSheetState(
                                                      () => selectedDueDate =
                                                          date,
                                                    );
                                                    final formatted =
                                                        MobileTaskPreviewSheet._formatDueDateText(
                                                          date,
                                                          forApi: true,
                                                        );
                                                    dialogContext
                                                        .read<ProjectPro>()
                                                        .updateProjectTask(
                                                          projectId:
                                                              task.projectId,
                                                          taskId: task.id,
                                                          payload: {
                                                            'due_date':
                                                                formatted,
                                                            'assigned_members':
                                                                selectedMemberIds
                                                                    .toList(),
                                                          },
                                                        );
                                                  },
                                                  descriptionController:
                                                      descriptionController,
                                                  onDescriptionChanged: (text) {
                                                    debounceTimer?.cancel();
                                                    debounceTimer = Timer(
                                                      const Duration(
                                                        milliseconds: 1500,
                                                      ),
                                                      () {
                                                        if (!dialogContext
                                                            .mounted) {
                                                          return;
                                                        }
                                                        if (text.trim() !=
                                                            task.description) {
                                                          dialogContext
                                                              .read<
                                                                ProjectPro
                                                              >()
                                                              .updateProjectTask(
                                                                projectId: task
                                                                    .projectId,
                                                                taskId: task.id,
                                                                payload: {
                                                                  'description':
                                                                      text.trim(),
                                                                },
                                                              );
                                                        }
                                                      },
                                                    );
                                                  },
                                                  onMembersChanged: () {
                                                    final selectedDue =
                                                        selectedDueDate;
                                                    final duePayload =
                                                        selectedDue == null
                                                        ? task.dueDate
                                                        : MobileTaskPreviewSheet._formatDueDateText(
                                                            selectedDue,
                                                            forApi: true,
                                                          );
                                                    dialogContext
                                                        .read<ProjectPro>()
                                                        .updateProjectTask(
                                                          projectId:
                                                              task.projectId,
                                                          taskId: task.id,
                                                          payload: {
                                                            'due_date':
                                                                duePayload,
                                                            'assigned_members':
                                                                selectedMemberIds
                                                                    .toList(),
                                                          },
                                                        );
                                                  },
                                                  onLabelsChanged: () async {
                                                    // Optimistically update local UI state
                                                    final newLabels = editableLabels
                                                        .where(
                                                          (l) =>
                                                              selectedLabelIds
                                                                  .contains(
                                                                    l.id,
                                                                  ),
                                                        )
                                                        .map(
                                                          (l) =>
                                                              ProjectTaskLabel(
                                                                id: l.id,
                                                                name: l.name,
                                                                color:
                                                                    l.colorHex,
                                                              ),
                                                        )
                                                        .toList();

                                                    setSheetState(() {
                                                      task = task.copyWith(
                                                        labels: newLabels,
                                                      );
                                                    });

                                                    // Perform API update in background
                                                    if (!dialogContext
                                                        .mounted) {
                                                      return;
                                                    }
                                                    await dialogContext
                                                        .read<ProjectPro>()
                                                        .updateProjectTask(
                                                          projectId:
                                                              task.projectId,
                                                          taskId: task.id,
                                                          payload: {
                                                            'label_ids':
                                                                selectedLabelIds
                                                                    .toList(),
                                                          },
                                                        );
                                                  },
                                                ),
                                              )
                                            : Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                  14.w,
                                                  0,
                                                  14.w,
                                                  10.h,
                                                ),
                                                child: _buildTaskPreviewCommentsContent(
                                                  task,
                                                  commentController,
                                                  onSave: () async {
                                                    final comment =
                                                        commentController.text
                                                            .trim();
                                                    if (comment.isEmpty) {
                                                      showToast(
                                                        message:
                                                            'Please enter a comment',
                                                      );
                                                      return;
                                                    }

                                                    Loaders.show();
                                                    final didSave =
                                                        await dialogContext
                                                            .read<ProjectPro>()
                                                            .updateProjectTask(
                                                              projectId: task
                                                                  .projectId,
                                                              taskId: task.id,
                                                              payload: {
                                                                'activity_comment':
                                                                    comment,
                                                              },
                                                            );
                                                    if (didSave) {
                                                      commentController.clear();
                                                      final detail =
                                                          await dialogContext
                                                              .read<
                                                                ProjectPro
                                                              >()
                                                              .getProjectDetail(
                                                                ctx:
                                                                    dialogContext,
                                                                projectId: task
                                                                    .projectId,
                                                                forceRefresh:
                                                                    true,
                                                              );
                                                      if (detail != null) {
                                                        final refreshedTask =
                                                            detail.tasks
                                                                .where(
                                                                  (item) =>
                                                                      item.id ==
                                                                      task.id,
                                                                )
                                                                .firstOrNull;
                                                        if (refreshedTask !=
                                                            null) {
                                                          if (!dialogContext
                                                              .mounted) {
                                                            return;
                                                          }
                                                          setSheetState(
                                                            () => task =
                                                                refreshedTask,
                                                          );
                                                        }
                                                      }
                                                    }
                                                    Loaders.hide();
                                                  },
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  0,
                                  16.w,
                                  MediaQuery.of(context).padding.bottom > 0
                                      ? MediaQuery.of(context).padding.bottom
                                      : 55.h,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTaskPreviewFooterTab(
                                        label: 'Details',
                                        selected:
                                            selectedTab ==
                                            _TaskPreviewTab.details,
                                        onTap: () => setSheetState(
                                          () => selectedTab =
                                              _TaskPreviewTab.details,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: _buildTaskPreviewFooterTab(
                                        label: 'Comments',
                                        selected:
                                            selectedTab ==
                                            _TaskPreviewTab.comments,
                                        onTap: () => setSheetState(
                                          () => selectedTab =
                                              _TaskPreviewTab.comments,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isRefreshing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14.w),
                            ),
                            child: Center(child: showLoader()),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    commentController.dispose();
  }

  /// Opens the same task sheet UI but in creation mode — empty fields,
  /// a "Create" action instead of live-editing, and no delete button.
  static Future<void> showCreate(
    BuildContext context, {
    required int projectId,
    List<ProjectSectionModel> sections = const [],
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Create task',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _CreateTaskSheetContent(
          projectId: projectId,
          originalContext: context,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<void> _showProjectInfoPopup(
    BuildContext context,
    ProjectModel project, {
    required Offset anchor,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final horizontalMargin = 12.w;
    final popupWidth = (overlay.size.width - horizontalMargin * 2)
        .clamp(280.w, 400.w)
        .toDouble();
    final left = (anchor.dx - popupWidth + 22.w)
        .clamp(
          horizontalMargin,
          overlay.size.width - popupWidth - horizontalMargin,
        )
        .toDouble();
    final top = (anchor.dy + 8.h)
        .clamp(12.h, overlay.size.height - 220.h)
        .toDouble();

    final progressPercent = project.displayProgressPercent;
    final progressValue = (progressPercent.clamp(0, 100)) / 100;
    final progressState = project.displayStatus.toUpperCase();

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Project info',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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
                  child: _buildProjectInfoPopupCard(
                    dialogContext,
                    project,
                    progressPercent: progressPercent,
                    progressValue: progressValue.toDouble(),
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

  static Widget _buildProjectInfoPopupCard(
    BuildContext dialogContext,
    ProjectModel project, {
    required int progressPercent,
    required double progressValue,
    required String progressState,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24.w,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 14.h),
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
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF202226),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        project.popupMetaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8A8D95),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  borderRadius: BorderRadius.circular(999.w),
                  child: Padding(
                    padding: EdgeInsets.all(2.w),
                    child: Icon(
                      Icons.close,
                      size: 24.sp,
                      color: const Color(0xFF2C2D30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7E7EB)),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 16.h),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProjectInfoPill(
                            label: 'Customer: ${project.customerDisplayName}',
                            backgroundColor: const Color(0xFFFFF3CC),
                            foregroundColor: const Color(0xFFC28A00),
                          ),
                          SizedBox(height: 10.h),
                          _buildProjectInfoPill(
                            label: 'Client: ${project.clientDisplayName}',
                            backgroundColor: const Color(0xFFE9F1FF),
                            foregroundColor: const Color(0xFF0C58D6),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14.w),
                    _buildAvatarStrip(project.avatars),
                  ],
                ),
                SizedBox(height: 16.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999.w),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 5.h,
                    backgroundColor: const Color(0xFFE9E9ED),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF28A2E),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 6.h,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$progressPercent% $progressState',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF28A2E),
                            ),
                          ),
                          Text(
                            '|',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFD2D3D8),
                            ),
                          ),
                          Text(
                            'Late tasks ${project.lateTasksCount}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFE45843),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _buildProjectInfoMetric(
                      Icons.checklist_rounded,
                      project.tasksCount,
                    ),
                    SizedBox(width: 12.w),
                    _buildProjectInfoMetric(
                      CupertinoIcons.chat_bubble_text,
                      project.commentsCount,
                    ),
                    SizedBox(width: 12.w),
                    _buildProjectInfoMetric(
                      CupertinoIcons.paperclip,
                      project.attachmentsCount,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildProjectInfoMetric(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.sp, color: const Color(0xFF8F9199)),
        SizedBox(width: 4.w),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8F9199),
          ),
        ),
      ],
    );
  }

  static Widget _buildProjectInfoPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  /// Details content for task creation — same layout as edit but no
  /// auto-save debouncing, just local state.
  static Widget _buildCreateTaskDetailsContent({
    required BuildContext dialogContext,
    required void Function(void Function()) setSheetState,
    required String dueText,
    required List<TaskDraftLabel> labels,
    required Set<int> selectedLabelIds,
    required Set<int> selectedMemberIds,
    required List<ProjectTaskMember> availableMembers,
    required List<PlatformFile> selectedFiles,
    DateTime? selectedDueDate,
    required Function(DateTime) onDueDateChanged,
    required TextEditingController descriptionController,
    String? dueDateError,
    String? memberError,
    VoidCallback? onMemberErrorClear,
  }) {
    final selectedMembers = availableMembers
        .where((m) => selectedMemberIds.contains(m.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '* Members',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Builder(
                    builder: (context) {
                      final shown = selectedMembers.take(4).toList();
                      const avatarSize = 24.0;
                      final avatarSizeW = avatarSize.w;
                      final avatarSizeH = avatarSize.h;
                      final overlap = 14.w;
                      final addSizeW = 24.w;
                      final addSizeH = 24.h;
                      final stackWidth =
                          shown.length * overlap +
                          (shown.isNotEmpty ? avatarSizeW : 0) +
                          addSizeW +
                          4.w;

                      return SizedBox(
                        width: stackWidth,
                        height: 26.h,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int index = 0; index < shown.length; index++)
                              Positioned(
                                left: index * overlap,
                                child: Container(
                                  width: avatarSizeW,
                                  height: avatarSizeH,
                                  padding: EdgeInsets.all(1.3.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFCB04),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: ImageWidget(
                                      image: shown[index].image,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: shown.isNotEmpty
                                  ? shown.length * overlap
                                  : 0,
                              child: GestureDetector(
                                onTapDown: (details) {
                                  _showMemberPicker(
                                    dialogContext,
                                    availableMembers,
                                    selectedMemberIds,
                                    details.globalPosition,
                                    () {
                                      setSheetState(() {});
                                      onMemberErrorClear?.call();
                                    },
                                  );
                                },
                                child: Container(
                                  width: addSizeW,
                                  height: addSizeH,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFCB04),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    CupertinoIcons.add,
                                    size: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (memberError != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      memberError,
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD93025),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '* Due Date',
                    style: TextStyle(
                      fontSize: 8.8.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  InkWell(
                    onTap: () async {
                      final picked = await _pickDueDateTime(
                        dialogContext,
                        selectedDueDate,
                      );
                      if (picked == null) return;
                      onDueDateChanged(picked);
                    },
                    borderRadius: BorderRadius.circular(999.w),
                    child: Container(
                      height: 26.h,
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F5),
                        borderRadius: BorderRadius.circular(999.w),
                        border: Border.all(
                          color: dueDateError != null
                              ? const Color(0xFFD93025)
                              : const Color(0xFFE5E7ED),
                          width: dueDateError != null ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 12.sp,
                            color: dueDateError != null
                                ? const Color(0xFFD93025)
                                : const Color(0xFF8B9099),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              dueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.6.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF626770),
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 11.sp,
                            color: const Color(0xFF747A85),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (dueDateError != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      dueDateError,
                      style: TextStyle(
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD93025),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          'Description (optional)',
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5A606A),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 76.h,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(10.w),
            border: Border.all(color: const Color(0xFFDCDDDF)),
          ),
          child: TextFormField(
            controller: descriptionController,
            maxLines: null,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3138),
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Add task description',
              hintStyle: TextStyle(
                fontSize: 10.sp,
                color: const Color(0xFF909399),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Text(
              'Label (optional)',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A606A),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildTaskPreviewLabels(
                labels,
                selectedLabelIds,
                () => setSheetState(() {}),
              ),
            ),
            SizedBox(width: 6.w),
            InkWell(
              onTap: () async {
                await showTaskLabelEditorDialog(
                  context: dialogContext,
                  labels: labels,
                  selectedLabelIds: selectedLabelIds,
                  onChanged: () => setSheetState(() {}),
                  colorFromHex: _colorFromHex,
                  onCreateLabel: (name, colorHex) async {
                    final created = await dialogContext
                        .read<ProjectPro>()
                        .createProjectLabel(name: name, colorHex: colorHex);
                    if (created == null) return null;
                    return TaskDraftLabel(
                      id: created.id,
                      name: created.name,
                      colorHex: created.color,
                    );
                  },
                  onDeleteLabel: (labelId) async {
                    return dialogContext.read<ProjectPro>().deleteProjectLabel(
                      labelId: labelId,
                    );
                  },
                );
              },
              borderRadius: BorderRadius.circular(999.w),
              child: Container(
                width: 20.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8EC),
                  borderRadius: BorderRadius.circular(999.w),
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.add, size: 11.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Icon(
              CupertinoIcons.paperclip,
              size: 12.sp,
              color: const Color(0xFF8D919A),
            ),
            SizedBox(width: 6.w),
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A606A),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () async {
                final pickedFiles = await _pickAttachmentFiles();
                if (pickedFiles.isEmpty) return;

                final existingPaths = selectedFiles
                    .map((item) => item.path?.trim() ?? '')
                    .where((path) => path.isNotEmpty)
                    .toSet();

                var addedCount = 0;
                for (final file in pickedFiles) {
                  final path = file.path?.trim() ?? '';
                  if (path.isEmpty || existingPaths.contains(path)) continue;
                  existingPaths.add(path);
                  selectedFiles.add(file);
                  addedCount++;
                }

                if (addedCount == 0) {
                  showToast(message: 'No new attachments selected');
                  return;
                }

                setSheetState(() {});
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                width: 62.w,
                height: 30.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E63DC),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+ Add',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        if (selectedFiles.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.paperclip,
                    size: 32.sp,
                    color: const Color(0xFFDCDDE2),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No attachments selected.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF909399),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedFiles.length,
            itemBuilder: (context, index) {
              final file = selectedFiles[index];
              return ListTile(
                dense: true,
                leading: Icon(CupertinoIcons.doc, size: 20.sp),
                title: Text(file.name, style: TextStyle(fontSize: 11.sp)),
                trailing: IconButton(
                  icon: const Icon(
                    CupertinoIcons.delete,
                    color: Colors.red,
                    size: 16,
                  ),
                  onPressed: () {
                    setSheetState(() {
                      selectedFiles.removeAt(index);
                    });
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  /// Empty comments placeholder for create mode.
  static Widget _buildEmptyCommentsContent(
    TextEditingController commentController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        Container(
          height: 66.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.w),
            border: Border.all(color: const Color(0xFFDCDDDF)),
          ),
          child: TextField(
            controller: commentController,
            decoration: InputDecoration.collapsed(
              hintText: 'Write a comment...',
              hintStyle: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFF909399),
              ),
            ),
            style: TextStyle(fontSize: 11.sp),
          ),
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 64.w,
            height: 24.h,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 0,
                backgroundColor: const Color(0xFF0E63DC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.w),
                ),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 40.h),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 40.sp,
                color: const Color(0xFFDCDDE2),
              ),
              SizedBox(height: 12.h),
              Text(
                'No comments yet.',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF909399),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'The first comment will be added as activity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: const Color(0xFFAAB0BB),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Picks members from an anchored popup panel.
  static Future<void> _showMemberPicker(
    BuildContext context,
    List<ProjectTaskMember> options,
    Set<int> selectedIds,
    Offset anchor,
    VoidCallback onChanged,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final popupWidth = (176.w).clamp(150.0, overlay.size.width - 16.w);
    final left = (anchor.dx - popupWidth + 22.w).clamp(
      8.w,
      overlay.size.width - popupWidth - 8.w,
    );
    final top = (anchor.dy + 8.h).clamp(12.h, overlay.size.height - 260.h);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Assign members',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, _) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final maxListHeight = 200.h;

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
                    width: popupWidth,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: const Color(0xFFD7DBE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxListHeight),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            InkWell(
                              onTap: () {
                                selectedIds.clear();
                                setPopupState(() {});
                                onChanged();
                              },
                              borderRadius: BorderRadius.circular(8.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 7.h,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24.w,
                                      height: 24.h,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE6E9EF),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        CupertinoIcons.minus,
                                        size: 11.sp,
                                        color: const Color(0xFF7D8594),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'Unassigned',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF3D4451),
                                        ),
                                      ),
                                    ),
                                    if (selectedIds.isEmpty)
                                      Icon(
                                        CupertinoIcons.checkmark,
                                        size: 14.sp,
                                        color: const Color(0xFFFFCB04),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            for (final member in options)
                              InkWell(
                                onTap: () {
                                  if (selectedIds.contains(member.id)) {
                                    selectedIds.remove(member.id);
                                  } else {
                                    selectedIds.add(member.id);
                                  }
                                  setPopupState(() {});
                                  onChanged();
                                },
                                borderRadius: BorderRadius.circular(8.r),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 7.h,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24.w,
                                        height: 24.h,
                                        padding: EdgeInsets.all(1.w),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: ImageWidget(
                                            image: member.image,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          member.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF3D4451),
                                          ),
                                        ),
                                      ),
                                      if (selectedIds.contains(member.id))
                                        Icon(
                                          CupertinoIcons.checkmark,
                                          size: 14.sp,
                                          color: const Color(0xFFFFCB04),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Picks a section from an anchored popup menu.
  static Future<void> _showSectionPicker(
    BuildContext context,
    List<ProjectSectionModel> sections,
    int? currentId,
    Offset anchor,
    void Function(ProjectSectionModel) onPicked,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<ProjectSectionModel>(
      context: context,
      color: Colors.white,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(anchor.dx, anchor.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: sections
          .map(
            (section) => PopupMenuItem<ProjectSectionModel>(
              value: section,
              height: 38.h,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: section.id == currentId
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF2B2F36),
                      ),
                    ),
                  ),
                  if (section.id == currentId)
                    Icon(
                      CupertinoIcons.check_mark,
                      size: 14.sp,
                      color: const Color(0xFF0E63DC),
                    ),
                ],
              ),
            ),
          )
          .toList(),
    );

    if (selected != null) {
      onPicked(selected);
    }
  }

  static Widget _buildTaskPreviewDetailsContent(
    ProjectTaskModel task, {
    required BuildContext dialogContext,
    required void Function(void Function()) setSheetState,
    required Future<void> Function() onAddAttachment,
    required String dueText,
    required List<TaskDraftLabel> labels,
    required Set<int> selectedLabelIds,
    required Set<int> selectedMemberIds,
    required List<ProjectTaskMember> availableMembers,
    DateTime? selectedDueDate,
    required Function(DateTime) onDueDateChanged,
    required TextEditingController descriptionController,
    required Function(String) onDescriptionChanged,
    required VoidCallback onMembersChanged,
    required Future<void> Function() onLabelsChanged,
    required void Function(ProjectTaskModel) onTaskUpdated,
  }) {
    final selectedMembers = availableMembers
        .where((member) => selectedMemberIds.contains(member.id))
        .toList();

    final selectedMemberImages = <String>[
      ...selectedMembers
          .map((member) => member.image)
          .where((image) => image.trim().isNotEmpty),
      ...task.members
          .where(
            (member) =>
                selectedMemberIds.contains(member.id) &&
                selectedMembers.every((selected) => selected.id != member.id),
          )
          .map((member) => member.image)
          .where((image) => image.trim().isNotEmpty),
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDueTodayOrPast =
        selectedDueDate != null &&
        !DateTime(
          selectedDueDate.year,
          selectedDueDate.month,
          selectedDueDate.day,
        ).isAfter(today);
    final dueColor = isDueTodayOrPast
        ? const Color(0xFFE85B4A)
        : const Color(0xFF8B8F97);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '* Members',
                    style: TextStyle(
                      fontSize: 8.8.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Builder(
                    builder: (context) {
                      final shown = selectedMemberImages.take(4).toList();
                      const avatarSize = 24.0;
                      final avatarSizeW = avatarSize.w;
                      final avatarSizeH = avatarSize.h;
                      final overlap = 14.w;
                      final addSizeW = 24.w;
                      final addSizeH = 24.h;
                      final stackWidth =
                          shown.length * overlap +
                          (shown.isNotEmpty ? avatarSizeW : 0) +
                          addSizeW +
                          4.w;

                      return SizedBox(
                        width: stackWidth,
                        height: 26.h,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (int index = 0; index < shown.length; index++)
                              Positioned(
                                left: index * overlap,
                                child: Container(
                                  width: avatarSizeW,
                                  height: avatarSizeH,
                                  padding: EdgeInsets.all(1.3.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFCB04),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: ImageWidget(
                                      image: shown[index],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: shown.isNotEmpty
                                  ? shown.length * overlap
                                  : 0,
                              child: GestureDetector(
                                onTapDown: (details) {
                                  _showMemberPicker(
                                    dialogContext,
                                    availableMembers,
                                    selectedMemberIds,
                                    details.globalPosition,
                                    () {
                                      setSheetState(() {});
                                      onMembersChanged();
                                    },
                                  );
                                },
                                child: Container(
                                  width: addSizeW,
                                  height: addSizeH,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFCB04),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    CupertinoIcons.add,
                                    size: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '* Due Date',
                    style: TextStyle(
                      fontSize: 8.8.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  InkWell(
                    onTap: () async {
                      final picked = await _pickDueDateTime(
                        dialogContext,
                        selectedDueDate,
                      );
                      if (picked == null) return;
                      onDueDateChanged(picked);
                    },
                    borderRadius: BorderRadius.circular(999.w),
                    child: Container(
                      height: 26.h,
                      padding: EdgeInsets.symmetric(
                        horizontal: 9.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F1F5),
                        borderRadius: BorderRadius.circular(999.w),
                        border: Border.all(color: const Color(0xFFE5E7ED)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 12.sp,
                            color: dueColor,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              dueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.6.sp,
                                fontWeight: FontWeight.w700,
                                color: dueColor,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 11.sp,
                            color: const Color(0xFF747A85),
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

        SizedBox(height: 10.h),
        Text(
          'Description (optional)',
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5A606A),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          height: 76.h,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(10.w),
            border: Border.all(color: const Color(0xFFDCDDDF)),
          ),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: TextFormField(
                controller: descriptionController,
                maxLines: null,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2D3138),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Enter a task description...',
                  hintStyle: TextStyle(
                    fontSize: 10.sp,
                    color: const Color(0xFF909399),
                  ),
                ),
                onChanged: onDescriptionChanged,
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Text(
              'Label (optional)',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A606A),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildTaskPreviewLabels(labels, selectedLabelIds, () {
                setSheetState(() {});
                onLabelsChanged();
              }),
            ),
            SizedBox(width: 6.w),
            InkWell(
              onTap: () async {
                await showTaskLabelEditorDialog(
                  context: dialogContext,
                  labels: labels,
                  selectedLabelIds: selectedLabelIds,
                  onChanged: () {
                    setSheetState(() {});
                    onLabelsChanged();
                  },
                  colorFromHex: _colorFromHex,
                  onCreateLabel: (name, colorHex) async {
                    final created = await dialogContext
                        .read<ProjectPro>()
                        .createProjectLabel(name: name, colorHex: colorHex);
                    if (created == null) return null;
                    return TaskDraftLabel(
                      id: created.id,
                      name: created.name,
                      colorHex: created.color,
                    );
                  },
                  onDeleteLabel: (labelId) async {
                    return dialogContext.read<ProjectPro>().deleteProjectLabel(
                      labelId: labelId,
                    );
                  },
                );
              },
              borderRadius: BorderRadius.circular(999.w),
              child: Container(
                width: 20.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8EC),
                  borderRadius: BorderRadius.circular(999.w),
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.add, size: 11.sp),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Icon(
              CupertinoIcons.paperclip,
              size: 12.sp,
              color: const Color(0xFF8D919A),
            ),
            SizedBox(width: 6.w),
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A606A),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 62.w,
              height: 30.h,
              child: InkWell(
                onTap: onAddAttachment,
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  width: 62.w,
                  height: 30.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E63DC),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        if (task.attachments.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.paperclip,
                    size: 40.sp,
                    color: const Color(0xFFDCDDE2),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No attachment available.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF909399),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 2.h),
              itemCount: task.attachments.length,
              itemBuilder: (_, index) {
                final attachment = task.attachments[index];
                return _buildTaskPreviewAttachmentTile(
                  attachment,
                  dialogContext,
                  setSheetState,
                  task,
                  onTaskUpdated,
                );
              },
            ),
          ),
      ],
    );
  }

  static Widget _buildTaskPreviewLabels(
    List<TaskDraftLabel> labels,
    Set<int> selectedLabelIds,
    VoidCallback onSelectionChanged,
  ) {
    return buildSelectedTaskLabelChips(
      labels: labels,
      selectedLabelIds: selectedLabelIds,
      chipBuilder: _buildTaskPreviewLabelPill,
      colorFromHex: _colorFromHex,
      onSelectionChanged: onSelectionChanged,
    );
  }

  static Widget _buildTaskPreviewLabelPill(
    String label,
    Color color,
    VoidCallback? onRemove,
  ) {
    final foreground = color == const Color(0xFFCD3B43) ? Colors.white : color;
    final background = color == const Color(0xFFCD3B43)
        ? color
        : color.withValues(alpha: 0.16);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          if (onRemove != null) ...[
            SizedBox(width: 5.w),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                CupertinoIcons.xmark,
                size: 9.sp,
                color: foreground.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildTaskPreviewCommentsContent(
    ProjectTaskModel task,
    TextEditingController commentController, {
    required Future<void> Function() onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        Container(
          height: 66.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.w),
            border: Border.all(color: const Color(0xFFDCDDDF)),
          ),
          child: TextField(
            controller: commentController,
            decoration: const InputDecoration.collapsed(hintText: '|'),
            style: TextStyle(fontSize: 11.sp),
          ),
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 64.w,
            height: 24.h,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                elevation: 0,
                backgroundColor: const Color(0xFF0E63DC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.w),
                ),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (task.activities.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.chat_bubble_2,
                    size: 40.sp,
                    color: const Color(0xFFDCDDE2),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No activity yet.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF909399),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
              itemCount: task.activities.length,
              separatorBuilder: (context, index) => SizedBox(height: 10.h),
              itemBuilder: (_, index) {
                final activity = task.activities[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22.w,
                      height: 22.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E5EB),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: activity.userImage.trim().isEmpty
                            ? Icon(Icons.person, size: 12.sp)
                            : Image.network(
                                activity.userImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(Icons.person, size: 12.sp),
                              ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${activity.userName}: ',
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2228),
                                  ),
                                ),
                                TextSpan(
                                  text: activity.content,
                                  style: TextStyle(
                                    fontSize: 10.3.sp,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF2B2F36),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            activity.createdAt,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8A8E96),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  static Widget _buildTaskPreviewSheetIcon(IconData icon, Color color) {
    return Container(
      width: 20.w,
      height: 20.h,
      alignment: Alignment.center,
      child: Icon(icon, size: 18.sp, color: color),
    );
  }

  static Widget _buildTaskPreviewFooterTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(60.r),
      child: Container(
        height: 40.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFCB04) : Colors.white,
          borderRadius: BorderRadius.circular(999.w),
          border: Border.all(color: const Color(0xFFE1E3E8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.09),
              blurRadius: 6.w,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  static Widget _buildTaskPreviewAttachmentTile(
    ProjectTaskAttachment attachment,
    BuildContext dialogContext,
    void Function(void Function()) setSheetState,
    ProjectTaskModel task,
    void Function(ProjectTaskModel) onTaskUpdated,
  ) {
    final imageUrl = attachment.previewImageUrl;
    final hasImagePreview =
        attachment.hasImagePreview && imageUrl.trim().isNotEmpty;

    final String metaLabel = attachment.displayMeta;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EAEC),
              borderRadius: BorderRadius.circular(12.w),
            ),
            child: hasImagePreview
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.w),
                    child: ImageWidget(
                      image: imageUrl,
                      fit: BoxFit.cover,
                      width: 52,
                      height: 52,
                      errorWidget: Icon(
                        CupertinoIcons.doc,
                        size: 18.sp,
                        color: const Color(0xFF9AA0A8),
                      ),
                    ),
                  )
                : Icon(
                    CupertinoIcons.doc,
                    size: 18.sp,
                    color: const Color(0xFF9AA0A8),
                  ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF1D1E20),
                  ),
                ),
                if (metaLabel.isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    metaLabel,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8B8F97),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Builder(
            builder: (iconCtx) {
              return GestureDetector(
                onTapDown: (details) {
                  _showAttachmentActionMenu(
                    context: dialogContext,
                    iconCtx: iconCtx,
                    attachment: attachment,
                    onDeleteAttachment: () async {
                      final confirmed = await showDialog<bool>(
                        context: dialogContext,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          title: const Text(
                            'Delete Attachment',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          content: const Text(
                            'Are you sure you want to delete this attachment?',
                            style: TextStyle(fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;

                      Loaders.show();
                      try {
                        final didDelete = await dialogContext
                            .read<ProjectPro>()
                            .updateProjectTask(
                              projectId: task.projectId,
                              taskId: task.id,
                              fallbackTask: task,
                              payload: {
                                'remove_attachment_ids': [attachment.id],
                              },
                            );
                        if (didDelete) {
                          final detail = await dialogContext
                              .read<ProjectPro>()
                              .getProjectDetail(
                                ctx: dialogContext,
                                projectId: task.projectId,
                                forceRefresh: true,
                              );
                          if (detail != null) {
                            final refreshedTask = detail.tasks
                                .where((item) => item.id == task.id)
                                .firstOrNull;
                            if (refreshedTask != null) {
                              onTaskUpdated(refreshedTask);
                            }
                          }
                        }
                      } finally {
                        Loaders.hide();
                      }
                    },
                  );
                },
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_vert,
                    size: 16.sp,
                    color: const Color(0xFF383C43),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static void _showAttachmentActionMenu({
    required BuildContext context,
    required BuildContext iconCtx,
    required ProjectTaskAttachment attachment,
    required VoidCallback onDeleteAttachment,
  }) {
    final RenderBox box = iconCtx.findRenderObject() as RenderBox;
    final Offset pos = box.localToGlobal(Offset.zero);
    final Size size = box.size;
    final screenWidth = MediaQuery.of(context).size.width;
    const menuWidth = 160.0;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AttachmentMenu',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 160),
      transitionBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
      pageBuilder: (dlgCtx, _, _) {
        return GestureDetector(
          onTap: () => Navigator.pop(dlgCtx),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned(
                top: pos.dy + size.height + 6,
                right: (screenWidth - pos.dx - size.width).clamp(8.0, screenWidth - menuWidth - 8),
                child: GestureDetector(
                  onTap: () {}, // prevent tap-through
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: menuWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _attachmentMenuItem(
                            icon: Icon(
                              Icons.cloud_download_outlined,
                              size: 18.sp,
                              color: const Color(0xFF1D1E20),
                            ),
                            label: 'Download',
                            onTap: () async {
                              Navigator.pop(dlgCtx);
                              try {
                                await DownloadService.instance.downloadFile(
                                  url: attachment.url,
                                  fileName: attachment.name,
                                );
                              } catch (e) {
                                showToast(message: 'Could not download attachment');
                              }
                            },
                          ),
                          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
                          _attachmentMenuItem(
                            icon: ImageWidget(
                              image: Paths.delete,
                              width: 18.w,
                              height: 18.w,
                              color: const Color(0xFFEF4444),
                            ),
                            label: 'Delete',
                            color: const Color(0xFFEF4444),
                            onTap: () {
                              Navigator.pop(dlgCtx);
                              onDeleteAttachment();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _attachmentMenuItem({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF1D1E20),
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _taskStatusText(ProjectTaskModel task) {
    if (task.sectionName.trim().isNotEmpty) return task.sectionName;
    final status = task.status.trim();
    if (status.isEmpty) return 'Task';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  static DateTime? _parseDueDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return _parseFlexibleDateTime(value);
  }

  static DateTime? _parseFlexibleDateTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final direct = DateTime.tryParse(value);
    if (direct != null) return direct.toLocal();

    final normalizedIso = value.contains('T')
        ? value
        : value.replaceFirst(' ', 'T');
    final isoTry = DateTime.tryParse(normalizedIso);
    if (isoTry != null) return isoTry.toLocal();

    final compactDate = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(value);
    if (compactDate != null) {
      final day = int.tryParse(compactDate.group(1)!);
      final month = int.tryParse(compactDate.group(2)!);
      final year = int.tryParse(compactDate.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    final text = value
        .replaceAll('|', ' ')
        .replaceAll(',', ' ')
        .replaceAll('  ', ' ');
    final textMatch = RegExp(
      r'^([A-Za-z]{3,9})\s+(\d{1,2})\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(am|pm))?$',
      caseSensitive: false,
    ).firstMatch(text.trim());

    if (textMatch != null) {
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

      final monthName = textMatch.group(1)!.toLowerCase().substring(0, 3);
      final month = monthMap[monthName];
      final day = int.tryParse(textMatch.group(2)!);
      final year = int.tryParse(textMatch.group(3)!);

      if (month != null && day != null && year != null) {
        var hour = 0;
        var minute = 0;
        final hourRaw = textMatch.group(4);
        final minuteRaw = textMatch.group(5);
        final meridian = textMatch.group(6)?.toLowerCase();

        if (hourRaw != null && minuteRaw != null) {
          hour = int.tryParse(hourRaw) ?? 0;
          minute = int.tryParse(minuteRaw) ?? 0;
          if (meridian == 'pm' && hour < 12) hour += 12;
          if (meridian == 'am' && hour == 12) hour = 0;
        }

        return DateTime(year, month, day, hour, minute);
      }
    }

    return null;
  }

  static String _formatDueDateText(DateTime? value, {bool forApi = false}) {
    if (value == null) return 'MMM DD, YYYY | ---:--';

    if (forApi) {
      return '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
    }
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
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'pm' : 'am';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$month $day, ${value.year} $hour:$minute$suffix';
  }

  static Future<DateTime?> _pickDueDateTime(
    BuildContext pickerContext,
    DateTime? initial,
  ) async {
    final base = initial ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: pickerContext,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: pickerContext,
      initialTime: TimeOfDay.fromDateTime(base),
    );

    final safeTime = pickedTime ?? TimeOfDay.fromDateTime(base);
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      safeTime.hour,
      safeTime.minute,
    );
  }

  static Future<List<PlatformFile>> _pickAttachmentFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        return const <PlatformFile>[];
      }
      return result.files;
    } catch (e) {
      showToast(message: 'Unable to pick files');
      return const <PlatformFile>[];
    }
  }

  static Color _colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.isEmpty) return const Color(0xFF8A8E97);
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF8A8E97);
  }

  static Widget _buildAvatarStrip([List<String>? avatars, int maxVisible = 4]) {
    final items = avatars ?? const <String>[];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final shown = items.take(maxVisible).toList();
    return SizedBox(
      width: shown.length * 14.w + 26.w,
      height: 26.h,
      child: Stack(
        children: [
          for (int index = 0; index < shown.length; index++)
            Positioned(
              left: index * 14.w,
              child: Container(
                width: 26.w,
                height: 26.h,
                padding: EdgeInsets.all(1.3.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: ImageWidget(image: shown[index], fit: BoxFit.cover),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _showSaveTaskTemplateDialog({
    required BuildContext context,
    required ProjectTaskModel task,
    required String baseTitle,
    required void Function(ProjectTaskModel) onTaskUpdated,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SaveTaskTemplateDialogContent(
        task: task,
        baseTitle: baseTitle,
        onTaskUpdated: onTaskUpdated,
      ),
    );
  }
}

class _CreateTaskSheetContent extends StatefulWidget {
  final int projectId;
  final BuildContext originalContext;

  const _CreateTaskSheetContent({
    required this.projectId,
    required this.originalContext,
  });

  @override
  State<_CreateTaskSheetContent> createState() =>
      _CreateTaskSheetContentState();
}

class _CreateTaskSheetContentState extends State<_CreateTaskSheetContent> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  _TaskPreviewTab selectedTab = _TaskPreviewTab.details;
  DateTime? selectedDueDate;
  int? selectedSectionId;
  String selectedStatus = 'No status';
  bool isCreating = false;

  /// Inline validation error messages shown beneath the respective fields.
  String? _titleError;
  String? _dueDateError;
  String? _memberError;

  late List<TaskDraftLabel> editableLabels;
  final Set<int> selectedLabelIds = {};
  final Set<int> selectedMemberIds = {};
  final List<PlatformFile> selectedFiles = [];
  List<ProjectTaskTemplateModel> _taskTemplates =
      const <ProjectTaskTemplateModel>[];
  int? _editingTemplateId;
  String _editingTemplateName = '';
  bool _didSeedCreateContextDefaults = false;

  void _seedCreateContextDefaults(ProjectPro projectPro) {
    if (_didSeedCreateContextDefaults) return;

    final createContext = projectPro.activeProjectDetail?.taskCreateContext;
    if (createContext == null) return;

    final defaultSectionId = createContext.selectedSectionId;
    if (defaultSectionId > 0) {
      selectedSectionId = defaultSectionId;
    }

    final defaultSectionName = createContext.selectedSectionName.trim();
    if (defaultSectionName.isNotEmpty) {
      selectedStatus = defaultSectionName;
    }

    final defaultMemberIds = createContext.selectedMemberIds;
    if (defaultMemberIds.isNotEmpty) {
      selectedMemberIds
        ..clear()
        ..addAll(defaultMemberIds);
    }

    _didSeedCreateContextDefaults = true;
  }

  @override
  void initState() {
    super.initState();
    final projectPro = widget.originalContext.read<ProjectPro>();
    editableLabels = buildInitialTaskDraftLabels(
      projectLabels: projectPro.projectLabels,
      taskLabels: const [],
    );
    _seedCreateContextDefaults(projectPro);
    if (!_didSeedCreateContextDefaults) {
      final availableSections = projectPro.activeProjectDetail?.sections ?? [];
      if (availableSections.isNotEmpty) {
        selectedSectionId = availableSections.first.id;
        selectedStatus = availableSections.first.name;
      }
    }

    // Always fetch latest templates when opening Add Task sheet.
    projectPro.getTaskTemplates(forceRefresh: true).then((templates) {
      if (!mounted) return;
      setState(() {
        _taskTemplates = templates;
      });
    });

    Future<void>(() async {
      final detail = await projectPro.getProjectDetail(
        ctx: widget.originalContext,
        projectId: widget.projectId,
        forceRefresh: true,
      );
      if (!mounted || detail == null) return;

      setState(() {
        _seedCreateContextDefaults(projectPro);
      });
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    commentController.dispose();
    super.dispose();
  }

  ProjectModel? _resolveProjectInfo(ProjectPro projectPro) {
    final activeProject = projectPro.activeProjectDetail?.project;
    if (activeProject != null && activeProject.numericId == widget.projectId) {
      return activeProject;
    }

    for (final project in projectPro.projects) {
      if (project.numericId == widget.projectId) {
        return project;
      }
    }

    return null;
  }

  Future<void> _handleCreateTask() async {
    final title = titleController.text.trim();
    bool hasError = false;

    if (title.isEmpty) {
      setState(() {
        _titleError = 'Task name is required.';
      });
      hasError = true;
    }

    if (selectedDueDate == null) {
      setState(() {
        _dueDateError = 'Due date is required before closing.';
        selectedTab = _TaskPreviewTab.details;
      });
      hasError = true;
    }

    if (selectedMemberIds.isEmpty) {
      setState(() {
        _memberError = 'At least one member is required.';
        selectedTab = _TaskPreviewTab.details;
      });
      hasError = true;
    }

    if (hasError) return;
    if (isCreating) return;
    setState(() => isCreating = true);

    final payload = <String, dynamic>{
      'title': title,
      'description': descriptionController.text.trim(),
    };

    if (selectedSectionId != null) {
      payload['project_section_id'] = selectedSectionId;
    }

    if (selectedDueDate != null) {
      payload['due_date'] = MobileTaskPreviewSheet._formatDueDateText(
        selectedDueDate,
        forApi: true,
      );
    }

    if (selectedLabelIds.isNotEmpty) {
      payload['label_ids'] = selectedLabelIds.toList();
    }

    if (selectedMemberIds.isNotEmpty) {
      payload['assigned_members'] = selectedMemberIds.toList();
    }

    final comment = commentController.text.trim();
    if (comment.isNotEmpty) {
      payload['activity_comment'] = comment;
    }

    final projectPro = context.read<ProjectPro>();
    final didCreate = await projectPro.createProjectTask(
      projectId: widget.projectId,
      payload: payload,
      filePaths: selectedFiles
          .map((f) => f.path ?? '')
          .where((p) => p.isNotEmpty)
          .toList(),
      fileNames: selectedFiles.map((f) => f.name).toList(),
      fileKeys: List.generate(selectedFiles.length, (_) => 'attachments[]'),
    );

    if (!mounted) return;
    setState(() => isCreating = false);

    if (didCreate) {
      await projectPro.getProjectDetail(
        ctx: context,
        projectId: widget.projectId,
        forceRefresh: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _showSaveTemplateDialog() async {
    final baseTitle = titleController.text.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SaveProjectTemplateDialogContent(
        projectId: widget.projectId,
        baseTitle: baseTitle,
      ),
    );
  }

  Future<void> _showTemplateDropdown(Offset anchor) async {
    final pro = context.read<ProjectPro>();
    final templates = await pro.getTaskTemplates();
    if (!mounted) return;

    setState(() {
      _taskTemplates = templates;
    });

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    const horizontalMargin = 10.0;
    final popupWidth = (246.w).clamp(
      220.0,
      overlay.size.width - (horizontalMargin * 2),
    );

    final left = (anchor.dx - popupWidth + 22.w).clamp(
      horizontalMargin,
      overlay.size.width - popupWidth - horizontalMargin,
    );
    final top = (anchor.dy + 6.h).clamp(12.0, overlay.size.height - 300.h);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Task templates',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.06),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, _) {
        String query = '';

        return StatefulBuilder(
          builder: (dialogContext, setPopupState) {
            final filtered = _taskTemplates.where((template) {
              final source =
                  '${template.name} ${template.projectName} ${template.updatedAt}'
                      .toLowerCase();
              return source.contains(query.toLowerCase());
            }).toList();

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
                    width: popupWidth,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.w),
                        border: Border.all(color: const Color(0xFFD7DBE4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            onChanged: (value) =>
                                setPopupState(() => query = value),
                            decoration: InputDecoration(
                              hintText: 'Search templates...',
                              hintStyle: TextStyle(
                                fontSize: 11.sp,
                                color: const Color(0xFF9AA0AE),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A6CF3),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFFC7D2F6),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9.r),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A6CF3),
                                  width: 1,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: const Color(0xFF2D3340),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 220.h),
                            child: filtered.isEmpty
                                ? Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 24.h,
                                    ),
                                    child: Text(
                                      'No templates found',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8E94A1),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) =>
                                        SizedBox(height: 8.h),
                                    itemBuilder: (context, index) {
                                      final template = filtered[index];
                                      return InkWell(
                                        onTap: () async {
                                          await _loadAndApplyTemplateToForm(
                                            templateId: template.id,
                                            dialogContext: dialogContext,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                            vertical: 2.h,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      template.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: const Color(
                                                          0xFF252A33,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 2.h),
                                                    Text(
                                                      template.subtitle,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10.sp,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: const Color(
                                                          0xFF8F95A3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 6.w),
                                              GestureDetector(
                                                onTap: () async {
                                                  await _loadAndApplyTemplateToForm(
                                                    templateId: template.id,
                                                    dialogContext:
                                                        dialogContext,
                                                  );
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding: EdgeInsets.all(2.w),
                                                  child: ImageWidget(
                                                    image: Paths.edit,
                                                    width: 13,
                                                    height: 13,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              GestureDetector(
                                                onTap: () async {
                                                  final shouldDelete =
                                                      await _confirmDeleteTemplate(
                                                        template.name,
                                                      );
                                                  if (!shouldDelete) return;

                                                  final deleted =
                                                      await _deleteTemplateById(
                                                        template.id,
                                                      );
                                                  if (deleted) {
                                                    setPopupState(() {});
                                                  }
                                                },
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: Padding(
                                                  padding: EdgeInsets.all(2.w),
                                                  child: ImageWidget(
                                                    image: Paths.delete,
                                                    width: 13,
                                                    height: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  DateTime? _parseTemplateDueDateInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return MobileTaskPreviewSheet._parseDueDate(value);
  }

  Future<bool> _confirmDeleteTemplate(String templateName) async {
    final name = templateName.trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete template'),
        content: Text(
          name.isEmpty
              ? 'Are you sure you want to delete this template? This action cannot be undone.'
              : 'Are you sure you want to delete "$name"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE45B45)),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _deleteTemplateById(int templateId) async {
    Loaders.show();
    final deleted = await context.read<ProjectPro>().deleteTaskTemplate(
      templateId: templateId,
    );
    Loaders.hide();

    if (!mounted || !deleted) return false;

    final latest = await context.read<ProjectPro>().getTaskTemplates(
      forceRefresh: true,
    );
    if (!mounted) return false;

    setState(() {
      _taskTemplates = latest;
      if (_editingTemplateId == templateId) {
        _editingTemplateId = null;
        _editingTemplateName = '';
      }
    });

    return true;
  }

  Future<void> _loadAndApplyTemplateToForm({
    required int templateId,
    required BuildContext dialogContext,
  }) async {
    Loaders.show();
    final detail = await context.read<ProjectPro>().getTaskTemplateDetail(
      templateId: templateId,
    );
    Loaders.hide();

    if (!mounted) return;
    if (detail == null) {
      showToast(message: 'Unable to load template');
      return;
    }

    _applyTemplateDetailToForm(detail);
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
    showToast(message: 'Template applied');
  }

  void _applyTemplateDetailToForm(ProjectTaskTemplateDetailModel detail) {
    final sections =
        context.read<ProjectPro>().activeProjectDetail?.sections ??
        const <ProjectSectionModel>[];

    ProjectSectionModel? matchedSection;
    for (final section in sections) {
      if (section.id == detail.projectSectionId) {
        matchedSection = section;
        break;
      }
    }

    final knownLabelIds = <int>{for (final label in editableLabels) label.id};
    for (final label in detail.labels) {
      if (label.id <= 0 || knownLabelIds.contains(label.id)) continue;
      editableLabels.add(
        TaskDraftLabel(id: label.id, name: label.name, colorHex: label.color),
      );
      knownLabelIds.add(label.id);
    }

    setState(() {
      _editingTemplateId = detail.id;
      _editingTemplateName = detail.name;
      titleController.text = detail.title;
      descriptionController.text = detail.description;
      commentController.text = detail.commentText;
      selectedDueDate = _parseTemplateDueDateInput(detail.dueDateInput);
      if (detail.projectSectionId > 0) {
        selectedSectionId = detail.projectSectionId;
      }
      if (matchedSection != null) {
        selectedStatus = matchedSection.name;
      } else if (detail.sectionName.trim().isNotEmpty) {
        selectedStatus = detail.sectionName;
      }

      selectedMemberIds
        ..clear()
        ..addAll(detail.memberIds);

      selectedLabelIds
        ..clear()
        ..addAll(detail.labels.map((item) => item.id).where((id) => id > 0));

      selectedTab = _TaskPreviewTab.details;
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use watcher on the broad provider for updates
    final projectPro = context.watch<ProjectPro>();
    final availableSections = projectPro.activeProjectDetail?.sections ?? [];
    final availableMembers =
        projectPro.activeProjectDetail?.taskCreateContext?.memberOptions ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Force validation and attempt to save before closing.
        // If mandatory fields (title/date/members) are missing, validation blocks the close.
        _handleCreateTask();
      },
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.only(top: 2.h),
              width: MediaQuery.of(context).size.width - 10.w,
              constraints: BoxConstraints(maxWidth: 410.w),
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    10.h,
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.w),
                        ),
                        child: Column(
                          children: [
                            // ── Header ──
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                14.w,
                                15.h,
                                14.w,
                                8.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: titleController,
                                          maxLines: null,
                                          onChanged: (val) {
                                            if (_titleError != null) {
                                              setState(
                                                () => _titleError = null,
                                              );
                                            }
                                          },
                                          style: TextStyle(
                                            fontSize: 14.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1D1F24),
                                            height: 1.2,
                                          ),
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: 'Task Name',
                                            hintStyle: TextStyle(
                                              fontSize: 14.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF7B8496),
                                            ),
                                          ),
                                        ),
                                        if (_titleError != null) ...[
                                          SizedBox(height: 2.h),
                                          Text(
                                            _titleError!,
                                            style: TextStyle(
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFD93025),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTapDown: (details) {
                                      final project = _resolveProjectInfo(
                                        projectPro,
                                      );
                                      if (project == null) return;

                                      MobileTaskPreviewSheet._showProjectInfoPopup(
                                        context,
                                        project,
                                        anchor: details.globalPosition,
                                      );
                                    },
                                    child:
                                        MobileTaskPreviewSheet._buildTaskPreviewSheetIcon(
                                          CupertinoIcons.info,
                                          const Color(0xFF22252B),
                                        ),
                                  ),
                                  SizedBox(width: 8.w),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
                                    child:
                                        MobileTaskPreviewSheet._buildTaskPreviewSheetIcon(
                                          CupertinoIcons.xmark,
                                          const Color(0xFF111111),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Text(
                                        'Status:',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2F3138),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      GestureDetector(
                                        onTapDown: (details) {
                                          if (availableSections.isEmpty) return;
                                          MobileTaskPreviewSheet._showSectionPicker(
                                            context,
                                            availableSections
                                                .cast<ProjectSectionModel>(),
                                            selectedSectionId,
                                            details.globalPosition,
                                            (section) {
                                              setState(() {
                                                selectedStatus = section.name;
                                                selectedSectionId = section.id;
                                              });
                                            },
                                          );
                                        },
                                        child: Container(
                                          height: 24.h,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              999.w,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE0E2E8),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                selectedStatus,
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF232731),
                                                ),
                                              ),
                                              SizedBox(width: 5.w),
                                              Icon(
                                                CupertinoIcons.chevron_down,
                                                size: 10.sp,
                                                color: const Color(0xFF737985),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      if (_editingTemplateId == null) ...[
                                        InkWell(
                                          onTapDown: (details) {
                                            _showTemplateDropdown(
                                              details.globalPosition,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8.w,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(
                                                8.w,
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFFE0E2E8),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.save_outlined,
                                                  size: 11.sp,
                                                  color: const Color(0xFF6D727C),
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'Template',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF3B3F46,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        InkWell(
                                          onTap: _showSaveTemplateDialog,
                                          borderRadius: BorderRadius.circular(
                                            8.w,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4C4AE8),
                                              borderRadius: BorderRadius.circular(
                                                8.w,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.doc_on_clipboard,
                                                  size: 11.sp,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 5.w),
                                                Text(
                                                  'Save as Template',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        InkWell(
                                          onTap: () {
                                            final label =
                                                _editingTemplateName
                                                    .trim()
                                                    .isEmpty
                                                ? 'template'
                                                : _editingTemplateName;
                                            showToast(
                                              message:
                                                  'Update Template: $label (coming soon)',
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8.w,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4C4AE8),
                                              borderRadius: BorderRadius.circular(
                                                8.w,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.doc_on_clipboard,
                                                  size: 11.sp,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 5.w),
                                                Text(
                                                  'Update Template',
                                                  style: TextStyle(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        GestureDetector(
                                          onTap: () async {
                                            final templateId = _editingTemplateId;
                                            if (templateId == null) return;

                                            final shouldDelete =
                                                await _confirmDeleteTemplate(
                                                  _editingTemplateName,
                                                );
                                            if (shouldDelete == true) {
                                              await context
                                                  .read<ProjectPro>()
                                                  .deleteTaskTemplate(
                                                    templateId: templateId,
                                                  );
                                              setState(() {
                                                _editingTemplateId = null;
                                                _editingTemplateName = '';
                                              });
                                            }
                                          },
                                          child:
                                              MobileTaskPreviewSheet._buildTaskPreviewSheetIcon(
                                                CupertinoIcons.trash,
                                                const Color(0xFFD93025),
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Divider(color: Colors.grey.shade300),
                            SizedBox(height: 6.h),

                            // ── Body Scrollable Area ──
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  14.w,
                                  0,
                                  14.w,
                                  10.h,
                                ),
                                child: selectedTab == _TaskPreviewTab.details
                                    ? MobileTaskPreviewSheet._buildCreateTaskDetailsContent(
                                        dialogContext: context,
                                        setSheetState: setState,
                                        dueText:
                                            MobileTaskPreviewSheet._formatDueDateText(
                                              selectedDueDate,
                                            ),
                                        labels: editableLabels,
                                        selectedLabelIds: selectedLabelIds,
                                        selectedMemberIds: selectedMemberIds,
                                        availableMembers: availableMembers,
                                        selectedFiles: selectedFiles,
                                        selectedDueDate: selectedDueDate,
                                        onDueDateChanged: (date) {
                                          setState(() {
                                            selectedDueDate = date;
                                            _dueDateError =
                                                null; // clear error on selection
                                          });
                                        },
                                        descriptionController:
                                            descriptionController,
                                        dueDateError: _dueDateError,
                                        memberError: _memberError,
                                        onMemberErrorClear: () {
                                          if (_memberError != null) {
                                            setState(() => _memberError = null);
                                          }
                                        },
                                      )
                                    : MobileTaskPreviewSheet._buildEmptyCommentsContent(
                                        commentController,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Footer tabs ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        0,
                        16.w,
                        MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom
                            : 55.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                MobileTaskPreviewSheet._buildTaskPreviewFooterTab(
                                  label: 'Details',
                                  selected:
                                      selectedTab == _TaskPreviewTab.details,
                                  onTap: () => setState(
                                    () => selectedTab = _TaskPreviewTab.details,
                                  ),
                                ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child:
                                MobileTaskPreviewSheet._buildTaskPreviewFooterTab(
                                  label: 'Comments',
                                  selected:
                                      selectedTab == _TaskPreviewTab.comments,
                                  onTap: () => setState(
                                    () =>
                                        selectedTab = _TaskPreviewTab.comments,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveTaskTemplateDialogContent extends StatefulWidget {
  final ProjectTaskModel task;
  final String baseTitle;
  final void Function(ProjectTaskModel) onTaskUpdated;

  const _SaveTaskTemplateDialogContent({
    required this.task,
    required this.baseTitle,
    required this.onTaskUpdated,
  });

  @override
  State<_SaveTaskTemplateDialogContent> createState() =>
      __SaveTaskTemplateDialogContentState();
}

class __SaveTaskTemplateDialogContentState
    extends State<_SaveTaskTemplateDialogContent> {
  late final TextEditingController nameController;
  bool isPublic = true;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.baseTitle.isEmpty
          ? 'task template'
          : '${widget.baseTitle.toLowerCase()} template',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      content: Container(
        width: 1.sw,
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 20.sp,
                  color: const Color(0xFF10A273),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Save as Template',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101928),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 18.sp,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Text(
                  '* ',
                  style: TextStyle(
                    color: const Color(0xFFF04438),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Template Name',
                  style: TextStyle(
                    color: const Color(0xFF1D2939),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
              ),
              style: TextStyle(fontSize: 13.sp),
            ),
            SizedBox(height: 20.h),
            Text(
              'Visibility',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
            SizedBox(height: 10.h),
            RadioListTile<bool>(
              value: true,
              groupValue: isPublic,
              onChanged: (val) {
                if (val == null) return;
                setState(() => isPublic = val);
              },
              activeColor: const Color(0xFF2E6FF1),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Available for all users',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: isPublic,
              onChanged: (val) {
                if (val == null) return;
                setState(() => isPublic = val);
              },
              activeColor: const Color(0xFF2E6FF1),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Only for me',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showToast(message: 'Please enter a template name');
                    return;
                  }

                  Navigator.pop(context);
                  Loaders.show();

                  String? formattedDueDate;
                  if (widget.task.dueDate.isNotEmpty) {
                    final parsed = MobileTaskPreviewSheet._parseDueDate(widget.task.dueDate);
                    if (parsed != null) {
                      formattedDueDate =
                          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
                    }
                  }

                  final success = await context.read<ProjectPro>().saveTaskAsTemplate(
                        projectId: widget.task.projectId,
                        taskId: widget.task.id,
                        name: name,
                        isPublic: isPublic,
                        title: widget.task.title,
                        description: widget.task.description,
                        projectSectionId: widget.task.projectSectionId == 0
                            ? null
                            : widget.task.projectSectionId,
                        dueDate: formattedDueDate,
                        memberIds: widget.task.members.map((m) => m.id).toList(),
                        labelIds: widget.task.labels.map((l) => l.id).toList(),
                        templateAttachmentIds:
                            widget.task.attachments.map((a) => a.id).toList(),
                      );

                  Loaders.hide();

                  if (success) {
                    showToast(message: 'Task saved as template');
                    widget.onTaskUpdated(
                      widget.task.copyWith(isTaskSavedAsTemplate: true),
                    );
                  } else {
                    showToast(message: 'Failed to save template');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C4AE8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save Template',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveProjectTemplateDialogContent extends StatefulWidget {
  final int projectId;
  final String baseTitle;

  const _SaveProjectTemplateDialogContent({
    required this.projectId,
    required this.baseTitle,
  });

  @override
  State<_SaveProjectTemplateDialogContent> createState() =>
      __SaveProjectTemplateDialogContentState();
}

class __SaveProjectTemplateDialogContentState
    extends State<_SaveProjectTemplateDialogContent> {
  late final TextEditingController nameController;
  bool isPublic = true;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.baseTitle.isEmpty
          ? 'project template'
          : '${widget.baseTitle.toLowerCase()} template',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      content: Container(
        width: 1.sw,
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 20.sp,
                  color: const Color(0xFF17181B),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Save Template',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101928),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 18.sp,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'Template Name',
              style: TextStyle(
                color: const Color(0xFF1D2939),
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
              ),
              style: TextStyle(fontSize: 13.sp),
            ),
            SizedBox(height: 20.h),
            Text(
              'Visibility',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
            SizedBox(height: 10.h),
            RadioListTile<bool>(
              value: true,
              groupValue: isPublic,
              onChanged: (val) {
                if (val == null) return;
                setState(() => isPublic = val);
              },
              activeColor: const Color(0xFF2E6FF1),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Available for all users',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: isPublic,
              onChanged: (val) {
                if (val == null) return;
                setState(() => isPublic = val);
              },
              activeColor: const Color(0xFF2E6FF1),
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Only for me',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF344054),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    showToast(message: 'Please enter a template name');
                    return;
                  }

                  Navigator.pop(context);
                  Loaders.show();
                  await context.read<ProjectPro>().saveProjectTemplate(
                        projectId: widget.projectId,
                        name: name,
                        isPublic: isPublic,
                      );
                  Loaders.hide();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C4AE8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save as Template',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
