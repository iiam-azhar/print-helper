import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/widgets/text_widget.dart';

class CreditEntry {
  final String date;
  final String description;
  final double amount;
  final String appliedTo;
  final String addedBy;

  CreditEntry({
    required this.date,
    required this.description,
    required this.amount,
    required this.appliedTo,
    required this.addedBy,
  });
}

class DiscountsCreditsMobile extends StatefulWidget {
  const DiscountsCreditsMobile({super.key});

  @override
  State<DiscountsCreditsMobile> createState() => _DiscountsCreditsMobileState();
}

class _DiscountsCreditsMobileState extends State<DiscountsCreditsMobile> {
  final List<CreditEntry> _credits = [
    CreditEntry(
      date: "Apr 14, 2026",
      description: "Referral discount — referred FastPrint LA",
      amount: 200.00,
      appliedTo: "Apr 14–20 invoice",
      addedBy: "Jesús M.",
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  double get _availableBalance {
    return _credits
        .where((e) => e.appliedTo.toLowerCase() == 'pending')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleAddCredit() {
    if (_formKey.currentState!.validate()) {
      final amtStr = _amountController.text.trim();
      final desc = _descriptionController.text.trim();
      final amt = double.tryParse(amtStr) ?? 0.0;

      if (amt <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TextWidget(
              text: "Please enter an amount greater than 0",
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _credits.insert(
          0,
          CreditEntry(
            date: _getFormattedToday(),
            description: desc,
            amount: amt,
            appliedTo: "Pending",
            addedBy: "Admin",
          ),
        );
      });

      _amountController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TextWidget(
            text: "Credit/Discount added successfully",
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getFormattedToday() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${months[now.month - 1]} ${now.day}, ${now.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Available Credit Balance Banner
          _buildBalanceBanner(),
          SizedBox(height: 16.h),

          // 2. Add Credit Form Card
          _buildAddCreditFormCard(),
          SizedBox(height: 16.h),

          // 3. Credit History Card
          _buildCreditHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Dark grey/black
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: "AVAILABLE CREDIT BALANCE",
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 0.5,
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: "\$${_availableBalance.toStringAsFixed(2)}",
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFACC15), // Yellow
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: _availableBalance > 0 
                      ? "Pending credits will auto-apply on next invoice"
                      : "No pending credits — auto-applies on next invoice",
                  fontSize: 11.sp,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
          Icon(
            Icons.savings,
            color: const Color(0xFFCA8A04), // Gold piggy bank
            size: 36.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCreditFormCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3.h,
            color: const Color(0xFFFACC15),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: "ADD CREDIT / DISCOUNT",
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                  SizedBox(height: 16.h),
                  
                  // Amount Input Field
                  _buildInputLabel("AMOUNT (\$)"),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "0.00",
                      hintStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey.shade400),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFFACC15)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Required";
                      }
                      if (double.tryParse(value.trim()) == null) {
                        return "Invalid amount";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),

                  // Reason/Description Input Field
                  _buildInputLabel("REASON / DESCRIPTION"),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "e.g. Referral discount — referred FastPrint LA",
                      hintStyle: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey.shade400),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.r),
                        borderSide: const BorderSide(color: Color(0xFFFACC15)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Required";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Add Credit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15), // Yellow
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
                    ),
                    onPressed: _handleAddCredit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14.sp, color: Colors.black),
                        SizedBox(width: 4.w),
                        TextWidget(
                          text: "Add Credit",
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.poppins(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
          children: const [
            TextSpan(
              text: " *",
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditHistoryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextWidget(
              text: "CREDIT HISTORY",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 650.w,
              child: Column(
                children: [
                  // Table Header Row
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _buildTableHeader("DATE")),
                        Expanded(flex: 4, child: _buildTableHeader("DESCRIPTION")),
                        Expanded(flex: 2, child: _buildTableHeader("AMOUNT")),
                        Expanded(flex: 3, child: _buildTableHeader("APPLIED TO")),
                        Expanded(flex: 2, child: _buildTableHeader("ADDED BY")),
                      ],
                    ),
                  ),

                  // Data Rows
                  ...List.generate(_credits.length, (index) {
                    final entry = _credits[index];
                    final isPending = entry.appliedTo.toLowerCase() == 'pending';
                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextWidget(
                              text: entry.date,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: TextWidget(
                              text: entry.description,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextWidget(
                              text: "\$${entry.amount.toStringAsFixed(2)}",
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981), // Green
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: isPending 
                                      ? const Color(0xFFFEF9C3) // Light yellow
                                      : const Color(0xFFDCFCE7), // Light green
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: TextWidget(
                                  text: entry.appliedTo,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isPending 
                                      ? const Color(0xFF854D0E) // Dark yellow/gold
                                      : const Color(0xFF15803D), // Dark green
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextWidget(
                              text: entry.addedBy,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // "No other credits on record" label
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: const Center(
              child: TextWidget(
                text: "No other credits on record",
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TextWidget(
      text: text,
      fontSize: 10.sp,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade500,
    );
  }
}
