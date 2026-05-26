import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/colors.dart';
import '../../../constants/paths.dart';
import '../../../providers/files_pro.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart' as tab_text;

class TabFilesFilter extends StatefulWidget {
  static const String clearFiltersKey = '__clear_filters__';

  const TabFilesFilter({super.key});

  static Future<Map<String, String>?> show({
    required BuildContext context,
  }) async {
    return showGeneralDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FilesFilterPanel',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (context, _, _) {
        return const Align(
          alignment: Alignment.centerRight,
          child: TabFilesFilter(),
        );
      },
    );
  }

  @override
  State<TabFilesFilter> createState() => _TabFilesFilterState();
}

class _TabFilesFilterState extends State<TabFilesFilter> {
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

      if (mounted) setState(() {});
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
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 370,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: _buildFilterBody(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          ImageWidget(image: Paths.filter, width: 22, height: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: tab_text.TextWidget(
              text: "Filter Files",
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.black45),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBody() {
    final filesPro = context.watch<FilesPro>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdown(
          "Sort by",
          sortBy,
          filesPro.sortByOptions,
          filesPro.sortByPlaceholder,
          (v) => setState(() => sortBy = v == null || v.isEmpty ? null : v),
        ),
        const SizedBox(height: 20),
        _input("File name", fileName),
        const SizedBox(height: 20),
        _dropdown(
          "File Extension",
          fileExt,
          filesPro.fileExtensionOptions,
          filesPro.fileExtensionPlaceholder,
          (v) => setState(() => fileExt = v == null || v.isEmpty ? null : v),
        ),
        const SizedBox(height: 20),
        _input("Client's Company Name", clientCompanyName),
        const SizedBox(height: 20),
        _input("Client's Contact Name", clientContactName),
        const SizedBox(height: 20),
        _input("Client's Contact Lastname", clientContactLastName),
        const SizedBox(height: 20),
        _input("Customer's Company Name", customerCompanyName),
        const SizedBox(height: 20),
        _input("Customer's Contact Name", customerContactName),
        const SizedBox(height: 20),
        _input("Customer's Contact Lastname", customerContactLastName),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _input("Staff Name", staffName)),
            const SizedBox(width: 16),
            Expanded(child: _input("Staff Lastname", staffLastName)),
          ],
        ),
        const SizedBox(height: 24),
        _dateRangeCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _clearForm();
                Navigator.pop(context, {TabFilesFilter.clearFiltersKey: ''});
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                side: const BorderSide(color: Colors.black12),
              ),
              child: const tab_text.TextWidget(
                text: 'Clear',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _buildFilters());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const tab_text.TextWidget(
                text: 'Apply',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tab_text.TextWidget(
          text: label,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.black87,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Type ${label.toLowerCase()}",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
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
        tab_text.TextWidget(
          text: label,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.black87,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              hint: tab_text.TextWidget(
                text: placeholder,
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['value'] ?? '',
                      child: tab_text.TextWidget(
                        text: e['label'] ?? '',
                        fontSize: 14,
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

  Widget _dateRangeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF3F4F6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Colors.black87,
              ),
              SizedBox(width: 10),
              tab_text.TextWidget(
                text: "Date Added",
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _dateField("From", fromDate, (d) => setState(() => fromDate = d)),
          const SizedBox(height: 12),
          _dateField("To", toDate, (d) => setState(() => toDate = d)),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onPick) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: tab_text.TextWidget(
            text: label,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: tab_text.TextWidget(
                      text: value == null
                          ? 'dd-mm-yyyy'
                          : DateFormat('MMM dd, yyyy').format(value),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
