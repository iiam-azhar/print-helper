import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          SnackBar(
            content: Text(
              "Please enter an amount greater than 0",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
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
        SnackBar(
          content: Text(
            "Credit/Discount added successfully",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
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
          Container(
            height: 3,
            color: const Color(0xFFFACC15),
          ),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "0.00",
                                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
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
                              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black),
                              decoration: InputDecoration(
                                hintText: "e.g. Referral discount — referred FastPrint LA",
                                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade400),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            child: Text(
              "CREDIT HISTORY",
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
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
              ..._credits.map((entry) {
                final isPending = entry.appliedTo.toLowerCase() == 'pending';
                return TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                    ),
                  ),
                  children: [
                    _buildTableCell(entry.date),
                    _buildTableCell(entry.description, isBold: false),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Text(
                          "\$${entry.amount.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? const Color(0xFFFEF9C3)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.appliedTo,
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isPending
                                    ? const Color(0xFF854D0E)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildTableCell(entry.addedBy, color: Colors.grey.shade600),
                  ],
                );
              }),
            ],
          ),

          // Legend / Centered text
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                "No other credits on record",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
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
}
