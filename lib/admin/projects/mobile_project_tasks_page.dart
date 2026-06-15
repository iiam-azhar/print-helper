import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../widgets/loaders.dart';
import 'mobile_project_calendar_view.dart';
import '../../constants/paths.dart';
import '../../models/projects_models.dart';
import '../../providers/project_pro.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/toasts.dart';
import 'widgets/mobile_project_tasks_filter_sheet.dart';
import 'widgets/mobile_task_preview_sheet.dart';

class MobileProjectTasksPage extends StatefulWidget {
  final int projectId;

  const MobileProjectTasksPage({super.key, required this.projectId});

  @override
  State<MobileProjectTasksPage> createState() => _MobileProjectTasksPageState();
}

class _MobileProjectTasksPageState extends State<MobileProjectTasksPage> {
  _TaskPageView _selectedView = _TaskPageView.list;
  final Map<String, String> _activeTaskFilters = <String, String>{};
  TextEditingController? _projectNameController;
  Timer? _projectNameDebounce;
  bool _isEditingName = false;

  int get _appliedTaskFilterCount {
    const ignoredKeys = {'view', 'page', 'per_page'};
    var count = 0;
    _activeTaskFilters.forEach((key, value) {
      if (ignoredKeys.contains(key)) return;
      if (value.trim().isEmpty) return;
      count++;
    });
    return count;
  }

  List<ProjectTaskModel> _visibleTasks(List<ProjectTaskModel> source) {
    final tasks = List<ProjectTaskModel>.from(source);
    if (_activeTaskFilters.isEmpty) return tasks;

    final statusFilter = (_activeTaskFilters['status'] ?? '')
        .trim()
        .toLowerCase();
    final taskFilter = (_activeTaskFilters['task'] ?? '').trim().toLowerCase();
    final assignedToFilter = (_activeTaskFilters['assigned_to'] ?? '')
        .trim()
        .toLowerCase();
    final lateTasksFilter = (_activeTaskFilters['late_tasks'] ?? '')
        .trim()
        .toLowerCase();
    final fromDate = DateTime.tryParse(_activeTaskFilters['date_from'] ?? '');
    final toDate = DateTime.tryParse(_activeTaskFilters['date_to'] ?? '');
    final sortBy = (_activeTaskFilters['sort_by'] ?? '').trim().toLowerCase();

    bool hasStatus(ProjectTaskModel task) {
      if (statusFilter.isEmpty) return true;
      final status = task.status.trim().toLowerCase();
      final section = task.sectionName.trim().toLowerCase();
      return status == statusFilter || section == statusFilter;
    }

    bool hasTaskText(ProjectTaskModel task) {
      if (taskFilter.isEmpty) return true;
      final title = task.title.trim().toLowerCase();
      final description = task.description.trim().toLowerCase();
      return title.contains(taskFilter) || description.contains(taskFilter);
    }

    bool hasAssignedMember(ProjectTaskModel task) {
      if (assignedToFilter.isEmpty) return true;
      return task.members.any(
        (member) => member.name.trim().toLowerCase().contains(assignedToFilter),
      );
    }

    bool inDateRange(ProjectTaskModel task) {
      if (fromDate == null && toDate == null) return true;
      final due = _parseTaskDate(task.dueDate);
      if (due == null) return false;

      final normalized = DateTime(due.year, due.month, due.day);
      if (fromDate != null) {
        final min = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (normalized.isBefore(min)) return false;
      }
      if (toDate != null) {
        final max = DateTime(toDate.year, toDate.month, toDate.day);
        if (normalized.isAfter(max)) return false;
      }
      return true;
    }

    bool respectsLateFlag(ProjectTaskModel task) {
      if (lateTasksFilter.isEmpty) return true;
      final due = _parseTaskDate(task.dueDate);
      if (due == null) return true;
      final status = task.status.trim().toLowerCase();
      final isDone = status.contains('complete') || status.contains('done');
      final isLate = due.isBefore(DateTime.now()) && !isDone;

      if (lateTasksFilter == 'yes' ||
          lateTasksFilter == '1' ||
          lateTasksFilter == 'true') {
        return isLate;
      }
      if (lateTasksFilter == 'no' ||
          lateTasksFilter == '0' ||
          lateTasksFilter == 'false') {
        return !isLate;
      }
      return true;
    }

    final filtered = tasks.where((task) {
      return hasStatus(task) &&
          hasTaskText(task) &&
          hasAssignedMember(task) &&
          inDateRange(task) &&
          respectsLateFlag(task);
    }).toList();

    int byDueDate(ProjectTaskModel a, ProjectTaskModel b) {
      final da = _parseTaskDate(a.dueDate);
      final db = _parseTaskDate(b.dueDate);
      if (da == null && db == null) return b.id.compareTo(a.id);
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    }

    switch (sortBy) {
      case 'name_asc':
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'name_desc':
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;
      case 'oldest':
      case 'updated_asc':
        filtered.sort((a, b) => -byDueDate(a, b));
        break;
      case 'newest':
      case 'updated_desc':
        filtered.sort(byDueDate);
        break;
      default:
        break;
    }

    return filtered;
  }

  DateTime? _parseTaskDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;

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
        // Try next known format.
      }
    }

    return null;
  }

  String _formatTaskDueDate(String rawDate) {
    if (rawDate.trim().isEmpty) return '';
    final parsed = _parseTaskDate(rawDate);
    if (parsed == null) return rawDate;

    const monthAbbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = monthAbbr[parsed.month - 1];
    final day = parsed.day.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'pm' : 'am';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final formatted = '$month $day, ${parsed.year} $hour:$minute$suffix';
    return formatted.replaceFirst(' ', ' | ');
  }

  @override
  void dispose() {
    _projectNameController?.dispose();
    _projectNameDebounce?.cancel();
    super.dispose();
  }

  void _onProjectNameChanged(String value) {
    _projectNameDebounce?.cancel();
    _projectNameDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (value.trim().isNotEmpty) {
        context.read<ProjectPro>().updateProject(
          projectId: widget.projectId,
          payload: {'name': value.trim()},
        );
      }
    });
  }

  Future<void> _pickProjectDateTime(ProjectModel project) async {
    final DateTime now = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(project.createdAt) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final String dateStr =
        '${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.year.toString().substring(2)}';
    final String timeStr =
        '${(pickedTime.hour % 12 == 0 ? 12 : pickedTime.hour % 12)}:${pickedTime.minute.toString().padLeft(2, '0')}${pickedTime.hour >= 12 ? 'pm' : 'am'}';

    if (mounted) {
      await context.read<ProjectPro>().updateProject(
        projectId: widget.projectId,
        payload: {'date': dateStr, 'time': timeStr},
      );
    }
  }

  Future<void> _handleDeleteProject(int projectId) async {
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
        projectId: projectId,
      );
      Loaders.hide();

      if (success && mounted) {
        Navigator.of(context).pop(); // Go back to projects list
        // Re-fetch projects list to reflect deletion
        context.read<ProjectPro>().getProjects(ctx: context);
      }
    }
  }

  Future<void> _showSaveTemplateDialog() async {
    final pro = context.read<ProjectPro>();
    final nameController = TextEditingController(
      text: '${pro.activeProjectDetail?.project.name ?? ""} project template'
          .toLowerCase(),
    );
    bool isPublic = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        'Save Project Template',
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
                  RichText(
                    text: TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red, fontSize: 13.sp),
                      children: [
                        TextSpan(
                          text: ' Template Name',
                          style: TextStyle(
                            color: const Color(0xFF1D2939),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                  _buildVisibilityRadio(
                    value: true,
                    groupValue: isPublic,
                    label: 'Available for all users',
                    onChanged: (val) => setDialogState(() => isPublic = val!),
                  ),
                  _buildVisibilityRadio(
                    value: false,
                    groupValue: isPublic,
                    label: 'Only for me',
                    onChanged: (val) => setDialogState(() => isPublic = val!),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              showToast(
                                message: 'Please enter a template name',
                              );
                              return;
                            }

                            Navigator.pop(context); // Close dialog

                            Loaders.show();
                            await context
                                .read<ProjectPro>()
                                .saveProjectTemplate(
                                  projectId: widget.projectId,
                                  name: name,
                                  isPublic: isPublic,
                                );
                            Loaders.hide();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006C62),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 12.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Save Template',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisibilityRadio({
    required bool value,
    required bool groupValue,
    required String label,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24.w,
              width: 24.w,
              child: Radio<bool>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: const Color(0xFF2E6FF1),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF344054),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddStatusDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        // Controller is owned by StatefulBuilder — disposed when the dialog
        // widget is actually unmounted (after close animation finishes).
        return _AddStatusDialog();
      },
    );
  }

  Future<void> _showTaskFilterSheet() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileProjectTasksFilterSheet(
        projectId: widget.projectId,
        initialFilters: _activeTaskFilters,
      ),
    );

    if (!mounted || result == null) return;

    if (result is Map &&
        result[MobileProjectTasksFilterSheet.clearFiltersKey] == true) {
      _activeTaskFilters.clear();
      await context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: widget.projectId,
        forceRefresh: true,
      );
      setState(() {});
      return;
    }

    if (result is Map) {
      final filters = <String, String>{};
      for (final entry in result.entries) {
        if (entry.key == null || entry.value == null) continue;
        filters[entry.key.toString()] = entry.value.toString();
      }
      _activeTaskFilters
        ..clear()
        ..addAll(filters);

      await context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: widget.projectId,
        forceRefresh: true,
        filters: _activeTaskFilters,
      );
      setState(() {});
    }
  }

  Widget _actionPill({
    required String label,
    IconData? icon,
    bool hideIcon = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.w),
      child: Container(
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999.w),
          border: Border.all(color: const Color(0xFFE7E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!hideIcon && icon != null) ...[
              Icon(icon, size: 14.sp, color: const Color(0xFF4B4C4E)),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF17181B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProjectPro>().getProjectLabels(ctx: context);
      context.read<ProjectPro>().getProjectDetail(
        ctx: context,
        projectId: widget.projectId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectPro>(
      builder: (context, pro, child) {
        final detail = pro.activeProjectDetail;
        final visibleTasks = detail == null
            ? <ProjectTaskModel>[]
            : _visibleTasks(detail.tasks);
        final isCurrentDetail = detail?.project.numericId == widget.projectId;
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7),
          appBar: _buildAppBar(detail),
          body: SafeArea(
            top: false,
            child: pro.projectDetailLoad && !isCurrentDetail
                ? Center(child: showLoader())
                : !isCurrentDetail || detail == null
                ? Center(
                    child: Text(
                      'No tasks found',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7E8088),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            await context.read<ProjectPro>().getProjectDetail(
                              ctx: context,
                              projectId: detail.project.numericId,
                              forceRefresh: true,
                              filters: _activeTaskFilters.isEmpty
                                  ? null
                                  : _activeTaskFilters,
                            );
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(20.r),
                                      bottomRight: Radius.circular(20.r),
                                    ),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    14.w,
                                    8.h,
                                    14.w,
                                    8.h,
                                  ),
                                  child: _buildProjectInfoHeader(
                                    detail.project,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    14.w,
                                    6.h,
                                    14.w,
                                    0,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: _actionPill(
                                              label: '+ Add Status',
                                              icon: CupertinoIcons.add,
                                              hideIcon: true,
                                              onTap: _showAddStatusDialog,
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            flex: 5,
                                            child: _actionPill(
                                              label: 'Template',
                                              icon: Icons.save_outlined,
                                              onTap: _showSaveTemplateDialog,
                                            ),
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            flex: 5,
                                            child: _buildFilterPill(),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 14.h),
                                      _selectedView == _TaskPageView.list
                                          ? (visibleTasks.isEmpty
                                                ? SizedBox(
                                                    height: 0.4.sh,
                                                    child: Center(
                                                      child: Text(
                                                        'No tasks available for this project',
                                                        style: TextStyle(
                                                          fontSize: 14.sp,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: const Color(
                                                            0xFF7E8088,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : ListView.separated(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        visibleTasks.length,
                                                    padding: EdgeInsets.only(
                                                      bottom: 110.h,
                                                    ),
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    separatorBuilder: (_, _) =>
                                                        SizedBox(height: 12.h),
                                                    itemBuilder:
                                                        (
                                                          context,
                                                          index,
                                                        ) => _buildTaskCard(
                                                          detail.project,
                                                          visibleTasks[index],
                                                        ),
                                                  ))
                                          : Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 110.h,
                                              ),
                                              child: MobileProjectCalendarView(
                                                project: detail.project,
                                                tasks: visibleTasks,
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
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomActions(),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildProjectInfoHeader(ProjectModel project) {
    final progressPercent = project.displayProgressPercent;
    final progressValue = (progressPercent.clamp(0, 100)) / 100.0;
    final progressState = project.displayStatus.toUpperCase();

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProjectInfoPill(
                    label: 'Customer: ${project.customerName}',
                    backgroundColor: const Color(0xFFFFF6D7),
                    foregroundColor: const Color(0xFFC09000),
                  ),
                  SizedBox(height: 10.h),
                  _buildProjectInfoPill(
                    label: 'Client: ${project.clientName}',
                    backgroundColor: const Color(0xFFE5F0FF),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF28A2E)),
          ),
        ),
        SizedBox(height: 14.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
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
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(ProjectDetailModel? detail) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      toolbarHeight: 66.h,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(
          CupertinoIcons.back,
          color: const Color(0xFF1B1B1B),
          size: 24.sp,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: detail == null
          ? const SizedBox()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditingName = true;
                      _projectNameController ??= TextEditingController(
                        text: detail.project.name,
                      );
                    });
                  },
                  child: _isEditingName
                      ? SizedBox(
                          height: 20.h,
                          child: TextFormField(
                            controller: _projectNameController,
                            autofocus: true,
                            onChanged: _onProjectNameChanged,
                            onFieldSubmitted: (_) =>
                                setState(() => _isEditingName = false),
                            onTapOutside: (_) =>
                                setState(() => _isEditingName = false),
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF104A7F),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        )
                      : Text(
                          detail.project.name.isNotEmpty
                              ? detail.project.name
                              : 'Project name goes here',
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF104A7F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                SizedBox(height: 1.h),
                GestureDetector(
                  onTap: () => _pickProjectDateTime(detail.project),
                  child: Text(
                    detail.project.popupMetaText,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8B8F97),
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedView = _selectedView == _TaskPageView.list
                  ? _TaskPageView.calendar
                  : _TaskPageView.list;
            });
          },
          icon: Icon(
            _selectedView == _TaskPageView.list
                ? CupertinoIcons.calendar
                : CupertinoIcons.list_bullet,
            color: const Color(0xFF1B1B1B),
            size: 21.sp,
          ),
          tooltip: _selectedView == _TaskPageView.list
              ? 'Calendar view'
              : 'List view',
        ),
        IconButton(
          onPressed: () => _handleDeleteProject(widget.projectId),
          icon: ImageWidget(
            image: Paths.delete, // Use existing SVG mapping
            width: 19,
            height: 19,
          ),
        ),
        SizedBox(width: 6.w),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFECECEF)),
      ),
    );
  }

  Widget _buildFilterPill() {
    return InkWell(
      onTap: _showTaskFilterSheet,
      borderRadius: BorderRadius.circular(999.w),
      child: Container(
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999.w),
          border: Border.all(color: const Color(0xFFE7E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ImageWidget(image: Paths.filter, width: 18, height: 18),
                if (_appliedTaskFilterCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCB04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_appliedTaskFilterCount',
                        style: TextStyle(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 8.w),
            Text(
              'Filter',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF17181B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(ProjectModel project, ProjectTaskModel task) {
    final parsedDue = _parseTaskDate(task.dueDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDueTodayOrPast =
        parsedDue != null &&
        !DateTime(
          parsedDue.year,
          parsedDue.month,
          parsedDue.day,
        ).isAfter(today);
    final dueColor = isDueTodayOrPast
        ? const Color(0xFFE85B4A)
        : const Color(0xFF8B8F97);

    return InkWell(
      onTap: () async {
        await MobileTaskPreviewSheet.show(context, task);
        if (context.mounted) {
          await context.read<ProjectPro>().getProjectDetail(
                ctx: context,
                projectId: widget.projectId,
                forceRefresh: true,
              );
        }
      },
      borderRadius: BorderRadius.circular(16.w),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 15.h, 14.w, 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.w),
          border: Border.all(color: const Color(0xFFE7E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6F737C),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _buildTaskOverflowButton(
                  project,
                  task,
                  menuType: _TaskMenuType.primary,
                ),
              ],
            ),
            SizedBox(height: 5.h),

            Row(
              children: [
                Icon(CupertinoIcons.clock, size: 13.sp, color: dueColor),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    _formatTaskDueDate(task.dueDate),
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
                        child: _buildPill(
                          task.status,
                          const Color(0xFFF3F3F5),
                          const Color(0xFF8A8E97),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _buildTaskOverflowButton(
                        project,
                        task,
                        menuType: _TaskMenuType.secondary,
                      ),
                    ],
                  ),
                ),
                _buildAvatarStrip(
                  task.members.map((member) => member.image).toList(),
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
                        _buildPill(
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
                    _buildMetric(
                      CupertinoIcons.chat_bubble_text,
                      task.commentsCount,
                    ),
                    SizedBox(width: 12.w),
                    _buildMetric(
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

  Widget _buildTaskOverflowButton(
    ProjectModel project,
    ProjectTaskModel task, {
    required _TaskMenuType menuType,
  }) {
    return Builder(
      builder: (buttonContext) => InkWell(
        onTap: () =>
            _showTaskActions(buttonContext, project, task, menuType: menuType),
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          width: 24.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.more_vert,
            size: 13.sp,
            color: const Color(0xFF7C8088),
          ),
        ),
      ),
    );
  }

  Future<void> _showTaskActions(
    BuildContext buttonContext,
    ProjectModel project,
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
          ? const [
              PopupMenuItem<_TaskAction>(
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
              PopupMenuItem<_TaskAction>(
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
      case _TaskAction.deleteStatus:
        showToast(message: 'Delete status coming soon');
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

  Future<void> _showTaskDetailsSheet(ProjectTaskModel task) async {
    await MobileTaskPreviewSheet.show(context, task);
    if (mounted) {
      await context.read<ProjectPro>().getProjectDetail(
            ctx: context,
            projectId: widget.projectId,
            forceRefresh: true,
          );
    }
  }

  Widget _buildMetric(IconData icon, int count) {
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

  Widget _buildProjectInfoMetric(IconData icon, int count) {
    return _buildMetric(icon, count);
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

  Widget _buildBottomActions() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Spacer(flex: 3),
          Expanded(
            flex: 8,
            child: ElevatedButton(
              onPressed: () async {
                final detail = context.read<ProjectPro>().activeProjectDetail;
                await MobileTaskPreviewSheet.showCreate(
                  context,
                  projectId: widget.projectId,
                  sections: detail?.sections ?? const [],
                );
                if (context.mounted) {
                  await context.read<ProjectPro>().getProjectDetail(
                        ctx: context,
                        projectId: widget.projectId,
                        forceRefresh: true,
                      );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCB04),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(60.w),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.h),
              ),
              child: Text(
                '+ Add Task',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF17181B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          // Expanded(
          //   flex: 4,
          //   child: ElevatedButton(
          //     onPressed: () {},
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: const Color(0xFFFFCB04),
          //       elevation: 0,
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(60.r),
          //       ),
          //       padding: EdgeInsets.symmetric(vertical: 10.h),
          //     ),
          //     child: ImageWidget(
          //       image: 'assets/images/template.png',
          //       width: 18,
          //       height: 18,
          //     ),
          //   ),
          // ),
          Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
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

  Widget _buildAvatarStrip([List<String>? avatars, int maxVisible = 4]) {
    final items = avatars ?? const <String>[];
    if (items.isEmpty) return const SizedBox.shrink();
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

  Color _colorFromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.isEmpty) return const Color(0xFF8A8E97);
    final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(normalized, radix: 16) ?? 0xFF8A8E97);
  }
}

enum _TaskPageView { list, calendar }

enum _TaskMenuType { primary, secondary }

enum _TaskAction { projectInfo, deleteTask, automation, deleteStatus }

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

// ─────────────────────────────────────────────────────────────────────────────
// Add-Status dialog — owns its controller so dispose() fires after the
// close animation completes, not while the animation is still running.
// ─────────────────────────────────────────────────────────────────────────────
class _AddStatusDialog extends StatefulWidget {
  const _AddStatusDialog();

  @override
  State<_AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<_AddStatusDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.list_bullet_below_rectangle,
                    size: 18.sp,
                    color: const Color(0xFF4B4C4E),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF17181B),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: const Color(0xFF8A8E97),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            // ── Label ──
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE45B45),
                    ),
                  ),
                  TextSpan(
                    text: 'Status Name',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF17181B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            // ── Text field ──
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFF17181B)),
              decoration: InputDecoration(
                hintText: 'Type Status Name',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFFB0B3BA),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: const BorderSide(color: Color(0xFFE7E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: const BorderSide(
                    color: Color(0xFF3CAB58),
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            SizedBox(height: 20.h),
            // ── Create button ──
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final name = _controller.text.trim();
                        if (name.isEmpty) return;
                        setState(() => _isLoading = true);
                        final result = await context
                            .read<ProjectPro>()
                            .createProjectSection(name: name);
                        if (!mounted) return;
                        setState(() => _isLoading = false);
                        if (result != null) {
                          Navigator.of(context).pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CAB58),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create New',
                        style: TextStyle(
                          fontSize: 13.sp,
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
