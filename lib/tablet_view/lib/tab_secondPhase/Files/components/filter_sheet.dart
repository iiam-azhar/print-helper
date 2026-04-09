import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/files_pro.dart';

import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';

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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          _header(context),
          Spacers.sb5(),
          const Divider(height: .8),
          Spacers.sb2(),
          Expanded(child: SingleChildScrollView(child: _filterBody())),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () {
                    _clearForm();
                    Navigator.pop(context, {
                      FilterFilesSheet.clearFiltersKey: true,
                    });
                  },
                  child: const TextWidget(
                    text: "Clear",
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Spacers.sbw15(),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, _buildFilters());
                  },
                  child: const TextWidget(
                    text: "Save",
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Spacers.sb10(),
        ],
      ),
    );
  }

  // ---------------- HEADER UI ----------------
  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Spacers.sb10(),
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 22),
              Spacers.sbw10(),
              const Expanded(
                child: TextWidget(
                  text: "Filter Files",
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- MAIN BODY ----------------
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

          _dateRangeCard(),

          Spacers.sb25(),
        ],
      ),
    );
  }

  // ---------------- INPUT FIELD ----------------
  Widget _input(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: label, fontWeight: FontWeight.bold, fontSize: 14),
        Spacers.sb5(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Type ${label.toLowerCase()}",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- DROPDOWN ----------------
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
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

  // ---------------- DATE RANGE CARD ----------------
  Widget _dateRangeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month),
              SizedBox(width: 10),
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

  // ---------------- DATE PICKER FIELD ----------------
  Widget _dateField(String label, DateTime? value, Function(DateTime) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: label, fontSize: 13, fontWeight: FontWeight.w500),
        Spacers.sb5(),
        GestureDetector(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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
                const Icon(Icons.calendar_month),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
