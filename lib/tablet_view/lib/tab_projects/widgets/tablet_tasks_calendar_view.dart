import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../models/projects_models.dart';

typedef TaskInfoTapCallback =
    void Function(BuildContext buttonContext, ProjectTaskModel task);
typedef TaskDropCallback =
    Future<bool> Function(ProjectTaskModel task, DateTime targetDate);
typedef TaskTapCallback = void Function(ProjectTaskModel task);

class TabletTasksCalendarView extends StatefulWidget {
  final List<ProjectTaskModel> tasks;
  final Future<void> Function() onRefresh;
  final TaskTapCallback onTaskTap;
  final TaskInfoTapCallback onTaskInfoTap;
  final TaskDropCallback onTaskDrop;

  const TabletTasksCalendarView({
    super.key,
    required this.tasks,
    required this.onRefresh,
    required this.onTaskTap,
    required this.onTaskInfoTap,
    required this.onTaskDrop,
  });

  @override
  State<TabletTasksCalendarView> createState() =>
      _TabletTasksCalendarViewState();
}

class _TabletTasksCalendarViewState extends State<TabletTasksCalendarView> {
  late DateTime _calendarMonth;
  final Map<int, DateTime> _optimisticTaskDates = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
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
      final dueDate = _effectiveTaskDate(task);
      if (dueDate == null) continue;
      final key = _dateKey(dueDate);
      tasksByDay.putIfAbsent(key, () => []).add(task);
    }
    const visibleSlots = 3;
    const gridAspectRatio = 0.62;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E4E9)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  _CalendarHeaderButton(
                    icon: Icons.chevron_left,
                    onTap: () {
                      setState(() {
                        _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month - 1,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _CalendarHeaderButton(
                    icon: Icons.chevron_right,
                    onTap: () {
                      setState(() {
                        _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month + 1,
                        );
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      final now = DateTime.now();
                      setState(() {
                        _calendarMonth = DateTime(now.year, now.month);
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7E8897),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'today',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMMM yyyy').format(_calendarMonth),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF121826),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E4E9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: const [
                  _CalendarDayHeader('Sun'),
                  _CalendarDayHeader('Mon'),
                  _CalendarDayHeader('Tue'),
                  _CalendarDayHeader('Wed'),
                  _CalendarDayHeader('Thu'),
                  _CalendarDayHeader('Fri'),
                  _CalendarDayHeader('Sat'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  itemCount: visibleDays.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: gridAspectRatio,
                  ),
                  itemBuilder: (context, index) {
                    final day = visibleDays[index];
                    final isCurrentMonth = day.month == _calendarMonth.month;
                    final dayTasks =
                        tasksByDay[_dateKey(day)] ?? const <ProjectTaskModel>[];
                    return _CalendarDayCell(
                      day: day,
                      isCurrentMonth: isCurrentMonth,
                      tasks: dayTasks,
                      visibleSlots: visibleSlots,
                      onTaskTap: widget.onTaskTap,
                      onTaskInfoTap: widget.onTaskInfoTap,
                      onTaskDrop: _handleTaskDrop,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return DateFormat('yyyy-MM-dd').format(normalized);
  }

  DateTime? _effectiveTaskDate(ProjectTaskModel task) {
    final optimistic = _optimisticTaskDates[task.id];
    if (optimistic != null) return optimistic;
    return task.dueDateParsed;
  }

  Future<bool> _handleTaskDrop(
    ProjectTaskModel task,
    DateTime targetDate,
  ) async {
    final current = _effectiveTaskDate(task);
    final isSameDay =
        current != null &&
        current.year == targetDate.year &&
        current.month == targetDate.month &&
        current.day == targetDate.day;
    if (isSameDay) return false;

    final optimisticDate = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      current?.hour ?? 9,
      current?.minute ?? 0,
      current?.second ?? 0,
    );

    setState(() {
      _optimisticTaskDates[task.id] = optimisticDate;
    });

    final ok = await widget.onTaskDrop(task, targetDate);
    if (!mounted) return ok;

    setState(() {
      _optimisticTaskDates.remove(task.id);
    });
    return ok;
  }
}

class _CalendarHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalendarHeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 44,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF30465E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _CalendarDayHeader extends StatelessWidget {
  final String label;

  const _CalendarDayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF151B27),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatefulWidget {
  final DateTime day;
  final bool isCurrentMonth;
  final List<ProjectTaskModel> tasks;
  final int visibleSlots;
  final TaskTapCallback onTaskTap;
  final TaskInfoTapCallback onTaskInfoTap;
  final TaskDropCallback onTaskDrop;

  const _CalendarDayCell({
    required this.day,
    required this.isCurrentMonth,
    required this.tasks,
    required this.visibleSlots,
    required this.onTaskTap,
    required this.onTaskInfoTap,
    required this.onTaskDrop,
  });

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  late final ScrollController _scrollController;
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        widget.day.year == today.year &&
        widget.day.month == today.month &&
        widget.day.day == today.day;
    return DragTarget<ProjectTaskModel>(
      onWillAcceptWithDetails: (details) {
        final parsed = DateTime.tryParse(details.data.dueDate.trim());
        final sameDay =
            parsed != null &&
            parsed.year == widget.day.year &&
            parsed.month == widget.day.month &&
            parsed.day == widget.day.day;
        final accept = !sameDay;
        if (accept) setState(() => _isDragOver = true);
        return accept;
      },
      onLeave: (_) {
        if (_isDragOver) setState(() => _isDragOver = false);
      },
      onAcceptWithDetails: (details) async {
        setState(() => _isDragOver = false);
        await widget.onTaskDrop(details.data, widget.day);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _isDragOver
                ? const Color(0xFFEAF3FF)
                : (isToday ? const Color(0xFFFFFBE9) : Colors.white),
            border: Border.all(
              color: _isDragOver
                  ? const Color(0xFF6EA8FF)
                  : const Color(0xFFE2E4E9),
              width: _isDragOver ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  '${widget.day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !widget.isCurrentMonth
                        ? const Color(0xFFA4A9B2)
                        : isToday
                        ? const Color(0xFF8F6A00)
                        : const Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: widget.tasks.isEmpty
                    ? const SizedBox.shrink()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 6.0;
                          final separators = (widget.visibleSlots - 1).clamp(
                            0,
                            10,
                          );
                          final available =
                              constraints.maxHeight - (gap * separators);
                          final itemHeight = (available / widget.visibleSlots)
                              .clamp(52.0, 170.0);
                          return Scrollbar(
                            controller: _scrollController,
                            thumbVisibility:
                                widget.tasks.length > widget.visibleSlots,
                            interactive: true,
                            thickness: 5,
                            radius: const Radius.circular(99),
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: widget.tasks.length,
                              itemBuilder: (context, index) => SizedBox(
                                height: itemHeight,
                                child: _CalendarTaskChip(
                                  task: widget.tasks[index],
                                  onTaskTap: widget.onTaskTap,
                                  onTaskInfoTap: widget.onTaskInfoTap,
                                ),
                              ),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: gap),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CalendarTaskChip extends StatelessWidget {
  final ProjectTaskModel task;
  final TaskTapCallback onTaskTap;
  final TaskInfoTapCallback onTaskInfoTap;

  const _CalendarTaskChip({
    required this.task,
    required this.onTaskTap,
    required this.onTaskInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusText =
        (task.sectionName.trim().isEmpty ? task.status : task.sectionName)
            .replaceAll('_', ' ');
    final dateLabel = _calendarTaskDateLabel(task.dueDate);
    final dueLabel = _calendarTaskTimeLabel(task.dueDate);
    final statusColor = _calendarStatusTextColor(task);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 66 || constraints.maxWidth < 155;
        final padV = compact ? 4.0 : 6.0;
        final gap1 = compact ? 3.0 : 5.0;
        final gap2 = compact ? 3.0 : 5.0;

        final card = Container(
          padding: EdgeInsets.fromLTRB(8, padV, 8, padV),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE1E7)),
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
                        fontSize: compact ? 9.0 : 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101727),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dateLabel.isNotEmpty ? '$dateLabel ' : ''}$dueLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 7.5 : 8,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6F7A8D),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap1),
              Row(
                children: [
                  Container(
                    width: compact ? 20 : 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: _calendarStatusAccent(task),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _toTitleCase(statusText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 8.0 : 8.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap2),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          _CalendarMiniMetric(
                            icon: Icons.chat_bubble_outline,
                            count: task.commentsCount,
                            compact: compact,
                          ),
                          const SizedBox(width: 6),
                          _CalendarMiniMetric(
                            icon: Icons.attach_file,
                            count: task.attachmentsCount,
                            compact: compact,
                          ),
                          const SizedBox(width: 6),
                          _CalendarMiniMetric(
                            icon: Icons.person_outline,
                            count: task.members.length,
                            compact: compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (buttonContext) => InkWell(
                      onTap: () => onTaskInfoTap(buttonContext, task),
                      borderRadius: BorderRadius.circular(99),
                      child: Icon(
                        Icons.info_outline,
                        size: compact ? 11 : 12,
                        color: const Color(0xFF586579),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        return LongPressDraggable<ProjectTaskModel>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Opacity(opacity: 0.95, child: card),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: InkWell(
            onTap: () => onTaskTap(task),
            borderRadius: BorderRadius.circular(10),
            child: card,
          ),
        );
      },
    );
  }
}

class _CalendarMiniMetric extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool compact;

  const _CalendarMiniMetric({
    required this.icon,
    required this.count,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: compact ? 10 : 11, color: const Color(0xFF6F7A8D)),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: compact ? 7.5 : 8,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7C889C),
          ),
        ),
      ],
    );
  }
}

String _calendarTaskDateLabel(String dueDate) {
  final parsed = DateTime.tryParse(dueDate.trim());
  if (parsed == null) return '';
  return DateFormat('MMM dd').format(parsed);
}

String _calendarTaskTimeLabel(String dueDate) {
  final parsed = DateTime.tryParse(dueDate.trim());
  if (parsed == null) return '--';
  final raw = DateFormat('h:mma').format(parsed).toLowerCase();
  if (raw.endsWith('am') || raw.endsWith('pm')) {
    final trimmedMinute = raw.replaceAll(':00', '');
    return trimmedMinute.endsWith('am')
        ? '${trimmedMinute.substring(0, trimmedMinute.length - 2)}a'
        : '${trimmedMinute.substring(0, trimmedMinute.length - 2)}p';
  }
  return raw;
}

Color _calendarStatusAccent(ProjectTaskModel task) {
  return const Color(0xFFBCC2CB);
}

Color _calendarStatusTextColor(ProjectTaskModel task) {
  final value = '${task.status} ${task.sectionName}'.toLowerCase();
  if (value.contains('new')) return const Color(0xFF2E5E9E);
  if (value.contains('progress')) return const Color(0xFF314E74);
  if (value.contains('complete') || value.contains('done')) {
    return const Color(0xFF2D6B42);
  }
  if (value.contains('verif')) return const Color(0xFF3B4A63);
  return const Color(0xFF4A5A74);
}

String _toTitleCase(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  return parts
      .map((word) {
        final lower = word.toLowerCase();
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
