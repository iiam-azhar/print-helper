import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/text_widget.dart';

import '../../providers/files_pro.dart';
import '../../constants/paths.dart';
import '../../widgets/image_widget.dart';

class FilterFilesSheet extends StatefulWidget {
  static const String clearFiltersKey = '__clear_filters__';

  const FilterFilesSheet({super.key});

  @override
  State<FilterFilesSheet> createState() => _FilterFilesSheetState();
}

class _FilterFilesSheetState extends State<FilterFilesSheet> {
  final fileName = TextEditingController();
  final clientCompanyName = TextEditingController();
  final clientContactName = TextEditingController();
  final clientContactLastName = TextEditingController();
  final customerCompanyName = TextEditingController();
  final customerContactName = TextEditingController();
  final customerContactLastName = TextEditingController();
  final staffName = TextEditingController();
  final staffLastName = TextEditingController();

  String? sortBy;
  String? fileExt;

  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final filesPro = context.read<FilesPro>();
      filesPro.getFileFilterOptions();

      final active = filesPro.activeFilters;
      sortBy = active['sort_by']?.toString().trim().isNotEmpty == true
          ? active['sort_by'].toString().trim()
          : null;
      fileExt = active['file_extension']?.toString().trim().isNotEmpty == true
          ? active['file_extension'].toString().trim()
          : null;
      fileName.text = (active['filename'] ?? '').toString();
      clientCompanyName.text = (active['client_company_name'] ?? '').toString();
      clientContactName.text = (active['client_contact_name'] ?? '').toString();
      clientContactLastName.text = (active['client_contact_lastname'] ?? '')
          .toString();
      customerCompanyName.text = (active['customer_company_name'] ?? '')
          .toString();
      customerContactName.text = (active['customer_contact_name'] ?? '')
          .toString();
      customerContactLastName.text = (active['customer_contact_lastname'] ?? '')
          .toString();
      staffName.text = (active['staff_name'] ?? '').toString();
      staffLastName.text = (active['staff_lastname'] ?? '').toString();
      fromDate = DateTime.tryParse((active['date_from'] ?? '').toString());
      toDate = DateTime.tryParse((active['date_to'] ?? '').toString());

      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    fileName.dispose();
    clientCompanyName.dispose();
    clientContactName.dispose();
    clientContactLastName.dispose();
    customerCompanyName.dispose();
    customerContactName.dispose();
    customerContactLastName.dispose();
    staffName.dispose();
    staffLastName.dispose();
    super.dispose();
  }

  String _formatApiDate(DateTime value) =>
      DateFormat('yyyy-MM-dd').format(value);

  void _clearForm() {
    fileName.clear();
    clientCompanyName.clear();
    clientContactName.clear();
    clientContactLastName.clear();
    customerCompanyName.clear();
    customerContactName.clear();
    customerContactLastName.clear();
    staffName.clear();
    staffLastName.clear();
    setState(() {
      sortBy = null;
      fileExt = null;
      fromDate = null;
      toDate = null;
    });
  }

  Map<String, String> _buildFilters() {
    final filters = <String, String>{
      'sort_by': sortBy ?? '',
      'filename': fileName.text.trim(),
      'file_extension': fileExt ?? '',
      'client_company_name': clientCompanyName.text.trim(),
      'client_contact_name': clientContactName.text.trim(),
      'client_contact_lastname': clientContactLastName.text.trim(),
      'customer_company_name': customerCompanyName.text.trim(),
      'customer_contact_name': customerContactName.text.trim(),
      'customer_contact_lastname': customerContactLastName.text.trim(),
      'staff_name': staffName.text.trim(),
      'staff_lastname': staffLastName.text.trim(),
      'date_from': fromDate != null ? _formatApiDate(fromDate!) : '',
      'date_to': toDate != null ? _formatApiDate(toDate!) : '',
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
      child: Column(
        children: [
          _header(context),
          Spacers.sb5(),
          Divider(height: .8),
          Spacers.sb2(),
          Expanded(child: SingleChildScrollView(child: _filterBody())),
          Row(
            children: [
              Spacer(flex: 1),
              Expanded(
                child: CustomButton(
                  title: 'Clear',
                  onTap: () {
                    _clearForm();
                    Navigator.pop(context, {
                      FilterFilesSheet.clearFiltersKey: true,
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
                  onTap: () {
                    Navigator.pop(context, _buildFilters());
                  },
                  stadium: false,
                  height: 43,
                  showBorder: false,
                  borderRadius: 22,
                  buttonColor: Color(0xff30b76a),
                  textColor: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(flex: 1),
            ],
          ),
          Spacers.sb10(),
        ],
      ),
    );
  }

  Widget _filterBody() {
    final filesPro = context.watch<FilesPro>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _dropdown(
            "Sort by",
            sortBy,
            filesPro.sortByOptions,
            filesPro.sortByPlaceholder,
            (v) => setState(() => sortBy = v?.isEmpty == true ? null : v),
          ),
          Spacers.sb15(),
          _input("File name", fileName),
          Spacers.sb15(),
          _dropdown(
            "File Extension",
            fileExt,
            filesPro.fileExtensionOptions,
            filesPro.fileExtensionPlaceholder,
            (v) => setState(() => fileExt = v?.isEmpty == true ? null : v),
          ),
          Spacers.sb15(),
          _input("Client's Company Name", clientCompanyName),
          Spacers.sb15(),

          _input("Client's Contact Name", clientContactName),
          Spacers.sb15(),

          _input("Client's Contact Lastname", clientContactLastName),
          Spacers.sb15(),

          _input("Customer's Company Name", customerCompanyName),
          Spacers.sb15(),

          _input("Customer's Contact Name", customerContactName),
          Spacers.sb15(),

          _input("Customer's Contact Lastname", customerContactLastName),
          Spacers.sb15(),

          Row(
            children: [
              Expanded(child: _input("Staff Name", staffName)),
              Spacers.sbw10(),
              Expanded(child: _input("Staff Lastname", staffLastName)),
            ],
          ),
          Spacers.sb20(),

          /// Date Range Card
          _dateRangeCard(),

          Spacers.sb25(),
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
              ImageWidget(image: Paths.filter, width: 22, height: 22),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Filter Files",
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
              hintText: "Type ${label.toLowerCase()}",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14.sp),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  /// ------------------ DROPDOWN ------------------
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
        TextWidget(text: label, fontWeight: FontWeight.bold, fontSize: 14.sp),
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
              hint: Text(placeholder),
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

  /// ------------------ DATE RANGE ------------------
  Widget _dateRangeCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: Color(0xfff1f1f2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ImageWidget(
                image: 'assets/images/date.png',
                height: 25,
                width: 30,
                color: Colors.black,
              ),
              Spacers.sbw10(),
              TextWidget(
                text: "Date Added",
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
          Spacers.sb12(),
          _dateField("From", fromDate, (d) {
            setState(() => fromDate = d);
          }),
          Spacers.sb12(),
          _dateField("To", toDate, (d) {
            setState(() => toDate = d);
          }),
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
              DateTime? picked = await showDatePicker(
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
                  ImageWidget(
                    image: 'assets/images/date.png',
                    height: 25,
                    width: 25,
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
