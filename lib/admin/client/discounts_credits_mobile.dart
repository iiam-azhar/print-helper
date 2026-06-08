import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/models/client_billing_tabs_model.dart';

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
  final List<ClientBillingCreditHistoryModel> _localAddedCredits = [];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  double get _availableBalance {
    final discounts = context.watch<ClientPro>().currentClientBillingTabs?.discountsCredits;
    double apiBalance = 0.0;
    if (discounts?.summary != null) {
      final val = discounts!.summary['available_credit_balance'] ?? discounts.summary['availableCreditBalance'];
      if (val != null) {
        apiBalance = double.tryParse(val.toString()) ?? 0.0;
      }
    }
    final localPending = _localAddedCredits
        .where((e) => e.appliedTo.toLowerCase() == 'pending')
        .fold(0.0, (sum, item) => sum + item.amount);
    return apiBalance + localPending;
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return dateStr;
    }
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

      if (amt == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TextWidget(
              text: "Please enter a non-zero amount",
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Unfocus immediately when clicking add
      FocusManager.instance.primaryFocus?.unfocus();

      final clientPro = context.read<ClientPro>();
      final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
      if (clientId == 0) return;
      final currentWeek = clientPro.currentClientBillingTabs?.week.start ?? '';

      clientPro.addCredit(clientId: clientId, amount: amt, reason: desc).then((
        success,
      ) {
        if (success) {
          _amountController.clear();
          _descriptionController.clear();
          FocusManager.instance.primaryFocus?.unfocus();
          clientPro.getClientBillingTabs(
            clientId,
            currentWeek,
            showLoading: false,
          );
        }
      });
    }
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
          Container(height: 3.h, color: const Color(0xFFFACC15)),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "0.00",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
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
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          "e.g. Referral discount — referred FastPrint LA",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 12.h,
                      ),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: "CREDIT HISTORY",
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
                GestureDetector(
                  onTap: () {
                    final clientPro = context.read<ClientPro>();
                    final clientId =
                        clientPro.currentClientBillingTabs?.client.id ?? 0;
                    final currentWeek =
                        clientPro.currentClientBillingTabs?.week.start ?? '';
                    if (clientId != 0 && currentWeek.isNotEmpty) {
                      clientPro.getClientBillingTabs(clientId, currentWeek);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: context.watch<ClientPro>().clientBillingTabsLoad
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 16.sp,
                            color: Colors.black,
                          ),
                  ),
                ),
              ],
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
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 16.w,
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _buildTableHeader("DATE")),
                        Expanded(
                          flex: 4,
                          child: _buildTableHeader("DESCRIPTION"),
                        ),
                        Expanded(flex: 2, child: _buildTableHeader("AMOUNT")),
                        Expanded(
                          flex: 3,
                          child: _buildTableHeader("APPLIED TO"),
                        ),
                        Expanded(flex: 2, child: _buildTableHeader("ADDED BY")),
                      ],
                    ),
                  ),

                  // Data Rows
                  ...(() {
                    final apiCredits =
                        context
                            .watch<ClientPro>()
                            .currentClientBillingTabs
                            ?.discountsCredits
                            .items ??
                        [];

                    return apiCredits.map((entry) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFF3F4F6),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextWidget(
                                text: _formatDate(entry.createdAt),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: TextWidget(
                                text: entry.reason,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextWidget(
                                text: entry.amount < 0
                                    ? "-\$${entry.amount.abs().toStringAsFixed(2)}"
                                    : "\$${entry.amount.toStringAsFixed(2)}",
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: entry.amount < 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextWidget(
                                text: entry.appliedTo,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade600,
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
                    });
                  })(),
                ],
              ),
            ),
          ),

          // Pagination
          ...(() {
            final discounts =
                context
                    .watch<ClientPro>()
                    .currentClientBillingTabs
                    ?.discountsCredits;
            final pagination = discounts?.pagination ?? {};
            final activePage = pagination['current_page'] ?? 1;
            final totalPages = pagination['last_page'] ?? 1;

            if (totalPages > 1) {
              return [
                _buildPagination(
                  currentPage: activePage,
                  totalPages: totalPages,
                  onPageChanged: (page) {
                    final clientPro = context.read<ClientPro>();
                    final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
                    final currentWeek = clientPro.currentClientBillingTabs?.week.start ?? '';
                    if (clientId != 0) {
                      clientPro.getClientBillingTabs(
                        clientId,
                        currentWeek,
                        creditsPage: page,
                      );
                    }
                  },
                ),
                SizedBox(height: 12.h),
              ];
            }
            return const <Widget>[];
          })(),
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

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    List<int> pages = [];
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1); // ellipsis
      int start = (currentPage - 1).clamp(2, totalPages - 2);
      int end = (currentPage + 1).clamp(2, totalPages - 1);
      for (int i = start; i <= end; i++) {
        pages.add(i);
      }
      if (currentPage < totalPages - 2) pages.add(-1); // ellipsis
      pages.add(totalPages);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pageCircle(
                icon: Icons.keyboard_double_arrow_left,
                enabled: currentPage > 1,
                onTap: () => onPageChanged(1),
              ),
              _pageCircle(
                icon: Icons.chevron_left,
                enabled: currentPage > 1,
                onTap: () => onPageChanged(currentPage - 1),
              ),
              SizedBox(width: 4.w),
              ...pages.map((p) {
                if (p == -1) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    child: TextWidget(
                      text: "...",
                      fontSize: 14.sp,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey,
                    ),
                  );
                }
                final bool isActive = p == currentPage;
                return GestureDetector(
                  onTap: () => onPageChanged(p),
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFFACC15) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: TextWidget(
                        text: "$p",
                        fontSize: 11.sp,
                        color: isActive ? Colors.black : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(width: 4.w),
              _pageCircle(
                icon: Icons.chevron_right,
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(currentPage + 1),
              ),
              _pageCircle(
                icon: Icons.keyboard_double_arrow_right,
                enabled: currentPage < totalPages,
                onTap: () => onPageChanged(totalPages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageCircle({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28.w,
        height: 28.w,
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 14.sp,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }
}
