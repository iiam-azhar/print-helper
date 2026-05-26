import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/tablet_view/lib/tab_client/referrals_tablet.dart';

class AddReferralDialog extends StatefulWidget {
  final Referral? referral;
  final Function(Referral) onSave;

  const AddReferralDialog({
    super.key,
    this.referral,
    required this.onSave,
  });

  @override
  State<AddReferralDialog> createState() => _AddReferralDialogState();
}

class _AddReferralDialogState extends State<AddReferralDialog> {
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
    
    if (ref != null) {
      _selectedDate = _parseDateString(ref.date);
    } else {
      _selectedDate = DateTime.now();
    }
  }

  DateTime _parseDateString(String dateStr) {
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
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B), // Slate-500
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFACC15), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Black Header
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.referral != null ? "Edit Referral" : "Add New Referral",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel("FULL NAME *"),
                    TextFormField(
                      controller: _nameCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _buildInputDecoration("First and last name"),
                      validator: (value) => value == null || value.trim().isEmpty ? "Full name is required" : null,
                    ),

                    _buildFieldLabel("COMPANY"),
                    TextFormField(
                      controller: _compCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _buildInputDecoration("Company name (optional)"),
                    ),

                    // Amount & Date Referred
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
                                style: GoogleFonts.poppins(fontSize: 14),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("DATE REFERRED"),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _getFormattedDate(_selectedDate),
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
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
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                      decoration: _buildInputDecoration("Select status"),
                      items: ['Converted', 'Pending', 'Lost'].map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s, style: GoogleFonts.poppins(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),

                    // Commission Status & Invoice
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("COMMISSION STATUS"),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCommission,
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                                decoration: _buildInputDecoration("Select status"),
                                items: ['Paid', 'Waiting for Payment', 'Not Yet'].map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: GoogleFonts.poppins(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCommission = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel("INVOICE NUMBER"),
                              TextFormField(
                                controller: _invoiceCtrl,
                                style: GoogleFonts.poppins(fontSize: 14),
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
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _buildInputDecoration("Optional notes..."),
                    ),
                    const SizedBox(height: 24),

                    // Bottom Buttons
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFACC15),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 16, color: Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                "Save Referral",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
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
          ],
        ),
      ),
    );
  }
}
