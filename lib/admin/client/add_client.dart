import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/constants/strings.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/utils/regx.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/field_widget.dart';
import 'package:print_helper/widgets/toasts.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/accounts_models.dart';
import '../../models/contact_form_models.dart';
import '../../services/helpers.dart';
import '../../utils/formatter.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';

class AddClient extends StatefulWidget {
  const AddClient({super.key});

  @override
  State<AddClient> createState() => AddClientState();
}

class AddClientState extends State<AddClient> {
  final _formKey = GlobalKey<FormState>();
  int? selectedCompanyType;
  int? selectedClientRank;
  bool pickingFile = false;
  File? selectedImage;
  File? selectedLogo;

  String? userImage;
  int? openPhoneDropdownIndex;
  int? selectedState;
  int? selectedCity;
  bool formSubmitted = false;
  final addressCtrl = TextEditingController();
  final addressTwoCtrl = TextEditingController();
  final zipCodeCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final brandUrlCtrl = TextEditingController();
  final cmpnyNmeCtrl = TextEditingController();
  Color _primaryColor = const Color(0xFF4CC9F0);
  Color _secondaryColor = const Color(0xFFAEB0B3);
  String? selectedLanguage;
  bool showLanguageDropdown = false;
  List<int> selectedLanguageIds = [];
  List<String> selectedLanguages = [];
  List<int> selectedStaffIds = [];
  bool showStaffDropdown = false;
  int visibleStaffCount = 5;
  bool isLoadingMore = false;
  final ScrollController staffScrollController = ScrollController();
  final TextEditingController staffSearchCtrl = TextEditingController();
  Map<int, bool> passwordVisibility = {}; // Track visibility for each contact
  Map<int, bool> confirmPasswordVisibility =
      {}; // Track visibility for each contact

  List<PhoneType> phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];
  List<PhoneField> phoneFields = [
    PhoneField(
      type: PhoneType("Phone", Paths.call, "phone"),
      controller: TextEditingController(),
    ),
  ];
  List<PhoneRow> phones = [PhoneRow()];
  List<TextEditingController> emailCtrls = [TextEditingController()];
  List<ContactFormModel> contactForms = [];

  @override
  void initState() {
    super.initState();
    contactForms.add(ContactFormModel());
    staffScrollController.addListener(() async {
      if (staffScrollController.position.pixels >=
          staffScrollController.position.maxScrollExtent - 50) {
        if (showStaffDropdown && !isLoadingMore) {
          final clipro = getClientPro(context);
          final query = staffSearchCtrl.text.trim().toLowerCase();
          final totalMatches = clipro.staffList
              .where((s) => s.name.toLowerCase().contains(query))
              .length;
          if (visibleStaffCount < totalMatches) {
            setState(() {
              isLoadingMore = true;
            });
            await Future.delayed(const Duration(milliseconds: 500));
            if (!mounted) return;
            setState(() {
              visibleStaffCount = (visibleStaffCount + 5).clamp(0, totalMatches);
              isLoadingMore = false;
            });
          }
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final custPro = getAdminPro(context);
      final clientPro = getClientPro(context);
      custPro.fetchAllDropdownData(context);
      clientPro.fetchStates();
      clientPro.fetchStaff();
    });
  }

  @override
  void dispose() {
    staffScrollController.dispose();
    staffSearchCtrl.dispose();
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
        allowedExtensions: ['jpg', 'png', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        selectedImage = File(result.files.single.path!);
      }
    } catch (e) {
      printData(title: 'from pickImage', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  Future<void> pickLogo() async {
    if (pickingFile) return;
    pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg'],
      );
      if (result != null && result.files.single.path != null) {
        selectedLogo = File(result.files.single.path!);
      }
    } catch (e) {
      printData(title: 'from pickImage', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  void _onSave(dynamic context) async {
    setState(() => formSubmitted = true);
    if (selectedStaffIds.isEmpty) {
      showToast(message: "Please select at least one staff member");
      return;
    }
    for (var model in contactForms) {
      if (model.password.text.trim() != model.confirmPassword.text.trim()) {
        showToast(
          message:
              "Password and Confirm Password do not match for ${model.firstName.text.isNotEmpty ? model.firstName.text : 'a contact'}",
        );
        return;
      }
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final clipro = getClientPro(context);
    final success = await clipro.createClient(
      companyName: cmpnyNmeCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      address2: addressTwoCtrl.text.trim(),
      state: selectedState?.toString() ?? "",
      city: selectedCity?.toString() ?? "",
      zipcode: zipCodeCtrl.text.trim(),
      clientLanguages: selectedLanguageIds,
      status: 1,
      assignedStaff: selectedStaffIds,
      contacts: contactForms,
      companyType: selectedCompanyType ?? 0,
      clientRank: selectedClientRank ?? 0,
      brandingPrimary: _colorToHexReadable(_primaryColor),
      brandingSecondary: _colorToHexReadable(_secondaryColor),
      brandingUrl: brandUrlCtrl.text.trim(),
      clientImage: selectedImage,
      brandLogo: selectedLogo,
      context: context,
    );
    if (success) {
      showToast(message: "Client created successfully");
      // await clipro.getClients(ctx: context);
      Navigator.of(context).pop(true);
    } else {
      // showToast(message: "Failed to create client");
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
                      autovalidateMode: formSubmitted
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
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
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0.w),
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
        ),
      ],
    );
  }

  Widget _formBody() {
    final pro = getAdminPro(context);
    final clipro = getClientPro(context);
    DropdownItem? findById(List<DropdownItem> list, int? id) {
      if (id == null) return null;
      try {
        return list.firstWhere((e) => e.id == id);
      } catch (_) {
        return null;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
      child: Column(
        children: [
          _brandingLogoWidget(),
          Spacers.sb8(),
          _brandingColorWidget(
            label: "Branding Primary Color",
            color: _primaryColor,
            hex: _colorToHexReadable(_primaryColor),
            onTap: () => _openPicker(isPrimary: true),
          ),
          Spacers.sb8(),
          _brandingColorWidget(
            label: "Branding Secondary Color",
            color: _secondaryColor,
            hex: _colorToHexReadable(_secondaryColor),
            onTap: () => _openPicker(isPrimary: false),
          ),
          Spacers.sb10(),
          _roundedTextField(
            controller: brandUrlCtrl,
            label: 'Branding URL (optional)',
            hint: 'Type URL',
            regExpCondition: Regx.optionalText,
            errorText: null,
            regErrorText: null,
          ),

          Spacers.sb8(),
          _roundedTextField(
            controller: cmpnyNmeCtrl,
            label: 'Company Name',
            hint: 'Type Company Name',
            errorText: 'This field is required',
            regErrorText: 'Please enter a valid company name',
            regExpCondition: Regx.addressRegExp,
          ),
          Spacers.sb8(),
          _roundedDropdown(
            parentContext: context,
            label: '*Client\'s Company Type',
            value: pro.clientCmpnyType.any((e) => e.id == selectedCompanyType)
                ? pro.clientCmpnyType.firstWhere(
                    (e) => e.id == selectedCompanyType,
                  )
                : null,
            hint: 'Select',
            items: pro.clientCmpnyType,
            onChanged: (item) {
              setState(() => selectedCompanyType = item?.id);
            },
          ),
          Spacers.sb8(),
          _roundedDropdown(
            parentContext: context,
            label: '*Client\'s Rank',
            value: pro.clientRank.any((e) => e.id == selectedClientRank)
                ? pro.clientRank.firstWhere((e) => e.id == selectedClientRank)
                : null,
            hint: 'Select',
            items: pro.clientRank,
            onChanged: (item) {
              setState(() => selectedClientRank = item?.id);
            },
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: addressCtrl,
            label: 'Address',
            hint: 'Type Address',
            errorText: "Address is required",
            regErrorText: AppStrings.invalidInput,
            regExpCondition: Regx.addressRegExp,
          ),
          Spacers.sb8(),
          _roundedTextField(
            controller: addressTwoCtrl,
            label: 'Address 2',
            hint: 'Type Unit,Apt Etc Etc.',
            regExpCondition: Regx.optionalText,
            regErrorText: null,
          ),
          Spacers.sb8(),
          _roundedDropdown(
            parentContext: context,
            label: '*State',
            value: findById(clipro.stateDropdown, selectedState),
            hint: 'Select State',
            items: clipro.stateDropdown,
            onChanged: (item) {
              setState(() {
                selectedState = item?.id;
                selectedCity = null;
              });
              if (item != null) {
                clipro.loadCities(item.id);
              }
            },
          ),
          Spacers.sb8(),
          if (selectedState != null && clipro.cityDropdown.isNotEmpty)
            _roundedDropdown(
              parentContext: context,
              label: '*City',
              value: findById(clipro.cityDropdown, selectedCity),
              hint: selectedState == null
                  ? 'Select state first'
                  : 'Select City',
              items: clipro.cityDropdown,
              onChanged: (item) {
                setState(() => selectedCity = item?.id);
              },
            ),
          if (selectedState != null && clipro.cityDropdown.isNotEmpty)
            Spacers.sb8(),
          _roundedTextField(
            controller: zipCodeCtrl,
            label: '*Zipcode',
            hint: 'Type Zipcode (4-10 digits)',
            errorText: "Zipcode is required (4-10 digits)",
            regErrorText: "Zipcode must be 4-10 digits",
            regExpCondition: Regx.zipcodeRegExp,
          ),
          Spacers.sb8(),
          _assignStaff(),
          Spacers.sb12(),
          Column(
            children: contactForms
                .asMap()
                .entries
                .map((entry) => _contactFormSection(entry.key, entry.value))
                .toList(),
          ),
          Spacers.sb12(),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 5.0),
              child: CustomButton(
                title: "+ Add Contact",
                height: 40,
                width: 160,
                buttonColor: AppColors.amber,
                textColor: AppColors.black,
                stadium: false,
                borderRadius: 18,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                onTap: () {
                  contactForms.add(ContactFormModel());
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandingLogoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: "Branding Logo",
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb5(),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 45.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade300),
                  color: Colors.white,
                ),
                alignment: Alignment.centerLeft,
                child: TextWidget(
                  text: selectedLogo == null
                      ? "Select Logo"
                      : selectedLogo!.path.split('/').last,
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: Colors.black54,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Spacers.sbw12(),
            CustomButton(
              title: "Browse",
              height: 40,
              width: 80,
              buttonColor: Colors.white,
              textColor: AppColors.black,
              stadium: false,
              borderRadius: 12,
              borderWidth: 1,
              borderColor: AppColors.amber,
              showBorder: true,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              onTap: () => pickLogo(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _brandingColorWidget({
    required String label,
    required Color color,
    required String hex,
    required VoidCallback onTap,
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
        Row(
          children: [
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 47.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                ),
              ),
            ),
            Spacers.sbw12(),
            Expanded(
              flex: 2,
              child: TextWidget(
                text: hex,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                overflow: TextOverflow.ellipsis,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _contactFormSection(int index, ContactFormModel model) {
    bool isMain = index == 0;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 15.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: isMain ? AppColors.amber : AppColors.formHint,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isMain ? AppColors.amber : AppColors.formHint,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14.r),
                topRight: Radius.circular(14.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: isMain ? "Main Contact Info" : "Contact Info",
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
                if (!isMain)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        contactForms.removeAt(index);
                      });
                    },
                    child: ImageWidget(image: Paths.delete, width: 20),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacers.sb15(),
                contactProfileImage(
                  image: model.image,
                  onPick: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'jpeg'],
                    );
                    if (picked != null && picked.files.single.path != null) {
                      setState(
                        () => model.image = File(picked.files.single.path!),
                      );
                    }
                  },
                ),
                Spacers.sb15(),
                _roundedTextField(
                  controller: model.username,
                  label: "*User name",
                  hint: "Type User Name",
                  errorText: "Required",
                  regErrorText: "Invalid",
                  regExpCondition: Regx.userNameRegExp,
                ),
                Spacers.sb8(),
                _passwordField(
                  controller: model.password,
                  label: "*Password",
                  hint: "Type Password",
                  isVisible:
                      passwordVisibility[contactForms.indexOf(model)] ?? false,
                  onVisibilityToggle: () {
                    setState(() {
                      passwordVisibility[contactForms.indexOf(model)] =
                          !(passwordVisibility[contactForms.indexOf(model)] ??
                              false);
                    });
                  },
                  errorText: AppStrings.passError,
                  regErrorText: AppStrings.passRegError,
                  regExpCondition: Regx.passwordRegExp,
                ),
                Spacers.sb8(),
                _passwordField(
                  controller: model.confirmPassword,
                  label: "*Confirm Password",
                  hint: "Type Confirm Password",
                  isVisible:
                      confirmPasswordVisibility[contactForms.indexOf(model)] ??
                      false,
                  onVisibilityToggle: () {
                    setState(() {
                      confirmPasswordVisibility[contactForms.indexOf(model)] =
                          !(confirmPasswordVisibility[contactForms.indexOf(
                                model,
                              )] ??
                              false);
                    });
                  },
                  errorText: AppStrings.cnfmPassError,
                  regErrorText: AppStrings.passRegError,
                  regExpCondition: Regx.passwordRegExp,
                ),
                Spacers.sb8(),
                _roundedTextField(
                  controller: model.firstName,
                  label: "*First Name",
                  hint: "Type First Name",
                  errorText: "Required",
                  regErrorText: "Invalid",
                  regExpCondition: Regx.nameRegExp,
                ),
                Spacers.sb8(),
                _roundedTextField(
                  controller: model.lastName,
                  label: "*Last Name",
                  hint: "Type Last Name",
                  errorText: "Required",
                  regErrorText: "Invalid",
                  regExpCondition: Regx.nameRegExp,
                ),
                Spacers.sb8(),
                _languageSec(model),
                Spacers.sb8(),
                _contactPhoneSection(model),
                Spacers.sb8(),
                _contactEmailSection(model),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contactProfileImage({
    required File? image,
    required VoidCallback onPick,
  }) {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image),
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
              onTap: () => onPick(),
              child: ImageWidget(image: Paths.edit, width: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactPhoneSection(ContactFormModel model) {
    final hasPhoneField = model.phoneFields.any(
      (field) => field.type.label == "Phone",
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: hasPhoneField ? "Phone(s) with Country Code" : "Phone(s)",
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.black,
          ),
        ),
        Spacers.sb8(),
        Column(
          children: model.phoneFields.asMap().entries.map((entry) {
            int index = entry.key;
            PhoneField field = entry.value;
            bool isLast = index == model.phoneFields.length - 1;
            return Column(
              children: [
                Row(
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
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
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
                            ImageWidget(image: field.type.image, width: 20),
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
                              inputFormatters: [InternationalPhoneFormatter()],
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
                            model.phoneFields.add(
                              PhoneField(
                                type: phoneTypes[1],
                                controller: TextEditingController(),
                              ),
                            );
                          });
                        } else {
                          setState(() => model.phoneFields.removeAt(index));
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

                if (index != model.phoneFields.length - 1) Spacers.sb10(),
                if (openPhoneDropdownIndex == index)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 6.h, bottom: 12.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      children: phoneTypes.map((type) {
                        bool selected = field.type.label == type.label;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              field.type = type;
                              openPhoneDropdownIndex = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                              horizontal: 14.w,
                            ),
                            margin: EdgeInsets.only(bottom: 3.h, top: 5.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              color: selected
                                  ? const Color(0xFFE9F5D4)
                                  : Colors.grey.shade200,
                            ),
                            child: Row(
                              children: [
                                ImageWidget(image: type.image, width: 22),
                                Spacers.sbw10(),
                                Expanded(
                                  child: TextWidget(
                                    text: type.label,
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle,
                                    size: 22.sp,
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

  Widget _contactEmailSection(ContactFormModel model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: "Email (s)",
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Spacers.sb8(),
        Column(
          children: model.emails.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController ctrl = entry.value;
            bool isLast = index == model.emails.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Expanded(child: EmailListTextField(controller: ctrl)),
                  Spacers.sbw12(),
                  GestureDetector(
                    onTap: () {
                      if (isLast) {
                        setState(
                          () => model.emails.add(TextEditingController()),
                        );
                      } else {
                        setState(() => model.emails.removeAt(index));
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
            );
          }).toList(),
        ),
      ],
    );
  }

  Column _languageSec(ContactFormModel model) {
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
          onTap: () {
            setState(
              () => model.showLanguageDropdown = !model.showLanguageDropdown,
            );
          },
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
                    children: model.selectedLanguageIds.isEmpty
                        ? [
                            TextWidget(
                              text: "Select",
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ]
                        : model.selectedLanguageIds.map((id) {
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
                                        model.selectedLanguageIds.remove(id);
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
                  model.showLanguageDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 30.sp,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
        if (model.showLanguageDropdown)
          Container(
            margin: EdgeInsets.only(top: 6.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250.h),
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: pro.languages.map((lang) {
                    bool isSelected = model.selectedLanguageIds.contains(
                      lang.id,
                    );

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            model.selectedLanguageIds.remove(lang.id);
                          } else {
                            model.selectedLanguageIds.add(lang.id);
                          }
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
                            color: isSelected
                                ? Colors.green
                                : Colors.transparent,
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
            ),
          ),
      ],
    );
  }

  Widget _assignStaff() {
    final clipro = getClientPro(context);
    final bool hasError = selectedStaffIds.isEmpty && formSubmitted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15.w),
          child: TextWidget(
            text: '*Assign Staff Members',
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
        Spacers.sb8(),
        GestureDetector(
          onTap: () => setState(() {
            showStaffDropdown = !showStaffDropdown;
            if (showStaffDropdown) {
              visibleStaffCount = 5;
              isLoadingMore = false;
              staffSearchCtrl.clear();
            }
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: hasError ? Colors.red : Colors.grey.shade400,
                width: 1.2,
              ),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedStaffIds.isEmpty
                        ? [
                            TextWidget(
                              text: "Select Staff",
                              color: hasError ? Colors.red : Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ]
                        : selectedStaffIds.map((id) {
                            final staff = clipro.staffList.firstWhere(
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
                                    text: staff.name,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  Spacers.sbw8(),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedStaffIds.remove(id);
                                      });
                                    },
                                    child: ImageWidget(
                                      image: Paths.delete,
                                      width: 20,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
                Icon(
                  showStaffDropdown
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 30.sp,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(left: 15.w, top: 4.w),
            child: Text(
              "Please assign at least one staff member",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        if (showStaffDropdown)
          Container(
            margin: EdgeInsets.only(top: 6.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250.h),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.w),
                    child: TextField(
                      controller: staffSearchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search staff...",
                        prefixIcon: Icon(Icons.search, size: 20.sp),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8.h,
                          horizontal: 10.w,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          visibleStaffCount = 5;
                          isLoadingMore = false;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final query = staffSearchCtrl.text.trim().toLowerCase();
                        final filteredList = clipro.staffList
                            .where((s) => s.name.toLowerCase().contains(query))
                            .toList();
                        final displayList = filteredList.take(visibleStaffCount).toList();
                        final hasMore = visibleStaffCount < filteredList.length || isLoadingMore;

                        return ListView.builder(
                          controller: staffScrollController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayList.length + (hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == displayList.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: Center(
                                  child: isLoadingMore
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const SizedBox(height: 20),
                                ),
                              );
                            }
                            final staff = displayList[index];
                            bool isSelected = selectedStaffIds.contains(staff.id);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  isSelected
                                      ? selectedStaffIds.remove(staff.id)
                                      : selectedStaffIds.add(staff.id);
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
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.transparent,
                                    width: 1.4,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextWidget(
                                        text: staff.name,
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
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 10.w),
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
              ImageWidget(
                image: Paths.clientprofile,
                fit: BoxFit.cover,
                width: 27,
              ),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Client",
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

  void _openPicker({required bool isPrimary}) {
    Color tempColor = isPrimary ? _primaryColor : _secondaryColor;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: TextWidget(
            text: 'Pick a color',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          scrollable: true,
          backgroundColor: AppColors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (c) => tempColor = c,
                enableAlpha: false,
              ),
              ColorPickerInput(
                tempColor,
                (c) => tempColor = c,
                enableAlpha: false,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              child: TextWidget(
                text: 'Cancel',
                color: AppColors.black,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Select"),
              onPressed: () {
                setState(() {
                  if (isPrimary) {
                    _primaryColor = tempColor;
                  } else {
                    _secondaryColor = tempColor;
                  }
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  String _colorToHexReadable(Color c) {
    return colorToHex(
      c,
      includeHashSign: true,
      enableAlpha: true,
    ).toUpperCase();
  }

  Widget _roundedTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    String? errorText,
    String? regErrorText,
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
          autoValidate: formSubmitted,
          alphaWithSpaceOnly:
              regExpCondition.pattern == Regx.nameRegExp.pattern,
          regExpCondition: regExpCondition,
          regErrorText: regErrorText,
          errorText: errorText,
          controller: controller,
          obscureText: obscure,
          hintText: hint ?? '',
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(
            color: AppColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.w),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
    String? errorText,
    String? regErrorText,
    RegExp? regExpCondition,
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
          controller: controller,
          regExpCondition: regExpCondition ?? Regx.passwordRegExp,
          obscureText: !isVisible,
          passField: true,
          errorText: errorText,
          regErrorText: regErrorText,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          errorStyle: TextStyle(
            color: AppColors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.w),
          suffixIcon: GestureDetector(
            onTap: onVisibilityToggle,
            child: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey.shade600,
              size: 20.sp,
            ),
          ),
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
          autovalidateMode: formSubmitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
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
          },
          validator: (v) {
            if (label.startsWith('*') && v == null) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
