// edit_account.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_constants/strings.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/admin_pro.dart';
import '../../tab_services/helpers.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_custom_button.dart';
import '../../tab_widgets/tab_field_widget.dart';
import '../../tab_utils/regx.dart';
import '../../tab_widgets/tab_toasts.dart';

class EditAccount extends StatefulWidget {
  final AccountModel account;
  const EditAccount({super.key, required this.account});

  @override
  State<EditAccount> createState() => _EditAccountState();
}

class _EditAccountState extends State<EditAccount> {
  final _formKey = GlobalKey<FormState>();

  File? selectedImage;
  String? networkImage;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  int? _selectedTypeId;

  List<PhoneField> phoneFields = [];
  List<TextEditingController> emailCtrls = [];

  List<int> selectedLanguageIds = [];
  List<int> selectedSkillIds = [];

  bool showLanguageDropdown = false;
  bool showSkillsDropdown = false;
  int? openPhoneDropdownIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getAdminPro(
        context,
      ).fetchAllDropdownData(context).whenComplete(() => _loadInitialData());
    });
  }

  void _loadInitialData() {
    final acc = widget.account;
    final pro = getAdminPro(context);
    _firstNameCtrl.text = acc.name;
    _lastNameCtrl.text = acc.lastName;
    _usernameCtrl.text = acc.username;
    networkImage = acc.imageUrl;
    _selectedTypeId = int.tryParse(acc.accountType ?? "0");
    phoneFields = acc.phones
        .map(
          (p) => PhoneField(
            type: _matchPhoneType(p.type),
            controller: TextEditingController(text: p.number),
          ),
        )
        .toList();
    if (phoneFields.isEmpty) {
      phoneFields.add(
        PhoneField(
          type: PhoneType("Phone", Paths.call, "mobile"),
          controller: TextEditingController(),
        ),
      );
    }
    emailCtrls = acc.emails.map((e) => TextEditingController(text: e)).toList();
    if (emailCtrls.isEmpty) {
      emailCtrls.add(TextEditingController());
    }
    selectedLanguageIds =
        acc.staffDetails?.languages
            .map((langName) {
              final match = pro.languages.firstWhere(
                (e) => e.name.toLowerCase() == langName.toLowerCase(),
                orElse: () => DropdownItem(id: -1, name: ""),
              );
              return match.id;
            })
            .where((id) => id != -1)
            .toList() ??
        [];
    debugPrint(acc.staffDetails?.languages.toString());
    selectedSkillIds =
        acc.staffDetails?.skills
            .map((skillName) {
              final match = pro.skills.firstWhere(
                (e) => e.name.toLowerCase() == skillName.toLowerCase(),
                orElse: () => DropdownItem(id: -1, name: ""),
              );
              return match.id;
            })
            .where((id) => id != -1)
            .toList() ??
        [];

    setState(() {});
  }

  PhoneType _matchPhoneType(String type) {
    if (type == "mobile") {
      return PhoneType("Phone", Paths.call, "mobile");
    } else if (type == "landline") {
      return PhoneType("Land Phone", Paths.landPhone, "landline");
    } else {
      return PhoneType("Other", Paths.other, "another");
    }
  }

  Future<void> pickImage() async {
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
  }

  Future<void> _onSave(dynamic context) async {
    if (!_formKey.currentState!.validate()) return;
    final pro = getAdminPro(context);
    debugPrint('selectedLanguageIds: $selectedLanguageIds');
    List<Map<String, dynamic>> phones = phoneFields
        .map(
          (p) => {"type": p.type.apiValue, "value": p.controller.text.trim()},
        )
        .toList();
    debugPrint('111111');
    List<String> emails = emailCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    debugPrint('2222');
    bool success = await pro.updateAccount(
      id: widget.account.id,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      phones: phones,
      emails: emails,
      type: _selectedTypeId ?? 0,
      languages: selectedLanguageIds,
      skills: selectedSkillIds,
      imagePath: selectedImage?.path,
      context: context,
    );
    debugPrint('3333');
    debugPrint("Update API result: $success");

    if (success) {
      Navigator.pop(context);
      showToast(message: "Account Updated Successfully");
      pro.getAccounts(ctx: context);
    } else {
      showToast(message: "Update Failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = getAdminPro(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.only(top: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
              bottom: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              _header(context),
              Divider(thickness: 2),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Spacers.sb10(),
                        _profileImage(),
                        Spacers.sb20(),
                        _formBody(pro),
                        Spacers.sb25(),
                        scrollUp(context),
                      ],
                    ),
                  ),
                ),
              ),
              _saveButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              ImageWidget(image: Paths.accounts, width: 28),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Edit Account",
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

  Widget _profileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: selectedImage != null
                  ? FileImage(selectedImage!)
                  : (networkImage != null
                            ? NetworkImage(networkImage!)
                            : AssetImage(Paths.user))
                        as ImageProvider,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: pickImage,
            child: ImageWidget(image: Paths.edit, width: 22),
          ),
        ),
      ],
    );
  }

  Widget _formBody(AdminPro pro) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _dropdownAccountType(pro),
          Spacers.sb10(),
          _textField(
            _firstNameCtrl,
            "*Name",
            "Type Name",
            AppStrings.fNameError,
            AppStrings.fNameRegError,
            Regx.nameRegExp,
          ),
          Spacers.sb10(),
          _textField(
            _lastNameCtrl,
            "*Lastname",
            "Type Lastname",
            AppStrings.lNameError,
            AppStrings.lNameRegError,
            Regx.nameRegExp,
          ),
          Spacers.sb10(),
          _textField(
            _usernameCtrl,
            "*User Name",
            "Type User Name",
            AppStrings.usrNameError,
            AppStrings.userNmeRegError,
            Regx.userNameRegExp,
          ),
          Spacers.sb10(),
          _languageSection(pro),
          Spacers.sb10(),
          _twilioSection(widget.account),
          Spacers.sb10(),
          _phoneSection(),
          Spacers.sb10(),
          _emailSection(),
          Spacers.sb10(),
          _skillsSection(pro),
        ],
      ),
    );
  }

  Widget _dropdownAccountType(AdminPro pro) {
    DropdownItem? selected = pro.accountTypes.firstWhere(
      (e) => e.id == _selectedTypeId,
      orElse: () => DropdownItem(id: -1, name: "Select"),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
          child: TextWidget(
            text: "*Type of Account",
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Spacers.sb8(),
        DropdownButtonFormField<DropdownItem>(
          initialValue: selected.id == -1 ? null : selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
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
            text: 'Select',
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          items: pro.accountTypes.map((e) {
            return DropdownMenuItem(
              value: e,
              child: TextWidget(
                text: e.name,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            );
          }).toList(),
          onChanged: (v) {
            setState(() => _selectedTypeId = v?.id);
          },
          validator: (v) => v == null ? "Required" : null,
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    String errorText,
    String regErrorText,
    RegExp reg,
  ) {
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
          controller: controller,
          hintText: hint,
          regExpCondition: reg,
          errorText: errorText,
          regErrorText: regErrorText,
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(
            color: AppColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ],
    );
  }

  Widget _twilioSection(AccountModel acc) {
    return const SizedBox.shrink();
  }

  Widget _phoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(text: "Phones", fontWeight: FontWeight.bold, fontSize: 12),
        Spacers.sb10(),
        Column(
          children: phoneFields.asMap().entries.map((entry) {
            int index = entry.key;
            PhoneField field = entry.value;
            bool isLast = index == phoneFields.length - 1;

            return Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        openPhoneDropdownIndex = openPhoneDropdownIndex == index
                            ? null
                            : index;
                      }),
                      child: Container(
                        height: 45,
                        width: 90,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: _boxDecor(),
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
                    Spacers.sbw10(),
                    Expanded(
                      child: Container(
                        height: 45,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: _boxDecor(),
                        child: TextField(
                          controller: field.controller,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: field.type.label == "Phone"
                                ? "Type Phone"
                                : field.type.label == "Land Phone"
                                ? "Landline"
                                : "Other",
                          ),
                          inputFormatters: [UsPhoneTextFormatter()],
                        ),
                      ),
                    ),
                    Spacers.sbw10(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isLast) {
                            phoneFields.add(
                              PhoneField(
                                type: PhoneType("Phone", Paths.call, "mobile"),
                                controller: TextEditingController(),
                              ),
                            );
                          } else {
                            phoneFields.removeAt(index);
                          }
                        });
                      },
                      child: isLast
                          ? CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.yellow.shade600,
                              child: Icon(Icons.add, color: Colors.white),
                            )
                          : Container(
                              padding: EdgeInsets.all(6),
                              child: ImageWidget(
                                image: Paths.delete,
                                width: 24,
                              ),
                            ),
                    ),
                  ],
                ),
                if (openPhoneDropdownIndex == index) _phoneDropdown(field),
                Spacers.sb10(),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _phoneDropdown(PhoneField field) {
    List<PhoneType> types = [
      PhoneType("Phone", Paths.call, "mobile"),
      PhoneType("Land Phone", Paths.landPhone, "landline"),
      PhoneType("Other", Paths.other, "another"),
    ];

    return Container(
      padding: EdgeInsets.all(10),
      decoration: _boxDecor(),
      child: Column(
        children: types.map((type) {
          bool isSelected = field.type.apiValue == type.apiValue;

          return GestureDetector(
            onTap: () {
              setState(() {
                field.type = type;
                openPhoneDropdownIndex = null;
              });
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFE9F5D4) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ImageWidget(image: type.image, width: 22),
                  Spacers.sbw10(),
                  Expanded(
                    child: Text(
                      type.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emailSection() {
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
          spacing: 6,
          children: emailCtrls.asMap().entries.map((entry) {
            int index = entry.key;
            bool isLast = index == emailCtrls.length - 1;
            return Row(
              children: [
                Expanded(child: EmailListTextField(controller: entry.value)),
                Spacers.sbw12(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isLast) {
                        emailCtrls.add(TextEditingController());
                      } else {
                        emailCtrls.removeAt(index);
                      }
                    });
                  },
                  child: isLast
                      ? Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade600,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add, size: 23, color: Colors.white),
                        )
                      : Container(
                          padding: EdgeInsets.all(7),
                          width: 40,
                          height: 40,
                          child: ImageWidget(image: Paths.delete),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _languageSection(AdminPro pro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
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
            padding: EdgeInsets.all(12),
            decoration: _boxDecor(),
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
                              orElse: () =>
                                  DropdownItem(id: -1, name: "Unknown"),
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
        if (showLanguageDropdown) _chipList(pro.languages, selectedLanguageIds),
      ],
    );
  }

  Widget _skillsSection(AdminPro pro) {
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
            padding: EdgeInsets.all(12),
            decoration: _boxDecor(),
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
                              orElse: () =>
                                  DropdownItem(id: -1, name: "Unknown"),
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
        if (showSkillsDropdown) _chipList(pro.skills, selectedSkillIds),
      ],
    );
  }

  Widget _chipList(List<DropdownItem> list, List<int> selectedList) {
    return Container(
      padding: EdgeInsets.all(9),
      margin: EdgeInsets.only(top: 6),
      decoration: _boxDecor(),
      child: Column(
        children: list.map((item) {
          bool isSelected = selectedList.contains(item.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                isSelected
                    ? selectedList.remove(item.id)
                    : selectedList.add(item.id);
              });
            },
            child: Container(
              padding: EdgeInsets.all(11),
              margin: EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFFE9F5D4) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(item.name)),
                  if (isSelected) Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  BoxDecoration _boxDecor() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
      color: Colors.white,
    );
  }

  Widget _saveButtons(BuildContext context) {
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
              onTap: () => _onSave(context),
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
}
