import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/projects_models.dart';

class MobileProjectCalendarView extends StatefulWidget {
  final ProjectModel project;
  final List<ProjectTaskModel> tasks;

  const MobileProjectCalendarView({
    super.key,
    required this.project,
    required this.tasks,
  });

  @override
  State<MobileProjectCalendarView> createState() =>
      _MobileProjectCalendarViewState();
}

class _MobileProjectCalendarViewState extends State<MobileProjectCalendarView> {
  late DateTime _calendarMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _calendarMonth = _initialMonth();
    _selectedDate = _initialSelectedDate();
  }

  @override
  void didUpdateWidget(covariant MobileProjectCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.numericId != widget.project.numericId) {
      _calendarMonth = _initialMonth();
      _selectedDate = _initialSelectedDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_calendarMonth.year, _calendarMonth.month);
    final monthEnd = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday % 7),
    );
    final gridEnd = monthEnd.add(Duration(days: 6 - (monthEnd.weekday % 7)));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final visibleDays = List<DateTime>.generate(
      totalDays,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    );
    final tasksByDay = <String, List<ProjectTaskModel>>{};

    for (final task in widget.tasks) {
      final dueDate = _extractTaskDate(task);
      if (dueDate == null) continue;
      final key = _dateKey(dueDate);
      tasksByDay.putIfAbsent(key, () => []).add(task);
    }

    final today = DateTime.now();
    final monthAgenda = _buildAgendaEntries(tasksByDay, monthStart, monthEnd);

    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.w),
              border: Border.all(color: const Color(0xFFE7E7EB)),
            ),
            child: Column(
              children: [
                _buildAgendaToolbar(),
                SizedBox(height: 14.h),
                _buildMiniMonthGrid(
                  visibleDays: visibleDays,
                  tasksByDay: tasksByDay,
                  today: today,
                ),
                SizedBox(height: 18.h),
                if (monthAgenda.isEmpty)
                  _buildEmptyAgendaState()
                else
                  Column(
                    children: [
                      for (
                        int index = 0;
                        index < monthAgenda.length;
                        index++
                      ) ...[
                        _buildAgendaGroup(monthAgenda[index]),
                        if (index != monthAgenda.length - 1)
                          SizedBox(height: 16.h),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime _initialMonth() {
    final firstDate = _extractTaskDate(
      widget.tasks.isNotEmpty ? widget.tasks.first : null,
    );
    if (firstDate != null) {
      return DateTime(firstDate.year, firstDate.month);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  DateTime _initialSelectedDate() {
    final firstDate = _extractTaskDate(
      widget.tasks.isNotEmpty ? widget.tasks.first : null,
    );
    if (firstDate != null) {
      return DateTime(firstDate.year, firstDate.month, firstDate.day);
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Widget _buildCalendarSummary(ProjectModel project) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.w),
        border: Border.all(color: const Color(0xFFE7E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildProjectInfoPill(
                      label: 'Client: ${project.clientDisplayName}',
                      backgroundColor: const Color(0xFFE9F1FF),
                      foregroundColor: const Color(0xFF0C58D6),
                    ),
                    _buildProjectInfoPill(
                      label: 'Customer: ${project.customerDisplayName}',
                      backgroundColor: const Color(0xFFFFF3CC),
                      foregroundColor: const Color(0xFFC28A00),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _buildCalendarActionPill(
                icon: CupertinoIcons.add,
                label: 'Add Status',
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999.w),
                  child: LinearProgressIndicator(
                    value: project.displayProgressPercent / 100,
                    minHeight: 5.h,
                    backgroundColor: const Color(0xFFE9E9ED),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF28A2E),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                '${project.displayProgressPercent}%',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF28A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaToolbar() {
    return Row(
      children: [
        InkWell(
          onTap: _pickCalendarMonth,
          borderRadius: BorderRadius.circular(10.w),
          child: Row(
            children: [
              Text(
                '${_calendarMonthNames[_calendarMonth.month - 1]} ${_calendarMonth.year}',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2A2D33),
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                CupertinoIcons.chevron_down,
                size: 13.sp,
                color: const Color(0xFF6F737C),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildCalendarNavButton(Icons.chevron_left, () {
          setState(() {
            _calendarMonth = DateTime(
              _calendarMonth.year,
              _calendarMonth.month - 1,
            );
            _selectedDate = DateTime(
              _calendarMonth.year,
              _calendarMonth.month,
              1,
            );
          });
        }),
        SizedBox(width: 8.w),
        _buildCalendarNavButton(Icons.chevron_right, () {
          setState(() {
            _calendarMonth = DateTime(
              _calendarMonth.year,
              _calendarMonth.month + 1,
            );
            _selectedDate = DateTime(
              _calendarMonth.year,
              _calendarMonth.month,
              1,
            );
          });
        }),
        SizedBox(width: 10.w),
        _buildCalendarNavButton(Icons.calendar_today_outlined, () {
          setState(() {
            final now = DateTime.now();
            _calendarMonth = DateTime(now.year, now.month);
            _selectedDate = DateTime(now.year, now.month, now.day);
          });
        }),
      ],
    );
  }

  Future<void> _pickCalendarMonth() async {
    DateTime draftMonth = DateTime(_calendarMonth.year, _calendarMonth.month);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.w)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: 300.h,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(draftMonth),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.monthYear,
                  initialDateTime: draftMonth,
                  minimumDate: DateTime(2000, 1),
                  maximumDate: DateTime(2100, 12),
                  onDateTimeChanged: (date) {
                    draftMonth = DateTime(date.year, date.month);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || picked == null) return;

    final daysInPickedMonth = DateTime(picked.year, picked.month + 1, 0).day;
    final selectedDay = _selectedDate.day > daysInPickedMonth
        ? daysInPickedMonth
        : _selectedDate.day;

    setState(() {
      _calendarMonth = DateTime(picked.year, picked.month);
      _selectedDate = DateTime(picked.year, picked.month, selectedDay);
    });
  }

  Widget _buildMiniMonthGrid({
    required List<DateTime> visibleDays,
    required Map<String, List<ProjectTaskModel>> tasksByDay,
    required DateTime today,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(18.w),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 22.w),
              for (final dayName in _calendarDayLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF969AA3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          for (int row = 0; row < visibleDays.length / 7; row++)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 22.w,
                    child: Text(
                      '${_weekNumber(visibleDays[row * 7])}',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFB1B4BC),
                      ),
                    ),
                  ),
                  for (int col = 0; col < 7; col++)
                    Expanded(
                      child: _buildMiniDayCell(
                        date: visibleDays[row * 7 + col],
                        hasTask:
                            (tasksByDay[_dateKey(visibleDays[row * 7 + col])] ??
                                    const [])
                                .isNotEmpty,
                        isCurrentMonth:
                            visibleDays[row * 7 + col].month ==
                            _calendarMonth.month,
                        isToday: _isSameDate(visibleDays[row * 7 + col], today),
                        isSelected: _isSameDate(
                          visibleDays[row * 7 + col],
                          _selectedDate,
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

  Widget _buildMiniDayCell({
    required DateTime date,
    required bool hasTask,
    required bool isCurrentMonth,
    required bool isToday,
    required bool isSelected,
  }) {
    final foreground = isSelected
        ? Colors.white
        : isCurrentMonth
        ? const Color(0xFF2A2D33)
        : const Color(0xFFC0C3CA);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = DateTime(date.year, date.month, date.day);
        });
      },
      borderRadius: BorderRadius.circular(16.w),
      child: Container(
        height: 34.h,
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F8EF7) : Colors.transparent,
          borderRadius: BorderRadius.circular(16.w),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            SizedBox(height: 2.h),
            Container(
              width: 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : hasTask
                    ? (isToday
                          ? const Color(0xFF4F8EF7)
                          : const Color(0xFF3DBB7A))
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAgendaState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Text(
        'No tasks scheduled for this month',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8A8E97),
        ),
      ),
    );
  }

  Widget _buildCalendarActionPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14.w),
        border: Border.all(color: const Color(0xFFE4E4E8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: const Color(0xFF17181B)),
          SizedBox(width: 6.w),
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
    );
  }

  Widget _buildAgendaGroup(_AgendaDayGroup group) {
    // final isSelected = _isSameDate(group.date, _selectedDate);
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.w),
        // color: isSelected ? const Color(0xFFF7FAFF) : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.date.day}',
                  style: TextStyle(
                    fontSize: 24.sp,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF22252B),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _weekdayShort(group.date),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6E727B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              children: [
                for (int index = 0; index < group.tasks.length; index++) ...[
                  _buildAgendaTaskCard(group.tasks[index]),
                  if (index != group.tasks.length - 1) SizedBox(height: 8.h),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTaskCard(ProjectTaskModel task) {
    final dueDate = _extractTaskDate(task);
    final statusProgress = _agendaProgress(task);
    final statusColor = _getTaskProgressBarColor(task);
    final statusTextColor = _getTaskStatusTextColor(task);
    final statusBgColor = _getTaskProgressBarBgColor(task);

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF121418),
                  ),
                ),
              ),
              if (dueDate != null)
                Text(
                  _taskTimeLabel(task),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF43484F),
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Divider(height: 1, thickness: 0.8.h, color: const Color(0xFFD8DADF)),
          SizedBox(height: 6.h),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34.w,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(999.w),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: statusProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(999.w),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  _taskStatusLabel(task),
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: statusTextColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildTaskMetaMetric(
                      CupertinoIcons.chat_bubble_text,
                      task.commentsCount,
                    ),
                    SizedBox(width: 10.w),
                    _buildTaskMetaMetric(
                      CupertinoIcons.paperclip,
                      task.attachmentsCount,
                    ),
                    SizedBox(width: 10.w),
                    _buildTaskMetaMetric(
                      CupertinoIcons.check_mark_circled,
                      task.members.length,
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (buttonContext) => InkWell(
                  onTap: () => _showTaskInfoPopover(buttonContext, task),
                  borderRadius: BorderRadius.circular(999.w),
                  child: Container(
                    width: 18.w,
                    height: 18.h,
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.info,
                      size: 16.sp,
                      color: const Color(0xFF4C515A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskInfoPopover(
    BuildContext buttonContext,
    ProjectTaskModel task,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonBox = buttonContext.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final buttonBottomRight = buttonBox.localToGlobal(
      Offset(buttonBox.size.width, buttonBox.size.height),
      ancestor: overlay,
    );

    final cardWidth = 320.w;
    final estimatedCardHeight = 172.h;
    final horizontalGap = 8.w;
    final verticalGap = 8.h;

    double left = buttonBottomRight.dx - cardWidth;
    final maxLeft = overlay.size.width - cardWidth - horizontalGap;
    if (left < horizontalGap) left = horizontalGap;
    if (left > maxLeft) left = maxLeft;

    double top = buttonTopLeft.dy - estimatedCardHeight - verticalGap;
    if (top < verticalGap) {
      top = buttonBottomRight.dy + verticalGap;
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
                child: _buildTaskInfoPopoverCard(
                  dialogContext,
                  task,
                  onClose: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskInfoPopoverCard(
    BuildContext context,
    ProjectTaskModel task, {
    required VoidCallback onClose,
  }) {
    final dueDate = _extractTaskDate(task);
    final progressPercent = (_agendaProgress(task) * 100).round();
    final lateTasks = widget.project.lateTasksCount;

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14.w),
        border: Border.all(color: const Color(0xFFE3E3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20.w,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 23.sp,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C20),
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999.w),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16.sp,
                  color: const Color(0xFF9A9EA7),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            dueDate == null
                ? '${task.id} •'
                : '${dueDate.day} • ${_taskTimeLabel(task)}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9A9EA7),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMiniInfoPill(
                      label: 'Customer: ${widget.project.customerDisplayName}',
                      backgroundColor: const Color(0xFFFFF0CF),
                      foregroundColor: const Color(0xFFC58500),
                    ),
                    SizedBox(height: 8.h),
                    _buildMiniInfoPill(
                      label: 'Client: ${widget.project.clientDisplayName}',
                      backgroundColor: const Color(0xFFE6EDFF),
                      foregroundColor: const Color(0xFF2D6AE6),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              _buildTaskMemberAvatars(task),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.w),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 3.5.h,
              backgroundColor: const Color(0xFFD9DCE2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFF78A2D),
              ),
            ),
          ),
          SizedBox(height: 7.h),
          Row(
            children: [
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF78A2D),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'Late tasks $lateTasks',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE15C49),
                ),
              ),
              const Spacer(),
              _buildTaskMetaMetric(
                CupertinoIcons.list_bullet,
                task.id > 0 ? 1 : 0,
              ),
              SizedBox(width: 8.w),
              _buildTaskMetaMetric(
                CupertinoIcons.chat_bubble_text,
                task.commentsCount,
              ),
              SizedBox(width: 8.w),
              _buildTaskMetaMetric(
                CupertinoIcons.paperclip,
                task.attachmentsCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildTaskMemberAvatars(ProjectTaskModel task) {
    if (task.members.isEmpty) return const SizedBox.shrink();

    final visible = task.members.take(3).toList();
    return SizedBox(
      width: visible.length * 14.w + 22.w,
      height: 22.h,
      child: Stack(
        children: [
          for (int index = 0; index < visible.length; index++)
            Positioned(
              left: index * 14.w,
              child: Container(
                width: 22.w,
                height: 22.h,
                padding: EdgeInsets.all(1.2.w),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.network(
                    visible[index].image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE3E6ED),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person,
                        size: 11.sp,
                        color: const Color(0xFF7C828E),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskMetaMetric(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.5.sp, color: const Color(0xFF767B84)),
        SizedBox(width: 3.w),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF767B84),
          ),
        ),
      ],
    );
  }

  String _taskStatusLabel(ProjectTaskModel task) {
    final status = task.status.trim().toLowerCase();
    if (status.isEmpty) return 'Task';
    if (status == 'new') return 'New';
    return status
        .split(RegExp(r'[\s_]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Color _getTaskProgressBarColor(ProjectTaskModel task) {
    final status = task.status.trim().toLowerCase();
    if (status.contains('completed') || status.contains('done')) {
      return const Color(0xFF4F8EF7);
    }
    if (status.contains('new')) {
      return const Color(0xFF6B8EDC);
    }
    if (status.contains('wait')) {
      return const Color(0xFFFBA429);
    }
    return const Color(0xFF6B8EDC);
  }

  Color _getTaskProgressBarBgColor(ProjectTaskModel task) {
    final status = task.status.trim().toLowerCase();
    if (status.contains('completed') || status.contains('done')) {
      return const Color(0xFFCFE5F3);
    }
    if (status.contains('new')) {
      return const Color(0xFFD4DBEC);
    }
    if (status.contains('wait')) {
      return const Color(0xFFFFEDD1);
    }
    return const Color(0xFFD4DBEC);
  }

  Color _getTaskStatusTextColor(ProjectTaskModel task) {
    final status = task.status.trim().toLowerCase();
    if (status.contains('completed') || status.contains('done')) {
      return const Color(0xFF3D67C2);
    }
    if (status.contains('new')) {
      return const Color(0xFF3D67C2);
    }
    if (status.contains('wait')) {
      return const Color(0xFFC68500);
    }
    return const Color(0xFF3D67C2);
  }

  Widget _buildCalendarNavButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.w),
      child: Container(
        width: 32.w,
        height: 32.h,
        alignment: Alignment.center,
        child: Icon(icon, size: 18.sp, color: const Color(0xFF6F737C)),
      ),
    );
  }

  Widget _buildProjectInfoPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  DateTime? _extractTaskDate(ProjectTaskModel? task) {
    if (task == null) return null;
    final raw = task.dueDate.trim();
    if (raw.isEmpty) return null;

    final isoParsed = DateTime.tryParse(raw);
    if (isoParsed != null) {
      return DateTime(
        isoParsed.year,
        isoParsed.month,
        isoParsed.day,
        isoParsed.hour,
        isoParsed.minute,
      );
    }

    final match = RegExp(
      r'([A-Za-z]{3,9})\s+(\d{1,2}),\s*(\d{4})(?:\s*\|\s*(\d{1,2}):(\d{2})(am|pm))?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;

    final month = _monthMap[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2) ?? '');
    final year = int.tryParse(match.group(3) ?? '');
    if (month == null || day == null || year == null) return null;

    var hour = int.tryParse(match.group(4) ?? '') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '') ?? 0;
    final meridiem = (match.group(6) ?? '').toLowerCase();
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    return DateTime(year, month, day, hour, minute);
  }

  String _taskTimeLabel(ProjectTaskModel task) {
    final dueDate = _extractTaskDate(task);
    if (dueDate == null) return '';
    final minute = dueDate.minute.toString().padLeft(2, '0');
    final suffix = dueDate.hour >= 12 ? 'pm' : 'am';
    final hour = dueDate.hour % 12 == 0 ? 12 : dueDate.hour % 12;
    return '$hour:$minute$suffix';
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String();
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_AgendaDayGroup> _buildAgendaEntries(
    Map<String, List<ProjectTaskModel>> tasksByDay,
    DateTime monthStart,
    DateTime monthEnd,
  ) {
    final entries = <_AgendaDayGroup>[];

    for (
      DateTime date = monthStart;
      !date.isAfter(monthEnd);
      date = date.add(const Duration(days: 1))
    ) {
      final tasks = [
        ...(tasksByDay[_dateKey(date)] ?? const <ProjectTaskModel>[]),
      ];
      if (tasks.isEmpty) continue;
      tasks.sort((a, b) {
        final aDate = _extractTaskDate(a) ?? date;
        final bDate = _extractTaskDate(b) ?? date;
        return aDate.compareTo(bDate);
      });
      entries.add(_AgendaDayGroup(date: date, tasks: tasks));
    }

    entries.sort((a, b) {
      final aSelected = _isSameDate(a.date, _selectedDate);
      final bSelected = _isSameDate(b.date, _selectedDate);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.date.compareTo(b.date);
    });

    return entries;
  }

  String _weekdayShort(DateTime date) {
    return _weekdayNames[(date.weekday % 7)];
  }

  int _weekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final daysOffset =
        date.difference(startOfYear).inDays + startOfYear.weekday;
    return (daysOffset / 7).floor() + 1;
  }

  double _agendaProgress(ProjectTaskModel task) {
    final status = task.status.toLowerCase();
    if (status.contains('complete')) return 1;
    if (status.contains('wait')) return 0.72;
    return 0.48;
  }
}

class _AgendaDayGroup {
  final DateTime date;
  final List<ProjectTaskModel> tasks;

  const _AgendaDayGroup({required this.date, required this.tasks});
}

const List<String> _calendarDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const List<String> _weekdayNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

const List<String> _calendarMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const Map<String, int> _monthMap = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};
