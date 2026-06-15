import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_helper/models/account_contract_rules_model.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/services/download_service.dart';
import 'dart:io';
import 'package:print_helper/utils/formatter.dart';

import '../../tab_constants/colors.dart';
import '../../tab_constants/paths.dart';
import '../../tab_services/helpers.dart';
import '../../tab_widgets/tab_image_widget.dart';
import '../../tab_widgets/tab_spacers.dart';
import '../../tab_widgets/tab_text_widget.dart';
import '../../tab_widgets/tab_toasts.dart';

class TabAccountInfoTabletScreen extends StatefulWidget {
  final AccountModel account;
  final bool isFromAdmin;
  final VoidCallback? onBack;

  const TabAccountInfoTabletScreen({
    super.key,
    required this.account,
    this.isFromAdmin = true,
    this.onBack,
  });

  @override
  State<TabAccountInfoTabletScreen> createState() =>
      _TabAccountInfoTabletScreenState();
}

class _TabAccountInfoTabletScreenState
    extends State<TabAccountInfoTabletScreen> {
  // Add missing zip code controller
  final TextEditingController _zipCodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isDownloading = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _timeDoctorCtrl = TextEditingController();
  final _paymentMethodCtrl = TextEditingController();
  final _paymentAccountCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final List<TextEditingController> _emailCtrls = [];
  final List<PhoneField> _phoneEntries = [];
  int? _openPhoneDropdownIndex;

  int _activeTab = 0;
  int? _selectedTypeId;
  int? _selectedLanguageId;
  List<int> _selectedSkillIds = [];
  bool _isCurrentUserAdmin = false;
  final Set<String> _togglingChecklistItems = <String>{};
  bool _isOnboardingExpanded = true;
  bool _isTrainingExpanded = true;
  final Set<int> _expandedChecklistIds = <int>{};

  final List<String> _levels = ['Silver', 'Gold', 'Platinum', 'Diamond'];
  String _selectedLevel = 'Silver';

  late final List<PhoneType> _phoneTypes = [
    PhoneType("Land Phone", Paths.landPhone, "landline"),
    PhoneType("Phone", Paths.call, "mobile"),
    PhoneType("Other", Paths.other, "another"),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _isCurrentUserAdmin =
          (prefs.getString("role_name") ?? "").toLowerCase() == "admin";

      final pro = getAdminPro(context);
      final isAdmin = widget.account.roleName.toLowerCase() == 'admin';

      if (isAdmin) {
        await Future.wait([
          pro.fetchAllDropdownData(context),
          pro.fetchStates(),
          pro.getAccountInfo(widget.account.id),
        ]);
      } else {
        await Future.wait([
          pro.fetchAllDropdownData(context),
          pro.fetchStates(),
          pro.getAccountContractRules(widget.account.id),
          pro.getOnboardingTraining(widget.account.id),
          pro.getAccountInfo(widget.account.id),
        ]);
      }
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _roleCtrl.dispose();
    _startDateCtrl.dispose();
    _timeDoctorCtrl.dispose();
    _paymentMethodCtrl.dispose();
    _paymentAccountCtrl.dispose();
    _addressCtrl.dispose();
    _address2Ctrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _zipCodeCtrl.dispose();
    for (final c in _emailCtrls) {
      c.dispose();
    }
    for (final p in _phoneEntries) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _loadInitialData() {
    final acc = widget.account;
    final pro = getAdminPro(context);

    _firstNameCtrl.text = acc.name;
    _lastNameCtrl.text = acc.lastName;
    _usernameCtrl.text = acc.username;

    final rName = acc.roleName.isNotEmpty ? acc.roleName : "Silver";
    if (_levels.any((e) => e.toLowerCase() == rName.toLowerCase())) {
      _selectedLevel = _levels.firstWhere(
        (e) => e.toLowerCase() == rName.toLowerCase(),
      );
    } else {
      _selectedLevel = 'Silver';
    }
    _roleCtrl.text = _selectedLevel;

    _startDateCtrl.text = _safeDate(acc.createdAt);

    // Validate accountType exists in dropdown before setting
    final parsedTypeId = int.tryParse(acc.accountType ?? "0");
    if (parsedTypeId != null &&
        pro.accountTypes.any((e) => e.id == parsedTypeId)) {
      _selectedTypeId = parsedTypeId;
    } else {
      _selectedTypeId = pro.accountTypes.isNotEmpty
          ? pro.accountTypes.first.id
          : null;
    }

    _phoneEntries
      ..clear()
      ..addAll(
        acc.phones.map((p) {
          final phoneType = _phoneTypes.firstWhere(
            (t) => t.apiValue == p.type,
            orElse: () => _phoneTypes[1],
          );
          return PhoneField(
            type: phoneType,
            controller: TextEditingController(text: p.number),
          );
        }),
      );
    if (_phoneEntries.isEmpty) {
      _phoneEntries.add(
        PhoneField(type: _phoneTypes[1], controller: TextEditingController()),
      );
    }

    _emailCtrls
      ..clear()
      ..addAll(acc.emails.map((e) => TextEditingController(text: e)));
    if (_emailCtrls.isEmpty) {
      _emailCtrls.add(TextEditingController(text: acc.email ?? ""));
    }

    final languageIds =
        acc.staffDetails?.languages
            .map((langName) {
              final found = pro.languages.where(
                (e) => e.name.toLowerCase() == langName.toLowerCase(),
              );
              return found.isNotEmpty ? found.first.id : -1;
            })
            .where((id) => id != -1)
            .toList() ??
        [];
    if (languageIds.isNotEmpty) _selectedLanguageId = languageIds.first;

    _selectedSkillIds =
        acc.staffDetails?.skills
            .map((skillName) {
              final found = pro.skills.where(
                (e) => e.name.toLowerCase() == skillName.toLowerCase(),
              );
              return found.isNotEmpty ? found.first.id : -1;
            })
            .where((id) => id != -1)
            .toList() ??
        [];

    final detail = pro.currentAccountDetail;
    if (detail != null) {
      _paymentMethodCtrl.text = detail.roleAssignment.paymentMethod ?? "";
      _paymentAccountCtrl.text = detail.roleAssignment.paymentAccount ?? "";
      _addressCtrl.text = detail.roleAssignment.address ?? "";
      _address2Ctrl.text = detail.roleAssignment.address2 ?? "";
      _selectedSkillIds = List<int>.from(detail.personal.skillIds);
    }

    setState(() {});
  }

  String _safeDate(String raw) {
    final f = formatDateTime(raw);
    if (f.isEmpty) return "";
    return f.split("\n").first;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newPasswordCtrl.text.isNotEmpty &&
        _newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      showToast(message: "Password confirmation does not match");
      return;
    }
    final pro = getAdminPro(context);
    final phones = _phoneEntries
        .map(
          (p) => {"type": p.type.apiValue, "value": p.controller.text.trim()},
        )
        .toList();
    final emails = _emailCtrls
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final errorMsg = await pro.updateAccount(
      id: widget.account.id,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      phones: phones,
      emails: emails,
      type: _selectedTypeId ?? 0,
      languages: _selectedLanguageId == null ? [] : [_selectedLanguageId!],
      skills: _selectedSkillIds,
      level: _selectedLevel,
      paymentMethod: _paymentMethodCtrl.text.trim(),
      paymentAccount: _paymentAccountCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      address2: _address2Ctrl.text.trim(),
      password: _newPasswordCtrl.text.isNotEmpty ? _newPasswordCtrl.text : null,
      imagePath: null,
      context: context,
    );

    if (!mounted) return;
    if (errorMsg == null) {
      showToast(message: "Account Updated Successfully");
      _handleBack(context);
      pro.getAccounts(ctx: context);
    } else {
      showToast(message: errorMsg);
    }
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

  String _prettyRoleLabel() {
    final raw = widget.account.roleName.isNotEmpty
        ? widget.account.roleName
        : (widget.account.accountType ?? "-");
    if (raw.isEmpty || raw == "-") return "-";
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _cleanHtmlToText(String html) {
    if (html.trim().isEmpty) return "";
    final withBreaks = html
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*li\s*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'<\s*/\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<\s*p\s*>', caseSensitive: false), '');
    final stripped = withBreaks
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    return stripped
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  Color _colorFromHex(String? hex, {Color fallback = Colors.grey}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return fallback;
    final parsed = int.tryParse('FF$clean', radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  IconData _iconFromRuleName(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'triangle-exclamation':
      case 'exclamation-triangle':
        return Icons.warning_amber_rounded;
      case 'copyright':
        return Icons.copyright;
      case 'star':
        return Icons.star;
      default:
        return Icons.rule_folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = getAdminPro(context);
    final initials =
        "${widget.account.name.isNotEmpty ? widget.account.name[0] : ""}${widget.account.lastName.isNotEmpty ? widget.account.lastName[0] : ""}"
            .toUpperCase();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin: EdgeInsets.zero,
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Color(0xFFF4F5F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _topCards(initials),
                        ),
                        const SizedBox(height: 24),
                        _tabBar(),
                        const SizedBox(height: 24),
                        _buildActiveTab(pro),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      decoration: const BoxDecoration(color: AppColors.bg),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _handleBack(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          ),
          const SizedBox(width: 18),
          ImageWidget(image: Paths.accounts, width: 30),
          const SizedBox(width: 16),
          const TextWidget(
            text: "Account Info",
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _onSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              elevation: 0,
            ),
            child: const Row(
              children: [
                Icon(Icons.check, color: Colors.white, size: 20),
                SizedBox(width: 8),
                TextWidget(
                  text: "Save",
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTemplateContent(String content) {
    final clean = _cleanHtmlToText(content);
    if (clean.isEmpty) return clean;
    final lines = clean.split('\n');
    int bulletIndex = 1;
    final updatedLines = lines.map((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-')) {
        final cleanText = trimmed.substring(1).trim();
        return "${bulletIndex++}. $cleanText";
      }
      return line;
    }).toList();
    return updatedLines.join('\n');
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

  void _showAgreementDialog(BuildContext context, {required AdminPro pro}) {
    final data = pro.currentAccountContractRules;
    final account = data?.account;
    final agreement = data?.agreement;
    final template = data?.template;
    final name = account?.fullName.isNotEmpty == true
        ? account!.fullName
        : "${widget.account.name} ${widget.account.lastName}".trim();
    final role = account?.accountType.isNotEmpty == true
        ? account!.accountType
        : _prettyRoleLabel();
    final email = account?.email.isNotEmpty == true
        ? account!.email
        : (widget.account.email ?? "");
    final templateContent = _formatTemplateContent(template?.content ?? "");
    final rules = data?.rules ?? const <AccountRuleCategoryModel>[];
    final firstNameOnly = account?.name.isNotEmpty == true
        ? account!.name
        : widget.account.name;
    final displayRole = (role.isEmpty || role.toLowerCase() == 'null')
        ? ""
        : role;
    final displayEmail = (email.isEmpty || email.toLowerCase() == 'null')
        ? ""
        : email;

    final detail = pro.currentAccountDetail;
    final fallbackAddr = detail?.roleAssignment.address ?? "";
    final fallbackAddr2 = detail?.roleAssignment.address2 ?? "";
    final contractorAddress =
        (account?.address.isNotEmpty == true &&
            account?.address.toLowerCase() != 'null')
        ? account!.address
        : (fallbackAddr.isNotEmpty && fallbackAddr.toLowerCase() != 'null'
              ? fallbackAddr
              : "");
    final contractorAddress2 =
        (account?.address2.isNotEmpty == true &&
            account?.address2.toLowerCase() != 'null')
        ? account!.address2
        : (fallbackAddr2.isNotEmpty && fallbackAddr2.toLowerCase() != 'null'
              ? fallbackAddr2
              : "");

    // Signing form state
    final hasSigned = agreement?.isSigned == true;
    final signerNameCtrl = TextEditingController(
      text: hasSigned ? agreement!.signerName : name,
    );
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final formattedToday = "${months[now.month - 1]} ${now.day}, ${now.year}";
    final signedDateCtrl = TextEditingController(
      text: hasSigned ? agreement!.signedAtLabel : formattedToday,
    );
    bool isSigning = false;
    bool isConfirmed = hasSigned;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSigningState) {
            final isNameValid =
                signerNameCtrl.text.trim().toLowerCase() ==
                name.trim().toLowerCase();
            final canSign = isConfirmed && isNameValid && !isSigning;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 40,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: "Independent Contractor Agreement",
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 3),
                                  TextWidget(
                                    text:
                                        "Print Helpers – Please read carefully before signing",
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFAAAAAA),
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
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const TextWidget(
                                      text: "PRINT HELPERS LLC",
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF9CA3AF),
                                      letterSpacing: 2,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    const TextWidget(
                                      text: "Independent Contractor Agreement",
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151),
                                        ),
                                        children: [
                                          const TextSpan(
                                            text:
                                                "This agreement is entered into between ",
                                          ),
                                          const TextSpan(
                                            text: "Print Helpers LLC",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: " (Company) and ",
                                          ),
                                          TextSpan(
                                            text: name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: " (Contractor).",
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Color(0xFFE5E7EB)),
                              const SizedBox(height: 12),
                              IntrinsicHeight(
                                child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextWidget(
                                            text: "COMPANY",
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9CA3AF),
                                            letterSpacing: 1.5,
                                          ),
                                          SizedBox(height: 6),
                                          TextWidget(
                                            text: "Print Helpers LLC",
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          TextWidget(
                                            text: "printhelpers.com",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                          TextWidget(
                                            text:
                                                "2080 Empire Ave. #1032, Burbank, CA 91504",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "CONTRACTOR",
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9CA3AF),
                                            letterSpacing: 1.5,
                                          ),
                                          const SizedBox(height: 6),
                                          TextWidget(
                                            text: firstNameOnly,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          if (displayRole.isNotEmpty)
                                            TextWidget(
                                              text: displayRole,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          if (displayEmail.isNotEmpty)
                                            TextWidget(
                                              text: displayEmail,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          if (contractorAddress.isNotEmpty)
                                            TextWidget(
                                              text: contractorAddress,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF6B7280),
                                            ),
                                          if (contractorAddress2.isNotEmpty)
                                            TextWidget(
                                              text: contractorAddress2,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF6B7280),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: TextWidget(
                                  text: templateContent.isEmpty
                                      ? "No agreement content configured in Staff Template."
                                      : templateContent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (agreement != null && agreement.isSigned)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextWidget(
                                    text:
                                        "Signed on ${agreement.signedAtLabel.isNotEmpty ? agreement.signedAtLabel : 'N/A'} by ${agreement.signerName.isNotEmpty ? agreement.signerName : name}",
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                              ...rules.map((category) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: category.category.isEmpty
                                          ? "Uncategorized"
                                          : category.category,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    const Divider(color: Color(0xFFE5E7EB)),
                                    ...category.items.map((item) {
                                      final iconColor = _colorFromHex(
                                        item.colorHex,
                                        fallback: const Color(0xFF6B7280),
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              _iconFromRuleName(item.iconName),
                                              color: iconColor,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TextWidget(
                                                    text: item.title,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  TextWidget(
                                                    text: item.description,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                    color: const Color(
                                                      0xFF6B7280,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              }),
                              if (agreement != null &&
                                  (agreement.isSigned ||
                                      agreement.canSign)) ...[
                                const SizedBox(height: 16),
                                const TextWidget(
                                  text: "Electronic Signature",
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFEF3C7),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const TextWidget(
                                        text:
                                            "By typing your full name and clicking \"I Agree & Sign\" below, you acknowledge that:",
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF92400E),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "• ",
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF92400E),
                                          ),
                                          Expanded(
                                            child: TextWidget(
                                              text:
                                                  "You have read and understand this Agreement and all linked policies;",
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "• ",
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF92400E),
                                          ),
                                          Expanded(
                                            child: TextWidget(
                                              text:
                                                  "You have authority to enter into this Agreement;",
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "• ",
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF92400E),
                                          ),
                                          Expanded(
                                            child: TextWidget(
                                              text:
                                                  "You agree to be legally bound by all terms herein;",
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "• ",
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF92400E),
                                          ),
                                          Expanded(
                                            child: TextWidget(
                                              text:
                                                  "Your electronic signature is binding under the Uniform Electronic Transactions Act (UETA) and has the same legal effect as a handwritten signature;",
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "• ",
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF92400E),
                                          ),
                                          Expanded(
                                            child: TextWidget(
                                              text:
                                                  "You consent to Service Provider collecting your IP address for security and record-keeping purposes.",
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (agreement.isSigned) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF86EFAC),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(
                                          text:
                                              "Record of electronic signature",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF15803D),
                                        ),
                                        const SizedBox(height: 8),
                                        const TextWidget(
                                          text:
                                              "The name, date, and confirmation below reflect what was submitted when this agreement was signed.",
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF15803D),
                                        ),
                                        const SizedBox(height: 8),
                                        RichText(
                                          text: const TextSpan(
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF15803D),
                                            ),
                                            children: [
                                              TextSpan(text: 'The '),
                                              TextSpan(
                                                text: 'terms & conditions',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "Full Legal Name *",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: signerNameCtrl,
                                            enabled:
                                                !isSigning &&
                                                !agreement.isSigned,
                                            onChanged: (val) {
                                              setSigningState(() {});
                                            },
                                            decoration: InputDecoration(
                                              hintText:
                                                  "Enter your full legal name",
                                              hintStyle: const TextStyle(
                                                color: Color(0xFFD1D5DB),
                                                fontSize: 13,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFD1D5DB),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFD1D5DB),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          if (!agreement.isSigned) ...[
                                            const SizedBox(height: 4),
                                            const TextWidget(
                                              text:
                                                  "Must exactly match the account name to be valid.",
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "Date",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: signedDateCtrl,
                                            enabled: false,
                                            decoration: InputDecoration(
                                              hintText: "Date",
                                              hintStyle: const TextStyle(
                                                color: Color(0xFFD1D5DB),
                                                fontSize: 13,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFD1D5DB),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFD1D5DB),
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (agreement.isSigned &&
                                    agreement.ipAddress.isNotEmpty &&
                                    agreement.ipAddress.toLowerCase() !=
                                        'null') ...[
                                  const SizedBox(height: 12),
                                  TextWidget(
                                    text:
                                        "IP address (recorded): ${agreement.ipAddress}",
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: Checkbox(
                                        value: isConfirmed,
                                        onChanged:
                                            (isSigning || agreement.isSigned)
                                            ? null
                                            : (val) {
                                                setSigningState(() {
                                                  isConfirmed = val ?? false;
                                                });
                                              },
                                        activeColor: const Color(0xFFD58F16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextWidget(
                                        text: agreement.isSigned
                                            ? "I confirmed that I had read and agreed to the statements above at the time of signing."
                                            : "I confirm that I have read and agree to the statements above.",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            if (agreement != null &&
                                !agreement.isSigned &&
                                !agreement.canSign) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Color(0xFF6B7280),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: TextWidget(
                                        text:
                                            'View only: only this account holder can sign this agreement.',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Checkbox(
                                      value: false,
                                      onChanged: null,
                                      activeColor: const Color(0xFFD58F16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: TextWidget(
                                      text:
                                          'I confirm that I have read and agree to the statements above. Only the account holder can check this when signing.',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (agreement != null &&
                                !agreement.isSigned &&
                                agreement.canSign) ...[
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: canSign
                                      ? () async {
                                          final signerName = signerNameCtrl.text
                                              .trim();
                                          if (signerName.isEmpty) {
                                            showToast(
                                              message:
                                                  "Please enter your full legal name",
                                            );
                                            return;
                                          }

                                          setSigningState(() {
                                            isSigning = true;
                                          });

                                          final result = await pro
                                              .signAccountAgreement(
                                                accountId: widget.account.id,
                                                signerName: signerName,
                                                signedDate: DateTime.now()
                                                    .toIso8601String(),
                                              );

                                          setSigningState(() {
                                            isSigning = false;
                                          });

                                          if (result && ctx.mounted) {
                                            Navigator.pop(ctx);
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isSigning
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.draw_outlined,
                                              size: 18,
                                              color: canSign
                                                  ? const Color(0xFF475569)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 8),
                                            TextWidget(
                                              text: "I Agree & Sign",
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: canSign
                                                  ? const Color(0xFF475569)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ] else if (agreement != null &&
                                !agreement.isSigned &&
                                !agreement.canSign) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: null,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const TextWidget(
                                    text: "Only Account Holder Can Sign",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ] else if (agreement != null &&
                                agreement.isSigned) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    final link = agreement.pdfUrl.isNotEmpty
                                        ? agreement.pdfUrl
                                        : agreement.pdfWebUrl;
                                    if (link.isNotEmpty) {
                                      _downloadAgreementPdf(
                                        link,
                                        template?.name ??
                                            "Specialist Contractor Agreement",
                                      );
                                    } else {
                                      showToast(
                                        message: "PDF link not available",
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF2563EB),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                      const SizedBox(width: 8),
                                      const TextWidget(
                                        text: 'Download PDF',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            OutlinedButton(
                              onPressed: isSigning
                                  ? null
                                  : () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: const TextWidget(
                                text: "Cancel",
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
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

  Widget _buildActiveTab(AdminPro pro) {
    final isAdmin = widget.account.roleName.toLowerCase() == 'admin';

    if (isAdmin) {
      return _formCard(pro);
    }

    switch (_activeTab) {
      case 0:
        return _formCard(pro);
      case 1:
        return _careerPathTab();
      case 2:
        return _onboardingAndTrainingTab(pro);
      case 3:
        return _contractAndRulesTab(pro);
      default:
        return const SizedBox();
    }
  }

  // ─── Avatar ─────────────────────────────────────────────────────────────
  Widget _buildAvatar(String initials) {
    final imageUrl = widget.account.imageUrl;
    final hasImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        imageUrl.toLowerCase() != 'null';

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFDDF5D9),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasImage
          ? Image.network(
              imageUrl,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => TextWidget(
                text: initials,
                color: const Color(0xFF0A8C42),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            )
          : TextWidget(
              text: initials,
              color: const Color(0xFF0A8C42),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
    );
  }

  // ─── Top Cards ───────────────────────────────────────────────────────────
  Widget _topCards(String initials) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _profileSummaryCard(initials)),
        const SizedBox(width: 12),
        _earningsCard(),
      ],
    );
  }

  Widget _profileSummaryCard(String initials) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildAvatar(initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextWidget(
                  text: "${widget.account.name} ${widget.account.lastName}",
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      label: widget.account.status ? "● Active" : "● Inactive",
                      bg: widget.account.status
                          ? const Color(0xFFD8F4DF)
                          : const Color(0xFFFEE2E2),
                      fg: widget.account.status
                          ? const Color(0xFF0A8C42)
                          : const Color(0xFFB91C1C),
                    ),
                    _chip(
                      label: _prettyRoleLabel(),
                      bg: const Color(0xFFE5EEFF),
                      fg: const Color(0xFF2454C4),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextWidget(
                  text: "Started ${_safeDate(widget.account.createdAt)}",
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          TextWidget(
            text: "\$00.00",
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: Color(0xFF0A8C42),
          ),
          SizedBox(height: 2),
          TextWidget(
            text: "THIS WEEK'S EARNINGS",
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A8C42),
            letterSpacing: 1.5,
          ),
        ],
      ),
    );
  }

  // ─── Tab Bar ─────────────────────────────────────────────────────────────
  List<String> _getAvailableTabs() {
    final isAdmin = widget.account.roleName.toLowerCase() == 'admin';
    if (isAdmin) {
      return ["Info"];
    }
    return ["Info", "Career Path", "Onboarding & Training", "Contract & Rules"];
  }

  Widget _tabBar() {
    final tabs = _getAvailableTabs();
    if (tabs.length == 1) {
      return const SizedBox();
    }
    return Container(
      padding: const EdgeInsets.only(bottom: 6, left: 12, top: 6),
      decoration: BoxDecoration(
        color: Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final active = _activeTab == entry.key;
          return GestureDetector(
            onTap: () => setState(() => _activeTab = entry.key),
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active
                        ? const Color(0xFFFACC15)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: TextWidget(
                text: entry.value,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.black : const Color(0xFF6B7280),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Contract & Rules Tab ─────────────────────────────────────────────────
  Widget _contractAndRulesTab(AdminPro pro) {
    if (pro.accountContractRulesLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = pro.currentAccountContractRules;
    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextWidget(
              text: "Unable to load contract and rules",
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => pro.getAccountContractRules(widget.account.id),
              child: const TextWidget(
                text: "Retry",
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final agreement = data.agreement;
    final signed = agreement.isSigned;
    final signer = signed
        ? (agreement.signerName.isNotEmpty
              ? agreement.signerName
              : data.account.fullName)
        : (agreement.expectedSignerName.isNotEmpty
              ? agreement.expectedSignerName
              : data.account.fullName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: signed ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
              width: signed ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: signed
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        signed ? Icons.check : Icons.picture_as_pdf,
                        color: signed ? Colors.white : const Color(0xFF8A5800),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TextWidget(
                            text: "Contractor Agreement",
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          const SizedBox(height: 3),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                              children: [
                                TextSpan(
                                  text: signed
                                      ? "Signed by "
                                      : "Pending signature from ",
                                ),
                                TextSpan(
                                  text: signer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextWidget(
                            text: signed
                                ? "Agreement is signed and available for viewing."
                                : "Please review and sign the contractor agreement to activate your account and begin receiving compensation.",
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF374151),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: signed
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      signed
                                          ? Icons.check_circle
                                          : Icons.access_time_filled,
                                      color: signed
                                          ? Colors.white
                                          : const Color(0xFF8A5800),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    TextWidget(
                                      text: signed
                                          ? "Signed"
                                          : "Pending Signature",
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: signed
                                          ? Colors.white
                                          : const Color(0xFF8A5800),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final link = agreement.pdfWebUrl.isNotEmpty
                                      ? agreement.pdfWebUrl
                                      : agreement.pdfUrl;
                                  if (link.isNotEmpty) {
                                    tryLaunchUrl(
                                      url: link,
                                      message: "Unable to open agreement",
                                    );
                                  } else {
                                    _showAgreementDialog(context, pro: pro);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: signed
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFF2563EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        color: signed
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFF2563EB),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      TextWidget(
                                        text: "View Agreement",
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: signed
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isCurrentUserAdmin && !signed)
                                GestureDetector(
                                  onTap: () {
                                    showToast(
                                      message:
                                          "Reminder can be sent from Contracts settings.",
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications,
                                          color: Color(0xFFB45309),
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        TextWidget(
                                          text: "Send Reminder",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB45309),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (!signed && agreement.canSign)
                                GestureDetector(
                                  onTap: () =>
                                      _showAgreementDialog(context, pro: pro),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF92400E),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.draw_outlined,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        TextWidget(
                                          text: "Sign Agreement",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ],
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
              ),
              if (signed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F9EE),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF22C55E),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextWidget(
                          text:
                              "Agreement signed by $signer on ${agreement.signedAtLabel.isNotEmpty ? agreement.signedAtLabel : 'N/A'}.",
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                )
              else if (!agreement.canSign)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Color(0xFFD97706), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextWidget(
                          text:
                              "View only: only this account holder can sign the agreement.",
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: TextWidget(
                  text: "These are the core standards agreed for this account.",
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              if (data.rules.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: TextWidget(
                    text: "No rules available",
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                )
              else
                ...data.rules.map((category) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: category.category.isEmpty
                              ? "Uncategorized"
                              : category.category,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                        const SizedBox(height: 8),
                        ...category.items.map((item) {
                          final iconColor = _colorFromHex(
                            item.colorHex,
                            fallback: const Color(0xFF6B7280),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _iconFromRuleName(item.iconName),
                                  color: iconColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextWidget(
                                        text: item.title,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      const SizedBox(height: 3),
                                      TextWidget(
                                        text: item.description,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: Color(0xFFE5E7EB), height: 1),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _careerPathTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.map_rounded,
                size: 32,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 18),
            const TextWidget(
              text: "Career Path Coming Soon",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const TextWidget(
                text:
                    "This section is reserved for the upcoming career growth experience. Milestones, progression, and development goals will be available in a future release.",
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4B5563),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: const TextWidget(
                text: "UNDER DEVELOPMENT",
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _onboardingAndTrainingTab(AdminPro pro) {
    if (pro.onboardingTrainingLoad) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = pro.currentOnboardingTraining;
    if (data == null) {
      return _emptyOnboardingState();
    }

    if (data.onboarding.isEmpty && data.training.isEmpty) {
      return _emptyOnboardingState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildViewOnlyBanner(),
        if (data.onboarding.isNotEmpty) ...[
          _buildSectionCard(
            title: "Onboarding",
            subtitle: "Client onboarding progress and setup tasks",
            icon: Icons.rocket_launch_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBgColor: const Color(0xFFDBEAFE),
            listCount: data.onboarding.length,
            isExpanded: _isOnboardingExpanded,
            onToggle: () =>
                setState(() => _isOnboardingExpanded = !_isOnboardingExpanded),
            children: data.onboarding
                .map((c) => _buildChecklistCard(pro, c))
                .toList(),
          ),
        ],
        if (data.training.isNotEmpty) ...[
          _buildSectionCard(
            title: "Training",
            subtitle: "Staff training progress and learning paths",
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF16A34A),
            iconBgColor: const Color(0xFFDCFCE7),
            listCount: data.training.length,
            isExpanded: _isTrainingExpanded,
            onToggle: () =>
                setState(() => _isTrainingExpanded = !_isTrainingExpanded),
            children: data.training
                .map((c) => _buildChecklistCard(pro, c))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildViewOnlyBanner() {
    if (_isCurrentUserAdmin) return const SizedBox();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, color: Color(0xFFB45309), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextWidget(
                  text: "View Only Access",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
                const SizedBox(height: 2),
                const TextWidget(
                  text:
                      "Only administrators can update onboarding and training checklist items.",
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF92400E),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required int listCount,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(isExpanded ? 0 : 16),
              bottomRight: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: title,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        const SizedBox(height: 2),
                        TextWidget(
                          text: subtitle,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextWidget(
                      text: "$listCount Lists",
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: children),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistCard(AdminPro pro, ChecklistData checklist) {
    final isExpanded = _expandedChecklistIds.contains(checklist.id);
    final total = checklist.items.length;
    final completed = checklist.items.where((e) => e.isCompleted).length;
    final progress = total == 0 ? 0.0 : completed / total;

    String status = "Pending";
    Color statusBg = const Color(0xFFF3F4F6);
    Color statusFg = const Color(0xFF4B5563);

    if (completed == total && total > 0) {
      status = "Completed";
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF15803D);
    } else if (completed > 0) {
      status = "In Progress";
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFFB45309);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedChecklistIds.remove(checklist.id);
                } else {
                  _expandedChecklistIds.add(checklist.id);
                }
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(isExpanded ? 0 : 14),
              bottomRight: Radius.circular(isExpanded ? 0 : 14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      size: 16,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: checklist.name,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                        ),
                        const SizedBox(height: 2),
                        TextWidget(
                          text: "$completed of $total completed",
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: progress,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextWidget(
                      text: status,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusFg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: checklist.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _checklistItem(
                    pro: pro,
                    checklistId: checklist.id,
                    item: item,
                    displayIndex: idx + 1,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checklistItem({
    required AdminPro pro,
    required int checklistId,
    required ChecklistItemData item,
    required int displayIndex,
  }) {
    final toggleKey = '$checklistId-${item.index}';
    final isToggling = _togglingChecklistItems.contains(toggleKey);
    final canToggle = _isCurrentUserAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          InkWell(
            onTap: !canToggle || isToggling
                ? null
                : () async {
                    setState(() {
                      _togglingChecklistItems.add(toggleKey);
                    });

                    await pro.toggleAccountChecklistItem(
                      accountId: widget.account.id,
                      checklistId: checklistId,
                      itemIndex: item.index,
                    );

                    if (!mounted) return;
                    setState(() {
                      _togglingChecklistItems.remove(toggleKey);
                    });
                  },
            borderRadius: BorderRadius.circular(5),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(
                  color: item.isCompleted
                      ? const Color(0xFF10B981)
                      : canToggle
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(5),
                color: item.isCompleted
                    ? const Color(0xFF10B981)
                    : !canToggle
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
              ),
              child: isToggling
                  ? Padding(
                      padding: const EdgeInsets.all(3),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10B981),
                      ),
                    )
                  : item.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextWidget(
              text: "$displayIndex. ${_cleanBulletText(item.text)}",
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: item.isCompleted
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          TextWidget(
            text: item.completedAtLabel,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: item.isCompleted
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  String _cleanBulletText(String text) {
    String temp = text.trim();
    if (temp.startsWith('-')) {
      temp = temp.substring(1).trim();
    }
    return temp;
  }

  Widget _emptyOnboardingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rocket_launch_rounded, size: 18, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Expanded(
            child: TextWidget(
              text: "No onboarding checklists found for this account type.",
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Card ───────────────────────────────────────────────────────────
  Widget _formCard(AdminPro pro) {
    // State Dropdown
    Widget _stateDropdown(AdminPro pro) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("State"),
          DropdownButtonFormField<DropdownItem>(
            value: _findById(pro.stateDropdown, pro.selectedStateId),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
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
            hint: const TextWidget(
              text: 'Select State',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
            items: pro.stateDropdown
                .map(
                  (item) => DropdownMenuItem<DropdownItem>(
                    value: item,
                    child: TextWidget(
                      text: item.name,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                )
                .toList(),
            onChanged: (item) {
              if (item != null) {
                pro.setSelectedState(item.id);
              }
            },
            validator: (val) => val == null ? "Required" : null,
          ),
        ],
      );
    }

    // City Dropdown
    Widget _cityDropdown(AdminPro pro) {
      final isStateSelected = pro.selectedStateId != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("City"),
          DropdownButtonFormField<DropdownItem>(
            value: _findById(pro.citiesForSelectedState, pro.selectedCityId),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
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
              text: isStateSelected ? 'Select City' : 'Select state first',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
            items: pro.citiesForSelectedState
                .map(
                  (item) => DropdownMenuItem<DropdownItem>(
                    value: item,
                    child: TextWidget(
                      text: item.name,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                )
                .toList(),
            onChanged: isStateSelected
                ? (item) {
                    if (item != null) {
                      pro.setSelectedCity(item.id);
                    }
                  }
                : null,
            validator: (val) => val == null ? "Required" : null,
          ),
        ],
      );
    }

    // Static Country Field
    Widget _staticCountryField() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Country"),
          TextFormField(
            initialValue: "United States",
            enabled: false,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
          ),
        ],
      );
    }

    Widget _zipCodeField() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label("Zipcode"),
          TextFormField(
            controller: _zipCodeCtrl,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("ROLE & ASSIGNMENT"),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Account Type"), _accountTypeField(pro)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Level"), _levelDropdown()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Payment Method"),
                    _input(_paymentMethodCtrl),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Payment Account"),
                    _input(_paymentAccountCtrl),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Address"), _input(_addressCtrl)],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Address 2"), _input(_address2Ctrl)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _stateDropdown(pro)),
              const SizedBox(width: 16),
              Expanded(child: _cityDropdown(pro)),
              const SizedBox(width: 16),
              Expanded(child: _zipCodeField()),
              const SizedBox(width: 16),
              Expanded(child: _staticCountryField()),
            ],
          ),
          if (pro.currentAccountDetail?.twilio.printHelpersLines.isNotEmpty ==
              true) ...[
            const SizedBox(height: 16),
            _label("Print Helpers Line"),
            const SizedBox(height: 6),
            ...pro.currentAccountDetail!.twilio.printHelpersLines.map(
              (line) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.headset_mic,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextWidget(
                        text:
                            "${line.label.replaceAll(' Line', '')} • ${line.number}",
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (pro
                  .currentAccountDetail
                  ?.twilio
                  .assignedClientCompanies
                  .isNotEmpty ==
              true) ...[
            const SizedBox(height: 16),
            _label("Assigned Client's Companies"),
            const SizedBox(height: 6),
            ...pro.currentAccountDetail!.twilio.assignedClientCompanies.map(
              (cmp) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: cmp.image.isNotEmpty
                            ? Image.network(
                                cmp.image,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.business, size: 20),
                              )
                            : const Icon(Icons.business, size: 20),
                      ),
                      const SizedBox(width: 10),
                      TextWidget(
                        text: "${cmp.name} • ${cmp.number}",
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionHeader("PERSONAL INFORMATION"),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("First Name *"),
                    _input(_firstNameCtrl, validator: _required),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Last Name *"),
                    _input(_lastNameCtrl, validator: _required),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Username *"),
                    _input(_usernameCtrl, validator: _required),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Language"), _languageField(pro)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Phone(s)"), ..._phoneRows()],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label("Email(s)"), ..._emailRows()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("New Password"),
                    _input(
                      _newPasswordCtrl,
                      hint: "Leave blank to keep current",
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label("Confirm Password"),
                    _input(
                      _confirmPasswordCtrl,
                      hint: "Leave blank to keep current",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────
  Widget _sectionHeader(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      letterSpacing: 2.5,
      color: Color(0xFF374151),
    ),
  );

  Widget _chip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextWidget(
        text: label,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: TextWidget(
      text: text,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF9CA3AF),
    ),
  );

  DropdownItem? _findById(List<DropdownItem> list, int? id) {
    if (id == null) return null;
    for (final item in list) {
      if (item.id == id) return item;
    }
    return null;
  }

  Widget _accountTypeField(AdminPro pro) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedTypeId,
      items: pro.accountTypes
          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
          .toList(),
      onChanged: (v) => setState(() => _selectedTypeId = v),
      decoration: _inputDecoration(),
      validator: (v) => v == null ? "Required" : null,
    );
  }

  Widget _levelDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLevel,
      items: _levels
          .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() {
            _selectedLevel = v;
            _roleCtrl.text = v;
          });
        }
      },
      decoration: _inputDecoration(),
    );
  }

  Widget _languageField(AdminPro pro) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedLanguageId,
      items: pro.languages
          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
          .toList(),
      onChanged: (v) => setState(() => _selectedLanguageId = v),
      decoration: _inputDecoration(hint: "Select"),
    );
  }

  Widget _input(
    TextEditingController controller, {
    String? hint,
    Widget? suffix,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      validator: validator,
      decoration: _inputDecoration(hint: hint, suffix: suffix),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  List<Widget> _phoneRows() {
    return _phoneEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final field = entry.value;
      final isLast = index == _phoneEntries.length - 1;
      return Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _openPhoneDropdownIndex = _openPhoneDropdownIndex == index
                        ? null
                        : index;
                  });
                },
                child: Container(
                  height: 45,
                  width: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade400, width: 1.3),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      ImageWidget(image: field.type.image, width: 20),
                      const Spacer(),
                      Icon(
                        _openPhoneDropdownIndex == index
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      _phoneEntries.add(
                        PhoneField(
                          type: _phoneTypes[1],
                          controller: TextEditingController(),
                        ),
                      );
                    });
                  } else {
                    setState(() => _phoneEntries.removeAt(index));
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
                          child: const Icon(
                            Icons.add,
                            size: 23,
                            color: Colors.white,
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(7),
                          width: 40,
                          height: 40,
                          child: ImageWidget(image: Paths.delete),
                        ),
                ),
              ),
            ],
          ),
          if (index != _phoneEntries.length - 1) Spacers.sb10(),
          if (_openPhoneDropdownIndex == index)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6, bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade400, width: 1.3),
              ),
              child: Column(
                children: _phoneTypes.map((type) {
                  bool selected = field.type.label == type.label;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        field.type = type;
                        _openPhoneDropdownIndex = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      margin: const EdgeInsets.only(bottom: 3, top: 5),
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
                            const Icon(
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
    }).toList();
  }

  List<Widget> _emailRows() {
    return _emailCtrls.asMap().entries.map((entry) {
      final index = entry.key;
      final ctrl = entry.value;
      final isLast = index == _emailCtrls.length - 1;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: _input(ctrl)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isLast) {
                    _emailCtrls.add(TextEditingController());
                  } else {
                    ctrl.dispose();
                    _emailCtrls.removeAt(index);
                  }
                });
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLast ? AppColors.primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: isLast
                    ? const Icon(Icons.add, color: Colors.white, size: 18)
                    : Center(
                        child: ImageWidget(
                          image: Paths.delete,
                          width: 16,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    return null;
  }
}
