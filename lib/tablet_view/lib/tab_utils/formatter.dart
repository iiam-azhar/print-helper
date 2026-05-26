import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tab_constants/strings.dart';

class Frmtr {
  Frmtr(String createdAt);

  static dynamic frmtDate({
    String date = '',
    DateTime? dateTime,
    String? inForm,
    String outForm = 'dd-MMM-yyyy',
    bool asDateTime = false,
    String locale = AppStrings.enLoc,
  }) {
    DateTime parsedDate;

    if (dateTime != null) {
      parsedDate = dateTime.toLocal();
    } else if (date.isNotEmpty) {
      parsedDate = inForm != null
          ? DateFormat(inForm, locale).parse(date)
          : DateTime.parse(date).toLocal(); // Auto-detect format
    } else {
      throw ArgumentError('Either date or dateTime must be provided');
    }

    final formattedDate = DateFormat(outForm, locale).format(parsedDate);
    return asDateTime ? parsedDate : formattedDate;
  }

  static String frmtCurrency(double amount, {bool isPrefix = true}) {
    // final formatter = NumberFormat.currency(locale: 'en_AU', symbol: '\$');
    // return formatter.format(amount);

    // final formatter = NumberFormat.currency(locale: 'ar_QA', symbol: 'QAR');
    // return '${formatter.format(amount)} \$';

    final formatter = NumberFormat.currency(locale: 'ar_QA', symbol: '');
    final amt = formatter.format(amount).trim();

    if (isPrefix) {
      return '${AppStrings.currCode} $amt';
    } else {
      return amt;
    }
  }
}

String formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return "";
  try {
    final dt = DateTime.parse(raw).toLocal();
    final date =
        "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$date\n$hour:$minute$ampm";
  } catch (e) {
    debugPrint("formatDateTime ERROR: $e");
    return "";
  }
}

String frmtDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return "";
  try {
    final dt = DateTime.parse(raw).toLocal();
    final date =
        "${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}";
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return "$date - $hour:$minute$ampm";
  } catch (e) {
    debugPrint("formatDateTime ERROR: $e");
    return "";
  }
}

class UsPhoneTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow deletion naturally
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return oldValue;

    final formatted = _format(digits);

    // Cursor fix: count digits before cursor
    final digitCursorIndex = _countDigitsBeforeCursor(
      newValue.text,
      newValue.selection.end,
    );

    final newCursorPosition = _mapDigitIndexToFormattedIndex(
      digits,
      digitCursorIndex,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';

    if (digits.length <= 3) {
      return '($digits';
    } else if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '(${digits.substring(0, 3)}) '
          '${digits.substring(3, 6)}-${digits.substring(6)}';
    }
  }

  int _countDigitsBeforeCursor(String text, int cursor) {
    return RegExp(r'\d').allMatches(text.substring(0, cursor)).length;
  }

  int _mapDigitIndexToFormattedIndex(String digits, int digitIndex) {
    if (digitIndex <= 0) return 0;

    int index = 0;
    int digitCount = 0;

    final formatted = _format(digits);

    while (index < formatted.length) {
      if (RegExp(r'\d').hasMatch(formatted[index])) {
        digitCount++;
        if (digitCount == digitIndex) {
          return index + 1;
        }
      }
      index++;
    }

    return formatted.length;
  }
}

class InternationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    String digits = text.replaceAll(RegExp(r'\D'), '');

    // Limit to 15 digits max
    if (digits.length > 15) {
      digits = digits.substring(0, 15);
    }

    // Format as: +({cc}) ({area}) {exchange}-{line}
    // For example: +(453) (454) 354-5444
    if (digits.isEmpty) {
      return TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    String formatted = '+';

    // Add country code (1-3 digits) in brackets
    if (digits.length <= 3) {
      formatted += '($digits';
    } else if (digits.length <= 5) {
      formatted += '(${digits.substring(0, 3)}) (${digits.substring(3)}';
    } else if (digits.length <= 8) {
      formatted +=
          '(${digits.substring(0, 3)}) (${digits.substring(3, 5)}) ${digits.substring(5)}';
    } else {
      formatted +=
          '(${digits.substring(0, 3)}) (${digits.substring(3, 5)}) ${digits.substring(5, 8)}-${digits.substring(8)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
