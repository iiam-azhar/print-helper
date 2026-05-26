import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/models/projects_models.dart';
import 'package:print_helper/providers/project_pro.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/loaders.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/tablet_view/lib/tab_projects/widgets/tablet_task_preview_popup.dart';
import '../tab_widgets/tab_toasts.dart';

import 'package:print_helper/tablet_view/lib/tab_projects/widgets/tablet_tasks_calendar_view.dart';
import 'package:print_helper/tablet_view/lib/tab_projects/widgets/tablet_project_tasks_filter_sidebar.dart';

enum ProjectViewType { kanban, list, calendar }

class TabletProjectDetailView extends StatefulWidget {
  final ProjectModel project;
  final VoidCallback onBack;

  const TabletProjectDetailView({
    super.key,
    required this.project,
    required this.onBack,
  });

  @override
  State<TabletProjectDetailView> createState() =>
      _TabletProjectDetailViewState();
}

class _TabletProjectDetailViewState extends State<TabletProjectDetailView> {
  late final ScrollController _boardScrollController;
  ProjectViewType _viewType = ProjectViewType.kanban;
  Map<String, String> _activeFilters = {};

  @override
  @override
  void initState() {
    super.initState();
    _boardScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProjectPro>().getProjectLabels(ctx: context);
      context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: widget.project.numericId,
        forceRefresh: true,
      );
    });
  }

  @override
  void dispose() {
    _boardScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F6),
      appBar: _buildAppBar(),
      body: Consumer<ProjectPro>(
        builder: (context, pro, _) {
          final detail = pro.activeProjectDetail;
          final bool isCurrentDetail =
              detail?.project.numericId == widget.project.numericId;

          if (pro.projectDetailLoad && !isCurrentDetail) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!isCurrentDetail || detail == null) {
            return const Center(
              child: Text(
                'No tasks found',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7E8088),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8EC)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildSummary(detail),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _viewType == ProjectViewType.kanban
                          ? _buildKanbanView(detail)
                          : _viewType == ProjectViewType.list
                          ? _buildListView(detail)
                          : _buildCalendarView(detail),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE7E8EC))),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: widget.onBack,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Icon(
                    CupertinoIcons.chevron_back,
                    size: 22,
                    color: Color(0xFF151B27),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.project.cardCodeLabel.isNotEmpty) ...[
                Text(
                  widget.project.cardCodeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF98A0AC),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                widget.project.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17181B),
                ),
              ),
              const Spacer(),
              Text(
                widget.project.date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF98A0AC),
                ),
              ),
              const SizedBox(width: 16),
              _buildAvatarStrip(widget.project.avatars),
              const SizedBox(width: 16),
              if (_viewType == ProjectViewType.list) ...[
                _toolbarPill('+ Add Task', null, onTap: _showAddTaskDialog),
                const SizedBox(width: 12),
                _toolbarPill(
                  'Filter',
                  null,
                  iconImage: Paths.filter,
                  showBorder: true,
                  onTap: _showFilterSidebar,
                ),
                const SizedBox(width: 16),
              ],

              InkWell(
                onTap: _confirmDeleteProject,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    CupertinoIcons.delete,
                    size: 20,
                    color: Color(0xFF1F242E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final blankTask = ProjectTaskModel(
      id: 0,
      projectId: widget.project.numericId,
      projectName: widget.project.name,
      title: '',
      description: '',
      status: 'New',
      sectionName: 'New',
      statusKey: 'new',
      projectSectionId: 1,
      dueDate: '',
      apiCommentsCount: 0,
      apiAttachmentsCount: 0,
      members: [],
      labels: [],
      activities: [],
      attachments: [],
    );
    TabletTaskPreviewPopup.show(context, blankTask);
  }

  Future<void> _confirmDeleteProject() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
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
        projectId: widget.project.numericId,
      );
      Loaders.hide();

      if (success && mounted) {
        widget.onBack();
        context.read<ProjectPro>().getProjects(ctx: context);
      }
    }
  }

  void _showFilterSidebar() async {
    final result = await showGeneralDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filter Sidebar',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: TabletProjectTasksFilterSidebar(
              projectId: widget.project.numericId,
              initialFilters: _activeFilters,
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        if (result.containsKey(
          TabletProjectTasksFilterSidebar.clearFiltersKey,
        )) {
          _activeFilters = {};
        } else {
          _activeFilters = result;
        }
      });
      context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: widget.project.numericId,
        forceRefresh: true,
        filters: _activeFilters,
      );
    }
  }

  Widget _buildSummary(ProjectDetailModel detail) {
    final progress = widget.project.displayProgressPercent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8EC)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  'Client: ${widget.project.clientDisplayName}',
                  const Color(0xFFE7F1FF),
                  const Color(0xFF2D7CF6),
                ),
                _badge(
                  'Customer: ${widget.project.customerDisplayName}',
                  const Color(0xFFFFF4CE),
                  const Color(0xFFC18B00),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress <= 0 ? 0 : progress / 100,
                      minHeight: 3,
                      backgroundColor: const Color(0xFFE3E3E8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progressTrack(progress),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${progress.clamp(0, 100)}% ${_progressLabel(progress)}  |  Late tasks ${widget.project.lateTasksCount}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: _progressColor(progress),
                    ),
                  ),
                ],
              ),
            ),
          ),
          MenuAnchor(
            style: MenuStyle(
              backgroundColor: WidgetStateProperty.all(Colors.white),
              surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
              elevation: WidgetStateProperty.all(8),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            builder: (context, controller, child) {
              IconData icon = CupertinoIcons.square_grid_2x2;
              String label = 'Kanban';
              if (_viewType == ProjectViewType.list) {
                icon = CupertinoIcons.list_bullet;
                label = 'List';
              } else if (_viewType == ProjectViewType.calendar) {
                icon = CupertinoIcons.calendar;
                label = 'Calendar';
              }

              return _toolbarPill(
                label,
                icon,
                showChevron: true,
                chevronIcon: controller.isOpen
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(CupertinoIcons.list_bullet, size: 16),
                onPressed: () =>
                    setState(() => _viewType = ProjectViewType.list),
                child: const Text(
                  'List',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              MenuItemButton(
                leadingIcon: const Icon(
                  CupertinoIcons.square_grid_2x2,
                  size: 16,
                ),
                onPressed: () =>
                    setState(() => _viewType = ProjectViewType.kanban),
                child: const Text(
                  'Kanban',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              MenuItemButton(
                leadingIcon: const Icon(CupertinoIcons.calendar, size: 16),
                onPressed: () =>
                    setState(() => _viewType = ProjectViewType.calendar),
                child: const Text(
                  'Calendar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _toolbarPill('+ Add Status', null, onTap: _showAddStatusDialog),
          if (!detail.project.isProjectSavedAsTemplate) ...[
            const SizedBox(width: 8),
            _toolbarPill(
              'Template',
              CupertinoIcons.doc_text,
              onTap: _showSaveTemplateDialog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKanbanView(ProjectDetailModel detail) {
    final lanes = _buildLanes(detail);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLaneHeight = constraints.maxHeight;
        return Scrollbar(
          controller: _boardScrollController,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _boardScrollController,
            primary: false,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              height: maxLaneHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int index = 0; index < lanes.length; index++) ...[
                    SizedBox(
                      width: 280,
                      height: maxLaneHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: _estimatedLaneHeight(
                            lanes[index],
                            maxLaneHeight,
                          ),
                          child: _buildLane(
                            detail,
                            lanes[index],
                            _estimatedLaneHeight(lanes[index], maxLaneHeight),
                          ),
                        ),
                      ),
                    ),
                    if (index != lanes.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(ProjectDetailModel detail) {
    return TabletTasksCalendarView(
      tasks: detail.tasks,
      onRefresh: () async {
        context.read<ProjectPro>().getProjectDetail(
          ctx: context,
          projectId: widget.project.numericId,
          forceRefresh: true,
        );
      },
      onTaskTap: (task) => TabletTaskPreviewPopup.show(context, task),
      onTaskInfoTap: (buttonContext, task) =>
          TabletTaskPreviewPopup.show(context, task),
      onTaskDrop: _handleCalendarTaskDrop,
    );
  }

  Future<bool> _handleCalendarTaskDrop(
    ProjectTaskModel task,
    DateTime targetDate,
  ) async {
    final pro = context.read<ProjectPro>();
    final payload = {
      'title': task.title,
      'description': task.description,
      'project_section_id': task.projectSectionId,
      'due_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(targetDate),
      'assigned_members': task.members.map((m) => m.id).toList(),
      'label_ids': task.labels.map((l) => l.id).toList(),
    };

    final ok = await pro.updateProjectTask(
      projectId: task.projectId,
      taskId: task.id,
      payload: payload,
    );

    if (ok && mounted) {
      pro.getProjectDetail(
        ctx: context,
        projectId: task.projectId,
        forceRefresh: true,
        isSilent: true,
      );
    }
    return ok;
  }

  void _showAddStatusDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: _TabletAddStatusDialog(project: widget.project),
      ),
    );
  }

  void _showSaveTemplateDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _TabletSaveTemplateDialog(project: widget.project),
      ),
    );
  }

  void _showEditStatusDialog(ProjectSectionModel section) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: _TabletAddStatusDialog(
          project: widget.project,
          section: section,
        ),
      ),
    );
  }

  String _getTaskStatus(ProjectDetailModel detail, ProjectTaskModel task) {
    if (task.projectSectionId > 0) {
      final section = detail.sections.firstWhere(
        (s) => s.id == task.projectSectionId,
        orElse: () => const ProjectSectionModel(
          id: 0,
          name: '',
          sortOrder: 0,
          status: '',
        ),
      );
      if (section.id > 0) return section.name;
    }
    return task.sectionName.trim().isEmpty ? 'New' : task.sectionName;
  }

  Widget _buildListView(ProjectDetailModel detail) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8EC)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF2F2F5))),
            ),
            child: Row(
              children: [
                const Expanded(
                  flex: 4,
                  child: Text('Task', style: _headerStyle),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Status', style: _headerStyle),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('Labels', style: _headerStyle),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Members', style: _headerStyle),
                ),
                const Expanded(
                  flex: 3,
                  child: Text('Due Date', style: _headerStyle),
                ),
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Details',
                    style: _headerStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: detail.tasks.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF2F2F5)),
              itemBuilder: (context, index) =>
                  _buildListRow(detail, detail.tasks[index]),
            ),
          ),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF7E8088),
    letterSpacing: 0.5,
  );

  Widget _buildListRow(ProjectDetailModel detail, ProjectTaskModel task) {
    final avatars = task.members.map((m) => m.image).toList();

    return InkWell(
      onTap: () => TabletTaskPreviewPopup.show(context, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Task
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF272730),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.description.isEmpty
                        ? 'No description'
                        : task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF7E8088),
                    ),
                  ),
                ],
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F6),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFE8E8EC)),
                      ),
                      child: Text(
                        _getTaskStatus(detail, task),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF43434C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MenuAnchor(
                    style: MenuStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.white),
                      surfaceTintColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                      elevation: WidgetStateProperty.all(8),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    builder: (context, controller, child) {
                      return InkWell(
                        onTap: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F3F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 12,
                            color: Color(0xFF8A8A94),
                          ),
                        ),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(
                          CupertinoIcons.info_circle,
                          size: 16,
                          color: Color(0xFF586579),
                        ),
                        onPressed: () {},
                        child: const Text(
                          'Automation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Labels
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: task.labels.map((l) => _labelChip(l)).toList(),
              ),
            ),
            // Members
            Expanded(flex: 2, child: _buildAvatarStrip(avatars)),
            // Due Date
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    size: 11,
                    color: Color(0xFF7E8088),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDueDate(task.dueDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF43434C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _miniMetric(
                    CupertinoIcons.chat_bubble_text,
                    task.commentsCount.toString(),
                  ),
                  const SizedBox(width: 4),
                  _miniMetric(
                    CupertinoIcons.doc,
                    task.attachmentsCount.toString(),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _confirmDeleteTask(task),
                    child: const Icon(
                      CupertinoIcons.delete,
                      size: 14,
                      color: Color(0xFF8A8A94),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTask(ProjectTaskModel task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
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
      final success = await context.read<ProjectPro>().deleteProjectTask(
        projectId: task.projectId,
        taskId: task.id,
      );
      Loaders.hide();
      if (success && mounted) {
        showToast(message: 'Task deleted successfully');
        context.read<ProjectPro>().getProjectDetail(
          ctx: context,
          projectId: task.projectId,
          forceRefresh: true,
          isSilent: true,
        );
      }
    }
  }

  Widget _labelChip(ProjectTaskLabel label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: label.parsedColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.name,
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDueDate(String dateStr) {
    if (dateStr.isEmpty || dateStr.toLowerCase() == 'null') return '--';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy | hh:mma').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildLane(
    ProjectDetailModel detail,
    _DetailLane lane,
    double laneHeight,
  ) {
    final title = lane.title.toLowerCase();
    Color bgColor = const Color(0xFFFFFDF4);
    Color borderColor = const Color(0xFFF0E9D3);

    if (lane.id == 1 || title == 'new' || title == 'pending') {
      bgColor = const Color(0xFFE9EAEF);
      borderColor = const Color(0xFFDBDEE5);
    } else if (lane.id == 3 || title == 'completed') {
      bgColor = const Color(0xFFF5FEF5);
      borderColor = const Color(0xFFE2EFE2);
    }

    return DragTarget<ProjectTaskModel>(
      onWillAcceptWithDetails: (details) =>
          details.data.projectSectionId != lane.id,
      onAcceptWithDetails: (details) async {
        final task = details.data;
        final oldSectionId = task.projectSectionId;
        final oldSectionName = task.sectionName;

        final pro = context.read<ProjectPro>();

        // Optimistic Move
        pro.optimisticTaskMove(
          taskId: task.id,
          newSectionId: lane.id,
          newSectionName: lane.title,
        );

        final payload = {
          'title': task.title,
          'description': task.description,
          'project_section_id': lane.id,
          'due_date': task.dueDate,
          'assigned_members': task.members.map((m) => m.id).toList(),
          'label_ids': task.labels.map((l) => l.id).toList(),
        };

        final ok = await pro.updateProjectTask(
          projectId: task.projectId,
          taskId: task.id,
          payload: payload,
        );

        if (ok && mounted) {
          pro.getProjectDetail(
            ctx: context,
            projectId: task.projectId,
            forceRefresh: true,
            isSilent: true,
          );
        } else if (!ok && mounted) {
          // Rollback on failure
          pro.optimisticTaskMove(
            taskId: task.id,
            newSectionId: oldSectionId,
            newSectionName: oldSectionName,
          );
          showToast(message: 'Unable to move task');
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          height: laneHeight,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOver ? const Color(0xFFE0E7FF) : bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOver ? const Color(0xFF6366F1) : borderColor,
              width: isOver ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      final section = detail.sections.firstWhere(
                        (s) => s.id == lane.id,
                        orElse: () => ProjectSectionModel(
                          id: lane.id,
                          name: lane.title,
                          sortOrder: 0,
                          status: '',
                        ),
                      );
                      _showEditStatusDialog(section);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        lane.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00112C),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (lane.id != 1 && lane.id != 2 && lane.id != 3)
                    const Icon(
                      CupertinoIcons.ellipsis_vertical,
                      size: 14,
                      color: Color(0xFF8A8A94),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: lane.items.isEmpty
                    ? Align(
                        alignment: Alignment.topCenter,
                        child: DottedBorder(
                          options: RoundedRectDottedBorderOptions(
                            color: const Color(0xFFD4D9E2),
                            strokeWidth: 1,
                            dashPattern: const [5, 4],
                            radius: const Radius.circular(12),
                            padding: EdgeInsets.zero,
                          ),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 0),
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'No tasks in ${lane.title}.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFB1B1BB),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(
                          scrollbars: false,
                        ),
                        child: ListView.separated(
                          primary: false,
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          itemCount: lane.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _buildCard(lane.title, lane.items[index]),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      final pId = widget.project.numericId;
                      TabletTaskPreviewPopup.show(
                        context,
                        ProjectTaskModel(
                          id: 0,
                          projectId: pId,
                          projectName: widget.project.name,
                          projectSectionId: lane.id,
                          sectionName: lane.title,
                          title: '',
                          description: '',
                          status: lane.title,
                          statusKey: '',
                          dueDate: '',
                          members: [],
                          labels: [],
                          attachments: [],
                          activities: [],
                          apiCommentsCount: 0,
                          apiAttachmentsCount: 0,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.add,
                            size: 14,
                            color: Color(0xFF00112C),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Add Task',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00112C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  double _estimatedLaneHeight(_DetailLane lane, double maxLaneHeight) {
    const double laneMinHeight = 170;
    const double laneHeaderHeight = 24;
    const double laneHeaderGap = 10;
    const double laneFooterHeight = 44;
    const double laneFooterGap = 12;
    const double laneInnerPadding = 20;
    final double cardEstimate = 120;
    final double separators = lane.items.isEmpty
        ? 0
        : (lane.items.length - 1) * 10;
    final double desiredHeight =
        laneHeaderHeight +
        laneHeaderGap +
        laneFooterGap +
        laneFooterHeight +
        laneInnerPadding +
        (lane.items.length * cardEstimate) +
        separators;

    final double lowerBound = laneMinHeight.clamp(0.0, maxLaneHeight);
    return desiredHeight.clamp(lowerBound, maxLaneHeight).toDouble();
  }

  Widget _buildCard(String laneTitle, ProjectTaskModel task) {
    return LongPressDraggable<ProjectTaskModel>(
      data: task,
      axis: null,
      delay: const Duration(milliseconds: 150),
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: Directionality(
          textDirection: Directionality.of(context),
          child: SizedBox(
            width: 260,
            child: _buildCardContent(laneTitle, task),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(laneTitle, task),
      ),
      child: _buildCardContent(laneTitle, task),
    );
  }

  Widget _buildCardContent(String laneTitle, ProjectTaskModel task) {
    final avatars = task.members.map((m) => m.image).toList();
    final bool isNewLane = laneTitle == 'New';

    return InkWell(
      onTap: () {
        TabletTaskPreviewPopup.show(context, task);
      },
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isNewLane ? 126 : 0),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00112C),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isNewLane)
                        const Icon(
                          CupertinoIcons.ellipsis_vertical,
                          size: 14,
                          color: Color(0xFF8A8A94),
                        ),
                    ],
                  ),
                  if (task.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF98A0AC),
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildAvatarStrip(avatars),
                      const Spacer(),
                      _miniMetric(
                        CupertinoIcons.chat_bubble_text,
                        task.commentsCount.toString(),
                      ),
                      const SizedBox(width: 8),
                      _miniMetric(
                        CupertinoIcons.doc,
                        task.attachmentsCount.toString(),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('Delete Task'),
                              content: const Text(
                                'Are you sure you want to delete this task? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
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
                        },
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            CupertinoIcons.delete,
                            size: 12,
                            color: Color(0xFF7E7E88),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.dueDate.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.clock,
                          size: 13,
                          color: Color(0xFF98A0AC),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDueDate(task.dueDate),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF98A0AC),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (task.labels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < task.labels.length; i++) ...[
                          Expanded(
                            child: _progressBar(
                              Color(
                                int.tryParse(
                                      task.labels[i].color.replaceFirst(
                                        '#',
                                        'ff',
                                      ),
                                      radix: 16,
                                    ) ??
                                    0xFF000000,
                              ),
                            ),
                          ),
                          if (i < task.labels.length - 1)
                            const SizedBox(width: 5),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarPill(
    String label,
    IconData? icon, {
    String? iconImage,
    bool showChevron = false,
    IconData chevronIcon = CupertinoIcons.chevron_down,
    VoidCallback? onTap,
    bool showBorder = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: showBorder
              ? Border.all(color: const Color(0xFFE1E1E6))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconImage != null) ...[
              ImageWidget(
                image: iconImage,
                width: 4,
                height: 4,
                color: const Color(0xFF4F4F58),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFF4F4F58)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF43434C),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(chevronIcon, size: 11, color: const Color(0xFF4F4F58)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniMetric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFFB1B1BB)),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB1B1BB),
          ),
        ),
      ],
    );
  }

  Widget _progressBar(Color color) {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildAvatarStrip(List<String> avatars) {
    final shown = avatars.take(4).toList();
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: shown.length * 18.0 + 16,
      height: 26,
      child: Stack(
        children: [
          for (int index = 0; index < shown.length; index++)
            Positioned(
              left: index * 16,
              child: Container(
                width: 26,
                height: 26,
                padding: const EdgeInsets.all(1.3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.network(
                    (shown[index].isEmpty ||
                            shown[index].toLowerCase() == 'null')
                        ? Paths.user
                        : shown[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return ImageWidget(image: Paths.user, fit: BoxFit.cover);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_DetailLane> _buildLanes(ProjectDetailModel detail) {
    final options = detail.sections;
    final lanes = <_DetailLane>[];
    if (options.isNotEmpty) {
      for (final option in options) {
        lanes.add(
          _DetailLane(
            id: option.id,
            title: option.name,
            items: detail.tasks
                .where(
                  (t) =>
                      t.projectSectionId == option.id ||
                      t.sectionName == option.name,
                )
                .toList(),
          ),
        );
      }
    } else {
      final sectionNames = detail.tasks.map((t) => t.sectionName).toSet();
      for (final name in sectionNames) {
        final tasksInLane = detail.tasks
            .where((t) => t.sectionName == name)
            .toList();
        lanes.add(
          _DetailLane(
            id: tasksInLane.isNotEmpty ? tasksInLane.first.projectSectionId : 0,
            title: name.trim().isEmpty ? 'Pending' : name,
            items: tasksInLane,
          ),
        );
      }
    }
    return lanes;
  }

  String _progressLabel(int progress) {
    if (progress >= 100) return 'COMPLETED';
    if (progress > 0) return 'IN PROGRESS';
    return 'NOT STARTED';
  }

  Color _progressColor(int progress) {
    if (progress >= 100) return const Color(0xFF28B463);
    if (progress > 0) return const Color(0xFFF08A2B);
    return const Color(0xFF9A9AA4);
  }

  Color _progressTrack(int progress) {
    if (progress >= 100) return const Color(0xFF30B76A);
    if (progress > 0) return const Color(0xFFF08A2B);
    return const Color(0xFFD8D8DE);
  }
}

class _DetailLane {
  final int id;
  final String title;
  final List<ProjectTaskModel> items;

  const _DetailLane({
    required this.id,
    required this.title,
    required this.items,
  });
}

class _TabletAddStatusDialog extends StatefulWidget {
  final ProjectModel project;
  final ProjectSectionModel? section;

  const _TabletAddStatusDialog({required this.project, this.section});

  @override
  State<_TabletAddStatusDialog> createState() => _TabletAddStatusDialogState();
}

class _TabletAddStatusDialogState extends State<_TabletAddStatusDialog> {
  final _nameController = TextEditingController();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.section != null) {
      _nameController.text = widget.section!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(message: 'Please enter a status name');
      return;
    }

    setState(() => _isBusy = true);
    final pro = context.read<ProjectPro>();

    ProjectSectionModel? result;
    if (widget.section != null) {
      result = await pro.updateProjectSection(
        sectionId: widget.section!.id,
        name: name,
      );
    } else {
      result = await pro.createProjectSection(name: name);
    }

    if (mounted) {
      setState(() => _isBusy = false);
      if (result != null) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - viewInsets.bottom - 80;

    return Center(
      child: Container(
        width: 440,
        constraints: BoxConstraints(maxHeight: availableHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.square_list,
                    size: 24,
                    color: Color(0xFF1F1F27),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F1F27),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF98A0AC),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE9E9EF)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Color(0xFFE45B45),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' Status Name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F1F27),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type Status Name',
                        hintStyle: const TextStyle(
                          color: Color(0xFF98A0AC),
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E2E8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E2E8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isBusy ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1ECB5C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                widget.section != null
                                    ? 'Update Status'
                                    : 'Create New',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletSaveTemplateDialog extends StatefulWidget {
  final ProjectModel project;

  const _TabletSaveTemplateDialog({required this.project});

  @override
  State<_TabletSaveTemplateDialog> createState() =>
      _TabletSaveTemplateDialogState();
}

class _TabletSaveTemplateDialogState extends State<_TabletSaveTemplateDialog> {
  late final TextEditingController _nameController;
  bool _isPublic = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: '${widget.project.name.toLowerCase()} template',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showToast(message: 'Please enter a template name');
      return;
    }

    setState(() => _isBusy = true);
    final pro = context.read<ProjectPro>();

    final success = await pro.saveProjectTemplate(
      projectId: widget.project.numericId,
      name: name,
      isPublic: _isPublic,
    );

    if (mounted) {
      setState(() => _isBusy = false);
      if (success) {
        Navigator.of(context).pop();
        // Refresh project detail to update "isProjectSavedAsTemplate" state
        pro.getProjectDetail(
          ctx: context,
          projectId: widget.project.numericId,
          forceRefresh: true,
          isSilent: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - viewInsets.bottom - 80;

    return Center(
      child: Container(
        width: 440,
        constraints: BoxConstraints(maxHeight: availableHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 10),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.doc_text,
                    size: 24,
                    color: Color(0xFF1F1F27),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Save Project Template',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F1F27),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: Color(0xFF98A0AC),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE9E9EF)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: '*',
                            style: TextStyle(
                              color: Color(0xFFE45B45),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' Template Name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F1F27),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type Template Name',
                        hintStyle: const TextStyle(
                          color: Color(0xFF98A0AC),
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E2E8),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E2E8),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Visibility',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F1F27),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: _isPublic,
                      onChanged: (val) {
                        if (val != null) setState(() => _isPublic = val);
                      },
                      activeColor: const Color(0xFF2E6FF1),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Available for all users',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: _isPublic,
                      onChanged: (val) {
                        if (val != null) setState(() => _isPublic = val);
                      },
                      activeColor: const Color(0xFF2E6FF1),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Only for me',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isBusy ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E6FF1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Save Template',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
