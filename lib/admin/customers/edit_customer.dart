import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/utils/console_util.dart';
import 'package:print_helper/utils/regx.dart';
import 'package:print_helper/widgets/custom_button.dart';
import 'package:print_helper/widgets/field_widget.dart';
import 'package:print_helper/widgets/toasts.dart';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../models/accounts_models.dart';
import '../../models/contact_form_models.dart';
import '../../models/edit_customer_models.dart';
import '../../services/helpers.dart';
import '../../utils/formatter.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/spacers.dart';
import '../../widgets/text_widget.dart';

class EditCustomer extends StatefulWidget {
  final int? clientId;
  final int? customerId;
  final bool isFromClient;
  const EditCustomer({
    super.key,
    this.clientId,
    this.customerId,
    required this.isFromClient,
  });

  @override
  State<EditCustomer> createState() => EditCustomerState();
}

class EditCustomerState extends State<EditCustomer> {
  final _formKey = GlobalKey<FormState>();
  int? selectedCompanyType;
  int? selectedCustRank;
  bool pickingFile = false;
  File? selectedImage;
  String? customerImageUrl;
  String? brandingLogoUrl;
  DropdownItem? _selectedType;
  int? openPhoneDropdownIndex;
  bool formSubmitted = false;
  bool loading = false;
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final cmpnyNmeCtrl = TextEditingController();
  List<DropdownItem> cmpnyPrsnl = [
    DropdownItem(id: 1, name: "Company"),
    DropdownItem(id: 2, name: "Personal"),
  ];
  bool showLanguageDropdown = false;
  List<int> selectedLanguageIds = [];
  List<String> selectedLanguages = [];
  List<PhoneType> phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];
  List<ContactFormModel> contactForms = [];

  @override
  void initState() {
    super.initState();
    contactForms.add(ContactFormModel());
    printData(title: "customerId:", data: widget.customerId);
    printData(title: "clientId:", data: widget.clientId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    setState(() => loading = true);
    final adminPro = getAdminPro(context);
    final custPro = getCustPro(context);
    await Future.wait([adminPro.fetchAllDropdownData(context)]);
    if (widget.clientId != null) {
      final model = await custPro.getCustomerDetails(widget.customerId!);
      if (model != null) {
        await _fillCustomerData(model);
      }
    }
    setState(() => loading = false);
  }

  Future<void> _fillCustomerData(EditCustomerModel model) async {
    cmpnyNmeCtrl.text = model.companyName;
    if (model.companyTypeName != null) {
      _selectedType = cmpnyPrsnl.firstWhere(
        (x) => x.name.toLowerCase() == model.companyTypeName!.toLowerCase(),
        orElse: () => cmpnyPrsnl.first,
      );
    }
    final adminPro = getAdminPro(context);
    if (model.companyCategoryName != null) {
      final match = adminPro.custCmpnyType.firstWhere(
        (e) => e.name == model.companyCategoryName,
        orElse: () => DropdownItem(id: 0, name: ""),
      );
      selectedCompanyType = match.id != 0 ? match.id : null;
    }
    if (model.customerRankName != null) {
      final match = adminPro.customerRank.firstWhere(
        (e) => e.name == model.customerRankName,
        orElse: () => DropdownItem(id: 0, name: ""),
      );
      selectedCustRank = match.id != 0 ? match.id : null;
    }
    customerImageUrl = model.imageUrl;
    await _fillContacts(model.contacts);
    setState(() {});
  }

  Future<void> _fillContacts(List<EditCustomerContact> contacts) async {
    contactForms = [];
    for (final c in contacts) {
      final form = ContactFormModel();
      form.id = c.contactId;
      form.existingId = c.contactId;
      form.imageUrl = c.imageUrl;
      form.image = null;
      form.firstName.text = c.name;
      form.lastName.text = c.lastName;
      form.username.text = c.username;
      form.selectedLanguageIds = c.languageIds;
      if (c.emails.isEmpty) {
        form.emails = [TextEditingController()];
      } else {
        form.emails = c.emails
            .map((e) => TextEditingController(text: e))
            .toList();
      }
      if (c.phones.isEmpty) {
        form.phoneFields = [
          PhoneField(type: phoneTypes[1], controller: TextEditingController()),
        ];
      } else {
        form.phoneFields = c.phones.map((p) {
          final type = phoneTypes.firstWhere(
            (t) => t.apiValue == p.type,
            orElse: () => phoneTypes.last,
          );
          return PhoneField(
            type: type,
            controller: TextEditingController(text: p.number),
          );
        }).toList();
      }
      contactForms.add(form);
    }
    if (contactForms.isEmpty) contactForms.add(ContactFormModel());
    printData(
      title: "CONTACT IDS AFTER FILL:",
      data: contactForms.map((e) => e.existingId).toList(),
    );
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (var cf in contactForms) {
      try {
        cf.username.dispose();
        cf.password.dispose();
        cf.confirmPassword.dispose();
        cf.firstName.dispose();
        cf.lastName.dispose();
        for (var c in cf.emails) {
          c.dispose();
        }
        for (var p in cf.phoneFields) {
          p.controller.dispose();
        }
      } catch (_) {}
    }
    cmpnyNmeCtrl.dispose();
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
        setState(() => selectedImage = File(result.files.single.path!));
      }
    } catch (e) {
      printData(title: 'from pickImage', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  void _onSave(dynamic context) async {
    setState(() => formSubmitted = true);

    for (var model in contactForms) {
      if (model.password.text.trim().isNotEmpty ||
          model.confirmPassword.text.trim().isNotEmpty) {
        if (model.password.text.trim() != model.confirmPassword.text.trim()) {
          showToast(
            message:
                "Password and Confirm Password do not match for ${model.firstName.text.isNotEmpty ? model.firstName.text : 'a contact'}",
          );
          return;
        }
      }
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final clipro = getCustPro(context);
    final companyTypeStr = selectedCompanyType?.toString() ?? '';
    final success = await clipro.editCust(
      companyName: cmpnyNmeCtrl.text.trim(),
      clientLanguages: selectedLanguageIds,
      status: 1,
      contacts: contactForms,
      companyType: companyTypeStr,
      custImage: selectedImage,
      context: context,
      clientId: widget.clientId ?? 0,
      categoryType: selectedCompanyType ?? 0,
      custRank: selectedCustRank ?? 0,
      custId: widget.customerId ?? 0,
    );

    if (success) {
      Navigator.pop(context);
    }
  }

  Widget contactProfileImage({
    required File? image,
    required String? imageUrl,
    required VoidCallback onPick,
  }) {
    final hasLocal = image != null;
    final hasRemote = imageUrl != null && imageUrl.isNotEmpty;
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
                image: DecorationImage(
                  image: hasLocal
                      ? FileImage(image) as ImageProvider
                      : (hasRemote
                            ? NetworkImage(imageUrl)
                            : AssetImage(Paths.user) as ImageProvider),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onPick,
              child: ImageWidget(image: Paths.edit, width: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactPhoneSection(ContactFormModel model) {
    final pro = getCustPro(context);
    final Color primaryColor =
        widget.isFromClient && pro.client?.brandingPrimaryColor != null
        ? hexToColor(pro.client!.brandingPrimaryColor)
        : AppColors.primary;
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
                                    : (field.type.label == "Land Phone"
                                          ? "Landline"
                                          : "other"),
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
                        width: isLast ? 40.w : 40.w,
                        height: isLast ? 40.h : 40.h,
                        decoration: isLast
                            ? BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: isLast
                            ? Container(
                                width: 40.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: primaryColor,
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
    final pro = getCustPro(context);

    final Color primaryColor =
        widget.isFromClient && pro.client?.brandingPrimaryColor != null
        ? hexToColor(pro.client!.brandingPrimaryColor)
        : AppColors.primary;
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
                      width: isLast ? 40.w : 40.w,
                      height: isLast ? 40.h : 40.h,
                      decoration: isLast
                          ? BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: isLast
                          ? Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: primaryColor,
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
                              orElse: () =>
                                  DropdownItem(id: id, name: id.toString()),
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
                                      setState(
                                        () => model.selectedLanguageIds.remove(
                                          id,
                                        ),
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
            child: SizedBox(
              height: 250.h,
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  children: getAdminPro(context).languages.map((lang) {
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

  Widget profileImage() {
    final hasLocal = selectedImage != null;
    final hasRemote = customerImageUrl != null && customerImageUrl!.isNotEmpty;

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
              image: DecorationImage(
                image: hasLocal
                    ? FileImage(selectedImage!) as ImageProvider
                    : (hasRemote
                          ? NetworkImage(customerImageUrl!)
                          : AssetImage(Paths.user) as ImageProvider),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: pickImage,
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
              ImageWidget(image: Paths.customers, fit: BoxFit.cover, width: 27),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Customer",
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
          onChanged: (item) => onChanged(item),
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
    final cust = getCustPro(context);
    final Color primaryColor =
        widget.isFromClient && cust.client?.brandingPrimaryColor != null
        ? hexToColor(cust.client!.brandingPrimaryColor)
        : AppColors.primary;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
      child: Column(
        children: [
          _roundedDropdown(
            label: 'Company or Personal',
            value: _selectedType,
            hint: 'Select',
            items: cmpnyPrsnl,
            onChanged: (v) => setState(() => _selectedType = v),
            parentContext: context,
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
            label: '*Customer\'s Company Type',
            value: pro.custCmpnyType.any((e) => e.id == selectedCompanyType)
                ? pro.custCmpnyType.firstWhere(
                    (e) => e.id == selectedCompanyType,
                  )
                : null,
            hint: 'Select',
            items: pro.custCmpnyType,
            onChanged: (item) => setState(() => selectedCompanyType = item?.id),
          ),
          Spacers.sb8(),
          _roundedDropdown(
            parentContext: context,
            label: '*Customer\'s Rank',
            value: pro.customerRank.any((e) => e.id == selectedCustRank)
                ? pro.customerRank.firstWhere((e) => e.id == selectedCustRank)
                : null,
            hint: 'Select',
            items: pro.customerRank,
            onChanged: (item) => setState(() => selectedCustRank = item?.id),
          ),
          Spacers.sb8(),
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
                buttonColor: primaryColor,
                textColor: AppColors.black,
                stadium: false,
                borderRadius: 18,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                onTap: () {
                  setState(() => contactForms.add(ContactFormModel()));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactFormSection(int index, ContactFormModel model) {
    final pro = getCustPro(context);

    final Color primaryColor =
        widget.isFromClient && pro.client?.brandingPrimaryColor != null
        ? hexToColor(pro.client!.brandingPrimaryColor)
        : AppColors.primary;
    bool isMain = index == 0;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 15.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: isMain ? primaryColor : AppColors.formHint,
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
              color: isMain ? primaryColor : AppColors.formHint,
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
                    onTap: () => setState(() => contactForms.removeAt(index)),
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
                  imageUrl: model.imageUrl,
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

                _roundedTextField(
                  controller: model.password,
                  label: "Password",
                  obscure: true,
                  hint: "Type Password",
                  errorText: null,
                  regErrorText: null,
                  regExpCondition: Regx.optionalText,
                ),
                Spacers.sb8(),
                _roundedTextField(
                  controller: model.confirmPassword,
                  label: "Confirm Password",
                  obscure: true,
                  hint: "Type Confirm Password",
                  errorText: null,
                  regErrorText: null,
                  regExpCondition: Regx.optionalText,
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
}
