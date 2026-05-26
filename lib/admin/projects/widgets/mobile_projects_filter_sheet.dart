import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/paths.dart';
import '../../../providers/project_pro.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/image_widget.dart';
import '../../../widgets/spacers.dart';
import '../../../widgets/text_widget.dart';

enum _LateTaskOption { yes, no }

class MobileProjectsFilterSheet extends StatefulWidget {
  static const String clearFiltersKey = '__clear_filters__';

  const MobileProjectsFilterSheet({super.key});

  @override
  State<MobileProjectsFilterSheet> createState() =>
      _MobileProjectsFilterSheetState();
}

class _MobileProjectsFilterSheetState extends State<MobileProjectsFilterSheet> {
  final _projectNameController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _taskController = TextEditingController();
  final _clientCompanyController = TextEditingController();
  final _customerCompanyController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactLastNameController = TextEditingController();

  _LateTaskOption _lateTaskOption = _LateTaskOption.no;
  String? _selectedSortBy;
  String? _selectedAssignedTo;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final projectPro = context.read<ProjectPro>();
      projectPro.getProjectFilterProjectAssignees();

      final active = projectPro.activeProjectFilters;
      _selectedSortBy = active['sort_by']?.trim().isNotEmpty == true
          ? active['sort_by']!.trim()
          : null;
      _selectedAssignedTo = active['assigned_to']?.trim().isNotEmpty == true
          ? active['assigned_to']!.trim()
          : null;

      _projectNameController.text = active['project_name'] ?? '';
      _projectIdController.text = active['project_id'] ?? '';
      _taskController.text = active['task'] ?? '';
      _clientCompanyController.text = active['client_company_name'] ?? '';
      _customerCompanyController.text = active['customer_company_name'] ?? '';
      _contactNameController.text = active['contact_name'] ?? '';
      _contactLastNameController.text = active['contact_lastname'] ?? '';
      _fromDate = DateTime.tryParse(active['date_from'] ?? '');
      _toDate = DateTime.tryParse(active['date_to'] ?? '');

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectIdController.dispose();
    _taskController.dispose();
    _clientCompanyController.dispose();
    _customerCompanyController.dispose();
    _contactNameController.dispose();
    _contactLastNameController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _projectNameController.clear();
    _projectIdController.clear();
    _taskController.clear();
    _clientCompanyController.clear();
    _customerCompanyController.clear();
    _contactNameController.clear();
    _contactLastNameController.clear();
    setState(() {
      _selectedSortBy = null;
      _selectedAssignedTo = null;
      _lateTaskOption = _LateTaskOption.no;
      _fromDate = null;
      _toDate = null;
    });
  }

  String _formatApiDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  Map<String, String> _buildFilters() {
    final filters = <String, String>{
      'status': 'active',
      'sort_by': _selectedSortBy ?? '',
      'project_name': _projectNameController.text.trim(),
      'project_id': _projectIdController.text.trim(),
      'task': _taskController.text.trim(),
      'client_company_name': _clientCompanyController.text.trim(),
      'customer_company_name': _customerCompanyController.text.trim(),
      'contact_name': _contactNameController.text.trim(),
      'contact_lastname': _contactLastNameController.text.trim(),
      'assigned_to': _selectedAssignedTo ?? '',
      'date_from': _fromDate != null ? _formatApiDate(_fromDate!) : '',
      'date_to': _toDate != null ? _formatApiDate(_toDate!) : '',
      'per_page': '16',
    };

    filters.removeWhere((key, value) => value.trim().isEmpty);
    return filters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.91,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.r),
          topRight: Radius.circular(25.r),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          _header(context),
          Spacers.sb5(),
          const Divider(height: .8),
          Spacers.sb2(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _sortByDropdown(),
                    Spacers.sb15(),
                    _lateTasksRow(),
                    Spacers.sb15(),
                    _input('Project Name', _projectNameController),
                    Spacers.sb15(),
                    _input('Project ID', _projectIdController),
                    Spacers.sb15(),
                    _input('Task', _taskController),
                    Spacers.sb15(),
                    _input("Client's Company Name", _clientCompanyController),
                    Spacers.sb15(),
                    _input(
                      "Customer's Company Name",
                      _customerCompanyController,
                    ),
                    Spacers.sb15(),
                    _input('Contact Name', _contactNameController),
                    Spacers.sb15(),
                    _input('Contact Lastname', _contactLastNameController),
                    Spacers.sb15(),
                    _assignedToDropdown(),
                    Spacers.sb20(),
                    _dateRangeCard(),
                    Spacers.sb25(),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              const Spacer(flex: 1),
              Expanded(
                child: CustomButton(
                  title: 'Clear',
                  onTap: () {
                    _clearForm();
                    Navigator.pop(context, {
                      MobileProjectsFilterSheet.clearFiltersKey: true,
                    });
                  },
                  stadium: false,
                  height: 43,
                  showBorder: true,
                  borderRadius: 22,
                  buttonColor: Colors.white,
                  textColor: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacers.sbw15(),
              Expanded(
                child: CustomButton(
                  title: 'Save',
                  onTap: () => Navigator.pop(context, _buildFilters()),
                  stadium: false,
                  height: 43,
                  showBorder: false,
                  borderRadius: 22,
                  buttonColor: const Color(0xff30b76a),
                  textColor: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
          Spacers.sb10(),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 45.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          Spacers.sb10(),
          Row(
            children: [
              ImageWidget(image: Paths.filter, width: 20, height: 20),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: 'Filter Projects',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.close,
                  size: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: label, fontWeight: FontWeight.bold, fontSize: 14),
        Spacers.sb5(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.black12),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Type ${label.toLowerCase()}',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sortByDropdown() {
    const sortByOptions = <Map<String, String>>[
      {'value': '', 'label': 'Select'},
      {'value': 'newest', 'label': 'Newest First'},
      {'value': 'oldest', 'label': 'Oldest First'},
      {'value': 'name_asc', 'label': 'Project Name A-Z'},
      {'value': 'name_desc', 'label': 'Project Name Z-A'},
      {'value': 'updated_desc', 'label': 'Recently Updated'},
      {'value': 'updated_asc', 'label': 'Least Recently Updated'},
    ];

    return _dropdown(
      'Sort by',
      _selectedSortBy,
      sortByOptions,
      'Select',
      (v) => setState(() => _selectedSortBy = v?.isEmpty == true ? null : v),
    );
  }

  Widget _assignedToDropdown() {
    final projectPro = context.watch<ProjectPro>();
    final assignedOptions = projectPro.projectFilterProjectAssigneeOptions;

    return _dropdown(
      'Assigned to Name',
      _selectedAssignedTo,
      assignedOptions,
      'Select',
      (v) =>
          setState(() => _selectedAssignedTo = v?.isEmpty == true ? null : v),
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<Map<String, String>> items,
    String placeholder,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: label, fontWeight: FontWeight.bold, fontSize: 14),
        Spacers.sb5(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              hint: Text(placeholder, style: TextStyle(fontSize: 14.sp)),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['value'] ?? '',
                      child: TextWidget(
                        text: e['label'] ?? '',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _lateTasksRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Late Tasks',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        Spacers.sb8(),
        Row(
          children: [
            _radioOption(_LateTaskOption.yes, 'YES'),
            Spacers.sbw20(),
            _radioOption(_LateTaskOption.no, 'NO'),
          ],
        ),
      ],
    );
  }

  Widget _radioOption(_LateTaskOption value, String label) {
    final selected = _lateTaskOption == value;
    return InkWell(
      onTap: () => setState(() => _lateTaskOption = value),
      child: Row(
        children: [
          Container(
            width: 19.w,
            height: 19.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black38),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 11.w,
              height: 11.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xff30b76a) : Colors.transparent,
              ),
            ),
          ),
          Spacers.sbw8(),
          TextWidget(
            text: label,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ],
      ),
    );
  }

  Widget _dateRangeCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: const Color(0xfff1f1f2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 20.sp,
                color: Colors.black,
              ),
              Spacers.sbw10(),
              TextWidget(
                text: 'Date Added',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
          Spacers.sb12(),
          _dateField('From', _fromDate, (d) => setState(() => _fromDate = d)),
          Spacers.sb12(),
          _dateField('To', _toDate, (d) => setState(() => _toDate = d)),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onPick) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 1,
          child: TextWidget(
            text: label,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        Spacers.sb5(),
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2050),
                initialDate: value ?? DateTime.now(),
              );
              if (picked != null) onPick(picked);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextWidget(
                      text: value == null
                          ? 'dd-mm-yyyy'
                          : DateFormat('MMM dd, yyyy').format(value),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    CupertinoIcons.calendar,
                    size: 18.sp,
                    color: Colors.grey,
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
