import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/tablet_view/lib/tab_client/add_referral_dialog.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import '../tab_widgets/tab_image_widget.dart';

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

class ReferralsTablet extends StatefulWidget {
  const ReferralsTablet({super.key});

  @override
  State<ReferralsTablet> createState() => _ReferralsTabletState();
}

class _ReferralsTabletState extends State<ReferralsTablet> {
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
    showDialog(
      context: context,
      builder: (context) => AddReferralDialog(
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
        title: Text(
          "Delete Referral",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete the referral for ${referral.fullName}?",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
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
            child: Text(
              "Delete",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ClientPro>().clientBillingTabsLoad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                "TOTAL REFERRALS",
                "$_totalReferralsCount",
                "All time",
                const Color(0xFFFACC15),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                "TOTAL VALUE",
                "\$${_totalValue.toStringAsFixed(0)}",
                "Credits earned",
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                "PENDING CREDITS",
                "\$${_pendingCredits.toStringAsFixed(0)}",
                "Not yet applied",
                const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Referral History Header & Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Referral History",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.black,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFACC15),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => _showAddEditReferralDialog(),
                  icon: const Icon(Icons.add, size: 14, color: Colors.black),
                  label: Text(
                    "Add New Referral",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHistoryTableCard(),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    Color accentColor,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(height: 3, color: accentColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
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
        borderRadius: BorderRadius.circular(12),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1120,
              child: Table(
                columnWidths: const {
                  0: FixedColumnWidth(90), // Date
                  1: FixedColumnWidth(125), // Full Name
                  2: FixedColumnWidth(125), // Company
                  3: FixedColumnWidth(80), // Amount
                  4: FixedColumnWidth(100), // Status
                  5: FixedColumnWidth(150), // Commission
                  6: FixedColumnWidth(120), // Invoice
                  7: FixedColumnWidth(140), // Notes
                  8: FixedColumnWidth(90), // Actions
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: Colors.grey.shade50,
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                    ),
                    children: [
                      _buildTableHeaderCell("DATE"),
                      _buildTableHeaderCell("FULL NAME"),
                      _buildTableHeaderCell("COMPANY"),
                      _buildTableHeaderCell("AMOUNT"),
                      _buildTableHeaderCell("STATUS"),
                      _buildTableHeaderCell("COMMISSION"),
                      _buildTableHeaderCell("INVOICE"),
                      _buildTableHeaderCell("NOTES"),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "ACTIONS",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Data Rows
                  ...(() {
                    final allItems = _referrals;
                    return allItems.map((ref) {
                      // Amount colors
                      Color amtColor = const Color(
                        0xFF10B981,
                      ); // Converted -> Green
                      if (ref.status.toLowerCase().contains('pending')) {
                        amtColor = const Color(
                          0xFFF59E0B,
                        ); // Pending -> Orange/Gold
                      } else if (ref.status.toLowerCase().contains('lost')) {
                        amtColor = const Color(0xFFEF4444); // Lost -> Red
                      }

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFFF3F4F6),
                              width: 1,
                            ),
                          ),
                        ),
                        children: [
                          // Date
                          _buildTableCell(
                            ref.date,
                            color: Colors.grey.shade600,
                          ),
                          // Full Name
                          _buildTableCell(ref.fullName, isBold: true),
                          // Company
                          _buildTableCell(
                            ref.company,
                            color: ref.company == '—'
                                ? Colors.grey.shade400
                                : Colors.black87,
                          ),
                          // Amount
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                "\$${ref.amount.toStringAsFixed(2)}",
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: amtColor,
                                ),
                              ),
                            ),
                          ),
                          // Status Badge
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusBadge(ref.status),
                              ),
                            ),
                          ),
                          // Commission Badge
                          TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: 1.0,
                                child: _buildCommissionBadge(ref.commission),
                              ),
                            ),
                          ),
                          // Invoice
                          _buildTableCell(
                            ref.invoice,
                            color: ref.invoice == '—' || ref.invoice == '-'
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                          // Notes
                          _buildTableCell(
                            ref.notes,
                            color: ref.notes == '—'
                                ? Colors.grey.shade400
                                : Colors.black87,
                          ),
                          // Actions
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        _showAddEditReferralDialog(ref),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: ImageWidget(
                                        image: Paths.edit,
                                        width: 16,
                                        height: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    onTap: () => _handleDeleteReferral(ref),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: ImageWidget(
                                        image: Paths.delete,
                                        width: 16,
                                        height: 16,
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    });
                  })(),
                ],
              ),
            ),
          ),

          // Pagination
          ...(() {
            final myReferrals = context.watch<ClientPro>().currentClientBillingTabs?.myReferrals;
            final pagination = myReferrals?.pagination ?? {};
            final totalPages = pagination['last_page'] ?? 1;
            final activePage = pagination['current_page'] ?? 1;

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
                        referralsPage: page,
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ];
            }
            return const <Widget>[];
          })(),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        softWrap: true,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    List<int> pages = [];
    if (totalPages <= 7) {
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            const SizedBox(width: 8),
            ...pages.map((p) {
              if (p == -1) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    "...",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }
              final bool isActive = p == currentPage;
              return GestureDetector(
                onTap: () => onPageChanged(p),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFFACC15) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: Text(
                      "$p",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isActive ? Colors.black : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
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
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }
}
