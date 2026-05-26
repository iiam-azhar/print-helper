import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/project_pro.dart';
import 'package:print_helper/constants/colors.dart';
import 'package:print_helper/constants/paths.dart';
import '../../tab_widgets/tab_image_widget.dart';

enum _LateTaskOption { yes, no }

class TabletProjectTasksFilterSidebar extends StatefulWidget {
  static const String clearFiltersKey = '__clear_filters__';

  final int projectId;
  final Map<String, String> initialFilters;

  const TabletProjectTasksFilterSidebar({
    super.key,
    required this.projectId,
    this.initialFilters = const <String, String>{},
  });

  @override
  State<TabletProjectTasksFilterSidebar> createState() =>
      _TabletProjectTasksFilterSidebarState();
}

class _TabletProjectTasksFilterSidebarState
    extends State<TabletProjectTasksFilterSidebar> {
  final _taskController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactLastNameController = TextEditingController();

  String? _selectedStatus;
  String? _selectedSortBy;
  String? _selectedAssignedTo;
  _LateTaskOption? _lateTaskOption;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final projectPro = context.read<ProjectPro>();
      projectPro.getProjectFilterProjectTaskAssignees(
        projectId: widget.projectId,
      );
      projectPro.getProjectSectionFilterOptions();

      final active = widget.initialFilters;
      _selectedStatus = active['status']?.trim().isNotEmpty == true
          ? active['status']!.trim()
          : null;
      _selectedSortBy = active['sort_by']?.trim().isNotEmpty == true
          ? active['sort_by']!.trim()
          : null;
      _selectedAssignedTo = active['assigned_to']?.trim().isNotEmpty == true
          ? active['assigned_to']!.trim()
          : null;

      _taskController.text = active['task'] ?? '';
      _contactNameController.text = active['contact_name'] ?? '';
      _contactLastNameController.text = active['contact_lastname'] ?? '';

      final lateTasks = (active['late_tasks'] ?? '').trim().toLowerCase();
      if (lateTasks == 'yes' || lateTasks == '1' || lateTasks == 'true') {
        _lateTaskOption = _LateTaskOption.yes;
      } else if (lateTasks == 'no' ||
          lateTasks == '0' ||
          lateTasks == 'false') {
        _lateTaskOption = _LateTaskOption.no;
      }

      _fromDate = DateTime.tryParse(active['date_from'] ?? '');
      _toDate = DateTime.tryParse(active['date_to'] ?? '');

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _contactNameController.dispose();
    _contactLastNameController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _taskController.clear();
    _contactNameController.clear();
    _contactLastNameController.clear();
    setState(() {
      _selectedStatus = null;
      _selectedSortBy = null;
      _selectedAssignedTo = null;
      _lateTaskOption = null;
      _fromDate = null;
      _toDate = null;
    });
  }

  String _formatApiDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  Map<String, String> _buildFilters() {
    final filters = <String, String>{
      'view': 'list',
      'status': _selectedStatus ?? '',
      'sort_by': _selectedSortBy ?? '',
      'late_tasks': _lateTaskOption == null
          ? ''
          : (_lateTaskOption == _LateTaskOption.yes ? 'yes' : 'no'),
      'task': _taskController.text.trim(),
      'contact_name': _contactNameController.text.trim(),
      'contact_lastname': _contactLastNameController.text.trim(),
      'assigned_to': _selectedAssignedTo ?? '',
      'date_from': _fromDate != null ? _formatApiDate(_fromDate!) : '',
      'date_to': _toDate != null ? _formatApiDate(_toDate!) : '',
    };

    filters.removeWhere((key, value) => value.trim().isEmpty);
    return filters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE9E9EF)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdown(
                    'Status',
                    _selectedStatus,
                    context.watch<ProjectPro>().projectSectionFilterOptions,
                    (v) => setState(() => _selectedStatus = v),
                  ),
                  const SizedBox(height: 20),
                  _buildSortByDropdown(),
                  const SizedBox(height: 20),
                  _buildLateTasksOption(),
                  const SizedBox(height: 20),
                  _buildTextField('Task', _taskController),
                  const SizedBox(height: 20),
                  _buildTextField('Contact Name', _contactNameController),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Contact Lastname',
                    _contactLastNameController,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdown(
                    'Assigned to Name',
                    _selectedAssignedTo,
                    context
                        .watch<ProjectPro>()
                        .projectFilterProjectTaskAssigneeOptions,
                    (v) => setState(() => _selectedAssignedTo = v),
                  ),
                  const SizedBox(height: 24),
                  _buildDateRangePicker(),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9E9EF)),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
      child: Row(
        children: [
          ImageWidget(
            image: Paths.filter,
            width: 7,
            height: 7,
            color: const Color(0xFF1F1F27),
          ),
          const SizedBox(width: 10),
          const Text(
            'Filter Tasks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1F27),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              CupertinoIcons.xmark,
              size: 22,
              color: Color(0xFF98A0AC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context, {
                  TabletProjectTasksFilterSidebar.clearFiltersKey: true,
                });
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Color(0xFFE0E2E8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F27),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _buildFilters()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF1ECB5C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F1F27),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Type $label',
            hintStyle: const TextStyle(color: Color(0xFF98A0AC), fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E2E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E2E8)),
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
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<Map<String, String>> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F1F27),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E2E8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (items.any((e) => e['value'] == value)) ? value : null,
              isExpanded: true,
              icon: const Icon(CupertinoIcons.chevron_down, size: 16),
              hint: const Text(
                'Select',
                style: TextStyle(color: Color(0xFF98A0AC), fontSize: 14),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(
                    item['label'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortByDropdown() {
    const sortByOptions = <Map<String, String>>[
      {'value': '', 'label': 'Select'},
      {'value': 'newest', 'label': 'Newest First'},
      {'value': 'oldest', 'label': 'Oldest First'},
      {'value': 'name_asc', 'label': 'Task Name A-Z'},
      {'value': 'name_desc', 'label': 'Task Name Z-A'},
      {'value': 'updated_desc', 'label': 'Recently Updated'},
      {'value': 'updated_asc', 'label': 'Least Recently Updated'},
    ];

    return _buildDropdown(
      'Sort by',
      _selectedSortBy,
      sortByOptions,
      (v) => setState(() => _selectedSortBy = v),
    );
  }

  Widget _buildLateTasksOption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Late Tasks',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F1F27),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildRadio('YES', _LateTaskOption.yes),
            const SizedBox(width: 24),
            _buildRadio('NO', _LateTaskOption.no),
          ],
        ),
      ],
    );
  }

  Widget _buildRadio(String label, _LateTaskOption value) {
    final isSelected = _lateTaskOption == value;
    return GestureDetector(
      onTap: () => setState(() => _lateTaskOption = value),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1ECB5C)
                    : const Color(0xFFE0E2E8),
                width: isSelected ? 6 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F1F27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.calendar, size: 18, color: Color(0xFF1F1F27)),
              SizedBox(width: 10),
              Text(
                'Date Due Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F1F27),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateField(
            'From',
            _fromDate,
            (d) => setState(() => _fromDate = d),
          ),
          const SizedBox(height: 12),
          _buildDateField('To', _toDate, (d) => setState(() => _toDate = d)),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onPicked,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F1F27),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF1ECB5C),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) onPicked(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E2E8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date != null
                          ? DateFormat('MMM dd, yyyy').format(date)
                          : 'Select date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: date != null
                            ? const Color(0xFF1F1F27)
                            : const Color(0xFF98A0AC),
                      ),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.calendar,
                    size: 18,
                    color: Color(0xFF98A0AC),
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
