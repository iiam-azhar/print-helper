import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/constants/strings.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/utils/formatter.dart';
import 'package:print_helper/utils/regx.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/field_widget.dart';
import 'package:print_helper/widgets/toasts.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/accounts_models.dart';
import '../../services/helpers.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';

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
      final errorMsg = await pro.storeAccount(
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
      if (errorMsg == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created Successfully")),
        );

        await pro.getAccounts(ctx: context);
      } else {
        showToast(message: errorMsg);
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
          margin: EdgeInsets.only(top: 40.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SafeArea(
            top: true,
            child: Column(
              children: [
                _header(context),
                Divider(thickness: 2.w, color: const Color(0x5F9E9E9E)),
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
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12),
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
              onTap: () async {
                _onSave(context);
                printData(title: "Tap", data: "Save button tapped");
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.w),
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
            label: '*First name',
            hint: 'Type First Name',
            errorText: AppStrings.fNameError,
            regErrorText: AppStrings.fNameRegError,
            regExpCondition: Regx.nameRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: _lastNameCtrl,
            label: '*Last name',
            hint: 'Type Lastname',
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
            padding: EdgeInsets.only(left: 18.w),
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
              padding: EdgeInsets.only(bottom: 10.h),
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
                            width: 40.w,
                            height: 40.h,
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 23.sp,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(7.w),
                            width: 40.w,
                            height: 40.h,
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
    final hasPhoneField = phoneFields.any(
      (field) => field.type.label == "Phone",
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 18.w),
            child: TextWidget(
              text: hasPhoneField ? "Phone(s) with Country Code" : "Phone(s)",
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
                  padding: EdgeInsets.only(bottom: 14.h),
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
                          height: 45.h,
                          width: 70.w,
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
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
                                size: 22.sp,
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
                              height: 45.h,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.r),
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
                                    fontSize: 14.sp,
                                  ),
                                ),
                                inputFormatters: [UsPhoneTextFormatter()],
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
                          width: isLast ? 40.w : null,
                          height: isLast ? 40.h : null,
                          decoration: isLast
                              ? BoxDecoration(
                                  color: Colors.yellow.shade600,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: isLast
                              ? Container(
                                  width: 40.w,
                                  height: 40.h,
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.shade600,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 23.sp,
                                    color: Colors.white,
                                  ),
                                )
                              : Container(
                                  padding: EdgeInsets.all(7.w),
                                  width: 40.w,
                                  height: 40.h,
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
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
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
                              vertical: 3.h,
                              horizontal: 6.w,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                              horizontal: 14.w,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE9F5D4)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12.r),
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
                                    size: 26.sp,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: 'Language',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb8(),
        GestureDetector(
          onTap: () =>
              setState(() => showLanguageDropdown = !showLanguageDropdown),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
            ),
            child: Row(
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
                                horizontal: 14.w,
                                vertical: 8.w,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10.r),
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
                  size: 30.sp,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),

        if (showLanguageDropdown)
          Container(
            margin: EdgeInsets.only(top: 6.w),
            padding: EdgeInsets.symmetric(vertical: 8.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: Column(
              children: pro.languages.map((lang) {
                bool isSelected = selectedLanguageIds.contains(lang.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? selectedLanguageIds.remove(lang.id)
                          : selectedLanguageIds.add(lang.id);
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 12.w,
                      horizontal: 10.w,
                    ),
                    margin: EdgeInsets.symmetric(
                      vertical: 4.w,
                      horizontal: 10.w,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE9F5D4)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10.r),
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
                            size: 24.sp,
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
          padding: EdgeInsets.only(left: 15.w),
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
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.w),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
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
                                horizontal: 14.w,
                                vertical: 8.w,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5D4),
                                borderRadius: BorderRadius.circular(10.r),
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
            margin: EdgeInsets.only(top: 6.w),
            padding: EdgeInsets.symmetric(vertical: 8.w),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14.r),
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
                    padding: EdgeInsets.symmetric(
                      vertical: 12.w,
                      horizontal: 10.w,
                    ),
                    margin: EdgeInsets.symmetric(
                      vertical: 4.w,
                      horizontal: 10.w,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE9F5D4)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10.r),
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
                            size: 24.sp,
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
            width: 45.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10.r),
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
                child: Icon(
                  Icons.close,
                  size: 26.sp,
                  fontWeight: FontWeight.w800,
                ),
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
          padding: EdgeInsets.only(left: 15.w),
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
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.w),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.hint,
                    size: 20.sp,
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
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: label,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb5(),
        DropdownButtonFormField<DropdownItem>(
          borderRadius: BorderRadius.circular(12.r),
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 13.w,
              vertical: 15.w,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppColors.grey),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
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
