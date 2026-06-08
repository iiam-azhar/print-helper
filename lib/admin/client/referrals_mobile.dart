import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/admin/client/add_referral_bottomsheet.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/widgets/image_widget.dart';

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
  final List<Referral> _localReferrals = [];

  List<Referral> get _referrals {
    final apiItems =
        context
            .watch<ClientPro>()
            .currentClientBillingTabs
            ?.myReferrals
            .items ??
        [];
    final parsedApi = apiItems
        .map((e) {
          if (e is Map) {
            String dateStr = (e['referred_date'] ?? e['date'] ?? '').toString();
            if (dateStr.contains('T')) {
              dateStr = dateStr.split('T')[0];
            }
            String comp = e['company']?.toString() ?? '';
            if (comp.isEmpty || comp.toLowerCase() == 'null') comp = '—';
            String comm = (e['commission_status'] ?? e['commission'])?.toString() ?? '';
            if (comm.isEmpty || comm.toLowerCase() == 'null') comm = 'Not Yet';
            String inv = (e['invoice_number'] ?? e['invoice'])?.toString() ?? '';
            if (inv.isEmpty || inv.toLowerCase() == 'null') inv = '-';
            String nts = e['notes']?.toString() ?? '';
            if (nts.isEmpty || nts.toLowerCase() == 'null') nts = '—';

            return Referral(
              id: e['id']?.toString() ?? '',
              date: dateStr,
              fullName: (e['full_name'] ?? e['fullName'])?.toString() ?? '',
              company: comp,
              amount: double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
              status: e['status']?.toString() ?? 'Pending',
              commission: comm,
              invoice: inv,
              notes: nts,
            );
          }
          return null;
        })
        .whereType<Referral>()
        .toList();

    // Clean up local items that have been synchronized
    _localReferrals.removeWhere(
      (local) => parsedApi.any(
        (api) =>
            (api.id == local.id) ||
            (api.fullName == local.fullName &&
                api.company == local.company &&
                api.amount == local.amount &&
                api.status == local.status),
      ),
    );

    return [..._localReferrals, ...parsedApi];
  }

  int get _totalReferralsCount {
    final summary = context
        .watch<ClientPro>()
        .currentClientBillingTabs
        ?.myReferrals
        .summary;
    if (summary != null) {
      final count = summary['total_count'] ?? summary['totalCount'];
      if (count != null) {
        return int.tryParse(count.toString()) ?? 0;
      }
    }
    return _referrals
        .where(
          (e) => e.status.toLowerCase().contains('converted') && e.amount > 0,
        )
        .length;
  }

  double get _totalValue {
    final summary = context
        .watch<ClientPro>()
        .currentClientBillingTabs
        ?.myReferrals
        .summary;
    if (summary != null) {
      final val = summary['total_value'] ?? summary['totalValue'];
      if (val != null) {
        return double.tryParse(val.toString()) ?? 0.0;
      }
    }
    return _referrals
        .where(
          (e) =>
              e.status.toLowerCase().contains('converted') &&
              (e.commission.toLowerCase() == 'paid' ||
                  e.commission.toLowerCase() == 'waiting for payment'),
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _pendingCredits {
    final summary = context
        .watch<ClientPro>()
        .currentClientBillingTabs
        ?.myReferrals
        .summary;
    if (summary != null) {
      final creds = summary['pending_credits'] ?? summary['pendingCredits'];
      if (creds != null) {
        return double.tryParse(creds.toString()) ?? 0.0;
      }
    }
    return _referrals
        .where((e) => e.status.toLowerCase().contains('pending'))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  void _showAddEditReferralDialog([Referral? referral]) {
    final clientPro = context.read<ClientPro>();
    final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReferralBottomSheet(
        clientId: clientId,
        referral: referral,
        onSave: (savedReferral) {
          setState(() {
            if (referral != null) {
              final idx = _localReferrals.indexWhere(
                (e) => e.id == referral.id,
              );
              if (idx != -1) {
                _localReferrals[idx] = savedReferral;
              } else {
                _localReferrals.add(savedReferral);
              }
            } else {
              _localReferrals.insert(0, savedReferral);
            }
          });
        },
      ),
    );
  }

  void _handleDeleteReferral(Referral referral) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const TextWidget(
          text: "Delete Referral",
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        content: TextWidget(
          text:
              "Are you sure you want to delete the referral for ${referral.fullName}?",
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: TextWidget(
              text: "Cancel",
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Remove locally immediately
              setState(() {
                _localReferrals.removeWhere((e) => e.id == referral.id);
              });
              Navigator.pop(ctx);
              // Fire DELETE API in background
              final clientPro = context.read<ClientPro>();
              final clientId =
                  clientPro.currentClientBillingTabs?.client.id ?? 0;
              clientPro
                  .deleteReferral(clientId: clientId, referralId: referral.id)
                  .then((success) {
                    if (success) {
                      final currentWeek =
                          clientPro.currentClientBillingTabs?.week.start ?? '';
                      clientPro.getClientBillingTabs(
                        clientId,
                        currentWeek,
                        showLoading: false,
                      );
                    }
                  });
            },
            child: const TextWidget(
              text: "Delete",
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
                _buildSummaryCard(
                  "TOTAL REFERRALS",
                  "$_totalReferralsCount",
                  "All time",
                  const Color(0xFFFACC15),
                ),
                SizedBox(width: 12.w),
                _buildSummaryCard(
                  "TOTAL VALUE",
                  "\$${_totalValue.toStringAsFixed(0)}",
                  "Credits earned",
                  const Color(0xFF10B981),
                ),
                SizedBox(width: 12.w),
                _buildSummaryCard(
                  "PENDING CREDITS",
                  "\$${_pendingCredits.toStringAsFixed(0)}",
                  "Not yet applied",
                  const Color(0xFF3B82F6),
                ),
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
              Row(
                children: [
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
                      child: Icon(
                        Icons.refresh,
                        size: 16.sp,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
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
            ],
          ),
          SizedBox(height: 12.h),

          // 3. Referral History Table List Card
          _buildHistoryTableCard(),
          SizedBox(height: 8.h),
          (() {
            final myReferrals = context.watch<ClientPro>().currentClientBillingTabs?.myReferrals;
            final pagination = myReferrals?.pagination ?? {};
            final totalPages = pagination['last_page'] ?? 1;
            final activePage = pagination['current_page'] ?? 1;

            if (totalPages > 1) {
              return _buildPagination(
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
                      referralsPage: page,
                    );
                  }
                },
              );
            }
            return const SizedBox();
          })(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    Color accentColor,
  ) {
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
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: _buildTableHeader("COMMISSION"),
                      ),
                    ),
                    Expanded(flex: 4, child: _buildTableHeader("INVOICE")),
                    Expanded(flex: 5, child: _buildTableHeader("NOTES")),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _buildTableHeader("ACTIONS"),
                      ),
                    ),
                  ],
                ),
              ),

              // Data Rows
              ...List.generate(_referrals.length, (index) {
                final ref = _referrals[index];

                // Colors based on status
                Color amtColor = const Color(0xFF10B981); // Converted -> Green
                if (ref.status.toLowerCase().contains('pending')) {
                  amtColor = const Color(0xFFF59E0B); // Pending -> Orange/Gold
                } else if (ref.status.toLowerCase().contains('lost')) {
                  amtColor = const Color(0xFFEF4444); // Lost -> Red
                }

                return Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 16.w,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                    ),
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
                          color: ref.company == '—'
                              ? Colors.grey.shade400
                              : Colors.black87,
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
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 6.w),
                            child: _buildCommissionBadge(ref.commission),
                          ),
                        ),
                      ),
                      // Invoice
                      Expanded(
                        flex: 4,
                        child: TextWidget(
                          text: ref.invoice,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.normal,
                          color: ref.invoice == '—' || ref.invoice == '-'
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      // Notes
                      Expanded(
                        flex: 5,
                        child: TextWidget(
                          text: ref.notes,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.normal,
                          color: ref.notes == '—'
                              ? Colors.grey.shade400
                              : Colors.black87,
                          maxLines: 1,
                        ),
                      ),
                      // Actions
                      Expanded(
                        flex: 3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _showAddEditReferralDialog(ref),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: ImageWidget(
                                  image: Paths.edit,
                                  width: 14.sp,
                                  height: 14.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: () => _handleDeleteReferral(ref),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.all(4.w),
                                child: ImageWidget(
                                  image: Paths.delete,
                                  width: 14.sp,
                                  height: 14.sp,
                                  color: Colors.red.shade400,
                                ),
                              ),
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

    if (status.toLowerCase().contains('converted')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status.toLowerCase().contains('pending')) {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFF854D0E);
    } else if (status.toLowerCase().contains('lost')) {
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
    String label = commission;

    if (commission.toLowerCase().contains('paid')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Paid';
    } else if (commission.toLowerCase().contains('waiting')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = 'Waiting for Payment';
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = Colors.grey.shade500;
      label = 'Not Yet';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextWidget(
        text: label,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: fg,
      ),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Align(
        alignment: Alignment.centerRight,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                );
              }
              final bool isActive = p == currentPage;
              return GestureDetector(
                onTap: () => onPageChanged(p),
                child: Container(
                  width: 26.w,
                  height: 26.w,
                  margin: EdgeInsets.symmetric(horizontal: 2.w),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFACC15) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: TextWidget(
                      text: "$p",
                      fontSize: 10.sp,
                      color: isActive ? Colors.black : Colors.black87,
                      fontWeight: FontWeight.bold,
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
        width: 26.w,
        height: 26.w,
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
