import 'dart:io';

import 'package:flutter/widgets.dart';

import '../constants/paths.dart';
import 'accounts_models.dart';

class ContactFormModel {
  int? id;
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  List<TextEditingController> emails = [TextEditingController()];
  List<PhoneField> phoneFields = [
    PhoneField(
      type: PhoneType("Phone", Paths.call, "mobile"),
      controller: TextEditingController(),
    ),
  ];
  List<int> selectedLanguageIds = [];
  bool showLanguageDropdown = false;
  bool obscurePass = true;
  bool obscureConfirm = true;
  String? selectedLanguageName;
  File? image;
  int? existingId;
  String? imageUrl;
  String? existingImageUrl;
}
