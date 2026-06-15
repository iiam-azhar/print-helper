import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/models/client_info_tabs_model.dart';
import 'package:print_helper/models/contact_form_models.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/services/api_routes.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../constants/colors.dart';
import '../../constants/paths.dart';
import 'package:provider/provider.dart';

import 'package:permission_handler/permission_handler.dart';
import '../../services/download_service.dart';
import '../../widgets/loaders.dart';

class ClientInfoScreen extends StatefulWidget {
  final int clientId;
  const ClientInfoScreen({super.key, required this.clientId});

  @override
  State<ClientInfoScreen> createState() => _ClientInfoScreenState();
}

class _ClientInfoScreenState extends State<ClientInfoScreen> {
  int _activeTab = 0;
  bool _infoFormInitialized = false;
  bool _bootstrappedLocationDropdowns = false;
  bool _canEditOnboardingChecklist = false;
  bool _isStaff = false;
  String? _uploadingAssetType;
  File? _selectedLogoFile;
  File? _selectedFaviconFile;

  final TextEditingController _brandingUrlCtrl = TextEditingController();
  final TextEditingController _primaryColorCtrl = TextEditingController();
  final TextEditingController _secondaryColorCtrl = TextEditingController();
  Color _primaryColor = const Color(0xFF4CC9F0);
  Color _secondaryColor = const Color(0xFFAEB0B3);
  final TextEditingController _companyNameCtrl = TextEditingController();
  final TextEditingController _companyPhoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _address2Ctrl = TextEditingController();
  final TextEditingController _zipCodeCtrl = TextEditingController();

  int? _selectedState;
  int? _selectedCity;
  int? _selectedCompanyType;
  int? _selectedClientRank;

  @override
  void initState() {
    super.initState();
    _loadChecklistPermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = getClientPro(context);
      pro.fetchStates();
      pro.getClientInfoTabs(widget.clientId);
      final adminPro = Provider.of<AdminPro>(context, listen: false);
      adminPro.fetchAllDropdownData(context);
    });
  }

  Future<void> _loadChecklistPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final roleName = (prefs.getString('role_name') ?? '').trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      _canEditOnboardingChecklist = roleName == 'admin';
      _isStaff = roleName == 'staff';
    });
  }

  @override
  void dispose() {
    _brandingUrlCtrl.dispose();
    _primaryColorCtrl.dispose();
    _secondaryColorCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _address2Ctrl.dispose();
    _zipCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Consumer<ClientPro>(
          builder: (context, pro, _) {
            final info = pro.currentClientInfoTabs?.info.isNotEmpty == true
                ? pro.currentClientInfoTabs!.info.first
                : null;
            final name = info?.companyName ?? 'Client';
            final companyLogo = info?.image ?? '';

            return Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50.r),
                    child:
                        companyLogo.isNotEmpty &&
                            companyLogo.toLowerCase() != 'null'
                        ? ImageWidget(
                            image: companyLogo,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          )
                        : ImageWidget(
                            image: Paths.user,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: TextWidget(
                    text: name,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Consumer<ClientPro>(
            builder: (context, pro, _) {
              final authPro = Provider.of<AuthPro>(context, listen: false);
              final roleName = authPro.user?.roleName ?? '';
              final isAdminOrStaff = roleName == 'ADMIN' || roleName == 'STAFF';

              if (!isAdminOrStaff) return const SizedBox();

              final info = pro.currentClientInfoTabs?.info.isNotEmpty == true
                  ? pro.currentClientInfoTabs!.info.first
                  : null;
              if (info == null) return const SizedBox();

              final isActive = info.status;

              return GestureDetector(
                onTap: () => _showToggleClientStatusDialog(
                  context,
                  info.companyName,
                  isActive,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFF87171)
                          : const Color(0xFF34D399),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.block : Icons.check_circle_outline,
                        size: 14,
                        color: isActive
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      TextWidget(
                        text: isActive ? 'Deactivate' : 'Activate',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 14.w),
        ],
      ),
      bottomNavigationBar: _activeTab == 0
          ? SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                child: SizedBox(
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: _activeTab == 0
                        ? () async {
                            final hasLogoAsset = _selectedLogoFile != null;
                            final hasFaviconAsset =
                                _selectedFaviconFile != null;

                            setState(() {
                              if (hasLogoAsset && !hasFaviconAsset) {
                                _uploadingAssetType = 'logo';
                              } else if (!hasLogoAsset && hasFaviconAsset) {
                                _uploadingAssetType = 'favicon';
                              } else {
                                _uploadingAssetType = null;
                              }
                            });

                            final pro = getClientPro(context);

                            // Fetch full client details (no loader — we manage it ourselves)
                            final clientDetails = await pro.getClientDetails(
                              widget.clientId,
                              showLoader: false,
                            );
                            if (clientDetails == null) {
                              showToast(
                                message: 'Failed to load client details',
                              );
                              setState(() {
                                _uploadingAssetType = null;
                              });
                              return;
                            }

                            // Convert EditContactModel list to ContactFormModel list
                            final contactForms = clientDetails.contacts.map((
                              ec,
                            ) {
                              final cf = ContactFormModel();
                              cf.existingId = ec.id;
                              cf.firstName.text = ec.name ?? '';
                              cf.lastName.text = ec.lastName ?? '';
                              cf.username.text = ec.username ?? '';
                              cf.selectedLanguageIds = ec
                                  .contactDetails
                                  .languages
                                  .map((l) => l.id)
                                  .toList();

                              // Map phones
                              if (ec.contactDetails.phones.isNotEmpty) {
                                cf.phoneFields = ec.contactDetails.phones
                                    .map(
                                      (p) => PhoneField(
                                        type: PhoneType(
                                          p.type,
                                          Paths.call,
                                          p.type.toLowerCase(),
                                        ),
                                        controller: TextEditingController(
                                          text: p.number,
                                        ),
                                      ),
                                    )
                                    .toList();
                              }

                              // Map emails
                              if (ec.contactDetails.emails.isNotEmpty) {
                                cf.emails = ec.contactDetails.emails
                                    .map((e) => TextEditingController(text: e))
                                    .toList();
                              }

                              cf.imageUrl = ec.image;
                              cf.existingImageUrl = ec.image;
                              return cf;
                            }).toList();

                            // Parse company type ID (stored as string)
                            final companyTypeId =
                                clientDetails.companyType != null
                                ? int.tryParse(clientDetails.companyType!) ?? 1
                                : 1;

                            // Call updateClient with all required parameters
                            debugPrint(
                              'SCREEN FAVICON FILE => ${_selectedFaviconFile?.path ?? 'NULL'}',
                            );
                            debugPrint(
                              'SCREEN LOGO FILE => ${_selectedLogoFile?.path ?? 'NULL'}',
                            );
                            final success = await pro.updateClient(
                              clientId: widget.clientId,
                              companyName: _companyNameCtrl.text.trim(),
                              address: _addressCtrl.text.trim(),
                              address2: _address2Ctrl.text.trim(),
                              state:
                                  _selectedState?.toString() ??
                                  clientDetails.state?.id.toString() ??
                                  '',
                              city:
                                  _selectedCity?.toString() ??
                                  clientDetails.city?.id.toString() ??
                                  '',
                              zipcode: _zipCodeCtrl.text.trim(),
                              clientLanguages: clientDetails.languages
                                  .map((l) => l.id)
                                  .toList(),
                              status: clientDetails.status ? 1 : 0,
                              assignedStaff: List<int>.from(
                                clientDetails.assignedStaff.whereType<int>(),
                              ),
                              contacts: contactForms,
                              companyType:
                                  _selectedCompanyType ??
                                  clientDetails.companyTypeId ??
                                  1,
                              clientRank:
                                  _selectedClientRank ??
                                  clientDetails.clientRankId ??
                                  1,
                              brandingPrimary: _primaryColorCtrl.text.trim(),
                              brandingSecondary: _secondaryColorCtrl.text
                                  .trim(),
                              brandingUrl: _brandingUrlCtrl.text.trim(),
                              // Backend may persist logo to `image` even when
                              // `branding_logo` is null, so send as both.
                              clientImage: _selectedLogoFile,
                              brandinglogo: _selectedLogoFile,
                              brandingFavicon: _selectedFaviconFile,
                              context: context,
                            );

                            if (success) {
                              setState(() {
                                _selectedLogoFile = null;
                                _selectedFaviconFile = null;
                              });
                              showToast(message: 'Client updated successfully');
                              // Refresh client info tabs
                              await pro.getClientInfoTabs(widget.clientId);
                            } else {
                              showToast(message: 'Failed to update client');
                            }

                            if (!mounted) return;
                            setState(() {
                              _uploadingAssetType = null;
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: const TextWidget(
                      text: 'Save',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Consumer<ClientPro>(
        builder: (context, pro, _) {
          if (pro.clientInfoTabsLoad) {
            return Center(child: showLoader());
          }

          final tabsData = pro.currentClientInfoTabs;
          if (tabsData == null || tabsData.info.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TextWidget(
                    text: 'Unable to load client info',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  SizedBox(height: 10.h),
                  FilledButton(
                    onPressed: () => pro.getClientInfoTabs(widget.clientId),
                    child: const TextWidget(
                      text: 'Retry',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final info = tabsData.info.first;
          _initializeInfoForm(info, pro);

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _headerCard(info),
                SizedBox(height: 12.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      _tabsBar(),
                      Divider(height: 1.h, color: const Color(0xFFE5E7EB)),
                      Padding(
                        padding: EdgeInsets.all(14.w),
                        child: _buildTabBody(tabsData, info, pro),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard(ClientInfoModel info) {
    final initial = info.companyName.isNotEmpty
        ? info.companyName[0].toUpperCase()
        : 'C';
    final secondaryChip = info.clientRank.isNotEmpty
        ? info.clientRank
        : (info.companyType.isNotEmpty ? info.companyType : 'Client');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF5D9),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.center,
                  child: info.image.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: ImageWidget(
                            image: info.image,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        )
                      : TextWidget(
                          text: initial,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0A8C42),
                        ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: info.companyName,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        maxLines: 2,
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: [
                          _chip(
                            info.status ? 'Active' : 'Inactive',
                            info.status
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEE2E2),
                            info.status
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B),
                          ),
                          _chip(
                            secondaryChip,
                            const Color(0xFFE0E7FF),
                            const Color(0xFF3730A3),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      TextWidget(
                        text: info.startedAtLabel.isNotEmpty
                            ? 'Started ${info.startedAtLabel}'
                            : 'Started -',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(16.r),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: 'WEEKLY EARNINGS',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xFF059669),
                      ),
                      TextWidget(
                        text: 'Total for this week',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
                TextWidget(
                  text: '\$0.00',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsBar() {
    final tabs = _isStaff 
        ? const ['Info', 'Onboarding & Training'] 
        : const ['Info', 'Agreement & Standards', 'Onboarding & Training'];
    return SizedBox(
      height: 54.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final active = _activeTab == index;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = index),
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFF3F4F6) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: TextWidget(
                text: tabs[index],
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
          );
        },
      ),
    );
  }

  void _initializeInfoForm(ClientInfoModel info, ClientPro pro) {
    if (!_infoFormInitialized) {
      _brandingUrlCtrl.text = info.branding.url;
      _primaryColorCtrl.text = info.branding.primaryColor;
      _secondaryColorCtrl.text = info.branding.secondaryColor;
      _primaryColor = _hexToColor(info.branding.primaryColor);
      _secondaryColor = _hexToColor(info.branding.secondaryColor);
      _companyNameCtrl.text = info.companyName;
      _companyPhoneCtrl.text = _companyPhone(info);
      _addressCtrl.text = info.address.address;
      _address2Ctrl.text = info.address.address2;
      _zipCodeCtrl.text = info.address.zipcode;
      _selectedCompanyType = info.companyTypeId;
      _selectedClientRank = info.clientRankId;
      _infoFormInitialized = true;
    }

    if (!_bootstrappedLocationDropdowns && pro.stateDropdown.isNotEmpty) {
      final stateId =
          info.address.stateId ??
          _findByName(pro.stateDropdown, info.address.state)?.id;

      if (stateId != null) {
        _selectedState = stateId;
        _bootstrappedLocationDropdowns = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final updatedPro = getClientPro(context);
          updatedPro.loadCities(stateId);

          final cityId =
              info.address.cityId ??
              _findByName(updatedPro.cityDropdown, info.address.city)?.id;
          if (cityId != null && mounted) {
            setState(() {
              _selectedCity = cityId;
            });
          }
        });
      }
    }

    if (_selectedState != null &&
        _selectedCity == null &&
        pro.cityDropdown.isNotEmpty) {
      final cityId =
          info.address.cityId ??
          _findByName(pro.cityDropdown, info.address.city)?.id;
      if (cityId != null) {
        _selectedCity = cityId;
      }
    }
  }

  DropdownItem? _findByName(List<DropdownItem> list, String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final item in list) {
      if (item.name.trim().toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
  }

  DropdownItem? _findById(List<DropdownItem> list, int? id) {
    if (id == null) return null;
    for (final item in list) {
      if (item.id == id) return item;
    }
    return null;
  }

  Widget _buildTabBody(
    ClientInfoTabsModel tabsData,
    ClientInfoModel info,
    ClientPro pro,
  ) {
    final tabs = _isStaff 
        ? const ['Info', 'Onboarding & Training'] 
        : const ['Info', 'Agreement & Standards', 'Onboarding & Training'];
        
    final currentTabName = (_activeTab >= 0 && _activeTab < tabs.length) 
        ? tabs[_activeTab] 
        : 'Info';

    switch (currentTabName) {
      case 'Info':
        return _infoTab(info, pro);
      case 'Agreement & Standards':
        return _agreementTab(tabsData, info);
      case 'Onboarding & Training':
        return _onboardingTab(tabsData, pro);
      default:
        return const SizedBox();
    }
  }

  Widget _infoTab(ClientInfoModel info, ClientPro pro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _logoBox(
                label: 'logo',
                imageUrl: _normalizeImageUrl(_resolvedLogoUrl(info)),
                localFile: _selectedLogoFile,
                onTap: () => _pickAndUploadBrandingAsset(isFavicon: false),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _logoBox(
                label: 'favicon',
                imageUrl: _normalizeImageUrl(_resolvedFaviconUrl(info)),
                localFile: _selectedFaviconFile,
                subtitle: '32x32px',
                onTap: () => _pickAndUploadBrandingAsset(isFavicon: true),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        _editableField('Branding URL', _brandingUrlCtrl),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _editableColorField(
                'Primary Color',
                _primaryColorCtrl,
                _primaryColor,
                () => _openColorPicker(isPrimary: true),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _editableColorField(
                'Secondary Color',
                _secondaryColorCtrl,
                _secondaryColor,
                () => _openColorPicker(isPrimary: false),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        const TextWidget(
          text: 'COMPANY INFORMATION',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Color(0xFF64748B),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(child: _editableField('Company Name', _companyNameCtrl)),
            SizedBox(width: 10.w),
            Expanded(
              child: Builder(
                builder: (context) {
                  final adminPro = Provider.of<AdminPro>(context);
                  return _editableDropdownField(
                    label: 'Client Type',
                    hint: 'Select Type',
                    value: adminPro.clientCmpnyType
                        .where((e) => e.id == _selectedCompanyType)
                        .firstOrNull,
                    items: adminPro.clientCmpnyType,
                    onChanged: (item) =>
                        setState(() => _selectedCompanyType = item?.id),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final adminPro = Provider.of<AdminPro>(context);
                  return _editableDropdownField(
                    label: 'Client Rank',
                    hint: 'Select Rank',
                    value: adminPro.clientRank
                        .where((e) => e.id == _selectedClientRank)
                        .firstOrNull,
                    items: adminPro.clientRank,
                    onChanged: (item) =>
                        setState(() => _selectedClientRank = item?.id),
                  );
                },
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(child: _editableField('Company Phone', _companyPhoneCtrl)),
          ],
        ),
        if (info.companySupportLines.isNotEmpty ||
            info.supportLines.isNotEmpty ||
            info.assignedUsersForSupportLines.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: false,
              iconColor: const Color(0xFF64748B),
              collapsedIconColor: const Color(0xFF64748B),
              title: const TextWidget(
                text: 'SUPPORT LINES & ASSIGNED USERS',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Color(0xFF64748B),
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),
                    const TextWidget(
                      text: "MY COMPANY'S SUPPORT LINE",
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 10.h),
                    if (info.companySupportLines.isEmpty)
                      const TextWidget(
                        text: 'No company support lines found.',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      )
                    else
                      ...info.companySupportLines.map((line) {
                        final img = line.clientImage;
                        final label = line.clientName;
                        final number = line.phoneNumber;

                        return Container(
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6.r),
                                child:
                                    img.isNotEmpty && img.toLowerCase() != 'null'
                                    ? ImageWidget(
                                        image: img,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 28.w,
                                        height: 28.w,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            6.r,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.business,
                                          size: 16,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                              SizedBox(width: 12.w),
                              TextWidget(
                                text: "$label • $number",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ],
                          ),
                        );
                      }),
                    SizedBox(height: 16.h),
                    const TextWidget(
                      text: 'ASSIGNED USERS TO SUPPORT LINE',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 10.h),
                    if (info.assignedUsersForSupportLines.isEmpty)
                      const TextWidget(
                        text: 'No assigned users found.',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      )
                    else
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: info.assignedUsersForSupportLines.map((user) {
                          final img = user.image;
                          final name = user.name;
                          final phone = user.phoneNumber;

                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14.r,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  child: ClipOval(
                                    child:
                                        img.isNotEmpty &&
                                            img.toLowerCase() != 'null'
                                        ? ImageWidget(
                                            image: img,
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.person,
                                            size: 16.sp,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                TextWidget(
                                  text: "$name • $phone",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 20.h),
        const TextWidget(
          text: 'ADDRESS',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Color(0xFF64748B),
        ),
        SizedBox(height: 10.h),
        _editableField('Address', _addressCtrl),
        SizedBox(height: 10.h),
        _editableField('Address 2', _address2Ctrl),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: _editableDropdownField(
                label: 'State',
                hint: 'Select State',
                value: _findById(pro.stateDropdown, _selectedState),
                items: pro.stateDropdown,
                onChanged: (item) {
                  setState(() {
                    _selectedState = item?.id;
                    _selectedCity = null;
                  });
                  if (item != null) {
                    pro.loadCities(item.id);
                  }
                },
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _editableDropdownField(
                label: 'City',
                hint: _selectedState == null
                    ? 'Select state first'
                    : 'Select City',
                value: _findById(pro.cityDropdown, _selectedCity),
                items: pro.cityDropdown,
                onChanged: _selectedState == null
                    ? null
                    : (item) => setState(() => _selectedCity = item?.id),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        _editableField('Zipcode', _zipCodeCtrl),
      ],
    );
  }

  Widget _agreementTab(ClientInfoTabsModel data, ClientInfoModel info) {
    if (data.agreementStandards.isEmpty) {
      return const TextWidget(
        text: 'No agreement and standards available.',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF6B7280),
      );
    }

    final item = data.agreementStandards.first;
    final hasSigned = item.hasSigned;
    final canSign = item.canSign;
    final templateName = item.template.name;
    final version = item.template.version;

    final authPro = Provider.of<AuthPro>(context, listen: false);
    final roleName = authPro.user?.roleName ?? '';
    final isAdmin = roleName == 'ADMIN';

    final ClientContactInfoModel? primaryContact = info.contacts.isEmpty
        ? null
        : info.contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => info.contacts.first,
          );
    // Bug_37: Build full name (first + last) so we never show "N/A" when the
    // contact has a last name but an empty first name (or vice versa).
    final contactName = () {
      if (primaryContact == null) return 'N/A';
      final full = '${primaryContact.name} ${primaryContact.lastName}'.trim();
      return full.isEmpty ? 'N/A' : full;
    }();

    final statusLabel = hasSigned
        ? 'Signed by ${item.signerName.isNotEmpty ? item.signerName : contactName}'
        : 'Pending signature from $contactName';

    String formatSignedAt(String raw) {
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      var hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '$month $day, ${parsed.year} • $hour:$minute $period.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: hasSigned
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: hasSigned
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFEAB308),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: hasSigned
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3E8BE),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: hasSigned
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB07A00),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: TextWidget(
                                text: templateName,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                maxLines: 2,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            TextWidget(
                              text: 'v$version',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        TextWidget(
                          text: statusLabel,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF4B5563),
                        ),
                        const TextWidget(
                          text:
                              'Please review and sign the service agreement to confirm your partnership with Print Helpers.',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF4B5563),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _agreementStatusChip(hasSigned: hasSigned),
                  if (hasSigned) ...[
                    _agreementActionButton(
                      icon: Icons.remove_red_eye_outlined,
                      label: 'View Agreement',
                      onPressed: () =>
                          _showAgreementBottomSheet(info: info, item: item),
                    ),
                    if (item.pdfUrl.isNotEmpty)
                      _agreementActionButton(
                        icon: Icons.download_rounded,
                        label: 'Download PDF',
                        outlined: true,
                        onPressed: () => _downloadAgreementPdf(
                          item.pdfUrl,
                          item.template.name,
                        ),
                      ),
                  ] else ...[
                    if (isAdmin)
                      _agreementActionButton(
                        icon: Icons.remove_red_eye_outlined,
                        label: 'View Agreement',
                        onPressed: () =>
                            _showAgreementBottomSheet(info: info, item: item),
                      ),
                    if (canSign)
                      _agreementActionButton(
                        icon: Icons.draw_outlined,
                        label: 'Sign Agreement',
                        bgColorOverride: const Color(0xFF92400E),
                        textColorOverride: Colors.white,
                        borderColorOverride: const Color(0xFF92400E),
                        onPressed: () =>
                            _showAgreementBottomSheet(info: info, item: item),
                      ),
                  ],
                  if (isAdmin && !hasSigned)
                    _agreementActionButton(
                      icon: Icons.notifications_none_rounded,
                      label: 'Send Reminder',
                      outlined: true,
                      onPressed: () {
                        String agreementId = item.id;
                        if (agreementId.isEmpty ||
                            agreementId == '0' ||
                            agreementId == 'null') {
                          agreementId = 'client_${info.id}';
                        }

                        debugPrint(
                          'Agreements Tab - Sending Reminder for ID: $agreementId',
                        );
                        final adminPro = Provider.of<AdminPro>(
                          context,
                          listen: false,
                        );
                        adminPro.sendContractReminder(agreementId);
                      },
                    ),
                ],
              ),
              if (hasSigned) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF15803D),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: TextWidget(
                          text:
                              'Agreement signed by ${item.signerName} on ${formatSignedAt(item.signedAt)} • IP: ${item.ipAddress}',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EBC8),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Color(0xFF9A6700),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: TextWidget(
                          text: canSign
                              ? 'Agreement has not been signed yet. Click "Sign Agreement" to complete the process.'
                              : 'Agreement has not been signed yet. Only the primary contact can sign this agreement.',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9A6700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (item.rules.isNotEmpty) ...[
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text:
                      'These are some of the most important standards of our community. By working with us, you agree to uphold these principles in every interaction.',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                SizedBox(height: 12.h),
                ..._groupRulesByCategory(item.rules).entries.map((entry) {
                  final category = entry.key;
                  final rules = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: category.toUpperCase(),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                        letterSpacing: 3,
                      ),
                      SizedBox(height: 8.h),
                      ...rules.map(_standardRuleTile),
                      SizedBox(height: 10.h),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Map<String, List<ClientStandardRuleModel>> _groupRulesByCategory(
    List<ClientStandardRuleModel> rules,
  ) {
    final grouped = <String, List<ClientStandardRuleModel>>{};
    for (final rule in rules) {
      final key = rule.categoryName.trim().isEmpty
          ? 'General'
          : rule.categoryName.trim();
      grouped.putIfAbsent(key, () => <ClientStandardRuleModel>[]).add(rule);
    }
    return grouped;
  }

  Widget _standardRuleTile(ClientStandardRuleModel rule) {
    final iconColor = _resolveIconColor(
      colorHex: rule.colorHex,
      iconColorToken: rule.iconColor,
    );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFDFE6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: rule.iconSvgUrl.trim().isNotEmpty
                ? SvgPicture.network(
                    rule.iconSvgUrl,
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    placeholderBuilder: (context) => Icon(
                      _ruleIcon(
                        rule.iconName.isNotEmpty ? rule.iconName : rule.icon,
                      ),
                      size: 16,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    _ruleIcon(
                      rule.iconName.isNotEmpty ? rule.iconName : rule.icon,
                    ),
                    size: 16,
                    color: iconColor,
                  ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: rule.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
                if (rule.description.trim().isNotEmpty)
                  Text(
                    rule.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                    softWrap: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElectronicSignatureSection({
    required ClientAgreementStandardsModel item,
    required String contactName,
    required bool isConfirmed,
    required ValueChanged<bool> onConfirmedChanged,
    required StateSetter setModalState,
    required TextEditingController nameController,
    required String dateString,
  }) {
    final hasSigned = item.hasSigned;
    final canSign = item.canSign;

    String formatSignedDateOnly(String raw) {
      if (raw.isEmpty) return '';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      return '$month $day, ${parsed.year}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12.h),
        const TextWidget(
          text: 'Electronic Signature',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
        SizedBox(height: 10.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFFFEF3C7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(
                text:
                    'By typing your full name and clicking "I Agree & Sign" below, you acknowledge that:',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF92400E),
              ),
              SizedBox(height: 10.h),
              _signatureRequirementItem(
                'You have read and understand this Agreement and all linked policies;',
              ),
              _signatureRequirementItem(
                'You have authority to enter into this Agreement;',
              ),
              _signatureRequirementItem(
                'You agree to be legally bound by all terms herein;',
              ),
              _signatureRequirementItem(
                'Your electronic signature is binding under the Uniform Electronic Transactions Act (UETA) and has the same legal effect as a handwritten signature;',
              ),
              _signatureRequirementItem(
                'You consent to Service Provider collecting your IP address for security and record-keeping purposes.',
              ),
            ],
          ),
        ),
        if (hasSigned) ...[
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: 'Record of electronic signature',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
                SizedBox(height: 8.h),
                const TextWidget(
                  text:
                      'The name, date, and confirmation below reflect what was submitted when this agreement was signed.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF15803D),
                ),
                SizedBox(height: 8.h),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF15803D),
                    ),
                    children: const [
                      TextSpan(text: 'The '),
                      TextSpan(
                        text: 'terms & conditions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text:
                            ' and specialist standards shown above are part of this agreement and are included in your PDF download.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'FULL LEGAL NAME',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: item.signerName.isNotEmpty
                            ? item.signerName
                            : item.signature,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'DATE SIGNED',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: formatSignedDateOnly(item.signedAt),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TextWidget(
            text: 'IP address (recorded): ${item.ipAddress}',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: true,
                  onChanged: null,
                  activeColor: const Color(0xFFD58F16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirmed that I had read and agreed to the statements above at the time of signing.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ] else if (canSign) ...[
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'FULL LEGAL NAME *',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: nameController,
                      onChanged: (val) {
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: contactName.toLowerCase() == 'n/a'
                            ? 'First Last'
                            : contactName.split(RegExp(r'\s+')).length >= 2
                            ? contactName
                            : '$contactName Last',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    TextWidget(
                      text: contactName.toLowerCase() == 'n/a'
                          ? "Please enter your full first and last name."
                          : contactName.split(RegExp(r'\s+')).length >= 2
                          ? "Must match '$contactName' to be valid."
                          : "Must match '$contactName' and include your last name to be valid.",
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextWidget(
                      text: 'DATE',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.5,
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextWidget(
                        text: dateString,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: isConfirmed,
                  onChanged: (val) {
                    onConfirmedChanged(val ?? false);
                  },
                  activeColor: const Color(0xFFD58F16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirm that I have read and agree to the statements above.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFF475569),
                ),
                SizedBox(width: 8.w),
                const Expanded(
                  child: TextWidget(
                    text:
                        'View only: only the primary contact is allowed to sign this agreement.',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: false,
                  onChanged: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: TextWidget(
                  text:
                      'I confirm that I have read and agree to the statements above. Only the primary contact can check this when signing.',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _signatureRequirementItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextWidget(
            text: '•',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextWidget(
              text: text,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF92400E),
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _ruleIcon(String iconName) {
    final key = iconName.toLowerCase();
    if (key.contains('briefcase')) {
      return Icons.work_rounded;
    }
    if (key.contains('money') || key.contains('bill') || key.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (key.contains('triangle') || key.contains('exclamation')) {
      return Icons.warning_rounded;
    }
    if (key.contains('user-tie')) {
      return Icons.badge_rounded;
    }
    if (key.contains('warn') || key.contains('alert')) {
      return Icons.warning_rounded;
    }
    if (key.contains('check') || key.contains('done')) {
      return Icons.task_alt_rounded;
    }
    if (key.contains('user') || key.contains('group') || key.contains('team')) {
      return Icons.groups_rounded;
    }
    if (key.contains('doc') || key.contains('file')) {
      return Icons.description_rounded;
    }
    return Icons.circle_notifications_rounded;
  }

  Color _resolveIconColor({
    required String colorHex,
    required String iconColorToken,
  }) {
    if (colorHex.trim().isNotEmpty) {
      return _hexToColor(colorHex);
    }

    final token = iconColorToken.toLowerCase();
    if (token.contains('orange')) return const Color(0xFFF97316);
    if (token.contains('red')) return const Color(0xFFEF4444);
    if (token.contains('purple')) return const Color(0xFFA855F7);
    if (token.contains('green')) return const Color(0xFF22C55E);
    if (token.contains('blue')) return const Color(0xFF3B82F6);
    if (token.contains('amber') || token.contains('yellow')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF64748B);
  }

  Widget _agreementStatusChip({required bool hasSigned}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: hasSigned ? const Color(0xFFDCFCE7) : const Color(0xFFF5EBC8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSigned ? Icons.check_circle : Icons.error,
            size: 14,
            color: hasSigned
                ? const Color(0xFF15803D)
                : const Color(0xFF9A6700),
          ),
          SizedBox(width: 4.w),
          TextWidget(
            text: hasSigned ? 'Signed' : 'Pending Signature',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hasSigned
                ? const Color(0xFF15803D)
                : const Color(0xFF9A6700),
          ),
        ],
      ),
    );
  }

  Widget _agreementActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool outlined = false,
    Color? bgColorOverride,
    Color? textColorOverride,
    Color? borderColorOverride,
  }) {
    final borderColor =
        borderColorOverride ??
        (outlined ? const Color(0xFFD58F16) : const Color(0xFFD1D5DB));
    final bgColor =
        bgColorOverride ??
        (outlined ? Colors.transparent : const Color(0xFFF8FAFC));
    final textColor =
        textColorOverride ??
        (outlined ? const Color(0xFF9A6700) : const Color(0xFF1E3A8A));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              SizedBox(width: 5.w),
              TextWidget(
                text: label,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAgreementPdf(String url, String templateName) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photos = await Permission.photos.request();
          if (!photos.isGranted) {
            showToast(message: "Storage permission denied");
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Sanitise templateName to create a safe file name
      final safeName = templateName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${safeName}_agreement.pdf';

      showToast(message: "Starting download...");
      await DownloadService.instance.downloadFile(
        url: url,
        fileName: fileName,
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint("Download agreement error: $e");
      showToast(message: "Failed to download agreement");
    }
  }

  void _showAgreementBottomSheet({
    required ClientInfoModel info,
    required ClientAgreementStandardsModel item,
  }) {
    final templateName = item.template.name.trim().isEmpty
        ? 'Client Template Name'
        : item.template.name.trim();
    final version = item.template.version.trim().isEmpty
        ? '1.0'
        : item.template.version.trim();
    final clientName = info.companyName.trim().isEmpty
        ? 'Client'
        : info.companyName.trim();
    final ClientContactInfoModel? primaryContact = info.contacts.isEmpty
        ? null
        : info.contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => info.contacts.first,
          );
    final contactName = primaryContact == null
        ? 'N/A'
        : '${primaryContact.name.trim()} ${primaryContact.lastName.trim()}'
              .trim()
              .isEmpty
        ? 'N/A'
        : '${primaryContact.name.trim()} ${primaryContact.lastName.trim()}'
              .trim();
    final fullAddress = [
      info.address.address,
      info.address.address2,
      info.address.city.isNotEmpty ? '${info.address.city},' : '',
      '${info.address.state} ${info.address.zipcode}'.trim(),
    ].where((s) => s.trim().isNotEmpty).join('\n');

    final clientSubtitle = 'Contact: $contactName\n$fullAddress';

    final agreementContent = _stripHtml(item.content);

    bool isConfirmed = false;
    final nameController = TextEditingController(
      text: contactName.toLowerCase() == 'n/a' ? '' : contactName,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final now = DateTime.now();
        final month = months[now.month - 1];
        final day = now.day.toString().padLeft(2, '0');
        final dateString = '$month $day, ${now.year}';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final enteredText = nameController.text.trim();
            final enteredWords = enteredText
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList();
            final hasFirstAndLastName = enteredWords.length >= 2;

            bool isNameValid = false;
            if (hasFirstAndLastName) {
              final contactWords = contactName
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .toList();
              if (contactWords.isEmpty || contactName.toLowerCase() == 'n/a') {
                isNameValid = true;
              } else {
                final expectedFirstName = contactWords.first.toLowerCase();
                final enteredFirstName = enteredWords.first.toLowerCase();
                final exactMatch =
                    enteredText.toLowerCase() == contactName.toLowerCase();
                isNameValid =
                    exactMatch || (enteredFirstName == expectedFirstName);
              }
            }

            final viewInsets = MediaQuery.of(context).viewInsets;
            final screenHeight = MediaQuery.of(context).size.height;
            final availableHeight = screenHeight - viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
                child: Container(
                  height: availableHeight * 0.9,
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 12.h,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: templateName,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 2.h),
                                  const TextWidget(
                                    text:
                                        'Print Helpers - Please read carefully before signing',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 14.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const TextWidget(
                                      text: 'PRINT HELPERS LLC',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: TextWidget(
                                            text: templateName,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            maxLines: 2,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        TextWidget(
                                          text: 'v$version',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6.h),
                                    Text.rich(
                                      TextSpan(
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w400,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text:
                                                'This agreement is entered into between ',
                                          ),
                                          const TextSpan(
                                            text: 'Print Helpers LLC',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' (Company) and ',
                                          ),
                                          TextSpan(
                                            text: clientName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(text: ' (Client).'),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 14.h),
                              Divider(
                                color: const Color(0xFFE5E7EB),
                                height: 1.h,
                              ),
                              SizedBox(height: 12.h),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _agreementPartyCard(
                                        title: 'COMPANY',
                                        name: 'Print Helpers LLC',
                                        subtitle:
                                            'printhelpers.com\n2080 Empire Ave. #1032\nBurbank, CA 91504',
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: _agreementPartyCard(
                                        title: 'CLIENT',
                                        name: clientName,
                                        subtitle: clientSubtitle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 10.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: agreementContent.trim().isEmpty
                                    ? const TextWidget(
                                        text: 'No agreement content available.',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF6B7280),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: agreementContent
                                            .split('\n')
                                            .map((s) => s.trim())
                                            .where((s) => s.isNotEmpty)
                                            .map(
                                              (s) => s.startsWith('-')
                                                  ? s.substring(1).trim()
                                                  : s,
                                            )
                                            .toList()
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              final index = entry.key;
                                              final text = entry.value;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 8.h,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    TextWidget(
                                                      text: '${index + 1}. ',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                        0xFF111827,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: TextWidget(
                                                        text: text,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: const Color(
                                                          0xFF111827,
                                                        ),
                                                        maxLines: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                              ),
                              SizedBox(height: 12.h),
                              ..._groupRulesByCategory(item.rules).entries.map((
                                entry,
                              ) {
                                final category = entry.key;
                                final rules = entry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: category.toUpperCase(),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 3,
                                    ),
                                    SizedBox(height: 8.h),
                                    ...rules.map(_standardRuleTile),
                                    SizedBox(height: 10.h),
                                  ],
                                );
                              }),
                              _buildElectronicSignatureSection(
                                item: item,
                                contactName: contactName,
                                isConfirmed: isConfirmed,
                                onConfirmedChanged: (val) {
                                  setModalState(() {
                                    isConfirmed = val;
                                  });
                                },
                                setModalState: setModalState,
                                nameController: nameController,
                                dateString: dateString,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child:
                                  item.hasSigned
                                  ? OutlinedButton(
                                      onPressed: item.pdfUrl.isNotEmpty
                                          ? () {
                                              _downloadAgreementPdf(
                                                item.pdfUrl,
                                                item.template.name,
                                              );
                                            }
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFF2563EB),
                                        ),
                                        minimumSize: Size.fromHeight(44.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.picture_as_pdf,
                                            color: Color(0xFF2563EB),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8.w),
                                          TextWidget(
                                            text: 'Download PDF',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed:
                                          (item.canSign &&
                                              isConfirmed &&
                                              isNameValid)
                                          ? () async {
                                              final pro =
                                                  Provider.of<ClientPro>(
                                                    context,
                                                    listen: false,
                                                  );
                                              final res = await pro
                                                  .signClientAgreement(
                                                    clientId: info.id,
                                                    signerName: nameController
                                                        .text
                                                        .trim(),
                                                    signedDate: DateTime.now()
                                                        .toIso8601String(),
                                                  );
                                              if (res && context.mounted) {
                                                Navigator.pop(ctx);
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFF5D070,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFF5E8C4,
                                        ),
                                        foregroundColor: const Color(
                                          0xFF475569,
                                        ),
                                        disabledForegroundColor: const Color(
                                          0xFF94A3B8,
                                        ),
                                        minimumSize: Size.fromHeight(44.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        Icons.draw_outlined,
                                        size: 18,
                                        color:
                                            (item.canSign &&
                                                isConfirmed &&
                                                isNameValid)
                                            ? const Color(0xFF475569)
                                            : const Color(0xFF94A3B8),
                                      ),
                                      label: Text(
                                        'I Agree & Sign',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                            ),
                            SizedBox(width: 8.w),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(86.w, 44.h),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _agreementPartyCard({
    required String title,
    required String name,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: title,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 1.6,
          ),
          SizedBox(height: 6.h),
          TextWidget(
            text: name,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
          TextWidget(
            text: subtitle,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ],
      ),
    );
  }

  List<String> _extractListItemsFromHtml(String html) {
    if (html.trim().isEmpty) return const [];

    final liRegex = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = liRegex.allMatches(html);
    if (matches.isNotEmpty) {
      return matches
          .map((m) => _stripHtml(m.group(1) ?? '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    return _stripHtml(html)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Widget _onboardingTab(ClientInfoTabsModel data, ClientPro pro) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final horizontalPadding = isCompact ? 12.w : 16.w;
        final cardRadius = isCompact ? 14.r : 16.r;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12.h,
                horizontalPadding,
                10.h,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 12.w : 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: 'ONBOARDING CHECKLIST',
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    SizedBox(height: 6.h),
                    TextWidget(
                      text: 'Track client onboarding progress across all required areas.',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            if (!_canEditOnboardingChecklist)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  12.h,
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 16,
                        color: Color(0xFF92400E),
                      ),
                      SizedBox(width: 8.w),
                      const Expanded(
                        child: TextWidget(
                          text: 'Onboarding is view-only for your role. Only admin can check or update checklist items.',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _buildChecklistsAccordionSection(
              title: 'Onboarding',
              subtitle: 'Client onboarding checklist progress',
              iconData: Icons.rocket_launch,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
              borderColor: const Color(0xFFDBEAFE),
              lists: data.onboarding,
              pro: pro,
              isCompact: isCompact,
              horizontalPadding: horizontalPadding,
              emptyMessage: 'No onboarding checklists configured.',
              initiallyExpanded: true,
            ),
            SizedBox(height: 12.h),
            _buildChecklistsAccordionSection(
              title: 'Training',
              subtitle: 'Client training checklist progress',
              iconData: Icons.school,
              iconColor: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFFD1FAE5),
              lists: data.training,
              pro: pro,
              isCompact: isCompact,
              horizontalPadding: horizontalPadding,
              emptyMessage: 'No training checklists configured.',
              initiallyExpanded: true,
            ),
            SizedBox(height: 16.h),
          ],
        );
      },
    );
  }

  Widget _buildChecklistsAccordionSection({
    required String title,
    required String subtitle,
    required IconData iconData,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required List<ClientOnboardingChecklistModel> lists,
    required ClientPro pro,
    required bool isCompact,
    required double horizontalPadding,
    required String emptyMessage,
    required bool initiallyExpanded,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
            childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
            iconColor: iconColor,
            collapsedIconColor: iconColor,
            title: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(iconData, size: 16, color: iconColor),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: title,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                      TextWidget(
                        text: subtitle,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextWidget(
                    text: '${lists.length} Lists',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                SizedBox(width: 8.w),
              ],
            ),
            children: [
              if (lists.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.centerLeft,
                  child: TextWidget(
                    text: emptyMessage,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                )
              else
                ...lists.map((list) {
                  final listIconColor = _resolveIconColor(
                    colorHex: list.colorHex,
                    iconColorToken: list.iconColor,
                  );
                  final progress =
                      list.totalItems == 0
                          ? 0.0
                          : list.completedItems / list.totalItems;
                  final statusLabel =
                      list.completedItems == 0
                          ? 'Not Started'
                          : list.completedItems == list.totalItems
                          ? 'Complete'
                          : 'In Progress';
                  final statusBg =
                      list.completedItems == 0
                          ? const Color(0xFFFEF2F2)
                          : list.completedItems == list.totalItems
                          ? const Color(0xFFECFDF3)
                          : const Color(0xFFFFF7ED);
                  final statusFg =
                      list.completedItems == 0
                          ? const Color(0xFFB91C1C)
                          : list.completedItems == list.totalItems
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309);

                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        childrenPadding: EdgeInsets.fromLTRB(
                          14.w,
                          0,
                          14.w,
                          14.h,
                        ),
                        iconColor: const Color(0xFF6B7280),
                        collapsedIconColor: const Color(0xFF6B7280),
                        title: Row(
                          children: [
                            Container(
                              width: 34.w,
                              height: 34.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: listIconColor.withValues(alpha: 0.14),
                              ),
                              alignment: Alignment.center,
                              child:
                                  list.iconSvgUrl.trim().isNotEmpty
                                      ? SvgPicture.network(
                                          list.iconSvgUrl,
                                          width: 16.w,
                                          height: 16.w,
                                          colorFilter: ColorFilter.mode(
                                            listIconColor,
                                            BlendMode.srcIn,
                                          ),
                                          placeholderBuilder:
                                              (context) => Icon(
                                                _ruleIcon(
                                                  list.iconName.isNotEmpty
                                                      ? list.iconName
                                                      : list.icon,
                                                ),
                                                size: 16,
                                                color: listIconColor,
                                              ),
                                        )
                                      : Icon(
                                          _ruleIcon(
                                            list.iconName.isNotEmpty
                                                ? list.iconName
                                                : list.icon,
                                          ),
                                          size: 16,
                                          color: listIconColor,
                                        ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: list.name,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2937),
                                  ),
                                  SizedBox(height: 2.h),
                                  TextWidget(
                                    text: '${list.completedItems} of ${list.totalItems} completed',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  if (isCompact) ...[
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        Container(
                                          width: 60.w,
                                          height: 6.h,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE5E7EB),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: progress,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF3B82F6),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusBg,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: TextWidget(
                                            text: statusLabel,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: statusFg,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isCompact) ...[
                              Container(
                                width: 60.w,
                                height: 6.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: TextWidget(
                                  text: statusLabel,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusFg,
                                ),
                              ),
                            ],
                          ],
                        ),
                        children: [
                          ...list.items.map(
                            (it) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 5.h),
                              child: InkWell(
                                onTap:
                                    _canEditOnboardingChecklist
                                        ? () => _toggleOnboardingItem(
                                            pro,
                                            list.id,
                                            it.index,
                                          )
                                        : null,
                                borderRadius: BorderRadius.circular(8.r),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20.w,
                                      height: 20.w,
                                      decoration: BoxDecoration(
                                        color:
                                            it.isCompleted
                                                ? const Color(0xFF10B981)
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          5.r,
                                        ),
                                        border: Border.all(
                                          color:
                                              it.isCompleted
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child:
                                          it.isCompleted
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color: Colors.white,
                                                )
                                              : null,
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Text(
                                        it.text,
                                        style: TextStyle(
                                          fontSize: isCompact ? 13.sp : 14.sp,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              it.isCompleted
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleOnboardingItem(
    ClientPro pro,
    int checklistId,
    int itemIndex,
  ) async {
    if (!_canEditOnboardingChecklist) {
      showToast(message: 'Only Admin can check or uncheck checklist items.');
      return;
    }
    await pro.toggleClientChecklistItem(
      clientId: widget.clientId,
      checklistId: checklistId,
      itemIndex: itemIndex,
    );
  }

  Widget _editableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label.toUpperCase(),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _editableColorField(
    String label,
    TextEditingController controller,
    Color color,
    VoidCallback onTap,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final swatchColor = _hexToColor(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              text: label.toUpperCase(),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.5,
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = _hexToColor(val);
                      if (label.toLowerCase().contains('primary')) {
                        setState(() => _primaryColor = parsed);
                      } else {
                        setState(() => _secondaryColor = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
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
              child: const Text('Select'),
              onPressed: () {
                setState(() {
                  if (isPrimary) {
                    _primaryColor = tempColor;
                    _primaryColorCtrl.text = _colorToHexString(tempColor);
                  } else {
                    _secondaryColor = tempColor;
                    _secondaryColorCtrl.text = _colorToHexString(tempColor);
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

  String _colorToHexString(Color c) {
    return '#'
            '${c.red.toRadixString(16).padLeft(2, '0')}'
            '${c.green.toRadixString(16).padLeft(2, '0')}'
            '${c.blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Widget _editableDropdownField({
    required String label,
    required String hint,
    required DropdownItem? value,
    required List<DropdownItem> items,
    required ValueChanged<DropdownItem?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label.toUpperCase(),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
        SizedBox(height: 6.h),
        DropdownButtonFormField<DropdownItem>(
          initialValue: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: Color(0xFF64748B),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          hint: TextWidget(
            text: hint,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<DropdownItem>(
                  value: item,
                  child: TextWidget(
                    text: item.name,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _pickAndUploadBrandingAsset({required bool isFavicon}) async {
    if (_uploadingAssetType != null) return;

    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'ico'],
      );

      if (picked == null || picked.files.single.path == null) {
        return;
      }

      final file = File(picked.files.single.path!);

      if (isFavicon) {
        final size = await _readImageSize(file);
        if (size != null) {
          final w = size.width.round();
          final h = size.height.round();
          if (w != 32 || h != 32) {
            showToast(
              message:
                  'Recommended favicon size is 32x32px. Selected: ${w}x${h}px',
            );
          }
        }
      }

      setState(() {
        if (isFavicon) {
          _selectedFaviconFile = file;
        } else {
          _selectedLogoFile = file;
        }
      });
      debugPrint('PICKED FILE => ${file.path}, isFavicon=$isFavicon');
      debugPrint(
        '_selectedFaviconFile => ${_selectedFaviconFile?.path ?? 'NULL'}',
      );
      debugPrint('_selectedLogoFile => ${_selectedLogoFile?.path ?? 'NULL'}');

      showToast(
        message: isFavicon
            ? 'Favicon selected. Tap Save to upload.'
            : 'Logo selected. Tap Save to upload.',
      );
    } catch (e) {
      debugPrint('Branding pick/upload error: $e');
      showToast(message: 'Failed to select image');
    }
  }

  Future<ui.Size?> _readImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _logoBox({
    required String label,
    required String imageUrl,
    File? localFile,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 72.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            alignment: Alignment.center,
            child: _uploadingAssetType == label.toLowerCase() && onTap != null
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : (localFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.file(
                            localFile,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: ImageWidget(
                            image: imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : TextWidget(
                          text: label,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        )),
          ),
        ),
        SizedBox(height: 6.h),
        TextWidget(
          text: subtitle == null
              ? label.toUpperCase()
              : '${label.toUpperCase()} - ${subtitle.toUpperCase()}',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ],
    );
  }

  String _normalizeImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('file://') || value.startsWith('/data/')) {
      return value;
    }

    final base = Uri.parse(ApiRoutes.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';

    if (value.startsWith('//')) {
      return '${base.scheme}:$value';
    }

    if (value.startsWith('${base.host}/') || value == base.host) {
      return '${base.scheme}://$value';
    }

    if (value.startsWith('www.')) {
      return '${base.scheme}://$value';
    }

    if (value.startsWith('/')) {
      return '$origin$value';
    }
    return '$origin/$value';
  }

  void _showToggleClientStatusDialog(
    BuildContext context,
    String clientName,
    bool currentStatus,
  ) {
    final action = currentStatus ? 'Deactivate' : 'Activate';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: '$action Client',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                SizedBox(height: 12.h),
                TextWidget(
                  text: 'Are you sure you want to $action "$clientName"?',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF475569),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: const TextWidget(
                          text: 'Cancel',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: () async {
                        final clientPro = context.read<ClientPro>();
                        Navigator.pop(dialogContext);
                        await clientPro.toggleStatus(
                          widget.clientId,
                          !currentStatus,
                          context,
                        );
                        if (context.mounted) {
                          clientPro.getClientInfoTabs(widget.clientId);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: currentStatus
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: TextWidget(
                          text: action,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Bug_38: Branding logo must NEVER fall back to info.image (company profile photo).
  // They are separate assets — keep them independent.
  String _resolvedLogoUrl(ClientInfoModel info) {
    final brandingLogo = info.branding.logo.trim();
    if (brandingLogo.isNotEmpty && brandingLogo.toLowerCase() != 'null') {
      return brandingLogo;
    }
    return '';
  }

  String _resolvedFaviconUrl(ClientInfoModel info) {
    final favicon = info.branding.favicon.trim();
    if (favicon.isNotEmpty && favicon.toLowerCase() != 'null') {
      return favicon;
    }
    // Favicon can fall back to branding logo, but NOT to company image
    final brandingLogo = info.branding.logo.trim();
    if (brandingLogo.isNotEmpty && brandingLogo.toLowerCase() != 'null') {
      return brandingLogo;
    }
    return '';
  }

  Widget _chip(String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextWidget(
        text: text,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    );
  }

  String _companyPhone(ClientInfoModel info) {
    for (final contact in info.contacts) {
      if (contact.contactDetails.phones.isNotEmpty) {
        return contact.contactDetails.phones.first.number;
      }
      if (contact.phone.isNotEmpty) return contact.phone;
    }
    return '';
  }

  String _stripHtml(String html) {
    final withBreaks = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'<\s*/\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*p[^>]*>', caseSensitive: false), '');
    return withBreaks
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  Color _hexToColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return const Color(0xFFFFFFFF);
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return const Color(0xFFFFFFFF);
    final parsed = int.tryParse('FF$clean', radix: 16);
    if (parsed == null) return const Color(0xFFFFFFFF);
    return Color(parsed);
  }
}
