import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/strings.dart';
import 'console_util.dart';

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
    printData(title: "formatDateTime ERROR:", data: e, e: true);
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
    printData(title: "formatDateTime ERROR:", data: e, e: true);
    return "";
  }
}

Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

String formatChatDate(DateTime date) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(date, now)) {
    return DateFormat('hh:mm a').format(date);
  }
  return DateFormat('dd MMM yyyy').format(date);
}

class UsPhoneTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    String formatted = '';

    if (digits.isNotEmpty) {
      formatted = '(';
      if (digits.length >= 3) {
        formatted += '${digits.substring(0, 3)}) ';
        if (digits.length >= 6) {
          formatted += '${digits.substring(3, 6)}-';
          formatted += digits.substring(6);
        } else {
          formatted += digits.substring(3);
        }
      } else {
        formatted += digits;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class InternationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Allow leading +
    if (text.startsWith('+')) {
      String digits = text.substring(1).replaceAll(RegExp(r'\D'), '');
      if (digits.length > 14) {
        digits = digits.substring(0, 14);
      }
      text = '+$digits';
    } else {
      text = text.replaceAll(RegExp(r'\D'), '');
      if (text.length > 15) {
        text = text.substring(0, 15);
      }
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
