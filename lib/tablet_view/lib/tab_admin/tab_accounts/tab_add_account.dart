import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../tab_constants/strings.dart';
import '../../tab_utils/console_util.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_utils/regx.dart';
import '../../tab_widgets/tab_custom_button.dart';
import '../../tab_widgets/tab_field_widget.dart';

import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import 'package:print_helper/models/accounts_models.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_toasts.dart';

class AccountAddContent extends StatefulWidget {
  const AccountAddContent({super.key});

  @override
  State<AccountAddContent> createState() => AccountAddContentState();
}

class AccountAddContentState extends State<AccountAddContent> {
  final _formKey = GlobalKey<FormState>();
  File? selectedImage;
  String? userImage;
  bool pickingFile = false;
  int? openPhoneDropdownIndex;
  final formFieldKey = GlobalKey<FormFieldState>();

  // final _firstNameCtrl = TextEditingController();
  // final _lastNameCtrl = TextEditingController();
  // final _usernameCtrl = TextEditingController();
  // final _passwordCtrl = TextEditingController();
  // final _confirmPasswordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  List<PhoneType> phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];
  List<PhoneField> phoneFields = [
    PhoneField(
      type: PhoneType("Phone", Paths.call, "mobile"),
      controller: TextEditingController(),
    ),
  ];
  List<PhoneRow> phones = [PhoneRow()];
  List<TextEditingController> emailCtrls = [TextEditingController()];
  List<int> selectedLanguageIds = [];
  int? _selectedTypeId;
  List<int> selectedSkillIds = [];
  bool showLanguageDropdown = false;
  bool showSkillsDropdown = false;
  List<String> selectedSkills = [];
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final custPro = getAdminPro(context);
      custPro.fetchAllDropdownData(context);
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (var p in phones) {
      p.controller.dispose();
    }
    for (var c in emailCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pickImage() async {
    if (pickingFile) return;
    pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      printData(title: 'pickImage', data: '$e', e: true);
    } finally {
      pickingFile = false;
    }
  }

  void _onSave(dynamic context) async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_passwordCtrl.text.trim() != _confirmPasswordCtrl.text.trim()) {
        showToast(message: "Passwords do not match");
        return;
      }
      final pro = getAdminPro(context);
      List<Map<String, dynamic>> phoneList = phoneFields.map((p) {
        return {"type": p.type.apiValue, "value": p.controller.text.trim()};
      }).toList();
      List<String> emailList = emailCtrls
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      String? imagePath = selectedImage?.path;
      bool success = await pro.storeAccount(
        context: context,
        type: _selectedTypeId ?? 0,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        phones: phoneList,
        emails: emailList,
        languages: selectedLanguageIds,
        skills: selectedSkillIds,
        imagePath: imagePath,
      );
      if (success) {
        Navigator.of(context).pop();
        final parentPro = getAdminPro(context);
        parentPro.getAccounts(ctx: context, page: 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created Successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to create account")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SafeArea(
            top: true,
            child: Column(
              children: [
                _header(context),
                Divider(thickness: 2, color: const Color(0x5F9E9E9E)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Spacers.sb10(),
                          profileImage(),
                          Spacers.sb15(),
                          _formBody(),
                          Spacers.sb25(),
                          scrollUp(context),
                        ],
                      ),
                    ),
                  ),
                ),
                _cancelSaveBtn(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cancelSaveBtn(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Spacers.sbw30(),
          Expanded(
            child: CustomButton(
              height: 40,
              margin: EdgeInsets.symmetric(horizontal: 25),
              textColor: AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              showBorder: true,
              buttonColor: Colors.white,
              stadium: false,
              borderRadius: 18,
              borderWidth: 1,
              title: 'Cancel',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: CustomButton(
              height: 40,
              margin: EdgeInsets.symmetric(horizontal: 25),
              title: 'Save',
              onTap: () {
                _onSave(context);
                debugPrint('tap');
              },
              buttonColor: AppColors.btnClr,
              textColor: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              stadium: false,
              borderRadius: 18,
            ),
          ),
          Spacers.sbw30(),
        ],
      ),
    );
  }

  Widget _formBody() {
    final pro = getAdminPro(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _roundedDropdown(
            parentContext: context,
            label: '*Type of Account',
            value: pro.accountTypes.any((e) => e.id == _selectedTypeId)
                ? pro.accountTypes.firstWhere((e) => e.id == _selectedTypeId)
                : null,
            hint: 'Select',
            items: pro.accountTypes,
            onChanged: (item) {
              setState(() => _selectedTypeId = item?.id);
            },
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _firstNameCtrl,
            label: '*First Name',
            hint: 'Type First Name',
            errorText: AppStrings.fNameError,
            regErrorText: AppStrings.fNameRegError,
            regExpCondition: Regx.nameRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _lastNameCtrl,
            label: '*Last Name',
            hint: 'Type Last Name',
            errorText: AppStrings.lNameError,
            regErrorText: AppStrings.lNameRegError,
            regExpCondition: Regx.nameRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _usernameCtrl,
            label: '*User name',
            hint: 'Type User Name',
            errorText: AppStrings.usrNameError,
            regErrorText: AppStrings.userNmeRegError,
            regExpCondition: Regx.userNameRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _passwordCtrl,
            label: '*Password',
            hint: 'Type Password',
            obscure: !_showPassword,
            isPassword: true,
            showPassword: _showPassword,
            onToggleVisibility: () {
              setState(() => _showPassword = !_showPassword);
            },
            errorText: AppStrings.passError,
            regErrorText: AppStrings.passRegError,
            regExpCondition: Regx.passwordRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _confirmPasswordCtrl,
            label: '*Confirm Password',
            hint: 'Type Confirm Password',
            obscure: !_showConfirmPassword,
            isPassword: true,
            showPassword: _showConfirmPassword,
            onToggleVisibility: () {
              setState(() => _showConfirmPassword = !_showConfirmPassword);
            },
            errorText: AppStrings.passError,
            regErrorText: AppStrings.passRegError,
            regExpCondition: Regx.passwordRegExp,
          ),
          Spacers.sb8(),
          _languageSec(),
          Spacers.sb10(),
          _phoneFieldSec(),
          _emailFieldSec(),
          _skillsSec(),
        ],
      ),
    );
  }

  Widget _emailFieldSec() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 18),
            child: TextWidget(
              text: "Email (s)",
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.black,
            ),
          ),
        ),
        Spacers.sb8(),
        Column(
          children: emailCtrls.asMap().entries.map((entry) {
            final int index = entry.key;
            final TextEditingController ctrl = entry.value;
            bool isLast = index == emailCtrls.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: EmailListTextField(
                      controller: ctrl,
                      onSubmitted: () {
                        if (ctrl.text.trim().isNotEmpty) {
                          setState(
                            () => emailCtrls.add(TextEditingController()),
                          );
                        }
                      },
                    ),
                  ),
                  Spacers.sbw12(),
                  GestureDetector(
                    onTap: () {
                      if (isLast) {
                        setState(() {
                          emailCtrls.add(TextEditingController());
                        });
                      } else {
                        setState(() {
                          emailCtrls.removeAt(index);
                        });
                      }
                    },
                    child: isLast
                        ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 24,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(7),
                            width: 40,
                            height: 40,
                            child: ImageWidget(image: Paths.delete),
                          ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _phoneFieldSec() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 18),
            child: TextWidget(
              text: "Phone(s) with Country Code",
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.black,
            ),
          ),
        ),
        Spacers.sb8(),
        Column(
          children: phoneFields.asMap().entries.map((entry) {
            int index = entry.key;
            PhoneField field = entry.value;
            bool isLast = index == phoneFields.length - 1;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            openPhoneDropdownIndex =
                                openPhoneDropdownIndex == index ? null : index;
                          });
                        },
                        child: Container(
                          height: 45,
                          width: 90,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade400,
                              width: 1.3,
                            ),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              ImageWidget(image: field.type.image, width: 18),
                              Spacer(),
                              Icon(
                                openPhoneDropdownIndex == index
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Spacers.sbw12(),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 45,
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1.3,
                                ),
                                color: Colors.white,
                              ),
                              child: TextField(
                                controller: field.controller,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: field.type.label == "Phone"
                                      ? "Type Phone No"
                                      : field.type.label == "Land Phone"
                                      ? "Landline"
                                      : "other",

                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                                inputFormatters: [UsPhoneTextFormatter()],
                              ),
                            ),
                            if (field.type.label == "Phone")
                              Padding(
                                padding: EdgeInsets.only(top: 8, left: 70),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: TextWidget(
                                    text: "Phone No must include country code",
                                    fontSize: 11,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Spacers.sbw12(),
                      GestureDetector(
                        onTap: () {
                          if (isLast) {
                            setState(() {
                              phoneFields.add(
                                PhoneField(
                                  type: phoneTypes[1],
                                  controller: TextEditingController(),
                                ),
                              );
                            });
                          } else {
                            setState(() {
                              phoneFields.removeAt(index);
                            });
                          }
                        },
                        child: Container(
                          width: isLast ? 40 : null,
                          height: isLast ? 40 : null,
                          decoration: isLast
                              ? BoxDecoration(
                                  color: Colors.yellow.shade600,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: isLast
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 23,
                                    color: Colors.white,
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(7),
                                  width: 40,
                                  height: 40,
                                  child: ImageWidget(image: Paths.delete),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (openPhoneDropdownIndex == index)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.3,
                      ),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: phoneTypes.map((type) {
                        final bool isSelected = field.type.label == type.label;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              field.type = type;
                              openPhoneDropdownIndex = null;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 3,
                              horizontal: 6,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE9F5D4)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: Row(
                              children: [
                                ImageWidget(image: type.image, width: 25),
                                Spacers.sbw12(),
                                Expanded(
                                  child: TextWidget(
                                    text: type.label,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 26,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Column _languageSec() {
    final pro = getAdminPro(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 15),
            child: TextWidget(
              text: '*Language',
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.black,
            ),
          ),
        ),
        Spacers.sb8(),
        GestureDetector(
          onTap: () {
            setState(() => showLanguageDropdown = !showLanguageDropdown);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedLanguageIds.isEmpty
                        ? [
                            TextWidget(
                              text: "Select",
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ]
                        : selectedLanguageIds.map((id) {
                            final lang = pro.languages.firstWhere(
                              (e) => e.id == id,
                            );
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text: lang.name,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  Spacers.sbw8(),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedLanguageIds.remove(id);
                                      });
                                    },
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      width: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
                Icon(
                  showLanguageDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 30,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
        if (showLanguageDropdown)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 6),
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Column(
              children: pro.languages.map((lang) {
                final bool isSelected = selectedLanguageIds.contains(lang.id);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? selectedLanguageIds.remove(lang.id)
                          : selectedLanguageIds.add(lang.id);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE9F5D4)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextWidget(
                            text: lang.name,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            size: 25,
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget profileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: pickImage,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              image: selectedImage != null
                  ? DecorationImage(
                      image: FileImage(selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : DecorationImage(
                      image: AssetImage(Paths.user),
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () => pickImage(),
            child: ImageWidget(image: Paths.edit, width: 20),
          ),
        ),
      ],
    );
  }

  Widget _skillsSec() {
    final pro = getAdminPro(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
          child: TextWidget(
            text: 'Skills',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Spacers.sb8(),
        GestureDetector(
          onTap: () => setState(() => showSkillsDropdown = !showSkillsDropdown),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedSkillIds.isEmpty
                        ? [
                            TextWidget(
                              text: "Select",
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ]
                        : selectedSkillIds.map((id) {
                            final skill = pro.skills.firstWhere(
                              (e) => e.id == id,
                            );
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextWidget(
                                    text: skill.name,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  Spacers.sbw8(),
                                  GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => selectedSkillIds.remove(id),
                                      );
                                    },
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      width: 18,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
                Icon(
                  showSkillsDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),

        if (showSkillsDropdown)
          Container(
            margin: EdgeInsets.only(top: 6),
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: pro.skills.map((skill) {
                bool isSelected = selectedSkillIds.contains(skill.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? selectedSkillIds.remove(skill.id)
                          : selectedSkillIds.add(skill.id);
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE9F5D4)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextWidget(
                            text: skill.name,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            size: 24,
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Spacers.sb10(),
          Row(
            children: [
              ImageWidget(image: Paths.accounts, width: 28),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Account",
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, size: 26, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundedTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
    required String errorText,
    required String regErrorText,
    required RegExp regExpCondition,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
          child: TextWidget(
            text: label,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb5(),
        CustomTextField(
          regExpCondition: regExpCondition,
          regErrorText: regErrorText,
          errorText: errorText,
          controller: controller,
          obscureText: obscure,
          passField: isPassword,
          hintText: hint ?? '',
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(
            color: AppColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.hint,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
        ),
      ],
    );
  }

  Widget _roundedDropdown({
    required String label,
    required DropdownItem? value,
    required BuildContext parentContext,
    required String hint,
    required List<DropdownItem> items,
    required ValueChanged<DropdownItem?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
          child: TextWidget(
            text: label,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb5(),
        DropdownButtonFormField<DropdownItem>(
          borderRadius: BorderRadius.circular(12),
          initialValue: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 30,
            color: AppColors.black,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.grey),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
          hint: TextWidget(
            text: hint,
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: TextWidget(
                text: item.name,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            );
          }).toList(),
          onChanged: (item) {
            onChanged(item);

            formFieldKey.currentState?.validate();
          },

          validator: (v) {
            if (label.startsWith('*') && v == null) {
              return 'Account Type Required';
            }
            return null;
          },
          key: formFieldKey,
        ),
      ],
    );
  }
}
