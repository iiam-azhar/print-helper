import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:print_helper/models/account_contract_rules_model.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/services/helpers.dart';
import 'package:print_helper/utils/formatter.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/spacers.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_helper/services/download_service.dart';
import 'dart:io';

import '../../constants/colors.dart';
import '../../constants/paths.dart';
import '../../widgets/text_widget.dart';

class AccountInfoScreen extends StatefulWidget {
  final AccountModel account;
  final bool isFromAdmin;
  const AccountInfoScreen({super.key, required this.account, this.isFromAdmin = true});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();

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
  bool _obscureNew = true;
  bool _obscureConfirm = true;
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
          pro.getAccountInfo(widget.account.id),
        ]);
      } else {
        await Future.wait([
          pro.fetchAllDropdownData(context),
          pro.getAccountInfo(widget.account.id),
          pro.getOnboardingTraining(widget.account.id),
          pro.getAccountContractRules(widget.account.id),
        ]);
      }
      _loadInitialData();
      if (mounted) {
        setState(() {});
      }
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
    for (final c in _emailCtrls) {
      c.dispose();
    }
    for (final p in _phoneEntries) {
      p.controller.dispose();
    }
    super.dispose();
  }

  void _loadInitialData() {
    final pro = getAdminPro(context);
    final detail = pro.currentAccountDetail;

    // Use detailed info if available, otherwise fallback to widget.account
    if (detail != null) {
      final p = detail.personal;
      final r = detail.roleAssignment;

      _firstNameCtrl.text = p.name;
      _lastNameCtrl.text = p.lastName;
      _usernameCtrl.text = p.username;

      final rName = r.roleName.isNotEmpty ? r.roleName : "Silver";
      if (_levels.any((e) => e.toLowerCase() == rName.toLowerCase())) {
        _selectedLevel = _levels.firstWhere((e) => e.toLowerCase() == rName.toLowerCase());
      } else {
        _selectedLevel = 'Silver';
      }
      _roleCtrl.text = _selectedLevel;

      _startDateCtrl.text = detail.header.startedAt;

      _selectedTypeId = r.accountTypeId;
      _selectedLanguageId = p.languageIds.isNotEmpty
          ? p.languageIds.first
          : null;
      _selectedSkillIds = List<int>.from(p.skillIds);

      _phoneEntries.clear();
      if (p.phones.isNotEmpty) {
        _phoneEntries.addAll(
          p.phones.map((ph) {
            final phoneType = _phoneTypes.firstWhere(
              (t) => t.apiValue == ph.type,
              orElse: () => _phoneTypes[1],
            );
            return PhoneField(
              type: phoneType,
              controller: TextEditingController(text: ph.number),
            );
          }),
        );
      } else {
        _phoneEntries.add(
          PhoneField(type: _phoneTypes[1], controller: TextEditingController()),
        );
      }

      _emailCtrls.clear();
      if (p.emails.isNotEmpty) {
        _emailCtrls.addAll(p.emails.map((e) => TextEditingController(text: e)));
      } else {
        _emailCtrls.add(TextEditingController());
      }

      _timeDoctorCtrl.text = r.timeDoctorId ?? "";
      _paymentMethodCtrl.text = r.paymentMethod ?? "";
      _paymentAccountCtrl.text = r.paymentAccount ?? "";
      _addressCtrl.text = r.address ?? "";
      _address2Ctrl.text = r.address2 ?? "";
    } else {
      // Fallback logic
      final acc = widget.account;
      _firstNameCtrl.text = acc.name;
      _lastNameCtrl.text = acc.lastName;
      _usernameCtrl.text = acc.username;

      final rName = acc.roleName.isNotEmpty ? acc.roleName : "Silver";
      if (_levels.any((e) => e.toLowerCase() == rName.toLowerCase())) {
        _selectedLevel = _levels.firstWhere((e) => e.toLowerCase() == rName.toLowerCase());
      } else {
        _selectedLevel = 'Silver';
      }
      _roleCtrl.text = _selectedLevel;

      _startDateCtrl.text = _safeDate(acc.createdAt);

      // Validate accountType exists in dropdown before setting
      final parsedTypeId = int.tryParse(acc.accountType ?? "");
      if (parsedTypeId != null &&
          pro.accountTypes.any((e) => e.id == parsedTypeId)) {
        _selectedTypeId = parsedTypeId;
      } else {
        _selectedTypeId = pro.accountTypes.isNotEmpty
            ? pro.accountTypes.first.id
            : null;
      }

      _phoneEntries.clear();
      _phoneEntries.addAll(
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

      _emailCtrls.clear();
      _emailCtrls.addAll(acc.emails.map((e) => TextEditingController(text: e)));
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

      if (languageIds.isNotEmpty) {
        _selectedLanguageId = languageIds.first;
      }

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

    final success = await pro.updateAccount(
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
    if (success) {
      showToast(message: "Account Updated Successfully");
      Navigator.pop(context);
      pro.getAccounts(ctx: context);
    } else {
      showToast(message: "Update Failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = getAdminPro(context);
    final initials =
        "${widget.account.name.isNotEmpty ? widget.account.name[0] : ""}${widget.account.lastName.isNotEmpty ? widget.account.lastName[0] : ""}"
            .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ImageWidget(image: Paths.accounts, width: 20),
            SizedBox(width: 8.w),
            const TextWidget(
              text: "Account Info",
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ],
        ),
        actions: const [],
      ),
      bottomNavigationBar: _activeTab != 0
          ? null
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: const BoxDecoration(color: Colors.transparent),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: FilledButton(
                    onPressed: _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const TextWidget(
                      text: "Save Changes",
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 22.h),
            child: Column(
              children: [
                _profileEarningsCombinedCard(initials: initials),
                SizedBox(height: 12.h),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 52.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 8.h,
                          ),
                          itemCount: _getAvailableTabs().length,
                          itemBuilder: (context, index) {
                            final active = _activeTab == index;
                            return GestureDetector(
                              onTap: () => setState(() => _activeTab = index),
                              child: Container(
                                margin: EdgeInsets.only(right: 8.w),
                                padding: EdgeInsets.symmetric(horizontal: 14.w),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFF4F4F5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.center,
                                child: TextWidget(
                                  text: _getAvailableTabs()[index],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF374151),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Divider(height: 1.h, color: const Color(0xFFE5E7EB)),
                      Padding(
                        padding: EdgeInsets.all(12.w),
                        child: _buildActiveTab(pro),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab(AdminPro pro) {
    final isAdmin = widget.account.roleName.toLowerCase() == 'admin';

    if (isAdmin) {
      return _infoTab(pro);
    }

    switch (_activeTab) {
      case 0:
        return _infoTab(pro);
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
            onToggle: () => setState(() => _isOnboardingExpanded = !_isOnboardingExpanded),
            children: data.onboarding.map((c) => _buildChecklistCard(pro, c)).toList(),
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
            onToggle: () => setState(() => _isTrainingExpanded = !_isTrainingExpanded),
            children: data.training.map((c) => _buildChecklistCard(pro, c)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildViewOnlyBanner() {
    if (_isCurrentUserAdmin) return const SizedBox();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock,
              color: Color(0xFFB45309),
              size: 16,
            ),
          ),
          SizedBox(width: 12.w),
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
                SizedBox(height: 2.h),
                const TextWidget(
                  text: "Only administrators can update onboarding and training checklist items.",
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
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isExpanded ? 0 : 16.r),
              bottomRight: Radius.circular(isExpanded ? 0 : 16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
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
                        SizedBox(height: 2.h),
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
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
                  SizedBox(width: 10.w),
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
            Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
            Padding(
              padding: EdgeInsets.all(14.w),
              child: Column(
                children: children,
              ),
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
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
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
              topLeft: Radius.circular(14.r),
              topRight: Radius.circular(14.r),
              bottomLeft: Radius.circular(isExpanded ? 0 : 14.r),
              bottomRight: Radius.circular(isExpanded ? 0 : 14.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
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
                  SizedBox(width: 10.w),
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
                        SizedBox(height: 2.h),
                        TextWidget(
                          text: "$completed of $total completed",
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6.h,
                          value: progress,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.all(2.w),
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
            Divider(height: 1.h, color: const Color(0xFFE2E8F0)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
      padding: EdgeInsets.symmetric(vertical: 6.h),
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
            borderRadius: BorderRadius.circular(5.r),
            child: Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                border: Border.all(
                  color: item.isCompleted
                      ? const Color(0xFF10B981)
                      : canToggle
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(5.r),
                color: item.isCompleted
                    ? const Color(0xFF10B981)
                    : !canToggle
                    ? const Color(0xFFF8FAFC)
                    : Colors.white,
              ),
              child: isToggling
                  ? Padding(
                      padding: EdgeInsets.all(3.w),
                      child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                    )
                  : item.isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          SizedBox(width: 10.w),
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
          SizedBox(width: 8.w),
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
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.rocket_launch_rounded,
            size: 18.sp,
            color: const Color(0xFF3B82F6),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextWidget(
              text: "No onboarding checklists found for this account type.",
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTab(AdminPro pro) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextWidget(
            text: "ROLE & ASSIGNMENT",
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 3,
          ),
          SizedBox(height: 12.h),
          _label("Account Type"),
          _accountTypeField(pro),
          SizedBox(height: 10.h),
          _label("Level"),
          _levelDropdown(),
          SizedBox(height: 10.h),
          _label("Payment Method"),
          _input(_paymentMethodCtrl),
          SizedBox(height: 10.h),
          _label("Payment Account"),
          _input(_paymentAccountCtrl),
          SizedBox(height: 10.h),
          _label("Address"),
          _input(_addressCtrl),
          SizedBox(height: 10.h),
          _label("Address 2"),
          _input(_address2Ctrl),
          if (pro.currentAccountDetail?.twilio.printHelpersLines.isNotEmpty == true) ...[
            SizedBox(height: 16.h),
            _label("Print Helpers Line"),
            SizedBox(height: 6.h),
            ...pro.currentAccountDetail!.twilio.printHelpersLines.map((line) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.headset_mic, color: Colors.amber, size: 16.sp),
                    ),
                    SizedBox(width: 10.w),
                    TextWidget(
                      text: "${line.label.replaceAll(' Line', '')} • ${line.number}",
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ],
                ),
              ),
            )),
          ],
          if (pro.currentAccountDetail?.twilio.assignedClientCompanies.isNotEmpty == true) ...[
            SizedBox(height: 16.h),
            _label("Assigned Client's Companies"),
            SizedBox(height: 6.h),
            ...pro.currentAccountDetail!.twilio.assignedClientCompanies.map((cmp) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: cmp.image.isNotEmpty
                          ? Image.network(cmp.image, width: 24.w, height: 24.w, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.business, size: 20.sp))
                          : Icon(Icons.business, size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    TextWidget(
                      text: "${cmp.name} • ${cmp.number}",
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ],
                ),
              ),
            )),
          ],
          SizedBox(height: 14.h),
          const TextWidget(
            text: "PERSONAL INFORMATION",
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 3,
          ),
          SizedBox(height: 12.h),
          _label("First Name *"),
          _input(_firstNameCtrl, validator: _required),
          SizedBox(height: 10.h),
          _label("Last Name *"),
          _input(_lastNameCtrl, validator: _required),
          SizedBox(height: 10.h),
          _label("Username *"),
          _input(_usernameCtrl, validator: _required),
          SizedBox(height: 10.h),
          _label("Language"),
          _languageField(pro),
          SizedBox(height: 10.h),
          _label("Phone(s)"),
          ..._phoneRows(),
          SizedBox(height: 10.h),
          _label("Email(s)"),
          ..._emailRows(),
          SizedBox(height: 10.h),
          _label("New Password"),
          _input(
            _newPasswordCtrl,
            hint: "Leave blank to keep current",
            obscureText: _obscureNew,
            validator: _passwordValidator,
            suffix: IconButton(
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          SizedBox(height: 10.h),
          _label("Confirm Password"),
          _input(
            _confirmPasswordCtrl,
            hint: "Leave blank to keep current",
            obscureText: _obscureConfirm,
            validator: (v) {
              if (_newPasswordCtrl.text.isNotEmpty &&
                  v != _newPasswordCtrl.text) {
                return "Passwords do not match";
              }
              return null;
            },
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _careerPathTab() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.map_rounded,
                size: 32.sp,
                color: const Color(0xFF2563EB),
              ),
            ),
            SizedBox(height: 18.h),
            TextWidget(
              text: "Career Path Coming Soon",
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
            SizedBox(height: 10.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 280.w),
              child: TextWidget(
                text: "This section is reserved for the upcoming career growth experience. Milestones, progression, and development goals will be available in a future release.",
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF4B5563),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: TextWidget(
                text: "UNDER DEVELOPMENT",
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            SizedBox(height: 10.h),
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
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: signed ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
              width: signed ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
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
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TextWidget(
                            text: "Contractor Agreement",
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          SizedBox(height: 3.h),
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
                          SizedBox(height: 6.h),
                          TextWidget(
                            text: signed
                                ? "Agreement is signed and available for viewing."
                                : "Please review and sign the contractor agreement to activate your account and begin receiving compensation.",
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF374151),
                          ),
                          SizedBox(height: 12.h),
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 8.h,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 8.h,
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
                                  _showAgreementDialog(context, pro: pro);
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 8.h,
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
                                      SizedBox(width: 6),
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
                              if (widget.isFromAdmin && !signed)
                                GestureDetector(
                                  onTap: () {
                                    showToast(
                                      message:
                                          "Reminder can be sent from Contracts settings.",
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 8.h,
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
                                          fontWeight: FontWeight.w700,
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
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F9EE),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(14.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextWidget(
                          text: "Agreement signed by $signer on ${agreement.signedAtLabel.isNotEmpty ? agreement.signedAtLabel : 'N/A'}.",
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(14.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFA16207), size: 16),
                      SizedBox(width: 8.w),
                      const Expanded(
                        child: TextWidget(
                          text: "View only: only this account holder can sign the agreement.",
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A5800),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
                child: const TextWidget(
                  text: "These are the core standards agreed for this account.",
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              if (data.rules.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 14.h),
                  child: const TextWidget(
                    text: "No rules available",
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                )
              else
                ...data.rules.map((category) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
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
                        SizedBox(height: 8.h),
                        ...category.items.map((item) {
                          final iconColor = _colorFromHex(
                            item.colorHex,
                            fallback: const Color(0xFF6B7280),
                          );
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _iconFromRuleName(item.iconName),
                                  color: iconColor,
                                  size: 20,
                                ),
                                SizedBox(width: 8.w),
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
                                      SizedBox(height: 3.h),
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
    final displayRole = (role.isEmpty || role.toLowerCase() == 'null') ? "" : role;
    final displayEmail = (email.isEmpty || email.toLowerCase() == 'null') ? "" : email;

    final detail = pro.currentAccountDetail;
    final fallbackAddr = detail?.roleAssignment.address ?? "";
    final fallbackAddr2 = detail?.roleAssignment.address2 ?? "";
    final contractorAddress = (account?.address.isNotEmpty == true && account?.address.toLowerCase() != 'null')
        ? account!.address
        : (fallbackAddr.isNotEmpty && fallbackAddr.toLowerCase() != 'null' ? fallbackAddr : "");
    final contractorAddress2 = (account?.address2.isNotEmpty == true && account?.address2.toLowerCase() != 'null')
        ? account!.address2
        : (fallbackAddr2.isNotEmpty && fallbackAddr2.toLowerCase() != 'null' ? fallbackAddr2 : "");

    // Signing form state
    final hasSigned = agreement?.isSigned == true;
    final signerNameCtrl = TextEditingController(
      text: hasSigned ? agreement!.signerName : name,
    );
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final formattedToday = "${months[now.month - 1]} ${now.day}, ${now.year}";
    final signedDateCtrl = TextEditingController(
      text: hasSigned ? agreement!.signedAtLabel : formattedToday,
    );
    bool isSigning = false;
    bool isConfirmed = hasSigned;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSigningState) {
            final isNameValid = signerNameCtrl.text.trim().toLowerCase() == name.trim().toLowerCase();
            final canSign = isConfirmed && isNameValid && !isSigning;

            return ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                color: Colors.white,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    // ── Header
                    Container(
                      color: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 14.h,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TextWidget(
                                  text: "Independent Contractor Agreement",
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 3.h),
                                const TextWidget(
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
                    // ── Body (Scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(18.w),
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
                                  SizedBox(height: 4.h),
                                  const TextWidget(
                                    text: "Independent Contractor Agreement",
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8.h),
                                  RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF374151),
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
                                        const TextSpan(text: " (Company) and "),
                                        TextSpan(
                                          text: name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(text: " (Contractor)."),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Divider(color: const Color(0xFFE5E7EB)),
                            SizedBox(height: 12.h),
                            // ── Company / Contractor cards
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const TextWidget(
                                            text: "COMPANY",
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF9CA3AF),
                                            letterSpacing: 1.5,
                                          ),
                                          SizedBox(height: 6.h),
                                          const TextWidget(
                                            text: "Print Helpers LLC",
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          const TextWidget(
                                            text: "printhelpers.com",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                          const TextWidget(
                                            text: "2080 Empire Ave. #1032, Burbank, CA 91504",
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
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
                                          SizedBox(height: 6.h),
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
                            SizedBox(height: 14.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                  style: BorderStyle.solid,
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
                            SizedBox(height: 16.h),
                            if (agreement != null && agreement.isSigned)
                              Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
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
                                      padding: EdgeInsets.only(bottom: 10.h),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            _iconFromRuleName(item.iconName),
                                            color: iconColor,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8.w),
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
                                                SizedBox(height: 3.h),
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
                            if (agreement != null && (agreement.isSigned || agreement.canSign)) ...[
                              SizedBox(height: 16.h),
                              const TextWidget(
                                text: "Electronic Signature",
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                              SizedBox(height: 10.h),
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: const Color(0xFFFEF3C7)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const TextWidget(
                                      text: "By typing your full name and clicking \"I Agree & Sign\" below, you acknowledge that:",
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF92400E),
                                    ),
                                    SizedBox(height: 10.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(text: "• ", fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF92400E)),
                                        Expanded(child: TextWidget(text: "You have read and understand this Agreement and all linked policies;", fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF92400E))),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(text: "• ", fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF92400E)),
                                        Expanded(child: TextWidget(text: "You have authority to enter into this Agreement;", fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF92400E))),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(text: "• ", fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF92400E)),
                                        Expanded(child: TextWidget(text: "You agree to be legally bound by all terms herein;", fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF92400E))),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(text: "• ", fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF92400E)),
                                        Expanded(child: TextWidget(text: "Your electronic signature is binding under the Uniform Electronic Transactions Act (UETA) and has the same legal effect as a handwritten signature;", fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF92400E))),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(text: "• ", fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF92400E)),
                                        Expanded(child: TextWidget(text: "You consent to Service Provider collecting your IP address for security and record-keeping purposes.", fontSize: 12, fontWeight: FontWeight.w400, color: const Color(0xFF92400E))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (agreement.isSigned) ...[
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
                                        text: "Record of electronic signature",
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15803D),
                                      ),
                                      SizedBox(height: 8.h),
                                      const TextWidget(
                                        text: "The name, date, and confirmation below reflect what was submitted when this agreement was signed.",
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
                                              text: ' and specialist standards shown above are part of this agreement and are included in your PDF download.',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(height: 14.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(
                                          text: "Full Legal Name *",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151),
                                        ),
                                        SizedBox(height: 6.h),
                                        TextFormField(
                                          controller: signerNameCtrl,
                                          enabled: !isSigning && !agreement.isSigned,
                                          onChanged: (val) {
                                            setSigningState(() {});
                                          },
                                          decoration: InputDecoration(
                                            hintText: "Enter your full legal name",
                                            hintStyle: const TextStyle(
                                              color: Color(0xFFD1D5DB),
                                              fontSize: 13,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 10.h,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        if (!agreement.isSigned) ...[
                                          SizedBox(height: 4.h),
                                          const TextWidget(
                                            text: "Must exactly match the account name to be valid.",
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const TextWidget(
                                          text: "Date",
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151),
                                        ),
                                        SizedBox(height: 6.h),
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
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8.r),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFD1D5DB),
                                              ),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 10.h,
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
                              if (agreement.isSigned && agreement.ipAddress.isNotEmpty && agreement.ipAddress.toLowerCase() != 'null') ...[
                                SizedBox(height: 12.h),
                                TextWidget(
                                  text: "IP address (recorded): ${agreement.ipAddress}",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4B5563),
                                ),
                              ],
                              SizedBox(height: 12.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Checkbox(
                                      value: isConfirmed,
                                      onChanged: (isSigning || agreement.isSigned)
                                          ? null
                                          : (val) {
                                              setSigningState(() {
                                                isConfirmed = val ?? false;
                                              });
                                            },
                                      activeColor: const Color(0xFFD58F16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
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
                            ] else if (agreement != null &&
                                !agreement.isSigned &&
                                !agreement.canSign) ...[
                              SizedBox(height: 16.h),
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12.r),
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
                                            "View only: only this account holder can sign this agreement.",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // ── Footer with conditional buttons
                    Container(
                      padding: EdgeInsets.all(18.w),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (agreement != null &&
                              !agreement.isSigned &&
                              agreement.canSign)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: canSign
                                        ? () async {
                                            final signerName = signerNameCtrl
                                                .text
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
                                                  signedDate: DateTime.now().toIso8601String(),
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
                                      disabledBackgroundColor: const Color(0xFFF5E8C4),
                                      foregroundColor: const Color(0xFF475569),
                                      disabledForegroundColor: const Color(0xFF94A3B8),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                        vertical: 12.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: isSigning
                                        ? SizedBox(
                                            height: 18.sp,
                                            width: 18.sp,
                                            child:
                                                const CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
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
                                              SizedBox(width: 8.w),
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
                                SizedBox(width: 10.w),
                                OutlinedButton(
                                  onPressed: isSigning
                                      ? null
                                      : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  child: const TextWidget(
                                    text: "Cancel",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else if (agreement != null &&
                              !agreement.isSigned &&
                              !agreement.canSign)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: null,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFD1D5DB),
                                      ),
                                      backgroundColor: const Color(0xFFF3F4F6),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                        vertical: 12.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
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
                                SizedBox(width: 10.w),
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  child: const TextWidget(
                                    text: "Cancel",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else if (agreement != null && agreement.isSigned)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final link = agreement.pdfUrl.isNotEmpty
                                          ? agreement.pdfUrl
                                          : agreement.pdfWebUrl;
                                      if (link.isNotEmpty) {
                                        _downloadAgreementPdf(
                                          link,
                                          template?.name ?? "Specialist Contractor Agreement",
                                        );
                                      } else {
                                        showToast(message: "PDF link not available");
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF2563EB),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20.w,
                                        vertical: 12.h,
                                      ),
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
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  child: const TextWidget(
                                    text: "Cancel",
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          else
                            // Show cancel button for view-only
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20.w,
                                  vertical: 12.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
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
            );
          },
        );
      },
    );
  }

  Widget _profileEarningsCombinedCard({required String initials}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet =
            constraints.maxWidth >= 500; // Unified threshold for this card
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isTablet
              ? IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _profileSection(initials)),
                      Container(
                        width: 1,
                        margin: EdgeInsets.symmetric(vertical: 16.h),
                        color: const Color(0xFFE5E7EB),
                      ),
                      Expanded(
                        flex: 2,
                        child: _earningsSection(isTablet: true),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _profileSection(initials),
                    _earningsSection(isTablet: false),
                  ],
                ),
        );
      },
    );
  }

  Widget _profileSection(String initials) {
    final detail = getAdminPro(context).currentAccountDetail?.header;
    final displayInitials = detail?.initials ?? initials;
    final displayFullName =
        detail?.fullName ?? "${widget.account.name} ${widget.account.lastName}";
    final displayStatus =
        detail?.statusLabel ?? (widget.account.status ? "Active" : "Inactive");
    final displayRole = detail?.roleName ?? _prettyRoleLabel();
    final displayStarted =
        detail?.startedAt ?? _safeDate(widget.account.createdAt);

    return Padding(
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          Container(
            width: 54.w,
            height: 54.w,
            decoration: BoxDecoration(
              color: const Color(0xFFDDF5D9),
              borderRadius: BorderRadius.circular(14.r),
              image: (detail?.imageUrl != null && detail!.imageUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(detail.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: (detail?.imageUrl == null || detail!.imageUrl!.isEmpty)
                ? TextWidget(
                    text: displayInitials,
                    color: const Color(0xFF0A8C42),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextWidget(
                  text: displayFullName,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF111827),
                ),
                SizedBox(height: 5.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 5.h,
                  children: [
                    _chip(
                      label: displayStatus,
                      bg:
                          (detail?.status == 1 ||
                              (detail == null && widget.account.status))
                          ? const Color(0xFFD8F4DF)
                          : const Color(0xFFFEE2E2),
                      fg:
                          (detail?.status == 1 ||
                              (detail == null && widget.account.status))
                          ? const Color(0xFF0A8C42)
                          : const Color(0xFFB91C1C),
                    ),
                    _chip(
                      label: displayRole,
                      bg: const Color(0xFFE5EEFF),
                      fg: const Color(0xFF2454C4),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                TextWidget(
                  text: "Started $displayStarted",
                  fontSize: 12,
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

  Widget _earningsSection({required bool isTablet}) {
    final earnings = getAdminPro(context).currentAccountDetail?.earnings;
    final displayAmount = earnings?.thisWeekLabel ?? "\$0.00";

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: isTablet ? 16.h : 12.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Very light green
        borderRadius: isTablet
            ? BorderRadius.horizontal(right: Radius.circular(20.r))
            : BorderRadius.vertical(bottom: Radius.circular(20.r)),
      ),
      child: Column(
        crossAxisAlignment: isTablet
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: isTablet
                ? MainAxisAlignment.end
                : MainAxisAlignment.spaceBetween,
            children: [
              if (!isTablet)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: "WEEKLY EARNINGS",
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                      letterSpacing: 1.0,
                    ),
                    const SizedBox(height: 1),
                    const TextWidget(
                      text: "Total for this week",
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              if (isTablet) const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextWidget(
                    text: displayAmount,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 18 : 15,
                    color: const Color(0xFF059669),
                  ),
                  if (isTablet) ...[
                    SizedBox(height: 3.h),
                    TextWidget(
                      text: "THIS WEEK'S EARNINGS",
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669).withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
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

  Widget _label(String text) => Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: TextWidget(
      text: text,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF9CA3AF),
    ),
  );

  Widget _accountTypeField(AdminPro pro) {
    final uniqueTypes = <int, DropdownItem>{};
    for (final type in pro.accountTypes) {
      uniqueTypes.putIfAbsent(type.id, () => type);
    }

    final hasValidSelection =
        _selectedTypeId != null && uniqueTypes.containsKey(_selectedTypeId);

    return DropdownButtonFormField<int>(
      initialValue: hasValidSelection ? _selectedTypeId : null,
      items: uniqueTypes.values
          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
          .toList(),
      onChanged: null,
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
    bool enabled = true,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
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
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  List<String> _getAvailableTabs() {
    final isAdmin = widget.account.roleName.toLowerCase() == 'admin';
    if (isAdmin) {
      return ["Info"];
    }
    return ["Info", "Career Path", "Onboarding & Training", "Contract & Rules"];
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
                  height: 45.h,
                  width: 70.w,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
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
          if (index != _phoneEntries.length - 1) Spacers.sb10(),
          if (_openPhoneDropdownIndex == index)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 6.h, bottom: 12.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
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
    }).toList();
  }

  List<Widget> _emailRows() {
    return _emailCtrls.asMap().entries.map((entry) {
      final index = entry.key;
      final ctrl = entry.value;
      final isLast = index == _emailCtrls.length - 1;
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          children: [
            Expanded(child: _input(ctrl, validator: _emailValidator)),
            SizedBox(width: 8.w),
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
                width: 32.w,
                height: 32.w,
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

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return "Enter a valid email";
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length < 6) return "Password must be at least 6 characters";
    return null;
  }
}

// 
