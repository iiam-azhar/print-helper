import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/models/client_info_tabs_model.dart';
import 'package:print_helper/models/contact_form_models.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/providers/auth_pro.dart';
import 'package:print_helper/services/api_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_text_widget.dart';
import '../tab_widgets/tab_toasts.dart';
import '../tab_widgets/loaders.dart';

import 'package:print_helper/services/download_service.dart';
import '../tab_services/helpers.dart';

class TabClientInfoScreen extends StatefulWidget {
  final int clientId;
  final VoidCallback? onBack;

  const TabClientInfoScreen({super.key, required this.clientId, this.onBack});

  @override
  State<TabClientInfoScreen> createState() => _TabClientInfoScreenState();
}

class _TabClientInfoScreenState extends State<TabClientInfoScreen> {
  int _activeTab = 0;
  bool _infoFormInitialized = false;
  bool _bootstrappedLocationDropdowns = false;
  bool _canEditOnboardingChecklist = false;
  bool _isStaff = false;
  String? _uploadingAssetType;
  File? _selectedLogoFile;
  File? _selectedFaviconFile;

  final  _brandingUrlCtrl = TextEditingController();
  final  _primaryColorCtrl = TextEditingController();
  final  _secondaryColorCtrl = TextEditingController();
  Color _primaryColor = const Color(0xFF4CC9F0);
  Color _secondaryColor = const Color(0xFFAEB0B3);
  final  _companyNameCtrl = TextEditingController();
  final  _companyPhoneCtrl = TextEditingController();
  final  _addressCtrl = TextEditingController();
  final  _address2Ctrl = TextEditingController();
  final  _zipCodeCtrl = TextEditingController();

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

  void _handleBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _onSave() async {
    final pro = getClientPro(context);
    final hasLogoAsset = _selectedLogoFile != null;
    final hasFaviconAsset = _selectedFaviconFile != null;

    setState(() {
      if (hasLogoAsset && !hasFaviconAsset) {
        _uploadingAssetType = 'logo';
      } else if (!hasLogoAsset && hasFaviconAsset) {
        _uploadingAssetType = 'favicon';
      } else {
        _uploadingAssetType = null;
      }
    });

    final clientDetails = await pro.getClientDetails(
      widget.clientId,
      showLoader: false,
    );
    if (clientDetails == null) {
      showToast(message: 'Failed to load client details');
      if (!mounted) return;
      setState(() {
        _uploadingAssetType = null;
      });
      return;
    }

    if (!mounted) return;

    final contactForms = clientDetails.contacts.map((ec) {
      final cf = ContactFormModel();
      cf.existingId = ec.id;
      cf.firstName.text = ec.name ?? '';
      cf.lastName.text = ec.lastName ?? '';
      cf.username.text = ec.username ?? '';
      cf.selectedLanguageIds = ec.contactDetails.languages
          .map((l) => l.id)
          .toList();

      if (ec.contactDetails.phones.isNotEmpty) {
        cf.phoneFields = ec.contactDetails.phones
            .map(
              (p) => PhoneField(
                type: PhoneType(p.type, Paths.call, p.type.toLowerCase()),
                controller: TextEditingController(text: p.number),
              ),
            )
            .toList();
      }

      if (ec.contactDetails.emails.isNotEmpty) {
        cf.emails = ec.contactDetails.emails
            .map((e) => TextEditingController(text: e))
            .toList();
      }

      cf.imageUrl = ec.image;
      cf.existingImageUrl = ec.image;
      return cf;
    }).toList();

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
          _selectedCity?.toString() ?? clientDetails.city?.id.toString() ?? '',
      zipcode: _zipCodeCtrl.text.trim(),
      clientLanguages: clientDetails.languages.map((l) => l.id).toList(),
      status: clientDetails.status ? 1 : 0,
      assignedStaff: List<int>.from(
        clientDetails.assignedStaff.whereType<int>(),
      ),
      contacts: contactForms,
      companyType: _selectedCompanyType ?? clientDetails.companyTypeId ?? 1,
      clientRank: _selectedClientRank ?? clientDetails.clientRankId ?? 1,
      brandingPrimary: _primaryColorCtrl.text.trim(),
      brandingSecondary: _secondaryColorCtrl.text.trim(),
      brandingUrl: _brandingUrlCtrl.text.trim(),
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
      await pro.getClientInfoTabs(widget.clientId);
      if (!mounted) return;
      pro.getClients(ctx: context, page: pro.currentPage);
    } else {
      showToast(message: 'Failed to update client');
    }

    if (!mounted) return;
    setState(() {
      _uploadingAssetType = null;
    });
  }

  void _showToggleClientStatusDialog(
    BuildContext context,
    String clientName,
    bool isActive,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: TextWidget(
          text: isActive ? "Deactivate Client" : "Activate Client",
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        content: TextWidget(
          text:
              "Are you sure you want to ${isActive ? 'deactivate' : 'activate'} $clientName?",
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextWidget(
              text: "Cancel",
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final pro = getClientPro(context);
              await pro.toggleStatus(widget.clientId, !isActive, context);
              if (!context.mounted) return;
              pro.getClientInfoTabs(widget.clientId);
              pro.getClients(ctx: context, page: pro.currentPage);
            },
            child: TextWidget(
              text: "Confirm",
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pro = getClientPro(context, listen: true);
    final tabsData = pro.currentClientInfoTabs;
    final hasInfo = tabsData != null && tabsData.info.isNotEmpty;
    if (hasInfo) {
      _initializeInfoForm(tabsData.info.first, pro);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          child: Column(
            children: [
              _header(context, pro),
              Expanded(
                child: pro.clientInfoTabsLoad
                    ? Center(child: showLoader())
                    : !hasInfo
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TextWidget(
                              text: 'Unable to load client info',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: () =>
                                  pro.getClientInfoTabs(widget.clientId),
                              child: const TextWidget(
                                text: 'Retry',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _topCard(pro),
                            const SizedBox(height: 14),
                            _tabBar(),
                            const SizedBox(height: 12),
                            _buildActiveTab(pro, tabsData, tabsData.info.first),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ClientPro pro) {
    final info = pro.currentClientInfoTabs?.info.isNotEmpty == true
        ? pro.currentClientInfoTabs!.info.first
        : null;
    final name = info?.companyName ?? 'Client';
    final isActive = info?.status ?? false;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 35),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _handleBack(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextWidget(
              text: "Clients/ $name",
              fontWeight: FontWeight.w700,
              fontSize: 18,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              color: Colors.black,
            ),
          ),
          if (info != null && (_isStaff || _canEditOnboardingChecklist))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton(
                onPressed: () =>
                    _showToggleClientStatusDialog(context, name, isActive),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isActive
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 2,
                  ),
                ),
                child: TextWidget(
                  text: isActive ? 'Deactivate' : 'Activate',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
              ),
            ),
          if (_activeTab == 0)
            FilledButton(
              onPressed: _onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 4,
                ),
              ),
              child: const TextWidget(
                text: "✓ Save",
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _topCard(ClientPro pro) {
    final info = pro.currentClientInfoTabs?.info.isNotEmpty == true
        ? pro.currentClientInfoTabs!.info.first
        : null;
    final name = info?.companyName ?? 'Client';
    final companyLogo = info?.image ?? '';
    final isActive = info?.status ?? false;
    final createdLabel = info?.startedAtLabel ?? '';
    final typeName = info?.companyType ?? 'Type';
    final earnings = 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child:
                  companyLogo.isNotEmpty && companyLogo.toLowerCase() != 'null'
                  ? ImageWidget(image: companyLogo, fit: BoxFit.cover)
                  : ImageWidget(image: Paths.user, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: name,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          TextWidget(
                            text: isActive ? "Active" : "Inactive",
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade700,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextWidget(
                        text: typeName,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextWidget(
                      text: "Client since $createdLabel",
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextWidget(
                  text:
                      "${earnings > 0 ? "\$${earnings.toStringAsFixed(2)}" : "\$0.00"}/wk",
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 2),
                TextWidget(
                  text: "This week's charge",
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _tabItem(0, "Info"),
          if (!_isStaff) _tabItem(1, "Agreement & Standards"),
          _tabItem(2, "Onboarding & Training"),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String title) {
    bool isActive = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFFACC15) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: TextWidget(
          text: title,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? Colors.black : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildActiveTab(
    ClientPro pro,
    ClientInfoTabsModel tabsData,
    ClientInfoModel info,
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

  Widget _infoTab(ClientInfoModel info, ClientPro pro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: _logoBox(
                        label: 'LOGO',
                        imageUrl: _normalizeImageUrl(_resolvedLogoUrl(info)),
                        localFile: _selectedLogoFile,
                        onTap: () =>
                            _pickAndUploadBrandingAsset(isFavicon: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _logoBox(
                        label: 'FAVICON · 32×32PX',
                        imageUrl: _normalizeImageUrl(_resolvedFaviconUrl(info)),
                        localFile: _selectedFaviconFile,
                        subtitle: '',
                        onTap: () =>
                            _pickAndUploadBrandingAsset(isFavicon: true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _editableField(
                      'BRANDING URL',
                      _brandingUrlCtrl,
                      fontSize: 11,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _editableColorField(
                            'PRIMARY COLOR',
                            _primaryColorCtrl,
                            _primaryColor,
                            () => _openColorPicker(isPrimary: true),
                            fontSize: 11,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _editableColorField(
                            'SECONDARY COLOR',
                            _secondaryColorCtrl,
                            _secondaryColor,
                            () => _openColorPicker(isPrimary: false),
                            fontSize: 11,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TextWidget(
            text: 'COMPANY INFORMATION',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _editableField(
                  'COMPANY NAME',
                  _companyNameCtrl,
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final adminPro = Provider.of<AdminPro>(context);
                    return _editableDropdownField(
                      label: 'CLIENT TYPE',
                      hint: 'Select Type',
                      value: adminPro.clientCmpnyType
                          .where((e) => e.id == _selectedCompanyType)
                          .firstOrNull,
                      items: adminPro.clientCmpnyType,
                      onChanged: (item) =>
                          setState(() => _selectedCompanyType = item?.id),
                      fontSize: 11,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final adminPro = Provider.of<AdminPro>(context);
                    return _editableDropdownField(
                      label: 'CLIENT RANK',
                      hint: 'Select Rank',
                      value: adminPro.clientRank
                          .where((e) => e.id == _selectedClientRank)
                          .firstOrNull,
                      items: adminPro.clientRank,
                      onChanged: (item) =>
                          setState(() => _selectedClientRank = item?.id),
                      fontSize: 11,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editableField(
                  'COMPANY PHONE',
                  _companyPhoneCtrl,
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const TextWidget(
            text: 'ADDRESS',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF64748B),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _editableField(
                  'ADDRESS',
                  _addressCtrl,
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editableField(
                  'ADDRESS 2',
                  _address2Ctrl,
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _editableDropdownField(
                  label: 'STATE',
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
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editableDropdownField(
                  label: 'CITY',
                  hint: _selectedState == null
                      ? 'Select state first'
                      : 'Select City',
                  value: _findById(pro.cityDropdown, _selectedCity),
                  items: pro.cityDropdown,
                  onChanged: _selectedState == null
                      ? null
                      : (item) => setState(() => _selectedCity = item?.id),
                  fontSize: 11,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _editableField(
            'ZIPCODE',
            _zipCodeCtrl,
            fontSize: 11,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _agreementTab(ClientInfoTabsModel data, ClientInfoModel info) {
    if (data.agreementStandards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const TextWidget(
          text: 'No agreement and standards available.',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6B7280),
        ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasSigned
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
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
                      width: 38,
                      height: 38,
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
                    const SizedBox(width: 10),
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
                              const SizedBox(width: 6),
                              TextWidget(
                                text: 'v$version',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _agreementStatusChip(hasSigned: hasSigned),
                    _agreementActionButton(
                      icon: Icons.remove_red_eye_outlined,
                      label: 'View Agreement',
                      onPressed: () => _showAgreementBottomSheet(
                        context: context,
                        info: info,
                        item: item,
                      ),
                    ),
                    if (hasSigned && item.pdfUrl.isNotEmpty)
                      _agreementActionButton(
                        icon: Icons.download_rounded,
                        label: 'Download PDF',
                        outlined: true,
                        onPressed: () => _downloadAgreementPdf(
                          item.pdfUrl,
                          item.template.name,
                        ),
                      ),
                    if (!hasSigned && canSign)
                      _agreementActionButton(
                        icon: Icons.draw_outlined,
                        label: 'Sign Agreement',
                        bgColorOverride: const Color(0xFF92400E),
                        textColorOverride: Colors.white,
                        borderColorOverride: const Color(0xFF92400E),
                        onPressed: () => _showAgreementBottomSheet(
                          context: context,
                          info: info,
                          item: item,
                        ),
                      ),
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(width: 6),
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
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EBC8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFF9A6700),
                        ),
                        const SizedBox(width: 6),
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
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 12),
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
                        const SizedBox(height: 8),
                        ...rules.map(_standardRuleTile),
                        const SizedBox(height: 10),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFE6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: rule.iconSvgUrl.trim().isNotEmpty
                ? SvgPicture.network(
                    rule.iconSvgUrl,
                    width: 16,
                    height: 16,
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
          const SizedBox(width: 8),
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
                      fontSize: 12,
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

  IconData _ruleIcon(String iconName) {
    final key = iconName.toLowerCase();
    if (key.contains('briefcase')) return Icons.work_rounded;
    if (key.contains('money') || key.contains('bill') || key.contains('cash')) {
      return Icons.payments_rounded;
    }
    if (key.contains('triangle') || key.contains('exclamation')) {
      return Icons.warning_rounded;
    }
    if (key.contains('user-tie')) return Icons.badge_rounded;
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

  Widget _onboardingTab(ClientInfoTabsModel data, ClientPro pro) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextWidget(
            text: 'ONBOARDING CHECKLIST',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          const SizedBox(height: 8),
          if (!_canEditOnboardingChecklist)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEF3C7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Color(0xFF92400E)),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextWidget(
                      text:
                          'Onboarding is view-only for your role. Only admin can check or update checklist items.',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
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
            emptyMessage: 'No onboarding checklists configured.',
          ),
          const SizedBox(height: 12),
          _buildChecklistsAccordionSection(
            title: 'Training',
            subtitle: 'Client training checklist progress',
            iconData: Icons.school,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFD1FAE5),
            lists: data.training,
            pro: pro,
            emptyMessage: 'No training checklists configured.',
          ),
        ],
      ),
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
    required String emptyMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: iconColor,
          collapsedIconColor: iconColor,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.1),
                ),
                child: Icon(iconData, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
          children: [
            if (lists.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    iconColor: const Color(0xFF6B7280),
                    collapsedIconColor: const Color(0xFF6B7280),
                    title: TextWidget(
                      text:
                          '${list.name} (${list.completedItems}/${list.totalItems})',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                    children: [
                      ...list.items.map(
                        (it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: InkWell(
                            onTap: _canEditOnboardingChecklist
                                ? () => _toggleOnboardingItem(
                                    pro,
                                    list.id,
                                    it.index,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: it.isCompleted
                                        ? const Color(0xFF10B981)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: it.isCompleted
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: it.isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    it.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: it.isCompleted
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
                );
              }),
          ],
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

  Widget _editableField(
    String label,
    TextEditingController controller, {
    double fontSize = 12,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label.toUpperCase(),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF374151),
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: contentPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
    VoidCallback onPick, {
    double fontSize = 12,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label.toUpperCase(),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            GestureDetector(
              onTap: onPick,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: contentPadding,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                onChanged: (value) {
                  final parsed = _hexToColor(value);
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
  }

  void _openColorPicker({required bool isPrimary}) {
    Color tempColor = isPrimary ? _primaryColor : _secondaryColor;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: TextWidget(
            text: isPrimary ? 'Select Primary Color' : 'Select Secondary Color',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) => tempColor = color,
              enableAlpha: false,
              displayThumbColor: true,
              pickerAreaHeightPercent: 0.7,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final hex = _colorToHexString(tempColor);
                setState(() {
                  if (isPrimary) {
                    _primaryColor = tempColor;
                    _primaryColorCtrl.text = hex;
                  } else {
                    _secondaryColor = tempColor;
                    _secondaryColorCtrl.text = hex;
                  }
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  String _colorToHexString(Color c) {
    final argb = c.toARGB32();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return '#'
            '${red.toRadixString(16).padLeft(2, '0')}'
            '${green.toRadixString(16).padLeft(2, '0')}'
            '${blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Widget _editableDropdownField({
    required String label,
    required String hint,
    required DropdownItem? value,
    required List<DropdownItem> items,
    required ValueChanged<DropdownItem?>? onChanged,
    double fontSize = 12,
    EdgeInsets contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label.toUpperCase(),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
        const SizedBox(height: 4),
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
            contentPadding: contentPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
          hint: TextWidget(
            text: hint,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<DropdownItem>(
                  value: item,
                  child: TextWidget(
                    text: item.name,
                    fontSize: fontSize,
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
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            alignment: Alignment.center,
            child: _uploadingAssetType == label.toLowerCase() && onTap != null
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (localFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            localFile,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 6),
        TextWidget(
          text: subtitle == null
              ? label.toUpperCase()
              : '${label.toUpperCase()}  ${subtitle.toUpperCase()}',
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

  String _companyPhone(ClientInfoModel info) {
    for (final contact in info.contacts) {
      if (contact.contactDetails.phones.isNotEmpty) {
        return contact.contactDetails.phones.first.number;
      }
      if (contact.phone.isNotEmpty) return contact.phone;
    }
    return '';
  }

  Widget _agreementStatusChip({required bool hasSigned}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 4),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 5),
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
            showToast(message: 'Storage permission denied');
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final safeName = templateName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = '${safeName}_agreement.pdf';

      showToast(message: 'Starting download...');
      await DownloadService.instance.downloadFile(
        url: url,
        fileName: fileName,
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      debugPrint('Download agreement error: $e');
      showToast(message: 'Failed to download agreement');
    }
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
          .map((match) => _stripHtml(match.group(1) ?? '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    return _stripHtml(html)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('-') ? line.substring(1).trim() : line)
        .toList();
  }

  void _showAgreementBottomSheet({
    required BuildContext context,
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
            (contact) => contact.isPrimary,
            orElse: () => info.contacts.first,
          );
    final fullContactName = primaryContact == null
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
    ].where((line) => line.trim().isNotEmpty).join('\n');
    final clientSubtitle = 'Contact: $fullContactName\n$fullAddress';
    final agreementItems = _extractListItemsFromHtml(item.content);

    bool isConfirmed = false;
    final nameController = TextEditingController(
      text: fullContactName.toLowerCase() == 'n/a' ? '' : fullContactName,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) {
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
        final dateString =
            '${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final enteredText = nameController.text.trim();
            final enteredWords = enteredText
                .split(RegExp(r'\s+'))
                .where((word) => word.isNotEmpty)
                .toList();
            final hasFirstAndLastName = enteredWords.length >= 2;

            bool isNameValid = false;
            if (hasFirstAndLastName) {
              final contactWords = fullContactName
                  .split(RegExp(r'\s+'))
                  .where((word) => word.isNotEmpty)
                  .toList();
              if (contactWords.isEmpty ||
                  fullContactName.toLowerCase() == 'n/a') {
                isNameValid = true;
              } else {
                final expectedFirstName = contactWords.first.toLowerCase();
                final enteredFirstName = enteredWords.first.toLowerCase();
                final exactMatch =
                    enteredText.toLowerCase() == fullContactName.toLowerCase();
                isNameValid =
                    exactMatch || enteredFirstName == expectedFirstName;
              }
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 28,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                  maxHeight: 760,
                ),
                child: Column(
                  children: [
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: templateName,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 4),
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
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: TextWidget(
                                          text: templateName,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          maxLines: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      TextWidget(
                                        text: 'v$version',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF9CA3AF),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
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
                                        const TextSpan(text: ' (Company) and '),
                                        TextSpan(
                                          text: clientName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const TextSpan(text: ' (Client).'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            const SizedBox(height: 14),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _agreementPartyCard(
                                      title: 'COMPANY',
                                      name: 'Print Helpers LLC',
                                      subtitle:
                                          'printhelpers.com\n2080 Empire Ave. #1032\nBurbank, CA 91504',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
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
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                ),
                              ),
                              child: agreementItems.isEmpty
                                  ? const TextWidget(
                                      text: 'No agreement content available.',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6B7280),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: agreementItems
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TextWidget(
                                                    text: '${entry.key + 1}. ',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: const Color(
                                                      0xFF111827,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: TextWidget(
                                                      text: entry.value,
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
                            if (item.rules.isNotEmpty) ...[
                              const SizedBox(height: 12),
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
                                    const SizedBox(height: 8),
                                    ...rules.map(_standardRuleTile),
                                    const SizedBox(height: 10),
                                  ],
                                );
                              }),
                            ],
                            _buildElectronicSignatureSection(
                              item: item,
                              contactName: fullContactName,
                              isConfirmed: isConfirmed,
                              onConfirmedChanged: (value) {
                                setModalState(() {
                                  isConfirmed = value;
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: item.hasSigned
                                ? OutlinedButton(
                                    onPressed: item.pdfUrl.isNotEmpty
                                        ? () => _downloadAgreementPdf(
                                            item.pdfUrl,
                                            item.template.name,
                                          )
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF2563EB),
                                      ),
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf,
                                          color: Color(0xFF2563EB),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        TextWidget(
                                          text: 'Download PDF',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ],
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    onPressed:
                                        item.canSign &&
                                            isConfirmed &&
                                            isNameValid
                                        ? () async {
                                            final pro = Provider.of<ClientPro>(
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
                                            if (res && dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          }
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF5D070),
                                      disabledBackgroundColor: const Color(
                                        0xFFF5E8C4,
                                      ),
                                      foregroundColor: const Color(0xFF475569),
                                      disabledForegroundColor: const Color(
                                        0xFF94A3B8,
                                      ),
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: Icon(
                                      Icons.draw_outlined,
                                      size: 18,
                                      color:
                                          item.canSign &&
                                              isConfirmed &&
                                              isNameValid
                                          ? const Color(0xFF475569)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    label: const Text(
                                      'I Agree & Sign',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(96, 46),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(nameController.dispose);
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
        const SizedBox(height: 12),
        const TextWidget(
          text: 'Electronic Signature',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 8),
                const TextWidget(
                  text:
                      'The name, date, and confirmation below reflect what was submitted when this agreement was signed.',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF15803D),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    children: [
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
          const SizedBox(height: 16),
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
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 12),
          TextWidget(
            text: 'IP address (recorded): ${item.ipAddress}',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: true,
                  onChanged: null,
                  activeColor: Color(0xFFD58F16),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
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
          const SizedBox(height: 16),
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
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: contactName.toLowerCase() == 'n/a'
                            ? 'First Last'
                            : contactName.split(RegExp(r'\s+')).length >= 2
                            ? contactName
                            : '$contactName Last',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF9CA3AF),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text: contactName.toLowerCase() == 'n/a'
                          ? 'Please enter your full first and last name.'
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: isConfirmed,
                  onChanged: (value) => onConfirmedChanged(value ?? false),
                  activeColor: const Color(0xFFD58F16),
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Expanded(
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
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(value: false, onChanged: null),
              ),
              SizedBox(width: 8),
              Expanded(
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextWidget(
            text: '•',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
          const SizedBox(width: 8),
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

  Widget _agreementPartyCard({
    required String title,
    required String name,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 6),
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
