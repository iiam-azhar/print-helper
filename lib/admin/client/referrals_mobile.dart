import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/admin/client/add_referral_bottomsheet.dart';

class Referral {
  final String id;
  final String date;
  final String fullName;
  final String company;
  final double amount;
  final String status; // Converted, Pending, Lost
  final String commission; // Paid, Waiting for Payment, Not Yet
  final String invoice;
  final String notes;

  Referral({
    required this.id,
    required this.date,
    required this.fullName,
    required this.company,
    required this.amount,
    required this.status,
    required this.commission,
    required this.invoice,
    required this.notes,
  });

  Referral copyWith({
    String? date,
    String? fullName,
    String? company,
    double? amount,
    String? status,
    String? commission,
    String? invoice,
    String? notes,
  }) {
    return Referral(
      id: id,
      date: date ?? this.date,
      fullName: fullName ?? this.fullName,
      company: company ?? this.company,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      commission: commission ?? this.commission,
      invoice: invoice ?? this.invoice,
      notes: notes ?? this.notes,
    );
  }
}

class ReferralsMobile extends StatefulWidget {
  const ReferralsMobile({super.key});

  @override
  State<ReferralsMobile> createState() => _ReferralsMobileState();
}

class _ReferralsMobileState extends State<ReferralsMobile> {
  final List<Referral> _referrals = [
    Referral(
      id: "1",
      date: "Apr 27, 2026",
      fullName: "sss",
      company: "—",
      amount: 0.00,
      status: "Converted",
      commission: "Paid",
      invoice: "—",
      notes: "—",
    ),
    Referral(
      id: "2",
      date: "Apr 14, 2026",
      fullName: "Luis Renteria",
      company: "FastPrint LA",
      amount: 200.00,
      status: "Converted",
      commission: "Paid",
      invoice: "INV-20260428",
      notes: "Long-time friend of Sheen",
    ),
    Referral(
      id: "3",
      date: "Mar 28, 2026",
      fullName: "Pedro Gómez",
      company: "Cali Signs Co.",
      amount: 250.00,
      status: "Pending",
      commission: "Not Yet",
      invoice: "—",
      notes: "In talks, demo scheduled",
    ),
    Referral(
      id: "4",
      date: "Feb 10, 2026",
      fullName: "Ana Torres",
      company: "PrintQuick Inc.",
      amount: 300.00,
      status: "Converted",
      commission: "Waiting for Payment",
      invoice: "INV-20260321",
      notes: "—",
    ),
    Referral(
      id: "5",
      date: "Jan 22, 2026",
      fullName: "Carlos Mendez",
      company: "SignWorks Miami",
      amount: 350.00,
      status: "Converted",
      commission: "Not Yet",
      invoice: "—",
      notes: "Referred by Sheen",
    ),
    Referral(
      id: "6",
      date: "Dec 15, 2025",
      fullName: "Maria Rodriguez",
      company: "Design Studio TX",
      amount: 150.00,
      status: "Lost",
      commission: "Not Yet",
      invoice: "—",
      notes: "Chose competitor",
    ),
  ];

  int get _totalReferralsCount {
    return _referrals.where((e) => e.status == 'Converted' && e.amount > 0).length;
  }

  double get _totalValue {
    return _referrals
        .where((e) => e.status == 'Converted' && (e.commission == 'Paid' || e.commission == 'Waiting for Payment'))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _pendingCredits {
    return _referrals
        .where((e) => e.status == 'Pending')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  void _showAddEditReferralDialog([Referral? referral]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReferralBottomSheet(
        referral: referral,
        onSave: (savedReferral) {
          setState(() {
            if (referral != null) {
              final idx = _referrals.indexWhere((e) => e.id == referral.id);
              if (idx != -1) {
                _referrals[idx] = savedReferral;
              }
            } else {
              _referrals.insert(0, savedReferral);
            }
          });
        },
      ),
    );
  }

  void _handleApproveCommission(Referral referral) {
    setState(() {
      final idx = _referrals.indexWhere((e) => e.id == referral.id);
      if (idx != -1) {
        _referrals[idx] = referral.copyWith(commission: "Paid");
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TextWidget(
          text: "Commission approved for ${referral.fullName}",
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleDeleteReferral(Referral referral) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const TextWidget(text: "Delete Referral", fontSize: 16, fontWeight: FontWeight.bold),
        content: TextWidget(
          text: "Are you sure you want to delete the referral for ${referral.fullName}?",
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: TextWidget(text: "Cancel", fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _referrals.removeWhere((e) => e.id == referral.id);
              });
              Navigator.pop(ctx);
            },
            child: const TextWidget(text: "Delete", fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Summary Cards Horizontal Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSummaryCard("TOTAL REFERRALS", "$_totalReferralsCount", "All time", const Color(0xFFFACC15)),
                SizedBox(width: 12.w),
                _buildSummaryCard("TOTAL VALUE", "\$${_totalValue.toStringAsFixed(0)}", "Credits earned", const Color(0xFF10B981)),
                SizedBox(width: 12.w),
                _buildSummaryCard("PENDING CREDITS", "\$${_pendingCredits.toStringAsFixed(0)}", "Not yet applied", const Color(0xFF3B82F6)),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // 2. Referral History Header & Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget(
                text: "Referral History",
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                ),
                onPressed: () => _showAddEditReferralDialog(),
                icon: Icon(Icons.add, size: 14.sp, color: Colors.black),
                label: TextWidget(
                  text: "Add New Referral",
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // 3. Referral History Table List Card
          _buildHistoryTableCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, Color accentColor) {
    return Container(
      width: 150.w,
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
          Container(height: 3.h, color: accentColor),
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: value,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: subtitle,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTableCard() {
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 920.w,
          child: Column(
            children: [
              // Header Row
              Container(
                color: const Color(0xFFF9FAFB),
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTableHeader("DATE")),
                    Expanded(flex: 4, child: _buildTableHeader("FULL NAME")),
                    Expanded(flex: 4, child: _buildTableHeader("COMPANY")),
                    Expanded(flex: 3, child: _buildTableHeader("AMOUNT")),
                    Expanded(flex: 3, child: _buildTableHeader("STATUS")),
                    Expanded(flex: 5, child: _buildTableHeader("COMMISSION")),
                    Expanded(flex: 4, child: _buildTableHeader("INVOICE")),
                    Expanded(flex: 5, child: _buildTableHeader("NOTES")),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader("ACTIONS"))),
                  ],
                ),
              ),

              // Data Rows
              ...List.generate(_referrals.length, (index) {
                final ref = _referrals[index];
                
                // Colors based on status
                Color amtColor = const Color(0xFF10B981); // Converted -> Green
                if (ref.status == 'Pending') {
                  amtColor = const Color(0xFFF59E0B); // Pending -> Orange/Gold
                } else if (ref.status == 'Lost') {
                  amtColor = const Color(0xFFEF4444); // Lost -> Red
                }

                return Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
                  ),
                  child: Row(
                    children: [
                      // Date
                      Expanded(
                        flex: 3,
                        child: TextWidget(
                          text: ref.date,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      // Full Name
                      Expanded(
                        flex: 4,
                        child: TextWidget(
                          text: ref.fullName,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      // Company
                      Expanded(
                        flex: 4,
                        child: TextWidget(
                          text: ref.company,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.normal,
                          color: ref.company == '—' ? Colors.grey.shade400 : Colors.black87,
                        ),
                      ),
                      // Amount
                      Expanded(
                        flex: 3,
                        child: TextWidget(
                          text: "\$${ref.amount.toStringAsFixed(2)}",
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: amtColor,
                        ),
                      ),
                      // Status
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusBadge(ref.status),
                        ),
                      ),
                      // Commission
                      Expanded(
                        flex: 5,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCommissionBadge(ref.commission),
                            if (ref.status == 'Converted' && ref.commission == 'Not Yet') ...[
                              SizedBox(width: 6.w),
                              GestureDetector(
                                onTap: () => _handleApproveCommission(ref),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check, size: 10.sp, color: Colors.white),
                                      SizedBox(width: 2.w),
                                      TextWidget(
                                        text: "Approve",
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      // Invoice
                      Expanded(
                        flex: 4,
                        child: TextWidget(
                          text: ref.invoice,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.normal,
                          color: ref.invoice == '—' ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      // Notes
                      Expanded(
                        flex: 5,
                        child: TextWidget(
                          text: ref.notes,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.normal,
                          color: ref.notes == '—' ? Colors.grey.shade400 : Colors.black87,
                          maxLines: 1,
                        ),
                      ),
                      // Actions
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 16.sp, color: Colors.grey.shade600),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showAddEditReferralDialog(ref),
                            ),
                            SizedBox(width: 10.w),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 16.sp, color: Colors.red.shade400),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _handleDeleteReferral(ref),
                            ),
                          ],
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

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = Colors.grey.shade600;

    if (status == 'Converted') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'Pending') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFF854D0E);
    } else if (status == 'Lost') {
      bg = const Color(0xFFF3F4F6);
      fg = Colors.grey.shade500;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextWidget(
        text: status,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: fg,
      ),
    );
  }

  Widget _buildCommissionBadge(String commission) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = Colors.grey.shade600;

    if (commission == 'Paid') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (commission == 'Waiting for Payment') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (commission == 'Not Yet') {
      bg = const Color(0xFFF3F4F6);
      fg = Colors.grey.shade500;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextWidget(
        text: commission,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: fg,
      ),
    );
  }
}
