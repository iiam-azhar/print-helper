import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class DiscountsCreditsTablet extends StatefulWidget {
  const DiscountsCreditsTablet({super.key});

  @override
  State<DiscountsCreditsTablet> createState() => _DiscountsCreditsTabletState();
}

class _DiscountsCreditsTabletState extends State<DiscountsCreditsTablet> {
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
          SnackBar(
            content: Text(
              "Please enter a non-zero amount",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Available Credit Balance Banner
          _buildBalanceBanner(),
          const SizedBox(height: 16),

          // 2. Add Credit Form Card (Side-by-side inputs on Tablet)
          _buildAddCreditFormCard(),
          const SizedBox(height: 16),

          // 3. Credit History Card
          _buildCreditHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Dark grey/black
        borderRadius: BorderRadius.circular(8),
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
                Text(
                  "AVAILABLE CREDIT BALANCE",
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "\$${_availableBalance.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFACC15), // Yellow
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _availableBalance > 0
                      ? "Pending credits will auto-apply on next invoice"
                      : "No pending credits — auto-applies on next invoice",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.savings,
            color: Color(0xFFCA8A04), // Gold piggy bank
            size: 32,
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
        borderRadius: BorderRadius.circular(8),
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
          Container(height: 3, color: const Color(0xFFFACC15)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ADD CREDIT / DISCOUNT",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Side-by-side Inputs on Tablet
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel("AMOUNT (\$)"),
                            TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText: "0.00",
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade400,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFACC15),
                                  ),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Reason / Description
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel("REASON / DESCRIPTION"),
                            TextFormField(
                              controller: _descriptionController,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    "e.g. Referral discount — referred FastPrint LA",
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade400,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFACC15),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Required";
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Add Credit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _handleAddCredit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 14, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          "Add Credit",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
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
        borderRadius: BorderRadius.circular(8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CREDIT HISTORY",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: context.watch<ClientPro>().clientBillingTabsLoad
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
              ],
            ),
          ),

          // Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2), // Date
              1: FlexColumnWidth(4), // Description
              2: FlexColumnWidth(2), // Amount
              3: FlexColumnWidth(2.5), // Applied To
              4: FlexColumnWidth(2), // Added By
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  color: Colors.grey.shade50,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                ),
                children: [
                  _buildTableHeaderCell("DATE"),
                  _buildTableHeaderCell("DESCRIPTION"),
                  _buildTableHeaderCell("AMOUNT"),
                  _buildTableHeaderCell("APPLIED TO"),
                  _buildTableHeaderCell("ADDED BY"),
                ],
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
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                      ),
                    ),
                    children: [
                      _buildTableCell(_formatDate(entry.createdAt)),
                      _buildTableCell(entry.reason, isBold: false),
                      TableCell(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Text(
                            entry.amount < 0
                                ? "-\$${entry.amount.abs().toStringAsFixed(2)}"
                                : "\$${entry.amount.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: entry.amount < 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                      _buildTableCell(
                        entry.appliedTo,
                        color: Colors.grey.shade600,
                      ),
                      _buildTableCell(
                        entry.addedBy,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  );
                });
              })(),
            ],
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
