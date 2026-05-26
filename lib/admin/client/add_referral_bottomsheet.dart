import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/admin/client/referrals_mobile.dart';

class AddReferralBottomSheet extends StatefulWidget {
  final Referral? referral;
  final Function(Referral) onSave;

  const AddReferralBottomSheet({
    super.key,
    this.referral,
    required this.onSave,
  });

  @override
  State<AddReferralBottomSheet> createState() => _AddReferralBottomSheetState();
}

class _AddReferralBottomSheetState extends State<AddReferralBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _compCtrl;
  late TextEditingController _amtCtrl;
  late TextEditingController _invoiceCtrl;
  late TextEditingController _notesCtrl;
  
  late String _selectedStatus;
  late String _selectedCommission;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final ref = widget.referral;
    _nameCtrl = TextEditingController(text: ref?.fullName ?? '');
    _compCtrl = TextEditingController(text: ref?.company == '—' ? '' : (ref?.company ?? ''));
    _amtCtrl = TextEditingController(text: ref != null ? ref.amount.toStringAsFixed(2) : '');
    _invoiceCtrl = TextEditingController(text: ref?.invoice == '—' ? '' : (ref?.invoice ?? ''));
    _notesCtrl = TextEditingController(text: ref?.notes == '—' ? '' : (ref?.notes ?? ''));
    
    _selectedStatus = ref?.status ?? 'Pending';
    _selectedCommission = ref?.commission ?? 'Not Yet';
    
    // Parse date if edit
    if (ref != null) {
      _selectedDate = _parseDateString(ref.date);
    } else {
      _selectedDate = DateTime.now();
    }
  }

  DateTime _parseDateString(String dateStr) {
    // Expected formats: "Apr 27, 2026" or "27-04-2026"
    try {
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } else {
        // Month name format e.g. "Apr 27, 2026"
        final clean = dateStr.replaceAll(',', '');
        final parts = clean.split(' ');
        if (parts.length == 3) {
          final monthStr = parts[0];
          final day = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          final months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          final month = months.indexOf(monthStr) + 1;
          if (month > 0) {
            return DateTime(year, month, day);
          }
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  String _getFormattedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return "$day-$month-$year";
  }

  String _getFormattedMonthNameDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFACC15),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h, top: 12.h),
      child: TextWidget(
        text: label,
        fontSize: 10.5.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B), // Slate-500
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 12.5.sp, color: Colors.grey.shade400),
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: const BorderSide(color: Color(0xFFFACC15), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: widget.referral != null ? "Edit Referral" : "Add New Referral",
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, size: 20.sp, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Form Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                top: 8.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("FULL NAME *"),
                    TextFormField(
                      controller: _nameCtrl,
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                      decoration: _buildInputDecoration("First and last name"),
                      validator: (value) => value == null || value.trim().isEmpty ? "Full name is required" : null,
                    ),

                    _buildFieldLabel("COMPANY"),
                    TextFormField(
                      controller: _compCtrl,
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                      decoration: _buildInputDecoration("Company name (optional)"),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("AMOUNT (\$) *"),
                              TextFormField(
                                controller: _amtCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(fontSize: 13.sp),
                                decoration: _buildInputDecoration("0.00"),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return "Required";
                                  if (double.tryParse(value.trim()) == null) return "Invalid";
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("DATE REFERRED"),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextWidget(
                                        text: _getFormattedDate(_selectedDate),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      Icon(Icons.calendar_today_outlined, size: 14.sp, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildFieldLabel("STATUS"),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black),
                      decoration: _buildInputDecoration("Select status"),
                      items: ['Converted', 'Pending', 'Lost'].map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s, style: GoogleFonts.poppins(fontSize: 13.sp)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("COMMISSION STATUS"),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCommission,
                                style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black),
                                decoration: _buildInputDecoration("Select status"),
                                items: ['Paid', 'Waiting for Payment', 'Not Yet'].map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: GoogleFonts.poppins(fontSize: 13.sp)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCommission = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("INVOICE NUMBER"),
                              TextFormField(
                                controller: _invoiceCtrl,
                                style: GoogleFonts.poppins(fontSize: 13.sp),
                                decoration: _buildInputDecoration("e.g. INV-20260428"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildFieldLabel("NOTES"),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: GoogleFonts.poppins(fontSize: 13.sp),
                      decoration: _buildInputDecoration("Optional notes..."),
                    ),
                    SizedBox(height: 20.h),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFACC15),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                final name = _nameCtrl.text.trim();
                                final company = _compCtrl.text.trim().isEmpty ? '—' : _compCtrl.text.trim();
                                final amt = double.tryParse(_amtCtrl.text.trim()) ?? 0.0;
                                final invoice = _invoiceCtrl.text.trim().isEmpty ? '—' : _invoiceCtrl.text.trim();
                                final notes = _notesCtrl.text.trim().isEmpty ? '—' : _notesCtrl.text.trim();

                                final savedReferral = Referral(
                                  id: widget.referral?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                  date: _getFormattedMonthNameDate(_selectedDate),
                                  fullName: name,
                                  company: company,
                                  amount: amt,
                                  status: _selectedStatus,
                                  commission: _selectedCommission,
                                  invoice: invoice,
                                  notes: notes,
                                );
                                widget.onSave(savedReferral);
                                Navigator.pop(context);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 14.sp, color: Colors.black),
                                SizedBox(width: 4.w),
                                TextWidget(
                                  text: "Save Referral",
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: TextWidget(
                              text: "Cancel",
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
