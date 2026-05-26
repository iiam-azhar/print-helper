import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../admin/projects/widgets/mobile_projects_forms_section.dart';
import '../../../constants/paths.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_toasts.dart';
import '../../../models/projects_models.dart';
import '../../../providers/project_pro.dart';
import 'project_detail_view.dart';
import 'widgets/tablet_tasks_calendar_view.dart';
import 'widgets/tablet_task_preview_popup.dart';
import 'widgets/tablet_project_tasks_filter_sidebar.dart';
import 'widgets/tablet_projects_filter_sidebar.dart';
import 'widgets/tablet_project_edit_sidebar.dart';

class TabProjectsSection extends StatefulWidget {
  const TabProjectsSection({super.key});

  @override
  State<TabProjectsSection> createState() => _TabProjectsSectionState();
}

class _TabProjectsSectionState extends State<TabProjectsSection> {
  _ProjectsHeaderView _selectedView = _ProjectsHeaderView.projects;
  _TaskDisplayMode _taskDisplayMode = _TaskDisplayMode.list;
  ProjectModel? _selectedProject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSelectedView();
    });
  }

  Future<void> _loadSelectedView() {
    final pro = context.read<ProjectPro>();
    if (_selectedView == _ProjectsHeaderView.projects) {
      return pro.getProjects(ctx: context);
    }
    return pro.getTasksList(ctx: context);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedProject != null) {
      return TabletProjectDetailView(
        project: _selectedProject!,
        onBack: () => setState(() => _selectedProject = null),
      );
    }

    return Consumer<ProjectPro>(
      builder: (context, pro, _) {
        final projects = pro.projects;
        final tasks = pro.tasks;
        final isProjectsView = _selectedView == _ProjectsHeaderView.projects;
        final appliedFilterCount = isProjectsView
            ? pro.appliedProjectFilterCount
            : pro.appliedTaskFilterCount;
        return Container(
          color: const Color(0xFFF2F3F6),
          padding: const EdgeInsets.fromLTRB(12, 30, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9DBE1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  _TabletProjectsHeader(
                    totalCount: pro.totalCount > 0
                        ? pro.totalCount
                        : (isProjectsView ? projects.length : tasks.length),
                    selectedView: _selectedView,
                    taskDisplayMode: _taskDisplayMode,
                    appliedFilters: appliedFilterCount,
                    onAdd: _showCreateProjectForm,
                    onFilter: _showFilterForm,
                    onViewChanged: _changeView,
                    onTaskDisplayModeChanged: (mode) {
                      setState(() => _taskDisplayMode = mode);
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE7E8EC),
                  ),
                  Expanded(
                    child:
                        (pro.projectLoad &&
                            (isProjectsView ? projects.isEmpty : tasks.isEmpty))
                        ? RefreshIndicator(
                            onRefresh: _loadSelectedView,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 400,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(),
                              ),
                            ),
                          )
                        : (isProjectsView
                              ? (projects.isEmpty
                                    ? RefreshIndicator(
                                        onRefresh: _loadSelectedView,
                                        child: SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: Container(
                                            height: 400,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'No projects found',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7D828D),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : RefreshIndicator(
                                        onRefresh: _loadSelectedView,
                                        child: ListView.separated(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            10,
                                          ),
                                          itemCount: projects.length,
                                          separatorBuilder: (_, _) =>
                                              const SizedBox(height: 9),
                                          itemBuilder: (context, index) {
                                            final project = projects[index];
                                            return _ProjectCard(
                                              project: project,
                                              highlighted: index == 0,
                                              onTap: () =>
                                                  _openProjectTasks(project),
                                              onEdit: () =>
                                                  _showEditProjectDialog(
                                                    project,
                                                  ),
                                              onDelete: () =>
                                                  _confirmDeleteProject(
                                                    project,
                                                  ),
                                            );
                                          },
                                        ),
                                      ))
                              : (tasks.isEmpty
                                    ? RefreshIndicator(
                                        onRefresh: _loadSelectedView,
                                        child: SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: Container(
                                            height: 400,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'No tasks found',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7D828D),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : (_taskDisplayMode == _TaskDisplayMode.list
                                          ? _TasksTable(
                                              tasks: tasks,
                                              onRefresh: _loadSelectedView,
                                            )
                                          : TabletTasksCalendarView(
                                              tasks: tasks,
                                              onRefresh: _loadSelectedView,
                                              onTaskTap: (task) {
                                                TabletTaskPreviewPopup.show(
                                                  context,
                                                  task,
                                                );
                                              },
                                              onTaskInfoTap:
                                                  (buttonContext, task) {
                                                    _showTabletTaskInfoPopup(
                                                      context: context,
                                                      buttonContext:
                                                          buttonContext,
                                                      task: task,
                                                    );
                                                  },
                                              onTaskDrop: (task, targetDate) async {
                                                final mergedDueDate =
                                                    _mergeTaskDropDate(
                                                      task: task,
                                                      targetDate: targetDate,
                                                    );
                                                final payload =
                                                    <String, dynamic>{
                                                      'title': task.title,
                                                      'description':
                                                          task.description
                                                              .trim()
                                                              .isEmpty
                                                          ? task.title
                                                          : task.description,
                                                      'due_date': DateFormat(
                                                        'yyyy-MM-dd HH:mm:ss',
                                                      ).format(mergedDueDate),
                                                    };
                                                final ok = await context
                                                    .read<ProjectPro>()
                                                    .updateProjectTask(
                                                      projectId: task.projectId,
                                                      taskId: task.id,
                                                      payload: payload,
                                                    );
                                                if (!ok && mounted) {
                                                  showToast(
                                                    message:
                                                        'Unable to move task to selected date',
                                                  );
                                                }
                                                return ok;
                                              },
                                            )))),
                  ),
                  if (pro.lastPage > 1 &&
                      (_selectedView == _ProjectsHeaderView.projects ||
                          _taskDisplayMode == _TaskDisplayMode.list))
                    _PaginationBar(
                      currentPage: pro.currentPage,
                      lastPage: pro.lastPage,
                      onPageTap: (page) => _loadPage(page),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
            child: isProjectsView
                ? const TabletProjectsFilterSidebar()
                : TabletProjectTasksFilterSidebar(
                    projectId:
                        0, // In global tasks view, projectId is 0 or handled differently
                    initialFilters: context
                        .read<ProjectPro>()
                        .activeTaskFilters,
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

    if (!mounted || result == null) return;

    final projectPro = context.read<ProjectPro>();

    // Check for clear filters key in either projects or tasks sidebar
    if (result.containsKey(TabletProjectsFilterSidebar.clearFiltersKey) ||
        result.containsKey(TabletProjectTasksFilterSidebar.clearFiltersKey)) {
      if (isProjectsView) {
        await projectPro.getProjects(ctx: context, clearFilters: true);
      } else {
        await projectPro.getTasksList(ctx: context, clearFilters: true);
      }
      return;
    }

    if (isProjectsView) {
      await projectPro.getProjects(ctx: context, filters: result);
    } else {
      await projectPro.getTasksList(ctx: context, filters: result);
    }
  }

  void _openProjectTasks(ProjectModel project) {
    setState(() => _selectedProject = project);
  }

  Future<void> _loadPage(int page) async {
    final pro = context.read<ProjectPro>();
    if (page == pro.currentPage || page < 1 || page > pro.lastPage) return;
    if (_selectedView == _ProjectsHeaderView.projects) {
      await pro.getProjects(ctx: context, page: page);
    } else {
      await pro.getTasksList(ctx: context, page: page);
    }
  }

  Future<void> _changeView(_ProjectsHeaderView next) async {
    if (_selectedView == next) return;
    setState(() => _selectedView = next);
    await _loadSelectedView();
  }

  DateTime _mergeTaskDropDate({
    required ProjectTaskModel task,
    required DateTime targetDate,
  }) {
    final existing = DateTime.tryParse(task.dueDate.trim());
    if (existing == null) {
      return DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
    }
    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      existing.hour,
      existing.minute,
      existing.second,
    );
  }

  Future<void> _showEditProjectDialog(ProjectModel project) async {
    final result = await TabletProjectEditSidebar.show(context, project);
    if (result == true && mounted) {
      await context.read<ProjectPro>().getProjects(ctx: context);
    }
  }

  Future<void> _confirmDeleteProject(ProjectModel project) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

    if (shouldDelete != true || !mounted) return;
    final success = await context.read<ProjectPro>().deleteProject(
      projectId: project.numericId,
    );
    if (success) {
      showToast(message: 'Project deleted');
    }
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.highlighted,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = project.displayProgressPercent;
    final accentColor = _progressAccentColor(project);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFE56B73)
                : const Color(0xFFE1E3E8),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    project.cardCodeLabel,
                    style: const TextStyle(
                      fontSize: 21 / 2,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AE),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 33 / 2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF181B22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      project.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF98A0AC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _AvatarStrip(avatars: project.avatars),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        Paths.edit,
                        width: 18,
                        height: 18,
                        color: const Color(0xFF1F242E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(
                        Paths.delete,
                        width: 18,
                        height: 18,
                        color: const Color(0xFF1F242E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE3E4E8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: _InfoChip(
                            label: 'Client: ${project.clientDisplayName}',
                            backgroundColor: const Color(0xFFD9E9FF),
                            textColor: const Color(0xFF005ED8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _InfoChip(
                            label: 'Customer: ${project.customerDisplayName}',
                            backgroundColor: const Color(0xFFF2ECD7),
                            textColor: const Color(0xFFB18400),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: LinearProgressIndicator(
                                  value: progress <= 0 ? 0 : progress / 100,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFDFE1E6),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${progress.clamp(0, 100)}% ${project.displayStatus.toUpperCase()}  |  Late tasks ${project.lateTasksCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _Counter(
                          icon: Icons.assignment_outlined,
                          count: project.tasksCount,
                        ),
                        const SizedBox(width: 12),
                        _Counter(
                          icon: Icons.chat_bubble_outline,
                          count: project.commentsCount,
                        ),
                        const SizedBox(width: 12),
                        _Counter(
                          icon: Icons.attach_file,
                          count: project.attachmentsCount,
                        ),
                      ],
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
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _TasksTable extends StatelessWidget {
  final List<ProjectTaskModel> tasks;
  final Future<void> Function() onRefresh;

  const _TasksTable({required this.tasks, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDFE2E8)),
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
          ),
          child: Column(
            children: [
              const _TaskTableHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFE5E8EE)),
                    itemBuilder: (context, index) =>
                        _TaskTableRow(task: tasks[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTableHeader extends StatelessWidget {
  const _TaskTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: const Color(0xFFF2F3F6),
      child: const Row(
        children: [
          SizedBox(width: 54, child: _TaskHeaderText('P.Info')),
          Expanded(flex: 35, child: _TaskHeaderText('Task')),
          Expanded(flex: 17, child: _TaskHeaderText('Status')),
          Expanded(flex: 21, child: _TaskHeaderText('Labels')),
          Expanded(flex: 17, child: _TaskHeaderText('Members')),
          Expanded(flex: 23, child: _TaskHeaderText('Due')),
          SizedBox(width: 108, child: _TaskHeaderText('Details')),
        ],
      ),
    );
  }
}

class _TaskHeaderText extends StatelessWidget {
  final String text;
  const _TaskHeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF151B27),
      ),
    );
  }
}

class _TaskTableRow extends StatelessWidget {
  final ProjectTaskModel task;

  const _TaskTableRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final dueInfo = _dueInfo(task.dueDate);
    final projectLabel = task.projectName.trim().isEmpty
        ? 'Project'
        : task.projectName.trim();

    return InkWell(
      onTap: () => TabletTaskPreviewPopup.show(context, task),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Builder(
                  builder: (buttonContext) => InkWell(
                    onTap: () => _showTabletTaskInfoPopup(
                      context: context,
                      buttonContext: buttonContext,
                      task: task,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Color(0xFF8F95A1),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF171D28),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$projectLabel · ${task.projectId.toString().padLeft(7, '0')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF96A0AF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 17,
                child: Row(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusPill(
                          status: task.sectionName.isEmpty
                              ? task.status
                              : task.sectionName,
                        ),
                      ),
                    ),
                    const _StatusMenuButton(),
                  ],
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                flex: 21,
                child: task.labels.isEmpty
                    ? const Text(
                        '-',
                        style: TextStyle(
                          color: Color(0xFFA0A8B6),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: task.labels.map((label) {
                          return _TaskLabelPill(label: label);
                        }).toList(),
                      ),
              ),
              SizedBox(width: 15),
              Expanded(flex: 17, child: _TaskMembers(members: task.members)),
              Expanded(
                flex: 23,
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: dueInfo.isLate
                          ? const Color(0xFFE35353)
                          : const Color(0xFF718199),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        dueInfo.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: dueInfo.isLate
                              ? const Color(0xFFE94D4D)
                              : const Color(0xFF64778F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 108,
                child: Row(
                  children: [
                    _AssetCounter(image: Paths.chat, count: task.commentsCount),
                    const SizedBox(width: 8),
                    _Counter(
                      icon: Icons.attach_file,
                      count: task.attachmentsCount,
                    ),
                    const SizedBox(width: 8),
                    const ImageWidget(
                      image: Paths.delete,
                      width: 5,
                      height: 5,
                      showLoad: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showTabletTaskInfoPopup({
  required BuildContext context,
  required BuildContext buttonContext,
  required ProjectTaskModel task,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final buttonBox = buttonContext.findRenderObject() as RenderBox?;
  if (buttonBox == null) return;

  final buttonTopLeft = buttonBox.localToGlobal(Offset.zero, ancestor: overlay);
  final buttonBottomRight = buttonBox.localToGlobal(
    Offset(buttonBox.size.width, buttonBox.size.height),
    ancestor: overlay,
  );

  const cardWidth = 440.0;
  const estimatedCardHeight = 260.0;
  const horizontalGap = 10.0;
  const verticalGap = 10.0;

  double left = buttonBottomRight.dx - cardWidth;
  final maxLeft = overlay.size.width - cardWidth - horizontalGap;
  if (left < horizontalGap) left = horizontalGap;
  if (left > maxLeft) left = maxLeft;

  double top = buttonTopLeft.dy - estimatedCardHeight - verticalGap;
  if (top < verticalGap) {
    top = buttonBottomRight.dy + verticalGap;
  }

  final pro = context.read<ProjectPro>();
  ProjectModel? project;
  try {
    project = pro.projects.firstWhere(
      (item) => item.numericId == task.projectId,
    );
  } catch (_) {
    project = null;
  }

  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Task details',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 130),
    pageBuilder: (dialogContext, _, _) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: cardWidth,
              child: _TabletTaskInfoPopup(
                task: task,
                project: project,
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TabletTaskInfoPopup extends StatelessWidget {
  final ProjectTaskModel task;
  final ProjectModel? project;
  final VoidCallback onClose;

  const _TabletTaskInfoPopup({
    required this.task,
    required this.project,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        project?.displayProgressPercent ?? _taskFallbackProgress(task);
    final lateTasks = project?.lateTasksCount ?? 0;
    final meta = _taskPopupMeta(task);
    final status =
        (task.sectionName.trim().isEmpty ? task.status : task.sectionName)
            .replaceAll('_', ' ')
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 32 / 2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1C20),
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(99),
                child: const Icon(
                  Icons.close,
                  size: 20,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 27 / 3,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F98A8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: $status',
            style: const TextStyle(
              fontSize: 22 / 2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4E5664),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE3E4E8)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoChip(
                      label:
                          'Customer: ${(project?.customerDisplayName ?? 'Customer').trim()}',
                      backgroundColor: const Color(0xFFF2ECD7),
                      textColor: const Color(0xFFB18400),
                    ),
                    const SizedBox(height: 10),
                    _InfoChip(
                      label:
                          'Client: ${(project?.clientDisplayName ?? 'Client').trim()}',
                      backgroundColor: const Color(0xFFD9E9FF),
                      textColor: const Color(0xFF005ED8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _TaskMembers(members: task.members),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFD9DCE2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFF78A2D),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$progress% IN PROGRESS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF46F2A),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '| Late tasks $lateTasks',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE35353),
                ),
              ),
              const Spacer(),
              _Counter(icon: Icons.assignment_outlined, count: 1),
              const SizedBox(width: 10),
              _Counter(
                icon: Icons.chat_bubble_outline,
                count: task.commentsCount,
              ),
              const SizedBox(width: 10),
              _Counter(icon: Icons.attach_file, count: task.attachmentsCount),
            ],
          ),
        ],
      ),
    );
  }
}

String _taskPopupMeta(ProjectTaskModel task) {
  final code = task.projectId.toString().padLeft(7, '0');
  final parsed = DateTime.tryParse(task.dueDate.trim());
  if (parsed == null) return code;
  final date = DateFormat('MM/dd/yy').format(parsed);
  final time = DateFormat('h:mma').format(parsed).toLowerCase();
  return '$code · $date · $time';
}

int _taskFallbackProgress(ProjectTaskModel task) {
  final value = '${task.status} ${task.sectionName}'.toLowerCase();
  if (value.contains('complete') || value.contains('done')) return 100;
  if (value.contains('progress')) return 45;
  return 0;
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.trim().replaceAll('_', ' ');
    final normalized = label.toLowerCase();
    Color bg = const Color(0xFFE6EAF0);
    Color fg = const Color(0xFF334156);
    if (normalized.contains('progress')) {
      bg = const Color(0xFFE8EDF7);
      fg = const Color(0xFF314C74);
    } else if (normalized.contains('complete')) {
      bg = const Color(0xFFCBEED8);
      fg = const Color(0xFF0B8A4A);
    } else if (normalized.contains('verif')) {
      bg = const Color(0xFFE8EAF3);
      fg = const Color(0xFF4B5671);
    } else if (normalized.contains('new')) {
      bg = const Color(0xFFE8EAEE);
      fg = const Color(0xFF4B5567);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Text(
        label.isEmpty ? 'New' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _StatusMenuButton extends StatelessWidget {
  const _StatusMenuButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0xFFE7E8EC),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: const Icon(Icons.more_vert, size: 15, color: Color(0xFF7E8898)),
    );
  }
}

class _TaskLabelPill extends StatelessWidget {
  final ProjectTaskLabel label;

  const _TaskLabelPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final bg = _safeColor(label.color, fallback: const Color(0xFFEE3E93));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Text(
        label.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskMembers extends StatelessWidget {
  final List<ProjectTaskMember> members;

  const _TaskMembers({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(color: Color(0xFFA0A8B6), fontWeight: FontWeight.w700),
      );
    }
    final shown = members.take(4).toList();
    return SizedBox(
      height: 25,
      width: shown.length * 16 + 25,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 16,
              child: Container(
                width: 25,
                height: 25,
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: shown[i].image.trim().isEmpty
                      ? Container(
                          color: const Color(0xFFD8DEE9),
                          alignment: Alignment.center,
                          child: Text(
                            shown[i].name.isNotEmpty
                                ? shown[i].name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : ImageWidget(
                          image: shown[i].image,
                          fit: BoxFit.cover,
                          showLoad: false,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DueInfo {
  final String text;
  final bool isLate;

  const _DueInfo({required this.text, required this.isLate});
}

_DueInfo _dueInfo(String dueDate) {
  final raw = dueDate.trim();
  if (raw.isEmpty) return const _DueInfo(text: 'No due date', isLate: false);

  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return _DueInfo(text: raw, isLate: false);

  final now = DateTime.now();
  final late = parsed.isBefore(now);
  return _DueInfo(
    text: DateFormat('MMM d, yyyy | h:mma').format(parsed).toLowerCase(),
    isLate: late,
  );
}

Color _safeColor(String hex, {required Color fallback}) {
  final value = hex.trim().replaceAll('#', '');
  if (value.isEmpty) return fallback;
  final full = value.length == 6 ? 'FF$value' : value;
  final parsed = int.tryParse(full, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

class _TabletProjectsHeader extends StatelessWidget {
  final int totalCount;
  final _ProjectsHeaderView selectedView;
  final _TaskDisplayMode taskDisplayMode;
  final int appliedFilters;
  final VoidCallback onAdd;
  final VoidCallback onFilter;
  final ValueChanged<_ProjectsHeaderView> onViewChanged;
  final ValueChanged<_TaskDisplayMode> onTaskDisplayModeChanged;

  const _TabletProjectsHeader({
    required this.totalCount,
    required this.selectedView,
    required this.taskDisplayMode,
    required this.appliedFilters,
    required this.onAdd,
    required this.onFilter,
    required this.onViewChanged,
    required this.onTaskDisplayModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Image.asset(
            Paths.task,
            width: 17,
            height: 17,
            color: const Color(0xFF383E4A),
          ),
          const SizedBox(width: 10),
          Text(
            '${selectedView == _ProjectsHeaderView.projects ? 'Projects' : 'Tasks'} ($totalCount)',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF14161A),
            ),
          ),
          const SizedBox(width: 16),
          Builder(
            builder: (buttonContext) => InkWell(
              onTap: () => _showViewMenu(context, buttonContext),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Text(
                      selectedView == _ProjectsHeaderView.projects
                          ? 'Projects'
                          : 'Tasks',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4D5361),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: Color(0xFF5E6573),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),

          if (selectedView == _ProjectsHeaderView.tasks) ...[
            Builder(
              builder: (buttonContext) => InkWell(
                onTap: () => _showTaskDisplayMenu(context, buttonContext),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE1E3E8)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        taskDisplayMode == _TaskDisplayMode.list
                            ? Icons.view_list_rounded
                            : Icons.calendar_month_outlined,
                        size: 14,
                        color: const Color(0xFF42536A),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        taskDisplayMode == _TaskDisplayMode.list
                            ? 'List'
                            : 'Calendar',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A3447),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Color(0xFF5E6573),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 34,
              height: 34,

              child: Center(
                child: Image.asset(
                  Paths.filter,
                  width: 20,
                  height: 20,
                  color: const Color(0xFF434B59),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (appliedFilters > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFC92A),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${appliedFilters > 9 ? '9+' : appliedFilters}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showViewMenu(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
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
        buttonBottomLeft.dy + 4,
        overlay.size.width - buttonTopLeft.dx - button.size.width,
        overlay.size.height - buttonBottomLeft.dy,
      ),
      items: [
        PopupMenuItem<_ProjectsHeaderView>(
          value: _ProjectsHeaderView.projects,
          child: Text(
            'Projects',
            style: TextStyle(
              fontWeight: selectedView == _ProjectsHeaderView.projects
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        PopupMenuItem<_ProjectsHeaderView>(
          value: _ProjectsHeaderView.tasks,
          child: Text(
            'Tasks',
            style: TextStyle(
              fontWeight: selectedView == _ProjectsHeaderView.tasks
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    if (selected != null) {
      onViewChanged(selected);
    }
  }

  Future<void> _showTaskDisplayMenu(
    BuildContext context,
    BuildContext buttonContext,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;
    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonBottomLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );

    final selected = await showMenu<_TaskDisplayMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonTopLeft.dx,
        buttonBottomLeft.dy + 4,
        overlay.size.width - buttonTopLeft.dx - button.size.width,
        overlay.size.height - buttonBottomLeft.dy,
      ),
      items: [
        PopupMenuItem<_TaskDisplayMode>(
          value: _TaskDisplayMode.list,
          child: Row(
            children: [
              const Icon(Icons.view_list_rounded, size: 16),
              const SizedBox(width: 8),
              Text(
                'List',
                style: TextStyle(
                  fontWeight: taskDisplayMode == _TaskDisplayMode.list
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_TaskDisplayMode>(
          value: _TaskDisplayMode.calendar,
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 16),
              const SizedBox(width: 8),
              Text(
                'Calendar',
                style: TextStyle(
                  fontWeight: taskDisplayMode == _TaskDisplayMode.calendar
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      onTaskDisplayModeChanged(selected);
    }
  }
}

enum _ProjectsHeaderView { projects, tasks }

enum _TaskDisplayMode { list, calendar }

class _AvatarStrip extends StatelessWidget {
  final List<String> avatars;

  const _AvatarStrip({required this.avatars});

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();
    final shown = avatars.take(3).toList();
    return SizedBox(
      width: shown.length * 16 + 28,
      height: 28,
      child: Stack(
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 16,
              child: Container(
                width: 28,
                height: 28,
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.network(
                    shown[i].isEmpty ? Paths.user : shown[i],
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
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int count;

  const _Counter({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF060606)),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA4A9B2),
          ),
        ),
      ],
    );
  }
}

class _AssetCounter extends StatelessWidget {
  final String image;
  final int count;

  const _AssetCounter({required this.image, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ImageWidget(image: image, width: 5, height: 5, showLoad: false),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA4A9B2),
          ),
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int lastPage;
  final ValueChanged<int> onPageTap;

  const _PaginationBar({
    required this.currentPage,
    required this.lastPage,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = _visiblePages(currentPage, lastPage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7E8EC))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _PageArrow(
                    icon: Icons.keyboard_double_arrow_left,
                    enabled: currentPage > 1,
                    onTap: () => onPageTap(1),
                  ),
                  const SizedBox(width: 4),
                  _PageArrow(
                    icon: Icons.chevron_left,
                    enabled: currentPage > 1,
                    onTap: () => onPageTap(currentPage - 1),
                  ),
                  const SizedBox(width: 6),
                  for (final page in items) ...[
                    if (page == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          '...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B8F98),
                          ),
                        ),
                      )
                    else
                      _PageNumber(
                        page: page,
                        selected: page == currentPage,
                        onTap: () => onPageTap(page),
                      ),
                  ],
                  const SizedBox(width: 6),
                  _PageArrow(
                    icon: Icons.chevron_right,
                    enabled: currentPage < lastPage,
                    onTap: () => onPageTap(currentPage + 1),
                  ),
                  const SizedBox(width: 4),
                  _PageArrow(
                    icon: Icons.keyboard_double_arrow_right,
                    enabled: currentPage < lastPage,
                    onTap: () => onPageTap(lastPage),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<int?> _visiblePages(int current, int last) {
    if (last <= 7) {
      return List<int?>.generate(last, (index) => index + 1);
    }

    final pages = <int?>[1];
    if (current > 3) pages.add(null);

    final start = current - 1 < 2 ? 2 : current - 1;
    final end = current + 1 > last - 1 ? last - 1 : current + 1;

    for (int page = start; page <= end; page++) {
      pages.add(page);
    }

    if (current < last - 2) pages.add(null);
    pages.add(last);
    return pages;
  }
}

class _PageArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9DCE3)),
        ),
        child: Icon(
          icon,
          size: 13,
          color: enabled ? const Color(0xFF545B68) : const Color(0xFFC0C4CD),
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback onTap;

  const _PageNumber({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFFED234) : const Color(0xFFF4F5F8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF0BF1D)
                  : const Color(0xFFD8DBE2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF22252C)
                  : const Color(0xFF5B6271),
            ),
          ),
        ),
      ),
    );
  }
}

Color _progressAccentColor(ProjectModel project) {
  if (project.isCompleted) return const Color(0xFF16A76A);
  if (project.displayProgressPercent > 0) return const Color(0xFFEE7E2A);
  return const Color(0xFF8F949E);
}
