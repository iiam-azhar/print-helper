import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../tab_constants/paths.dart';
import '../tab_constants/strings.dart';
import 'package:print_helper/providers/client_pro.dart';
import '../tab_utils/console_util.dart';
import '../tab_utils/regx.dart';
import '../tab_widgets/tab_custom_button.dart';
import '../tab_widgets/tab_field_widget.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_spacers.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_constants/colors.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/models/client_models.dart';
import 'package:print_helper/models/edit_client_models.dart';
import '../tab_services/helpers.dart';
import '../tab_widgets/tab_toasts.dart';
import 'package:print_helper/models/contact_form_models.dart';
import '../tab_utils/formatter.dart';

class EditClient extends StatefulWidget {
  final int clientId;
  const EditClient({super.key, required this.clientId});

  @override
  State<EditClient> createState() => EditClientState();
}

class EditClientState extends State<EditClient> {
  final _formKey = GlobalKey<FormState>();

  int? selectedCompanyType;
  int? selectedClientRank;
  bool pickingFile = false;
  File? selectedImage;
  File? selectedLogo;
  int? openPhoneDropdownIndex;
  int? selectedState;
  int? selectedCity;
  bool loading = false;
  bool formSubmitted = false;
  String? clientImageUrl;
  String? brandingLogoUrl;
  final addressCtrl = TextEditingController();
  final addressTwoCtrl = TextEditingController();
  final zipCodeCtrl = TextEditingController();
  final brandUrlCtrl = TextEditingController();
  final cmpnyNmeCtrl = TextEditingController();

  Color _primaryColor = const Color(0xFF4CC9F0);
  Color _secondaryColor = const Color(0xFFAEB0B3);

  List<int> selectedLanguageIds = [];
  List<int> selectedStaffIds = [];
  bool showStaffDropdown = false;
  int visibleStaffCount = 5;
  bool isLoadingMore = false;
  final ScrollController staffScrollController = ScrollController();
  final TextEditingController staffSearchCtrl = TextEditingController();
  List<ContactFormModel> contactForms = [];
  EditClientModel? _clientModel;
  Map<int, bool> passwordVisibility = {}; // Track visibility for each contact
  Map<int, bool> confirmPasswordVisibility =
      {}; // Track visibility for each contact

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
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    setState(() => loading = true);
    final adminPro = getAdminPro(context);
    final clipro = getClientPro(context);
    await Future.wait([
      adminPro.fetchAllDropdownData(context),
      clipro.fetchStates(),
      clipro.fetchStaff(),
    ]);
    final model = await clipro.getClientDetails(widget.clientId);
    if (model != null) {
      setState(() => _clientModel = model);
      await _fillClientData(model);
    }
    setState(() => loading = false);
  }

  Future<void> _fillClientData(EditClientModel model) async {
    cmpnyNmeCtrl.text = model.companyName;
    addressCtrl.text = model.address;
    addressTwoCtrl.text = model.address2 ?? "";
    zipCodeCtrl.text = model.zipcode;
    brandUrlCtrl.text = model.brandingUrl ?? "";
    clientImageUrl = model.image;
    brandingLogoUrl = model.brandingLogo;
    // company_type may be null, string id,  an object in API.
    // We store selectedCompanyType as int? and handle safely.
    if (model.companyType != null && model.companyType!.isNotEmpty) {
      selectedCompanyType = int.tryParse(model.companyType!);
    } else {
      selectedCompanyType = null;
    }
    selectedClientRank = model.clientRank?.id;
    _primaryColor = _safeHexToColor(model.brandingPrimaryColor);
    _secondaryColor = _safeHexToColor(model.brandingSecondaryColor);
    // Set state & load cities for the state (important)
    selectedState = model.state?.id;
    if (model.state != null) {
      // call provider to load cities for given state id
      getClientPro(context).loadCities(model.state!.id);
      selectedCity = model.city?.id;
    } else {
      selectedCity = null;
    }
    selectedLanguageIds = model.languages.map((e) => e.id).toList();
    // assignedStaff: API may return []  list of ints  array of objects -> handle all.
    final staffIds = model.assignedStaff
        .map<int>((s) {
          if (s is int) return s;
          if (s is Map && s.containsKey('id')) {
            return (s['id'] is int)
                ? s['id'] as int
                : int.tryParse(s['id'].toString()) ?? 0;
          }
          if (s is String) return int.tryParse(s) ?? 0;
          return 0;
        })
        .where((id) => id != 0)
        .toList();
    setState(() {
      selectedStaffIds = staffIds;
    });
    await _fillContacts(model);
    setState(() {});
  }

  Future<void> _fillContacts(EditClientModel model) async {
    contactForms = [];
    for (final c in model.contacts) {
      final form = ContactFormModel();
      form.id = c.id;
      form.existingId = c.id;
      form.imageUrl = c.image;
      form.image = null;
      form.firstName.text = c.name!;
      form.lastName.text = c.lastName!;
      form.username.text = c.username!;
      form.selectedLanguageIds = c.contactDetails.languages
          .map((l) => l.id)
          .toList();
      // form.emails = c.contactDetails.emails
      //     .map((e) => TextEditingController(text: e))
      //     .toList();
      if (c.contactDetails.emails.isEmpty) {
        form.emails = [TextEditingController()];
      } else {
        form.emails = c.contactDetails.emails
            .map((e) => TextEditingController(text: e))
            .toList();
      }
      if (c.contactDetails.phones.isEmpty) {
        form.phoneFields = [
          PhoneField(
            type: phoneTypes.first,
            controller: TextEditingController(),
          ),
        ];
      } else {
        form.phoneFields = c.contactDetails.phones.map((p) {
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
      // form.phoneFields = c.contactDetails.phones.map((p) {
      //   final type = phoneTypes.firstWhere(
      //     (t) => t.apiValue == p.type,
      //     orElse: () => phoneTypes.last,
      //   );
      //   return PhoneField(
      //     type: type,
      //     controller: TextEditingController(text: p.number),
      //   );
      // }).toList();
      debugPrint(
        "CONTACT IDS AFTER FILL: ${contactForms.map((e) => e.existingId).toList()}",
      );
      contactForms.add(form);
    }
  }

  Widget _twilioSection(EditClientModel? model) {
    return const SizedBox.shrink();
  }

  // Removed unused _twilioRow method
  /*
  Widget _twilioRow({    required String name,
    required String number,
    String? image,
    required bool isCompany,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.grey, width: .5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: image != null && image.isNotEmpty
                  ? ImageWidget(
                      image: image,
                      width: 35,
                      height: 35,
                      fit: BoxFit.contain,
                      errorWidget: ImageWidget(
                        image: isCompany ? Paths.clientprofile : Paths.user,
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      isCompany ? Paths.clientprofile : Paths.user,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          Spacers.sbw12(),
          Expanded(
            child: TextWidget(
              text: name,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          TextWidget(
            text: number,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: AppColors.black,
          ),
        ],
      ),
    );
  }
  */

  @override
  void dispose() {
    staffScrollController.dispose();
    staffSearchCtrl.dispose();
    addressCtrl.dispose();
    addressTwoCtrl.dispose();
    zipCodeCtrl.dispose();
    brandUrlCtrl.dispose();
    cmpnyNmeCtrl.dispose();
    for (var c in contactForms) {
      for (var email in c.emails) {
        email.dispose();
      }
      for (var p in c.phoneFields) {
        p.controller.dispose();
      }
    }
    super.dispose();
  }

  Color _safeHexToColor(String? hex) {
    try {
      if (hex == null || hex.trim().isEmpty) return const Color(0xFF4CC9F0);
      var cleaned = hex.replaceFirst('#', '').trim();
      // if 6 digits -> assume no alpha, else if 8 take last 6
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      } else {
        return Color(int.parse('FF$cleaned', radix: 16));
      }
    } catch (e) {
      return const Color(0xFF4CC9F0);
    }
  }

  String _colorToHex(Color c) {
    final argb = c.toARGB32();
    final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  Future<void> pickClientImage() async {
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
      printData(title: 'pickClientImage', data: '$e', e: true);
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
        setState(() => selectedLogo = File(result.files.single.path!));
      }
    } catch (e) {
      printData(title: 'pickLogo', data: '$e', e: true);
    } finally {
      setState(() => pickingFile = false);
    }
  }

  void _openColorPicker({required bool isPrimary}) {
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
              onPressed: () => Navigator.of(context).pop(),
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

  void _onSave(dynamic context) async {
    setState(() {
      formSubmitted = true;
    });
    if (selectedStaffIds.isEmpty) {
      showToast(message: "Please assign at least one staff member");
      return;
    }
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      showToast(message: "Please fix the errors in the form");
      return;
    }
    final clipro = getClientPro(context);
    final success = await clipro.updateClient(
      clientId: widget.clientId,
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
      brandingPrimary: _colorToHex(_primaryColor),
      brandingSecondary: _colorToHex(_secondaryColor),
      brandingUrl: brandUrlCtrl.text.trim(),
      clientImage: selectedImage,
      brandinglogo: selectedLogo,
      context: context,
    );
    if (success) {
      showToast(message: "Client updated successfully");
      Navigator.of(context).pop(true);
    } else {
      showToast(message: "Failed to update client");
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
              bottom: Radius.circular(25),
            ),
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
                      autovalidateMode: formSubmitted
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      child: Column(
                        children: [
                          Spacers.sb10(),
                          profileImageSection(),
                          Spacers.sb15(),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                _brandingLogoWidget(),
                                Spacers.sb8(),
                                _brandingColorWidget(
                                  label: "Branding Primary Color",
                                  color: _primaryColor,
                                  hex: _colorToHex(_primaryColor),
                                  onTap: () =>
                                      _openColorPicker(isPrimary: true),
                                ),
                                Spacers.sb8(),
                                _brandingColorWidget(
                                  label: "Branding Secondary Color",
                                  color: _secondaryColor,
                                  hex: _colorToHex(_secondaryColor),
                                  onTap: () =>
                                      _openColorPicker(isPrimary: false),
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
                                  regErrorText:
                                      'Please enter a valid company name',
                                  regExpCondition: Regx.addressRegExp,
                                ),
                                Spacers.sb8(),
                                _roundedDropdown(
                                  parentContext: context,
                                  label: selectedCompanyType == null
                                      ? 'Client\'s Company Type'
                                      : '*Client\'s Company Type',
                                  value: findById(
                                    getAdminPro(context).clientCmpnyType,
                                    selectedCompanyType,
                                  ),
                                  hint: 'Select',
                                  items: getAdminPro(context).clientCmpnyType,
                                  onChanged: (item) {
                                    setState(
                                      () => selectedCompanyType = item?.id,
                                    );
                                  },
                                ),
                                Spacers.sb8(),
                                _roundedDropdown(
                                  parentContext: context,
                                  label: '*Client\'s Rank',
                                  value: findById(
                                    pro.clientRank,
                                    selectedClientRank,
                                  ),
                                  hint: 'Select',
                                  items: pro.clientRank,
                                  onChanged: (item) => setState(
                                    () => selectedClientRank = item?.id,
                                  ),
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
                                  label: 'Address 2 (optional)',
                                  hint: 'Type Unit,Apt Etc Etc.',
                                  regExpCondition: Regx.optionalText,
                                  errorText: null,
                                  regErrorText: null,
                                ),
                                Spacers.sb8(),
                                _roundedDropdown(
                                  parentContext: context,
                                  label: '*State',
                                  value: findById(
                                    clipro.stateDropdown,
                                    selectedState,
                                  ),
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
                                if (selectedState != null &&
                                    clipro.cityDropdown.isNotEmpty)
                                  _roundedDropdown(
                                    parentContext: context,
                                    label: '*City',
                                    value: findById(
                                      clipro.cityDropdown,
                                      selectedCity,
                                    ),
                                    hint: selectedState == null
                                        ? 'Select state first'
                                        : 'Select City',
                                    items: clipro.cityDropdown,
                                    onChanged: (item) =>
                                        setState(() => selectedCity = item?.id),
                                  ),
                                if (selectedState != null &&
                                    clipro.cityDropdown.isNotEmpty)
                                  Spacers.sb8(),
                                _roundedTextField(
                                  controller: zipCodeCtrl,
                                  label: '*Zipcode',
                                  hint: 'Type Zipcode (4-10 digits)',
                                  errorText:
                                      "Zipcode is required (4-10 digits)",
                                  regErrorText: "Zipcode must be 4-10 digits",
                                  regExpCondition: Regx.zipcodeRegExp,
                                ),
                                Spacers.sb8(),
                                _assignStaff(clipro),
                                Spacers.sb12(),
                                _twilioSection(_clientModel),
                                Column(
                                  children: contactForms
                                      .asMap()
                                      .entries
                                      .map(
                                        (entry) => _contactFormSection(
                                          entry.key,
                                          entry.value,
                                        ),
                                      )
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
                                        setState(
                                          () => contactForms.add(
                                            ContactFormModel(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Spacers.sb25(),
                              ],
                            ),
                          ),
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
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
              ImageWidget(
                image: Paths.clientprofile,
                fit: BoxFit.cover,
                width: 27,
              ),
              Spacers.sbw10(),
              Expanded(
                child: TextWidget(
                  text: "Edit Client",
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

  Widget profileImageSection() {
    final apiImageUrl = clientImageUrl;
    ImageProvider imageProvider;
    if (selectedImage != null) {
      imageProvider = FileImage(selectedImage!);
    } else if (apiImageUrl != null && apiImageUrl.isNotEmpty) {
      imageProvider = NetworkImage(apiImageUrl);
    } else {
      imageProvider = AssetImage(Paths.user);
    }
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: pickClientImage,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: pickClientImage,
            child: ImageWidget(image: Paths.edit, width: 20),
          ),
        ),
      ],
    );
  }

  Widget _cancelSaveBtn(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8.0),
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

  Widget _brandingLogoWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
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
                height: 45,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
              onTap: pickLogo,
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
          padding: EdgeInsets.only(left: 15),
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
                  height: 47,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(15),
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    return CustomTextField(
      controller: controller,
      regExpCondition: regExpCondition ?? Regx.passwordRegExp,
      obscureText: !isVisible,
      passField: true,
      errorText: errorText,
      regErrorText: regErrorText,
      hintText: hint,
      labelText: label,
      outlined: true,
      suffixIcon: GestureDetector(
        onTap: onVisibilityToggle,
        child: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey.shade600,
          size: 20,
        ),
      ),
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

  Widget _assignStaff(ClientPro clipro) {
    final bool hasError = selectedStaffIds.isEmpty && formSubmitted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 15),
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
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
                              orElse: () =>
                                  StaffModel(id: id, name: "Staff #$id"),
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
                                    text: staff.name,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  Spacers.sbw8(),
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => selectedStaffIds.remove(id),
                                    ),
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
                  size: 30,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(left: 15, top: 4),
            child: Text(
              "Please assign at least one staff member",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        if (showStaffDropdown)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      controller: staffSearchCtrl,
                      decoration: InputDecoration(
                        hintText: "Search staff...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
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
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Center(
                                  child: isLoadingMore
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : SizedBox(height: 20),
                                ),
                              );
                            }
                            final staff = displayList[index];
                            final isSelected = selectedStaffIds.contains(staff.id);
                            return GestureDetector(
                              onTap: () => setState(() {
                                isSelected
                                    ? selectedStaffIds.remove(staff.id)
                                    : selectedStaffIds.add(staff.id);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                                margin: const EdgeInsets.symmetric(
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
                                        text: staff.name,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        size: 24,
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

  Widget _contactFormSection(int index, ContactFormModel model) {
    final isMain = index == 0;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
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
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: isMain ? AppColors.amber : AppColors.formHint,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
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
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacers.sb15(),
                contactProfileImage(
                  image: model.image,
                  apiImage: model.imageUrl,
                  onPick: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'jpeg'],
                    );
                    if (picked != null && picked.files.single.path != null) {
                      setState(() {
                        model.image = File(picked.files.single.path!);
                        model.imageUrl = null;
                      });
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
                  label: "Password",
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
                  regErrorText: AppStrings.passRegError,
                  regExpCondition: Regx.optionalPasswordRegExp,
                ),
                Spacers.sb8(),
                _passwordField(
                  controller: model.confirmPassword,
                  label: "Confirm Password",
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
                  regErrorText: AppStrings.passRegError,
                  regExpCondition: Regx.optionalPasswordRegExp,
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
    required String? apiImage,
    required VoidCallback onPick,
  }) {
    ImageProvider provider;
    if (image != null) {
      provider = FileImage(image);
    } else if (apiImage != null && apiImage.isNotEmpty) {
      provider = NetworkImage(apiImage);
    } else {
      provider = AssetImage(Paths.user);
    }
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
                image: DecorationImage(image: provider, fit: BoxFit.cover),
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
            final index = entry.key;
            final field = entry.value;
            final isLast = index == model.phoneFields.length - 1;
            return Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                        () => openPhoneDropdownIndex =
                            openPhoneDropdownIndex == index ? null : index,
                      ),
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
                                    : (field.type.label == "Land Phone"
                                          ? "Landline"
                                          : "other"),
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
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
                          setState(
                            () => model.phoneFields.add(
                              PhoneField(
                                type: PhoneType("Phone", Paths.call, "mobile"),
                                controller: TextEditingController(),
                              ),
                            ),
                          );
                        } else {
                          setState(() => model.phoneFields.removeAt(index));
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
                        final selected = field.type.label == type.label;
                        return GestureDetector(
                          onTap: () => setState(() {
                            field.type = type;
                            openPhoneDropdownIndex = null;
                          }),
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

  List<PhoneType> phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];

  Widget _contactEmailSection(ContactFormModel model) {
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
            final index = entry.key;
            final ctrl = entry.value;
            final isLast = index == model.emails.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: EmailListTextField(controller: ctrl)),
                  Spacers.sbw12(),
                  GestureDetector(
                    onTap: () => setState(() {
                      if (isLast) {
                        model.emails.add(TextEditingController());
                      } else {
                        model.emails.removeAt(index);
                      }
                    }),
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
          onTap: () => setState(
            () => model.showLanguageDropdown = !model.showLanguageDropdown,
          ),
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
                              orElse: () =>
                                  DropdownItem(id: id, name: 'Lang #$id'),
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
                                    onTap: () => setState(
                                      () =>
                                          model.selectedLanguageIds.remove(id),
                                    ),
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
                    final isSelected = model.selectedLanguageIds.contains(
                      lang.id,
                    );
                    return GestureDetector(
                      onTap: () => setState(
                        () => isSelected
                            ? model.selectedLanguageIds.remove(lang.id)
                            : model.selectedLanguageIds.add(lang.id),
                      ),
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
}
