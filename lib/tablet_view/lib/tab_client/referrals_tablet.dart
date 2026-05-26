import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/tablet_view/lib/tab_client/add_referral_dialog.dart';
import 'package:print_helper/constants/paths.dart';
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
    return _referrals
        .where((e) => e.status == 'Converted' && e.amount > 0)
        .length;
  }

  double get _totalValue {
    return _referrals
        .where(
          (e) =>
              e.status == 'Converted' &&
              (e.commission == 'Paid' || e.commission == 'Waiting for Payment'),
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _pendingCredits {
    return _referrals
        .where((e) => e.status == 'Pending')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  void _showAddEditReferralDialog([Referral? referral]) {
    showDialog(
      context: context,
      builder: (context) => AddReferralDialog(
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
        content: Text(
          "Commission approved for ${referral.fullName}",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
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
              setState(() {
                _referrals.removeWhere((e) => e.id == referral.id);
              });
              Navigator.pop(ctx);
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
                  ..._referrals.map((ref) {
                    // Amount colors
                    Color amtColor = const Color(
                      0xFF10B981,
                    ); // Converted -> Green
                    if (ref.status == 'Pending') {
                      amtColor = const Color(
                        0xFFF59E0B,
                      ); // Pending -> Orange/Gold
                    } else if (ref.status == 'Lost') {
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
                        _buildTableCell(ref.date, color: Colors.grey.shade600),
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
                        // Commission Badge & Approve
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCommissionBadge(ref.commission),
                                if (ref.status == 'Converted' &&
                                    ref.commission == 'Not Yet') ...[
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _handleApproveCommission(ref),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            "Approve",
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Invoice
                        _buildTableCell(
                          ref.invoice,
                          color: ref.invoice == '—'
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
                                  onTap: () => _showAddEditReferralDialog(ref),
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
                  }),
                ],
              ),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                "End of referrals list",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        commission,
        style: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
