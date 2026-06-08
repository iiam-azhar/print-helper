import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DialogAddEntry extends StatefulWidget {
  final Function(Map<String, dynamic> entryData) onSave;

  const DialogAddEntry({
    super.key,
    required this.onSave,
  });

  @override
  State<DialogAddEntry> createState() => _DialogAddEntryState();
}

class _DialogAddEntryState extends State<DialogAddEntry> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late String _selectedType;
  final _dateCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  final _jobsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedType = 'Wholesale';
    _dateCtrl.text = _formatDate(_selectedDate);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _orderCtrl.dispose();
    _jobsCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year;
    return "$month/$day/$year";
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
              primary: Color(0xFF22C55E), // matching the primary green
              onPrimary: Colors.white,
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
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: RichText(
        text: TextSpan(
          text: label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B), // Dark slate
            letterSpacing: 0.5,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: Colors.grey.shade400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      suffixIcon: suffixIcon,
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Add Entry",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Add jobs processed in Printobi today. Order # is optional; add one or more Job # values.",
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        _buildFieldLabel("Date"),
                        TextFormField(
                          controller: _dateCtrl,
                          readOnly: true,
                          onTap: _selectDate,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
                          decoration: _buildInputDecoration("Select date"),
                        ),

                        _buildFieldLabel("Type"),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedType,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
                          decoration: _buildInputDecoration("Select type"),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                          items: const ['Wholesale', 'Retail'].map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t, style: GoogleFonts.poppins(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedType = val;
                              });
                            }
                          },
                        ),

                        _buildFieldLabel("Order #"),
                        TextFormField(
                          controller: _orderCtrl,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
                          decoration: _buildInputDecoration("e.g. #1005"),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Order # is required";
                            }
                            return null;
                          },
                        ),

                        _buildFieldLabel("Job # List"),
                        TextFormField(
                          controller: _jobsCtrl,
                          maxLines: 4,
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black, height: 1.4),
                          decoration: _buildInputDecoration(
                            "One job per line or comma-separated\ne.g. J-225\nJ-226",
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Job # list is required";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Each Job # creates one row. If Order # is filled, all rows use that order.",
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Separator and Footer
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E), // Premium emerald green
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final rawJobs = _jobsCtrl.text.trim();
                            final List<String> jobList = rawJobs
                                .split(RegExp(r'[\n,]+'))
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            widget.onSave({
                              'date': '${_selectedDate.year}-${_selectedDate.month.padZero}-${_selectedDate.day.padZero}',
                              'pricing_mode': _selectedType,
                              'orderNo': _orderCtrl.text.trim(),
                              'jobNos': jobList,
                            });
                            Navigator.pop(context);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              "Add Entry",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on int {
  String get padZero => toString().padLeft(2, '0');
}
