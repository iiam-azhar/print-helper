import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/text_widget.dart';

import '../../widgets/image_widget.dart';

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
              Expanded(
                child: CustomButton(title: 'C', onTap: () {}),
              ),
              Spacers.sbw15(),
              Expanded(
                child: CustomButton(title: 'Save', onTap: () {}),
              ),
            ],
          ),
          Spacers.sb10(),
        ],
      ),
    );
  }

  Widget _filterBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _dropdown("Sort by", sortBy, [
            "Name",
            "Date",
            "Size",
          ], (v) => setState(() => sortBy = v)),
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
              Icon(
                Icons.filter_alt_outlined,
                size: 22.sp,
                fontWeight: FontWeight.w800,
              ),
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
    List<String> items,
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
              hint: Text("Select"),
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

  Widget _dateField(String label, DateTime value, Function(DateTime) onPick) {
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
                initialDate: value,
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
                      text: DateFormat('MMM dd, yyyy').format(value),
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
