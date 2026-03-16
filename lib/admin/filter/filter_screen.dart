import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/services/helpers.dart';

import '../../constants/paths.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';

class FilterSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  final bool isFromStaff;
  final bool isFromClient;

  const FilterSheet({
    super.key,
    this.initialFilters,
    required this.isFromStaff,
    required this.isFromClient,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String status = "all";
  final firstNameCtrl = TextEditingController();
  final cmpnyNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dateCtrl = TextEditingController();
  String? emailError;
  String? phoneError;
  String? firstNameError;
  String? lastNameError;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters ?? {};
    if (f.containsKey("status")) {
      status = f["status"] == 1
          ? "active"
          : f["status"] == 0
          ? "inactive"
          : "all";
    }
    firstNameCtrl.text = f["name"] ?? "";
    lastNameCtrl.text = f["last_name"] ?? "";
    cmpnyNameCtrl.text = f["company_name"] ?? "";
    emailCtrl.text = f["email"] ?? "";
    phoneCtrl.text = (f["phone"] ?? "").toString().replaceAll('%', '');
    if (f["created_date"] != null) {
      final parts = f["created_date"].split("-");
      if (parts.length == 3) {
        dateCtrl.text = "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.only(top: 40.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SafeArea(
            top: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 2.h),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          _header(context),
                          Spacers.sb5(),
                          Divider(
                            thickness: 1.5.w,
                            color: const Color(0x5F9E9E9E),
                          ),
                          Spacers.sb10(),
                          _sectionTitle("Status"),
                          RadioGroup<String>(
                            groupValue: status,
                            onChanged: (value) {
                              setState(() => status = value!);
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _radio("All", "all"),
                                _radio("Active", "active"),
                                _radio("Inactive", "inactive"),
                              ],
                            ),
                          ),
                          Spacers.sb10(),
                          if (!widget.isFromStaff || widget.isFromClient)
                            _sectionTitle("Company Name"),
                          if (!widget.isFromStaff || widget.isFromClient)
                            Spacers.sb5(),
                          if (!widget.isFromStaff || widget.isFromClient)
                            _input(cmpnyNameCtrl, "Filter by company name"),
                          if (!widget.isFromStaff || widget.isFromClient)
                            Spacers.sb10(),
                          _sectionTitle("First Name"),
                          Spacers.sb5(),
                          _nameInput(
                            firstNameCtrl,
                            "Filter by first name",
                            isLastName: false,
                          ),
                          Spacers.sb10(),
                          _sectionTitle("Last Name"),
                          Spacers.sb5(),
                          _nameInput(
                            lastNameCtrl,
                            "Filter by last name",
                            isLastName: true,
                          ),
                          Spacers.sb10(),
                          _sectionTitle("Email"),
                          Spacers.sb5(),
                          _emailInput(emailCtrl, "Filter by email"),
                          Spacers.sb10(),
                          _sectionTitle("Phone"),
                          Spacers.sb5(),
                          _phoneInput(phoneCtrl, "Filter by phone"),
                          Spacers.sb10(),
                          _sectionTitle("Date Added"),
                          Spacers.sb5(),
                          _dateField(),
                          Spacers.sb20(),
                          scrollUp(context),
                        ],
                      ),
                    ),
                  ),
                  _applyBtn(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _applyBtn(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0.w),
          child: Row(
            children: [
              Expanded(
                child: CustomButton(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  height: 40,
                  title: "Apply Filters",
                  buttonColor: const Color(0xFFFFC107),
                  textColor: Colors.white,
                  fontWeight: FontWeight.w600,
                  borderRadius: 12,
                  stadium: false,
                  fontSize: 13,
                  onTap: _applyFilters,
                ),
              ),
              Spacers.sbw12(),
              Expanded(
                child: CustomButton(
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  height: 40,
                  title: "Reset",
                  buttonColor: Colors.white,
                  showBorder: true,
                  borderWidth: 1,
                  borderRadius: 12,
                  stadium: false,
                  fontSize: 13,
                  textColor: Colors.black,
                  onTap: _clearAll,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Column(
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
            ImageWidget(image: Paths.filter, width: 22),
            Spacers.sbw10(),
            Expanded(
              child: TextWidget(
                text: "Filter",
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
    );
  }

  Widget _sectionTitle(String title) {
    return TextWidget(
      text: title,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );
  }

  Widget _radio(String label, String value) {
    return InkWell(
      onTap: () => setState(() => status = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: value,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => status = v!),
            ),
            TextWidget(text: label, fontSize: 14, fontWeight: FontWeight.w500),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 45.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: ctrl,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _nameInput(
    TextEditingController ctrl,
    String hint, {
    required bool isLastName,
  }) {
    final error = isLastName ? lastNameError : firstNameError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 45.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: error != null ? Colors.red : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: ctrl,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z ]")),
            ],
            onChanged: (value) {
              setState(() {
                final msg = _hasInvalidNameCharacters(value)
                    ? "${isLastName ? 'Last' : 'First'} name should contain only alphabetic characters"
                    : null;
                if (isLastName) {
                  lastNameError = msg;
                } else {
                  firstNameError = msg;
                }
              });
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ),
        ),
        if (error != null) ...[
          SizedBox(height: 4.h),
          TextWidget(
            text: error,
            fontSize: 12,
            color: Colors.red,
            fontWeight: FontWeight.w400,
          ),
        ],
      ],
    );
  }

  Widget _phoneInput(TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 45.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: phoneError != null ? Colors.red : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              setState(() {
                if (value.isEmpty) {
                  phoneError = null;
                } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  phoneError = "Phone number should contain only digits";
                } else {
                  phoneError = null;
                }
              });
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ),
        ),
        if (phoneError != null) ...[
          SizedBox(height: 4.h),
          TextWidget(
            text: phoneError!,
            fontSize: 12,
            color: Colors.red,
            fontWeight: FontWeight.w400,
          ),
        ],
      ],
    );
  }

  Widget _emailInput(TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 45.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: emailError != null ? Colors.red : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: ctrl,
            onChanged: (value) {
              setState(() {
                if (value.isEmpty) {
                  emailError = null;
                } else if (!_isValidEmail(value)) {
                  emailError = "Invalid email format";
                } else {
                  emailError = null;
                }
              });
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ),
        ),
        if (emailError != null) ...[
          SizedBox(height: 4.h),
          TextWidget(
            text: emailError!,
            fontSize: 12,
            color: Colors.red,
            fontWeight: FontWeight.w400,
          ),
        ],
      ],
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _hasInvalidNameCharacters(String value) {
    if (value.isEmpty) return false;
    return !RegExp(r'^[a-zA-Z ]+$').hasMatch(value);
  }

  String _buildPhoneQueryPattern(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.split('').join('%');
  }

  Widget _dateField() {
    final bool hasDate = dateCtrl.text.isNotEmpty;
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: 45.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextWidget(
                text: hasDate ? dateCtrl.text : "Select date",
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: hasDate ? Colors.black87 : Colors.grey,
              ),
            ),
            const Icon(Icons.calendar_month_outlined),
          ],
        ),
      ),
    );
  }

  void _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDate: today,
    );
    if (date != null) {
      setState(() {
        dateCtrl.text =
            "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
      });
    }
  }

  void _applyFilters() {
    final email = emailCtrl.text.trim();
    final fn = firstNameCtrl.text.trim();
    final ln = lastNameCtrl.text.trim();
    final phone = _buildPhoneQueryPattern(phoneCtrl.text);

    setState(() {
      emailError = null;
      firstNameError = null;
      lastNameError = null;
    });

    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => emailError = "Please enter a valid email address");
      return;
    }
    if (_hasInvalidNameCharacters(fn)) {
      setState(
        () => firstNameError =
            "First name should contain only alphabetic characters",
      );
      return;
    }
    if (_hasInvalidNameCharacters(ln)) {
      setState(
        () => lastNameError =
            "Last name should contain only alphabetic characters",
      );
      return;
    }
    Navigator.pop(context, {
      "status": status,
      "company_name": cmpnyNameCtrl.text,
      "first_name": fn,
      "last_name": ln,
      "email": email,
      "phone": phone,
      "date": dateCtrl.text,
    });
  }

  void _clearAll() {
    final pro = getAdminPro(context);
    final pro2 = getClientPro(context);
    final pro3 = getCustPro(context);
    setState(() {
      status = "all";
      firstNameCtrl.clear();
      lastNameCtrl.clear();
      cmpnyNameCtrl.clear();
      emailCtrl.clear();
      phoneCtrl.clear();
      dateCtrl.clear();
    });
    pro.clearAccountFilters(context);
    pro2.clearClientFilters(context);
    pro3.clearCustFilters(context);
  }
}
