import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';


import '../../constants/paths.dart';
import '../../widgets/loaders.dart';
import '../../widgets/toasts.dart';
import 'mobile_project_tasks_page.dart';
import 'widgets/mobile_projects_filter_sheet.dart';
import 'widgets/mobile_tasks_filter_sheet.dart';
import 'widgets/mobile_projects_forms_section.dart';
import '../../models/projects_models.dart';
import '../../providers/project_pro.dart';
import '../../widgets/image_widget.dart';
import 'widgets/task_label_editor.dart';
import 'widgets/mobile_task_preview_sheet.dart';

class MobileProjectsSection extends StatefulWidget {
  const MobileProjectsSection({super.key});

  @override
  State<MobileProjectsSection> createState() => _MobileProjectsSectionState();
}

class _MobileProjectsSectionState extends State<MobileProjectsSection> {
  _ProjectsHeaderView _selectedView = _ProjectsHeaderView.projects;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProjectPro>().getProjectLabels(ctx: context);
      _loadSelectedView();
    });
  }

  void _loadSelectedView() {
    final projectPro = context.read<ProjectPro>();
    if (_selectedView == _ProjectsHeaderView.projects) {
      projectPro.getProjects(ctx: context);
    } else {
      projectPro.getTasksList(ctx: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectPro>(
      builder: (context, pro, child) {
        if (pro.projectLoad) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F7),
            appBar: _buildMobileAppBar(pro),
            body: Center(child: showLoader()),
          );
        }
        final projects = pro.projects;
        final tasks = pro.tasks;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: _buildMobileAppBar(pro),
          body: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        if (_selectedView == _ProjectsHeaderView.projects) {
                          await pro.getProjects(ctx: context);
                        } else {
                          await pro.getTasksList(ctx: context);
                        }
                      },
                      child: _selectedView == _ProjectsHeaderView.projects
                          ? (projects.isEmpty
                                ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: SizedBox(
                                      height: 0.6.sh,
                                      child: Center(
                                        child: Text(
                                          'No projects found',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF7E8088),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: projects.length,
                                    padding: EdgeInsets.zero,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    separatorBuilder: (_, _) =>
                                        SizedBox(height: 12.h),
                                    itemBuilder: (context, index) =>
                                        _buildProjectCard(
                                          projects[index],
                                          index,
                                        ),
                                  ))
                          : (tasks.isEmpty
                                ? SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: SizedBox(
                                      height: 0.6.sh,
                                      child: Center(
                                        child: Text(
                                          'No tasks found',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF7E8088),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: tasks.length,
                                    padding: EdgeInsets.zero,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    separatorBuilder: (_, _) =>
                                        SizedBox(height: 10.h),
                                    itemBuilder: (context, index) =>
                                        _buildTaskCard(tasks[index]),
                                  )),
                    ),
                  ),

                  // _buildPagination(pro),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildMobileAppBar(ProjectPro pro) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      toolbarHeight: 66.h,
      titleSpacing: 14.w,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageWidget(image: Paths.task, width: 24, height: 24),
          SizedBox(width: 10.w),
          _buildHeaderDropdown(),
        ],
      ),
      actions: [
        _buildFilterButton(
          _selectedView == _ProjectsHeaderView.projects
              ? pro.appliedProjectFilterCount
              : pro.appliedTaskFilterCount,
        ),
        SizedBox(width: 14.w),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFECECEF)),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project, int index) {
    final highlighted = index == 0;
    final accentColor = _progressAccentColor(project);
    final progressValue = project.displayProgressPercent.toDouble() / 100;

    return InkWell(
      onTap: () => _openProjectTasks(project),
      borderRadius: BorderRadius.circular(20.w),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.w),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFFFB77B)
                : const Color(0xFFE7E7EB),
            width: highlighted ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: highlighted ? 0.05 : 0.035),
              blurRadius: highlighted ? 16.w : 12.w,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF17181B),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        project.cardHeaderText,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A9CA5),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _buildProjectOverflowButton(project),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoPill(
                        'Customer: ${project.customerDisplayName}',
                        const Color(0xFFFFF4DA),
                        const Color(0xFFD59312),
                      ),
                      SizedBox(height: 5.h),
                      _buildInfoPill(
                        'Client: ${project.clientDisplayName}',
                        const Color(0xFFE7F0FF),
                        const Color(0xFF2A72F8),
                      ),
                    ],
                  ),
                ),
                _buildAvatarStrip(project.avatars, 6),
              ],
            ),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(99.w),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 5.h,
                backgroundColor: const Color(0xFFF0F1F4),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(child: _buildProgressSection(project, accentColor)),
                _buildCounterItem(
                  CupertinoIcons.chat_bubble_text,
                  project.commentsCount,
                ),
                SizedBox(width: 10.w),
                _buildCounterItem(
                  CupertinoIcons.paperclip,
                  project.attachmentsCount,
                ),
                SizedBox(width: 10.w),
                _buildCounterItem(
                  CupertinoIcons.check_mark_circled,
                  project.tasksCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderDropdown() {
    final label = _selectedView == _ProjectsHeaderView.projects
        ? 'Projects'
        : 'Tasks';
    return Builder(
      builder: (buttonContext) => InkWell(
        onTap: () => _showHeaderDropdown(buttonContext),
        borderRadius: BorderRadius.circular(14.w),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(14.w),
            border: Border.all(color: const Color(0xFFE4E4E8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1D21),
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                CupertinoIcons.chevron_down,
                size: 12.sp,
                color: const Color(0xFF676971),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHeaderDropdown(BuildContext buttonContext) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;
    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<_ProjectsHeaderView>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonTopLeft.dx,
        buttonBottomLeft.dy + 4.h,
        overlay.size.width - buttonTopLeft.dx - button.size.width,
        overlay.size.height - buttonBottomLeft.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.w)),
      items: [
        PopupMenuItem<_ProjectsHeaderView>(
          value: _ProjectsHeaderView.projects,
          child: Text(
            'Projects',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: _selectedView == _ProjectsHeaderView.projects
                  ? const Color(0xFF2A72F8)
                  : const Color(0xFF24262C),
            ),
          ),
        ),
        PopupMenuItem<_ProjectsHeaderView>(
          value: _ProjectsHeaderView.tasks,
          child: Text(
            'Tasks',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: _selectedView == _ProjectsHeaderView.tasks
                  ? const Color(0xFF2A72F8)
                  : const Color(0xFF24262C),
            ),
          ),
        ),
      ],
    );

    if (!mounted || selected == null || selected == _selectedView) return;
    setState(() => _selectedView = selected);
    _loadSelectedView();
  }

  Widget _buildTaskCard(ProjectTaskModel task) {
    final dueText = _taskDueText(task);
    final statusText = _taskStatusText(task);
    
    final parsedDue = _parseDueDate(task.dueDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDueTodayOrPast = parsedDue != null && !DateTime(parsedDue.year, parsedDue.month, parsedDue.day).isAfter(today);
    final dueColor = isDueTodayOrPast ? const Color(0xFFE85B4A) : const Color(0xFF8B8F97);

    return InkWell(
      onTap: () => _showTaskPreviewModal(task),
      borderRadius: BorderRadius.circular(16.w),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.w),
          border: Border.all(color: const Color(0xFFE7E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10.w,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6F737C),
                    ),
                ),
              ),
              SizedBox(width: 8.w),
              Builder(
                builder: (buttonContext) => InkWell(
                  onTap: () => _showTaskActions(
                    buttonContext,
                    task,
                    menuType: _TaskMenuType.primary,
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  child: _buildTaskMiniMoreButton(),
                ),
              ),
            ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(
                  CupertinoIcons.clock,
                  size: 13.sp,
                  color: dueColor,
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    dueText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w700,
                      color: dueColor,
                    ),
                  ),
                ),
              ],
            ),

            Divider(color: const Color(0xFFE7E7EB), thickness: 0.8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: _buildTaskPill(
                          statusText,
                          const Color(0xFFF3F3F5),
                          const Color(0xFF8A8E97),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Builder(
                        builder: (buttonContext) => InkWell(
                          onTap: () => _showTaskActions(
                            buttonContext,
                            task,
                            menuType: _TaskMenuType.secondary,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                          child: _buildTaskMiniMoreButton(),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildAvatarStrip(
                  task.members
                      .map((member) => member.image)
                      .where((item) => item.trim().isNotEmpty)
                      .toList(),
                  3,
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      for (final label in task.labels)
                        _buildTaskPill(
                          label.name,
                          _colorFromHex(label.color).withValues(alpha: 0.14),
                          _colorFromHex(label.color),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCounterItem(
                      CupertinoIcons.chat_bubble_text,
                      task.commentsCount,
                    ),
                    SizedBox(width: 12.w),
                    _buildCounterItem(
                      CupertinoIcons.paperclip,
                      task.attachmentsCount,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskPreviewModal(ProjectTaskModel task) async {
    await MobileTaskPreviewSheet.show(context, task);
    if (mounted) {
      await context.read<ProjectPro>().getProjectDetail(
            ctx: context,
            projectId: task.projectId,
            forceRefresh: true,
          );
    }
  }

  // Legacy helper methods below are left to avoid accidental deletions of shared code.
  Future<void> _oldShowTaskPreviewModal(ProjectTaskModel task) async {
    final commentController = TextEditingController();
    _TaskPreviewTab selectedTab = _TaskPreviewTab.details;
    DateTime? selectedDueDate = _parseDueDate(task.dueDate);
    final editableLabels = buildInitialTaskDraftLabels(
      projectLabels: context.read<ProjectPro>().projectLabels,
      taskLabels: task.labels,
    );
    final selectedLabelIds = <int>{for (final label in task.labels) label.id};

    if (selectedLabelIds.isEmpty && editableLabels.isNotEmpty) {
      selectedLabelIds.add(editableLabels.first.id);
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
                return Material(
                  color: Colors.transparent,
                  child: Container(
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
                              margin: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 8.h),
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
                                          child: Text(
                                            task.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1D1F24),
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                        _buildTaskPreviewSheetIcon(
                                          CupertinoIcons.info,
                                          const Color(0xFF22252B),
                                        ),
                                        SizedBox(width: 8.w),
                                        GestureDetector(
                                          onTap: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: _buildTaskPreviewSheetIcon(
                                            CupertinoIcons.xmark,
                                            const Color(0xFF111111),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                    ),
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
                                        Container(
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
                                                _taskStatusText(task),
                                                style: TextStyle(
                                                  fontSize: 9.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF232731,
                                                  ),
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
                                        const Spacer(),
                                        Container(
                                          height: 22.h,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6.w,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE0E2E8),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.copy_outlined,
                                                size: 10.sp,
                                                color: const Color(0xFF6D727C),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                'Template',
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF3B3F46,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Expanded(
                                    child:
                                        selectedTab == _TaskPreviewTab.details
                                        ? Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              14.w,
                                              0,
                                              14.w,
                                              10.h,
                                            ),
                                            child: _buildTaskPreviewDetailsContent(
                                              task,
                                              dueText: _formatDueDateText(
                                                selectedDueDate,
                                              ),
                                              labels: editableLabels,
                                              selectedLabelIds:
                                                  selectedLabelIds,
                                              onLabelsChanged: () =>
                                                  setSheetState(() {}),
                                              onDueDateTap: () async {
                                                final picked =
                                                    await _pickDueDateTime(
                                                      dialogContext,
                                                      selectedDueDate,
                                                    );
                                                if (picked == null) return;
                                                setSheetState(
                                                  () =>
                                                      selectedDueDate = picked,
                                                );
                                              },
                                              onAddLabelTap: () async {
                                                await showTaskLabelEditorDialog(
                                                  context: dialogContext,
                                                  labels: editableLabels,
                                                  selectedLabelIds:
                                                      selectedLabelIds,
                                                  onChanged: () =>
                                                      setSheetState(() {}),
                                                  colorFromHex: _colorFromHex,
                                                  onCreateLabel:
                                                      (name, colorHex) async {
                                                        final created =
                                                            await context
                                                                .read<
                                                                  ProjectPro
                                                                >()
                                                                .createProjectLabel(
                                                                  name: name,
                                                                  colorHex:
                                                                      colorHex,
                                                                );
                                                        if (created == null) {
                                                          return null;
                                                        }
                                                        return TaskDraftLabel(
                                                          id: created.id,
                                                          name: created.name,
                                                          colorHex:
                                                              created.color,
                                                        );
                                                      },
                                                  onDeleteLabel:
                                                      (labelId) async {
                                                        return context
                                                            .read<ProjectPro>()
                                                            .deleteProjectLabel(
                                                              labelId: labelId,
                                                            );
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
                                            child:
                                                _buildTaskPreviewCommentsContent(
                                                  task,
                                                  commentController,
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
                                        selectedTab == _TaskPreviewTab.details,
                                    onTap: () => setSheetState(
                                      () =>
                                          selectedTab = _TaskPreviewTab.details,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildTaskPreviewFooterTab(
                                    label: 'Comments',
                                    selected:
                                        selectedTab == _TaskPreviewTab.comments,
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

  Widget _buildTaskPreviewDetailsContent(
    ProjectTaskModel task, {
    required String dueText,
    required List<TaskDraftLabel> labels,
    required Set<int> selectedLabelIds,
    required VoidCallback onLabelsChanged,
    required VoidCallback onDueDateTap,
    required VoidCallback onAddLabelTap,
  }) {
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
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      _buildAvatarStrip(
                        task.members
                            .map((e) => e.image)
                            .where((e) => e.trim().isNotEmpty)
                            .toList(),
                        4,
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        width: 18.w,
                        height: 18.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFCB04),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.add,
                          size: 12.sp,
                          color: Colors.black,
                        ),
                      ),
                    ],
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
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB04A47),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  InkWell(
                    onTap: onDueDateTap,
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
                            color: const Color(0xFF8B9099),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              dueText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
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
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              task.description.trim().isEmpty ? '|' : task.description,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D3138),
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
                onLabelsChanged,
              ),
            ),
            SizedBox(width: 6.w),
            InkWell(
              onTap: onAddLabelTap,
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
            Container(
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
          ],
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 2.h),
            itemCount: task.attachments.isEmpty ? 4 : task.attachments.length,
            itemBuilder: (_, index) {
              final isMock = task.attachments.isEmpty;
              final fileName = isMock
                  ? 'Filenamegoeshere.jpg'
                  : task.attachments[index].name;
              final String? imageUrl = isMock
                  ? null
                  : (task.attachments[index].isImage
                        ? task.attachments[index].iconUrl
                        : null);
              return _buildTaskPreviewAttachmentTile(
                fileName,
                imageUrl: imageUrl,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskPreviewLabels(
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

  Widget _buildTaskPreviewLabelPill(
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
              fontSize: 8.5.sp,
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

  Widget _buildTaskPreviewCommentsContent(
    ProjectTaskModel task,
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
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
            itemCount: task.activities.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
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
                            fontSize: 8.8.sp,
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

  Widget _buildTaskPreviewSheetIcon(IconData icon, Color color) {
    return Container(
      width: 20.w,
      height: 20.h,
      alignment: Alignment.center,
      child: Icon(icon, size: 18.sp, color: color),
    );
  }

  Widget _buildTaskPreviewFooterTab({
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

  Widget _buildTaskPreviewAttachmentTile(String name, {String? imageUrl}) {
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
            child: imageUrl != null && imageUrl.trim().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.w),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF1D1E20),
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  '15 mb | 01/21/2026 | 12:00pm',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8B8F97),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
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
        ],
      ),
    );
  }

  Widget _buildTaskMiniMoreButton() {
    return Container(
      width: 24.w,
      height: 24.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(10.r),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.more_vert, size: 13.sp, color: const Color(0xFF7C8088)),
    );
  }

  Widget _buildTaskPill(String label, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _taskDueText(ProjectTaskModel task) {
    final parsed = _parseDueDate(task.dueDate);
    if (parsed == null) {
      if (task.dueDate.trim().isEmpty) return '-';
      return task.dueDate.contains('|') ? task.dueDate : task.dueDate.replaceFirst(' ', ' | ');
    }
    final date = parsed;
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
    final month = monthAbbr[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'pm' : 'am';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final formatted = '$month $day, ${date.year} $hour:$minute$suffix';
    return formatted.replaceFirst(' ', ' | ');
  }

  DateTime? _parseDueDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso.toLocal();

    const formats = [
      'MMM d, yyyy h:mma',
      'MMM dd, yyyy h:mma',
      'MMM d, yyyy hh:mma',
      'MMM dd, yyyy hh:mma',
      'MMM d, yyyy',
      'MMM dd, yyyy',
    ];
    for (final pattern in formats) {
      try {
        return DateFormat(pattern).parse(value);
      } catch (_) {
        // Try next
      }
    }
    return null;
  }

  String _formatDueDateText(DateTime? value) {
    if (value == null) return 'No due date';
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

  Future<DateTime?> _pickDueDateTime(
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

  String _taskStatusText(ProjectTaskModel task) {
    if (task.sectionName.trim().isNotEmpty) return task.sectionName;
    final status = task.status.trim();
    if (status.isEmpty) return 'Task';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }

  Color _taskStatusPillBg(ProjectTaskModel task) {
    final value = task.status.toLowerCase();
    if (value.contains('done') || value.contains('complete')) {
      return const Color(0xFFFFECE8);
    }
    return const Color(0xFFE7F0FF);
  }

  Color _taskStatusPillFg(ProjectTaskModel task) {
    final value = task.status.toLowerCase();
    if (value.contains('done') || value.contains('complete')) {
      return const Color(0xFFD84C43);
    }
    return const Color(0xFF2A72F8);
  }

  Color _colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.isEmpty) return const Color(0xFF8A8E97);
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF8A8E97);
  }

  Widget _buildFilterButton(int filterCount) {
    return InkWell(
      onTap: _showFilterForm,
      borderRadius: BorderRadius.circular(999.w),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ImageWidget(image: Paths.filter, width: 24, height: 24),
          if (filterCount > 0)
            Positioned(
              right: -8.w,
              top: -10.h,
              child: Container(
                width: 18.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCB04),
                  borderRadius: BorderRadius.circular(999.w),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$filterCount',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectOverflowButton(ProjectModel project) {
    return Builder(
      builder: (buttonContext) => InkWell(
        onTap: () => _showProjectActions(buttonContext, project),
        borderRadius: BorderRadius.circular(999.w),
        child: _iconShell(CupertinoIcons.ellipsis, compact: true),
      ),
    );
  }

  Widget _buildProgressSection(ProjectModel project, Color accentColor) {
    final stateText = _progressStateText(project);
    final trailingText = project.lateTasksCount <= 0
        ? null
        : 'Late tasks ${project.lateTasksCount}';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${project.displayProgressPercent}% $stateText',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
              color: accentColor,
              letterSpacing: 0.1,
            ),
          ),
          if (trailingText != null)
            const TextSpan(
              text: '  |  ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFBCBDC4),
              ),
            ),
          if (trailingText != null)
            const TextSpan(
              text: '',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE15C49),
              ),
            ),
          if (trailingText != null)
            TextSpan(
              text: trailingText,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE15C49),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildInfoPill(String label, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildCounterItem(IconData icon, int count) {
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
            color: Color(0xFF8F9199),
          ),
        ),
      ],
    );
  }

  String _progressStateText(ProjectModel project) {
    if (project.isCompleted) return 'COMPLETED';
    if (project.isInProgress) return 'IN PROGRESS';
    if (project.lateTasksCount > 0) return 'LATE TASKS';
    return project.displayStatus.toUpperCase();
  }

  Color _progressAccentColor(ProjectModel project) {
    if (project.isCompleted) return const Color(0xFF31C46C);
    if (project.isInProgress) return const Color(0xFFFF8A3C);
    return const Color(0xFFE15C49);
  }

  Widget _iconShell(IconData icon, {bool compact = false}) {
    return Container(
      width: compact ? 24.w : 30.w,
      height: compact ? 24.h : 30.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999.w),
        border: Border.all(color: const Color(0xFFE2E2E7)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: compact ? 13.sp : 16.sp, color: Colors.black87),
    );
  }

  Widget _buildAvatarStrip([List<String>? avatars, int maxVisible = 4]) {
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

  void _showCreateProjectForm() {
    final sheet = MobileProjectsFormScaffold(
      title: 'Project',
      child: const MobileProjectsCreateFormBody(),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => sheet,
    );
  }

  Future<void> _showFilterForm() async {
    final isProjectsView = _selectedView == _ProjectsHeaderView.projects;
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => isProjectsView
          ? const MobileProjectsFilterSheet()
          : const MobileTasksFilterSheet(),
    );

    if (!mounted) return;
    if (result == null) return;

    final projectPro = context.read<ProjectPro>();

    if (result is Map &&
        result[MobileProjectsFilterSheet.clearFiltersKey] == true) {
      if (isProjectsView) {
        await projectPro.getProjects(ctx: context, clearFilters: true);
      } else {
        await projectPro.getTasksList(ctx: context, clearFilters: true);
      }
      return;
    }

    if (result is Map<String, String>) {
      if (isProjectsView) {
        await projectPro.getProjects(ctx: context, filters: result);
      } else {
        await projectPro.getTasksList(ctx: context, filters: result);
      }
      return;
    }

    if (result is Map) {
      final filters = <String, String>{};
      for (final entry in result.entries) {
        if (entry.key == null || entry.value == null) continue;
        filters[entry.key.toString()] = entry.value.toString();
      }
      if (isProjectsView) {
        await projectPro.getProjects(ctx: context, filters: filters);
      } else {
        await projectPro.getTasksList(ctx: context, filters: filters);
      }
    }
  }

  void _openProjectTasks(ProjectModel project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileProjectTasksPage(projectId: project.numericId),
      ),
    );
  }

  Future<void> _showProjectActions(
    BuildContext buttonContext,
    ProjectModel project,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;
    final buttonTopRight = button.localToGlobal(
      Offset(button.size.width, 0),
      ancestor: overlay,
    );
    final buttonBottomRight = button.localToGlobal(
      Offset(button.size.width, button.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<_ProjectAction>(
      context: context,
      color: Colors.white,
      elevation: 10,
      position: RelativeRect.fromLTRB(
        buttonTopRight.dx - 152.w,
        buttonBottomRight.dy + 6.h,
        overlay.size.width - buttonTopRight.dx,
        overlay.size.height - buttonBottomRight.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.w)),
      items: const [
        PopupMenuItem<_ProjectAction>(
          value: _ProjectAction.edit,
          height: 38,
          padding: EdgeInsets.zero,
          child: _ProjectActionMenuRow(
            label: 'Edit Project',
            icon: Paths.edit,
            color: Colors.black,
          ),
        ),
        PopupMenuItem<_ProjectAction>(
          value: _ProjectAction.delete,
          height: 38,
          padding: EdgeInsets.zero,
          child: _ProjectActionMenuRow(
            label: 'Delete Project',
            icon: Paths.delete,
            color: Color(0xFFE45B45),
            showDivider: true,
          ),
        ),
      ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _ProjectAction.edit:
        await _showEditProjectPopup(project);
        break;
      case _ProjectAction.delete:
        await _confirmDeleteProject(project);
        break;
    }
  }

  Future<void> _showEditProjectPopup(ProjectModel project) async {
    final pro = context.read<ProjectPro>();
    await pro.getProjectClientOptions();
    await pro.getProjectCustomerOptions();

    final nameController = TextEditingController(text: project.name);
    final clients = pro.projectClientOptions
        .where((item) => (item['id'] ?? '').trim().isNotEmpty)
        .toList();
    final customers = pro.projectCustomerOptions
        .where((item) => (item['id'] ?? '').trim().isNotEmpty)
        .toList();

    int? selectedClientId;
    int? selectedCustomerId;
    final projectClientName = project.clientDisplayName.trim().toLowerCase();
    final projectCustomerName = project.customerDisplayName
        .trim()
        .toLowerCase();

    for (final client in clients) {
      final label = (client['label'] ?? '').trim().toLowerCase();
      if (label == projectClientName) {
        selectedClientId = int.tryParse((client['id'] ?? '').trim());
        break;
      }
    }

    for (final customer in customers) {
      final label = (customer['label'] ?? '').trim().toLowerCase();
      if (label != projectCustomerName) continue;
      final customerClientId = int.tryParse(
        (customer['client_id'] ?? '').trim(),
      );
      if (selectedClientId == null || customerClientId == selectedClientId) {
        selectedCustomerId = int.tryParse((customer['id'] ?? '').trim());
        break;
      }
    }

    String? selectedClientLabel() {
      if (selectedClientId == null) return null;
      for (final item in clients) {
        if (int.tryParse((item['id'] ?? '').trim()) == selectedClientId) {
          return item['label'];
        }
      }
      return null;
    }

    String? selectedCustomerLabel() {
      if (selectedCustomerId == null) return null;
      for (final item in customers) {
        if (int.tryParse((item['id'] ?? '').trim()) == selectedCustomerId) {
          return item['label'];
        }
      }
      return null;
    }

    List<Map<String, String>> filteredCustomers() {
      if (selectedClientId == null) return customers;
      return customers.where((item) {
        final clientId = int.tryParse((item['client_id'] ?? '').trim());
        return clientId == selectedClientId;
      }).toList();
    }

    Map<String, String>? selectedClientOption() {
      if (selectedClientId == null) return null;
      for (final item in clients) {
        if (int.tryParse((item['id'] ?? '').trim()) == selectedClientId) {
          return item;
        }
      }
      return null;
    }

    var isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 18.h, 18.w, 14.h),
                  child: Row(
                    children: [
                      ImageWidget(
                        image: Paths.task,
                        width: 21.w,
                        height: 21.h,
                        color: const Color(0xFF1E232B),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Project',
                          style: TextStyle(
                            fontSize: 31 / 2.2,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF171B23),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        child: Icon(
                          Icons.close,
                          size: 19.sp,
                          color: const Color(0xFF535964),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFDADCE1),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEditFieldLabel('* Project Name'),
                      SizedBox(height: 7.h),
                      Container(
                        // height: 42.h,
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F5),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: const Color(0xFFD8DAE0)),
                        ),
                        child: TextField(
                          controller: nameController,
                          textAlign: TextAlign.start,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: 'your task project',
                            hintStyle: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF757B86),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF242A34),
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      _buildEditFieldLabel('* Assign Client'),
                      SizedBox(height: 7.h),
                      _buildAssignPickerField(
                        selectedText: selectedClientLabel(),
                        options: clients,
                        onPick: (value) {
                          setDialogState(() {
                            selectedClientId = int.tryParse(
                              (value['id'] ?? '').trim(),
                            );

                            final selectedCustomerInScope = filteredCustomers()
                                .any(
                                  (item) =>
                                      int.tryParse((item['id'] ?? '').trim()) ==
                                      selectedCustomerId,
                                );
                            if (!selectedCustomerInScope) {
                              selectedCustomerId = null;
                            }
                          });
                        },
                        onClear: () => setDialogState(() {
                          selectedClientId = null;
                          selectedCustomerId = null;
                        }),
                      ),
                      SizedBox(height: 14.h),
                      _buildEditFieldLabel('Assigned Staff (auto)'),
                      SizedBox(height: 7.h),
                      _buildAssignedStaffAutoField(
                        _extractAssignedStaffFromClient(selectedClientOption()),
                      ),
                      SizedBox(height: 14.h),
                      _buildEditFieldLabel('Assign Customer'),
                      SizedBox(height: 7.h),
                      _buildAssignPickerField(
                        selectedText: selectedCustomerLabel(),
                        options: filteredCustomers(),
                        onPick: (value) => setDialogState(() {
                          selectedCustomerId = int.tryParse(
                            (value['id'] ?? '').trim(),
                          );
                        }),
                        onClear: () =>
                            setDialogState(() => selectedCustomerId = null),
                      ),
                      SizedBox(height: 18.h),
                      Center(
                        child: InkWell(
                          onTap: isSaving
                              ? null
                              : () async {
                                  final trimmedName = nameController.text
                                      .trim();
                                  if (trimmedName.isEmpty) {
                                    showToast(
                                      message: 'Project name is required',
                                    );
                                    return;
                                  }
                                  if (selectedClientId == null) {
                                    showToast(
                                      message: 'Please select a client',
                                    );
                                    return;
                                  }
                                  if (selectedCustomerId == null) {
                                    showToast(
                                      message: 'Please select a customer',
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSaving = true);
                                  Loaders.show();

                                  final ok = await context
                                      .read<ProjectPro>()
                                      .updateProjectCoreFields(
                                        projectId: project.numericId,
                                        name: trimmedName,
                                        clientId: selectedClientId!,
                                        customerId: selectedCustomerId!,
                                        clientName: selectedClientLabel(),
                                        customerName: selectedCustomerLabel(),
                                      );
                                  Loaders.hide();

                                  if (!dialogContext.mounted) return;
                                  setDialogState(() => isSaving = false);
                                  if (ok) {
                                    await pro.getProjects(ctx: context);
                                    Navigator.of(dialogContext).pop();
                                  }
                                },
                          borderRadius: BorderRadius.circular(999.r),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 9.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27C25A),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              isSaving ? 'Updating...' : 'Update',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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
    );
  }

  List<Map<String, String>> _extractAssignedStaffFromClient(
    Map<String, String>? client,
  ) {
    final encoded = client?['assigned_staff']?.trim() ?? '';
    if (encoded.isEmpty) return const <Map<String, String>>[];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const <Map<String, String>>[];

      final items = <Map<String, String>>[];
      for (final member in decoded) {
        if (member is! Map) continue;
        final map = Map<String, dynamic>.from(member);
        final id = map['id']?.toString() ?? '';
        final name = map['name']?.toString().trim() ?? '';
        final image = map['image']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        items.add({'id': id, 'name': name, 'image': image});
      }
      return items;
    } catch (_) {
      return const <Map<String, String>>[];
    }
  }

  Widget _buildAssignedStaffAutoField(List<Map<String, String>> staff) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 44.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F5),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFD8DAE0)),
      ),
      child: staff.isEmpty
          ? Text(
              'No staff assigned',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF9BA1AC),
              ),
            )
          : Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final item in staff)
                  Container(
                    padding: EdgeInsets.fromLTRB(8.w, 5.h, 8.w, 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFD9DCE3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.h,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE1E4EA),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _staffInitial(item['name'] ?? ''),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF7C818C),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          item['name'] ?? '',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF525866),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ImageWidget(
                          image: Paths.delete,
                          width: 12,
                          height: 12,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _staffInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '-';
    return trimmed[0].toUpperCase();
  }

  Widget _buildEditFieldLabel(String text) {
    final hasRequired = text.startsWith('*');
    final content = hasRequired ? text.substring(1).trim() : text;
    return RichText(
      text: TextSpan(
        children: [
          if (hasRequired)
            TextSpan(
              text: '* ',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE24A4A),
              ),
            ),
          TextSpan(
            text: content,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF262D37),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignPickerField({
    required String? selectedText,
    required List<Map<String, String>> options,
    required ValueChanged<Map<String, String>> onPick,
    required VoidCallback onClear,
  }) {
    return Builder(
      builder: (pickerContext) => InkWell(
        onTap: () async {
          if (options.isEmpty) return;

          final fieldBox = pickerContext.findRenderObject() as RenderBox;
          final overlayBox =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final fieldTopLeft = fieldBox.localToGlobal(
            Offset.zero,
            ancestor: overlayBox,
          );
          final fieldBottomLeft = fieldBox.localToGlobal(
            Offset(0, fieldBox.size.height),
            ancestor: overlayBox,
          );

          final picked = await showMenu<Map<String, String>>(
            context: context,
            color: Colors.white,
            elevation: 10,
            constraints: BoxConstraints(
              minWidth: fieldBox.size.width,
              maxWidth: fieldBox.size.width,
              maxHeight: 240.h,
            ),
            position: RelativeRect.fromLTRB(
              fieldTopLeft.dx,
              fieldBottomLeft.dy + 2.h,
              overlayBox.size.width - (fieldTopLeft.dx + fieldBox.size.width),
              overlayBox.size.height - fieldBottomLeft.dy,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            items: [
              for (final item in options)
                PopupMenuItem<Map<String, String>>(
                  value: item,
                  height: 38.h,
                  child: Text(
                    (item['label'] ?? '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212834),
                    ),
                  ),
                ),
            ],
          );

          if (picked != null) {
            onPick(picked);
          }
        },
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F2F5),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFD8DAE0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: selectedText == null || selectedText.trim().isEmpty
                    ? Text(
                        'Select',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF808793),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 150.w),
                          height: 30.h,
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCB04),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  selectedText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF212834),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              InkWell(
                                onTap: onClear,
                                borderRadius: BorderRadius.circular(99.r),
                                child: ImageWidget(
                                  image: Paths.delete,
                                  width: 12,
                                  height: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Icon(
                CupertinoIcons.chevron_down,
                size: 15.sp,
                color: const Color(0xFF7B818B),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteProject(ProjectModel project) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Delete project'),
        content: const Text(
          'Are you sure you want to delete this project? This action cannot be undone.',
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

    if (shouldDelete == true && mounted) {
      Loaders.show();
      final success = await context.read<ProjectPro>().deleteProject(
        projectId: project.numericId,
      );
      Loaders.hide();
      if (success) {
        // List refresh is handled by deleteProject and getProjects triggers
      }
    }
  }

  Future<void> _showTaskActions(
    BuildContext buttonContext,
    ProjectTaskModel task, {
    required _TaskMenuType menuType,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;
    final buttonTopRight = button.localToGlobal(
      Offset(button.size.width, 0),
      ancestor: overlay,
    );
    final buttonBottomRight = button.localToGlobal(
      Offset(button.size.width, button.size.height),
      ancestor: overlay,
    );

    final project = context.read<ProjectPro>().projects.where((p) => p.numericId == task.projectId).firstOrNull;

    final selected = await showMenu<_TaskAction>(
      context: context,
      color: Colors.white,
      elevation: 10,
      position: RelativeRect.fromLTRB(
        buttonTopRight.dx - 152.w,
        buttonBottomRight.dy + 6.h,
        overlay.size.width - buttonTopRight.dx,
        overlay.size.height - buttonBottomRight.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.w)),
      items: menuType == _TaskMenuType.primary
          ? [
              if (project != null)
                const PopupMenuItem<_TaskAction>(
                  value: _TaskAction.projectInfo,
                  height: 42,
                  padding: EdgeInsets.zero,
                  child: _TaskActionRow(
                    label: 'Project Info',
                    foregroundColor: Color(0xFF191B20),
                    icon: CupertinoIcons.info_circle,
                    iconColor: Color(0xFF7C8088),
                  ),
                ),
              const PopupMenuItem<_TaskAction>(
                value: _TaskAction.deleteTask,
                height: 42,
                padding: EdgeInsets.zero,
                child: _TaskActionRow(
                  label: 'Delete Task',
                  foregroundColor: Color(0xFFE45B45),
                  icon: CupertinoIcons.trash,
                  iconColor: Color(0xFF7C8088),
                ),
              ),
            ]
          : const [
              PopupMenuItem<_TaskAction>(
                value: _TaskAction.automation,
                height: 42,
                padding: EdgeInsets.zero,
                child: _TaskActionRow(
                  label: 'Automation',
                  foregroundColor: Color(0xFF191B20),
                  icon: CupertinoIcons.info_circle_fill,
                  iconColor: Color(0xFF5A606E),
                ),
              ),
            ],
    );

    if (!mounted || selected == null) return;

    switch (selected) {
      case _TaskAction.projectInfo:
        if (project != null) {
          _showProjectInfoPopup(
            project,
            buttonRect: Rect.fromLTWH(
              buttonTopRight.dx - button.size.width,
              buttonTopRight.dy,
              button.size.width,
              button.size.height,
            ),
            overlaySize: overlay.size,
          );
        }
      case _TaskAction.deleteTask:
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('Delete task'),
            content: const Text(
              'Are you sure you want to delete this task? This action cannot be undone.',
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

        if (shouldDelete == true && mounted) {
          Loaders.show();
          await context.read<ProjectPro>().deleteProjectTask(
            projectId: task.projectId,
            taskId: task.id,
          );
          Loaders.hide();
        }
      case _TaskAction.automation:
        showToast(message: 'Automation coming soon');
    }
  }

  Future<void> _showProjectInfoPopup(
    ProjectModel project, {
    required Rect buttonRect,
    required Size overlaySize,
  }) async {
    final horizontalMargin = 12.w;
    final popupWidth = (overlaySize.width - horizontalMargin * 2).clamp(
      280.w,
      400.w,
    );
    final calculatedLeft = buttonRect.right - popupWidth;
    final left = calculatedLeft.clamp(
      horizontalMargin,
      overlaySize.width - popupWidth - horizontalMargin,
    );
    final top = (buttonRect.bottom + 8.h).clamp(
      12.h,
      overlaySize.height - 220.h,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Project info',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.10),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final progressPercent = project.displayProgressPercent;
        final progressValue = (progressPercent.clamp(0, 100)) / 100;
        final progressState = project.displayStatus.toUpperCase();
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

  Widget _buildProjectInfoPopupCard(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    _buildProjectInfoAvatarStrip(project.avatars),
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

  Widget _buildProjectInfoMetric(IconData icon, int count) {
    return _buildCounterItem(icon, count);
  }

  Widget _buildProjectInfoPill({
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

  Widget _buildProjectInfoAvatarStrip(List<String> avatars) {
    final items = avatars;
    if (items.isEmpty) return const SizedBox.shrink();
    final shown = items.take(4).toList();
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
}

enum _ProjectAction { edit, delete }

enum _ProjectsHeaderView { projects, tasks }

enum _TaskPreviewTab { details, comments }

class _ProjectActionMenuRow extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final bool showDivider;

  const _ProjectActionMenuRow({
    required this.label,
    required this.icon,
    required this.color,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150.w,
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(top: BorderSide(color: Color(0xFFF0F0F3)))
            : null,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          ImageWidget(image: icon, width: 12, height: 12, color: color),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TaskMenuType { primary, secondary }
enum _TaskAction { projectInfo, deleteTask, automation }

class _TaskActionRow extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final IconData icon;
  final Color? iconColor;

  const _TaskActionRow({
    required this.label,
    required this.foregroundColor,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164.w,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: iconColor ?? foregroundColor),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
