import 'package:flutter/material.dart';

import '../../../tab_widgets/tab_spacers.dart';
import '../../../tab_widgets/tab_text_widget.dart';

class FilterFilesSheet extends StatefulWidget {
  const FilterFilesSheet({super.key});

  @override
  State<FilterFilesSheet> createState() => _FilterFilesSheetState();
}

class _FilterFilesSheetState extends State<FilterFilesSheet> {
  final fileName = TextEditingController();
  final companyName = TextEditingController();
  final contactName = TextEditingController();
  final contactLastName = TextEditingController();
  final projectName = TextEditingController();
  final projectID = TextEditingController();
  final taskName = TextEditingController();

  String? sortBy;
  String? fileExt;

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

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
                  onPressed: () {},
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
                  onPressed: () {},
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _dropdown("Sort by", sortBy, ["Name", "Date", "Size"], (v) {
            setState(() => sortBy = v);
          }),
          Spacers.sb15(),

          _input("File name", fileName),
          Spacers.sb15(),

          _dropdown("File Extention", fileExt, ["pdf", "psd", "jpg", "png"], (
            v,
          ) {
            setState(() => fileExt = v);
          }),
          Spacers.sb15(),

          _input("Customer’s Company Name", companyName),
          Spacers.sb15(),

          _input("Contact Name", contactName),
          Spacers.sb15(),

          _input("Contact Lastname", contactLastName),
          Spacers.sb15(),

          _input("Project Name", projectName),
          Spacers.sb15(),

          _input("Project ID", projectID),
          Spacers.sb15(),

          _input("Task Name", taskName),
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
    List<String> items,
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
              hint: const Text("Select"),
              items: items
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: TextWidget(
                        text: e,
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
  Widget _dateField(String label, DateTime value, Function(DateTime) onPick) {
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
              initialDate: value,
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
                    text: "${value.month}/${value.day}/${value.year}",
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
