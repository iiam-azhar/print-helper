import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:print_helper/providers/auth_pro.dart';
import '../../tab_utils/console_util.dart';
import '../../tab_utils/regx.dart';
import '../../tab_widgets/tab_field_widget.dart';
import '../../tab_widgets/tab_toasts.dart';
import 'package:provider/provider.dart';

import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/models/contact_form_models.dart';
import '../../tab_services/helpers.dart';
import '../../tab_utils/formatter.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_custom_button.dart';

import 'package:print_helper/models/edit_customer_models.dart';

class DialogEditCustomer extends StatefulWidget {
  final int? clientId;
  final int? customerId;
  const DialogEditCustomer({super.key, this.clientId, this.customerId});

  @override
  State<DialogEditCustomer> createState() => _DialogEditCustomerState();
}

class _DialogEditCustomerState extends State<DialogEditCustomer> {
  String? customerImageUrl;
  final _formKey = GlobalKey<FormState>();
  int? selectedCompanyType;
  int? selectedCustRank;
  bool pickingFile = false;
  File? selectedImage;

  DropdownItem? _selectedType;
  int? openPhoneDropdownIndex;
  bool formSubmitted = false;

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
  List<PhoneField> phoneFields = [
    PhoneField(
      type: PhoneType("Phone", Paths.call, "phone"),
      controller: TextEditingController(),
    ),
  ];
  List<PhoneRow> phones = [PhoneRow()];
  List<TextEditingController> emailCtrls = [TextEditingController()];
  List<ContactFormModel> contactForms = [];

  bool loading = false;

  @override
  void initState() {
    super.initState();
    contactForms.add(ContactFormModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    setState(() => loading = true);
    final adminPro = getAdminPro(context);
    final custPro = getCustPro(context);
    await Future.wait([adminPro.fetchAllDropdownData(context)]);
    if (widget.clientId != null && widget.customerId != null) {
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
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: 600,
        height: 750,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _companyDetailsSection(),
                      const SizedBox(height: 24),
                      ...contactForms.asMap().entries.map(
                        (entry) => _contactFormSection(
                          entry.key,
                          entry.value,
                          AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            _cancelSaveBtn(context),
          ],
        ),
      ),
    );
  }

  Widget _companyDetailsSection() {
    final pro = getAdminPro(context, listen: true);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextWidget(
              text: 'COMPANY DETAILS',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      profileImage(),
                      const SizedBox(height: 12),
                      const TextWidget(
                        text: 'Company logo · JPG, PNG, WEBP, GIF (max 800KB)',
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roundedDropdown(
                        label: 'Company or Personal *',
                        value: _selectedType,
                        hint: 'Select',
                        items: cmpnyPrsnl,
                        onChanged: (v) => setState(() => _selectedType = v),
                        parentContext: context,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _roundedTextField(
                        controller: cmpnyNmeCtrl,
                        label: 'Company / Display Name',
                        hint: 'e.g. Lublas Co.',
                        errorText: 'This field is required',
                        regErrorText: 'Please enter a valid company name',
                        regExpCondition: Regx.addressRegExp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roundedDropdown(
                        parentContext: context,
                        label: 'Company Type',
                        value:
                            pro.custCmpnyType.any(
                              (e) => e.id == selectedCompanyType,
                            )
                            ? pro.custCmpnyType.firstWhere(
                                (e) => e.id == selectedCompanyType,
                              )
                            : null,
                        hint: 'Select',
                        items: pro.custCmpnyType,
                        emptyText: 'No types available',
                        onChanged: (item) {
                          setState(() => selectedCompanyType = item?.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _roundedDropdown(
                        parentContext: context,
                        label: 'Customer Rank',
                        value:
                            pro.customerRank.any(
                              (e) => e.id == selectedCustRank,
                            )
                            ? pro.customerRank.firstWhere(
                                (e) => e.id == selectedCustRank,
                              )
                            : null,
                        hint: 'Select',
                        items: pro.customerRank,
                        emptyText: 'No ranks available',
                        onChanged: (item) {
                          setState(() => selectedCustRank = item?.id);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelSaveBtn(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: CustomButton(
              title: "Cancel",
              onTap: () => Navigator.pop(context),
              buttonColor: Colors.white,
              textColor: Colors.black,
              showBorder: true,
              borderColor: Colors.grey.shade300,
              borderRadius: 18,
              height: 40,
              stadium: false,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: CustomButton(
              title: formSubmitted ? "Saving..." : "Save Changes",
              onTap: formSubmitted ? null : () => _onSave(context),
              buttonColor: const Color(0xFF22C55E),
              textColor: Colors.white,
              borderRadius: 18,
              height: 40,
              stadium: false,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactFormSection(
    int index,
    ContactFormModel model,
    Color primaryColor,
  ) {
    bool isMain = index == 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: isMain ? 'MAIN CONTACT' : 'ADDITIONAL CONTACT',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
                if (!isMain)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        contactForms.removeAt(index);
                      });
                    },
                    child: const ImageWidget(image: Paths.delete, width: 20),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: EdgeInsets.all(10),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roundedTextField(
                        controller: model.password,
                        label: "Password",
                        obscure: model.obscurePass,
                        isPassword: true,
                        onToggle: () => setState(
                          () => model.obscurePass = !model.obscurePass,
                        ),
                        hint: "Type Password",
                        regErrorText: "Invalid",
                        regExpCondition: Regx.optionalPasswordRegExp,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _roundedTextField(
                        controller: model.confirmPassword,
                        label: "Confirm Password",
                        obscure: model.obscureConfirm,
                        isPassword: true,
                        onToggle: () => setState(
                          () => model.obscureConfirm = !model.obscureConfirm,
                        ),
                        hint: "Type Confirm Password",
                        regErrorText: "Invalid",
                        regExpCondition: Regx.optionalPasswordRegExp,
                      ),
                    ),
                  ],
                ),
                Spacers.sb8(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _roundedTextField(
                        controller: model.firstName,
                        label: "*First Name",
                        hint: "Type First Name",
                        errorText: "Required",
                        regErrorText: "Invalid",
                        regExpCondition: Regx.nameRegExp,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _roundedTextField(
                        controller: model.lastName,
                        label: "*Last Name",
                        hint: "Type Last Name",
                        errorText: "Required",
                        regErrorText: "Invalid",
                        regExpCondition: Regx.nameRegExp,
                      ),
                    ),
                  ],
                ),
                Spacers.sb8(),
                _languageSec(model),
                Spacers.sb8(),
                _contactPhoneSection(model, primaryColor),
                Spacers.sb8(),
                _contactEmailSection(model, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contactProfileImage({
    required File? image,
    String? imageUrl,
    required VoidCallback onPick,
  }) {
    final hasRemote = imageUrl != null && imageUrl.isNotEmpty;
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: image != null
                    ? DecorationImage(
                        image: FileImage(image),
                        fit: BoxFit.cover,
                      )
                    : (hasRemote
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : DecorationImage(
                              image: AssetImage(Paths.user),
                              fit: BoxFit.contain,
                            )),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => onPick,
              child: ImageWidget(image: Paths.edit, width: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactPhoneSection(ContactFormModel model, Color primaryColor) {
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final isContact = authPro.user?.roleName == "CONTACT";
    final hasPhoneField = model.phoneFields.any(
      (field) => field.type.label == "Phone",
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
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
                        height: 45,
                        width: 90,
                        padding: EdgeInsets.symmetric(horizontal: 10),
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
                            ImageWidget(image: field.type.image, width: 20),
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
                                // hintText: "Type ${field.type.label}",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
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
                        width: isLast ? 40 : null,
                        height: isLast ? 40 : null,
                        decoration: isLast
                            ? BoxDecoration(
                                color: isContact
                                    ? primaryColor
                                    : Colors.yellow.shade600,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: isLast
                            ? Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isContact
                                      ? primaryColor
                                      : Colors.yellow.shade600,
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
                if (index != model.phoneFields.length - 1) Spacers.sb10(),
                if (openPhoneDropdownIndex == index)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 6, bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
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
                              vertical: 12,
                              horizontal: 14,
                            ),
                            margin: EdgeInsets.only(bottom: 3, top: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
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
                                    size: 22,
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

  Widget _contactEmailSection(ContactFormModel model, Color primaryColor) {
    final authPro = Provider.of<AuthPro>(context, listen: false);
    final isContact = authPro.user?.roleName == "CONTACT";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
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
              padding: EdgeInsets.only(bottom: 10),
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
                      width: isLast ? 40 : null,
                      height: isLast ? 40 : null,
                      decoration: isLast
                          ? BoxDecoration(
                              color: isContact
                                  ? primaryColor
                                  : Colors.yellow.shade600,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: isLast
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isContact
                                    ? primaryColor
                                    : Colors.yellow.shade600,
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
          onTap: () {
            setState(
              () => model.showLanguageDropdown = !model.showLanguageDropdown,
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                  size: 30,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
        if (model.showLanguageDropdown)
          Container(
            margin: EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
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
                          vertical: 12,
                          horizontal: 10,
                        ),
                        margin: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE9F5D4)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
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
            ),
          ),
      ],
    );
  }

  Widget profileImage() {
    final hasRemote = customerImageUrl != null && customerImageUrl!.isNotEmpty;
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: pickImage,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              image: selectedImage != null
                  ? DecorationImage(
                      image: FileImage(selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : (hasRemote
                        ? DecorationImage(
                            image: NetworkImage(customerImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : DecorationImage(
                            image: AssetImage(Paths.user),
                            fit: BoxFit.contain,
                          )),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const TextWidget(
            text: 'Edit Customer',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white, size: 24),
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
    VoidCallback? onToggle,
    String? errorText,
    String? regErrorText,
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
          alphaWithSpaceOnly:
              regExpCondition.pattern == Regx.nameRegExp.pattern,
          regExpCondition: regExpCondition,
          regErrorText: regErrorText,
          errorText: errorText,
          controller: controller,
          passField: isPassword,
          obscureText: obscure,
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
              ? GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
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
    String? emptyText,
  }) {
    final bool isEmpty = items.isEmpty;
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
          value: isEmpty ? null : value,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 30,
            color: isEmpty ? Colors.grey.shade400 : AppColors.black,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isEmpty ? Colors.grey.shade100 : Colors.white,
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
            text: isEmpty ? (emptyText ?? hint) : hint,
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: isEmpty ? Colors.grey.shade500 : Colors.black54,
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
          onChanged: isEmpty
              ? null
              : (item) {
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
