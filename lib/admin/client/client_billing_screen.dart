import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_helper/models/client_billing_tabs_model.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/client_models.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:print_helper/admin/client/discounts_credits_mobile.dart';
import 'package:print_helper/admin/client/referrals_mobile.dart';
import 'package:print_helper/admin/client/dialog_add_entry.dart';

class ClientBillingScreen extends StatefulWidget {
  final int clientId;

  const ClientBillingScreen({super.key, required this.clientId});

  @override
  State<ClientBillingScreen> createState() => _ClientBillingScreenState();
}

class _ClientBillingScreenState extends State<ClientBillingScreen> {
  int _activeTab = 0; // default is Services tab (index 0)
  bool _isSaving = false;
  bool _isSyncing = false;
  String _orderLogTypeFilter = 'All types';
  String _orderLogDayFilter = 'All days';
  final List<ExtraChargeItem> _extraCharges = [];
  bool _hasEditedExtraCharges = false;

  late String _selectedWeek;
  bool _isInitialLoading = true;
  bool _isWeekLoading = false;

  bool get _isWeekClosed {
    final clientPro = context.read<ClientPro>();
    return clientPro.currentClientBillingTabs?.week.isClosed ?? false;
  }

  @override
  void initState() {
    super.initState();
    _selectedWeek = _calculateCurrentWeekStart();
    _fetchBillingTabs();
  }

  @override
  void dispose() {
    for (var item in _extraCharges) {
      item.descController.dispose();
      item.amountController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchBillingTabs({bool isWeekChange = false}) async {
    final clientPro = context.read<ClientPro>();
    if (isWeekChange) {
      setState(() => _isWeekLoading = true);
    }
    try {
      await clientPro.getClientBillingTabs(
        widget.clientId,
        _selectedWeek,
        showLoading: false,
      );
      _syncLocalStateFromBilling(clientPro);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isWeekLoading = false;
        });
      }
    }
  }

  void _goToPreviousWeek() {
    for (var item in _extraCharges) {
      item.descController.dispose();
      item.amountController.dispose();
    }
    _extraCharges.clear();
    _hasEditedExtraCharges = false;

    final week = context.read<ClientPro>().currentClientBillingTabs?.week;
    if (week != null && week.previous.isNotEmpty) {
      _selectedWeek = week.previous;
    } else {
      final current = DateTime.parse(_selectedWeek);
      final prev = current.subtract(const Duration(days: 7));
      _selectedWeek =
          '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';
    }
    _fetchBillingTabs(isWeekChange: true);
  }

  void _goToNextWeek() {
    for (var item in _extraCharges) {
      item.descController.dispose();
      item.amountController.dispose();
    }
    _extraCharges.clear();
    _hasEditedExtraCharges = false;

    final week = context.read<ClientPro>().currentClientBillingTabs?.week;
    if (week != null && week.next.isNotEmpty) {
      _selectedWeek = week.next;
    } else {
      final current = DateTime.parse(_selectedWeek);
      final next = current.add(const Duration(days: 7));
      _selectedWeek =
          '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
    }
    _fetchBillingTabs(isWeekChange: true);
  }

  ClientBillingUsageBreakdownModel? get _breakdown =>
      context.read<ClientPro>().currentClientBillingTabs?.usage.breakdown;

  double get _callsIn => _breakdown?.calls.incoming.used ?? 0.0;
  double get _callsOut => _breakdown?.calls.outgoing.used ?? 0.0;

  double get _smsIn => _breakdown?.sms.incoming.used ?? 0.0;
  double get _smsOut => _breakdown?.sms.outgoing.used ?? 0.0;

  double get _mmsIn => _breakdown?.mms.incoming.used ?? 0.0;
  double get _mmsOut => _breakdown?.mms.outgoing.used ?? 0.0;

  int get _callsInIncluded => _breakdown?.calls.incoming.included.toInt() ?? 5;
  double get _callsInRate => _breakdown?.calls.overage.inRate ?? 0.05;
  int get _callsOutIncluded => _breakdown?.calls.outgoing.included.toInt() ?? 5;
  double get _callsOutRate => _breakdown?.calls.overage.outRate ?? 0.07;

  int get _smsInIncluded => _breakdown?.sms.incoming.included.toInt() ?? 5;
  double get _smsInRate => _breakdown?.sms.overage.inRate ?? 0.01;
  int get _smsOutIncluded => _breakdown?.sms.outgoing.included.toInt() ?? 5;
  double get _smsOutRate => _breakdown?.sms.overage.outRate ?? 0.02;

  int get _mmsInIncluded => _breakdown?.mms.incoming.included.toInt() ?? 5;
  double get _mmsInRate => _breakdown?.mms.overage.inRate ?? 0.05;
  int get _mmsOutIncluded => _breakdown?.mms.outgoing.included.toInt() ?? 5;
  double get _mmsOutRate => _breakdown?.mms.overage.outRate ?? 0.10;

  double get _callsInOverage => _callsIn > _callsInIncluded
      ? ((_callsIn - _callsInIncluded) * _callsInRate)
      : 0.0;
  double get _callsOutOverage => _callsOut > _callsOutIncluded
      ? ((_callsOut - _callsOutIncluded) * _callsOutRate)
      : 0.0;
  double get _smsInOverage =>
      _smsIn > _smsInIncluded ? ((_smsIn - _smsInIncluded) * _smsInRate) : 0.0;
  double get _smsOutOverage => _smsOut > _smsOutIncluded
      ? ((_smsOut - _smsOutIncluded) * _smsOutRate)
      : 0.0;
  double get _mmsInOverage =>
      _mmsIn > _mmsInIncluded ? ((_mmsIn - _mmsInIncluded) * _mmsInRate) : 0.0;
  double get _mmsOutOverage => _mmsOut > _mmsOutIncluded
      ? ((_mmsOut - _mmsOutIncluded) * _mmsOutRate)
      : 0.0;

  double get _overageCost =>
      _callsInOverage +
      _callsOutOverage +
      _smsInOverage +
      _smsOutOverage +
      _mmsInOverage +
      _mmsOutOverage;

  String _formatDouble(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'\.0+$'), '')
        .replaceAll(RegExp(r'(\.\d*?[1-9])0+$'), r'\1');
  }

  // Specialist Access Toggles
  bool _staffAccess = false;
  bool _graphicDesignerAccess = true;

  // Add-ons states
  bool _supportLinesActive = true;
  int _supportLinesQty = 0;

  bool _fileStorageActive = true;
  int _fileStorageQty = 0;

  bool _emailConnectionsActive = true;
  int _emailConnectionsQty = 0;
  String _pricingMode = 'free';

  Future<void> _updatePricingMode(String mode) async {
    if (_pricingMode == mode) return;
    setState(() => _pricingMode = mode);
    final clientPro = context.read<ClientPro>();
    final success = await clientPro.updatePricingMode(
      clientId: widget.clientId,
      mode: mode,
    );
    // After a successful pricing mode change, reload billing tabs to get
    // updated prices, charges, and addon values that depend on the active mode.
    if (success && mounted) {
      final currentWeek =
          clientPro.currentClientBillingTabs?.week.start ??
          _calculateCurrentWeekStart();
      await clientPro.getClientBillingTabs(
        widget.clientId,
        currentWeek,
        showLoading: false,
      );
      // Re-sync local state from the fresh API data
      _syncLocalStateFromBilling(clientPro);
      if (mounted) setState(() {});
    }
  }

  /// Syncs local widget state (addon toggles/quantities, specialist access,
  /// pricing mode) from the current provider billing data.
  void _syncLocalStateFromBilling(ClientPro clientPro) {
    final billing = clientPro.currentClientBillingTabs?.billing;
    if (billing == null) return;
    _pricingMode = billing.pricingMode.toLowerCase();
    for (var row in billing.addons) {
      if (row.key == 'support_lines') {
        _supportLinesActive = row.isActive;
        _supportLinesQty = row.quantity;
      } else if (row.key == 'extra_storage') {
        _fileStorageActive = row.isActive;
        _fileStorageQty = row.quantity;
      } else if (row.key == 'extra_emails') {
        _emailConnectionsActive = row.isActive;
        _emailConnectionsQty = row.quantity;
      }
    }
    for (var row in billing.specialistRows) {
      if (row.accountTypeId == 2 || row.name.toLowerCase().contains('staff')) {
        _staffAccess = row.isEnabled;
      } else if (row.accountTypeId == 3 ||
          row.name.toLowerCase().contains('graphic')) {
        _graphicDesignerAccess = row.isEnabled;
      }
    }

    _extraCharges.clear();
    _hasEditedExtraCharges = false;
    final weekChargeBreakdown = clientPro.currentClientBillingTabs?.weeklyVolume.weekChargeBreakdown;
    if (weekChargeBreakdown != null) {
      for (var charge in weekChargeBreakdown.addedExtraCharges) {
        _extraCharges.add(
          ExtraChargeItem(
            description: charge.description,
            amount: charge.amount,
          ),
        );
      }
    }
  }

  String _calculateCurrentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  ClientBillingAddonModel? _getAddon(String slug, String namePattern) {
    final clientPro = context.read<ClientPro>();
    final addons = clientPro.currentClientBillingTabs?.billing.addons;
    if (addons == null) return null;
    try {
      return addons.firstWhere(
        (a) =>
            a.slug.toLowerCase() == slug.toLowerCase() ||
            a.name.toLowerCase().contains(namePattern.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  double get _phPortalWeekly =>
      Provider.of<ClientPro>(
        context,
        listen: false,
      ).currentClientBillingTabs?.billing.phPortalWeekly ??
      345.40;

  double get _supportLineWeeklyPrice =>
      _getAddon('support-lines', 'support line')?.weeklyPrice ?? 0.69;
  int get _supportLinesIncluded =>
      int.tryParse(
        _getAddon('support-lines', 'support line')?.included ?? '',
      ) ??
      1;

  double get _storageWeeklyPrice =>
      _getAddon('file-storage', 'storage')?.weeklyPrice ?? 0.69;

  double get _emailWeeklyPrice =>
      _getAddon('email-connections', 'email')?.weeklyPrice ?? 4.62;
  int get _emailIncluded =>
      int.tryParse(_getAddon('email-connections', 'email')?.included ?? '') ??
      0;

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFACC15)),
        ),
      );
    }

    final clientPro = Provider.of<ClientPro>(context, listen: true);
    ClientModel? client;
    try {
      client = clientPro.clients.firstWhere((c) => c.id == widget.clientId);
    } catch (_) {
      client = null;
    }

    final companyName = client?.companyName ?? "Tron";
    final isClientActive = client?.status ?? true;
    final clientLogo = client?.logo ?? "";
    final clientType = client?.companyType ?? "Client Ltd";
    final clientSince = client != null
        ? "Client since ${client.createdDate}"
        : "Client since May 20, 2026";

    final pricingMode =
        clientPro.currentClientBillingTabs?.billing.pricingMode.toLowerCase() ??
        _pricingMode;

    // Weekly charge calculations
    final double phPortalWeekly = _phPortalWeekly;
    final double supportLineWeeklyPrice = _supportLineWeeklyPrice;
    final double storageWeeklyPrice = _storageWeeklyPrice;
    final double emailWeeklyPrice = _emailWeeklyPrice;

    final double supportLineCost = _supportLinesActive
        ? (_supportLinesQty * supportLineWeeklyPrice)
        : 0.0;
    final double storageCost = _fileStorageActive
        ? (_fileStorageQty * storageWeeklyPrice)
        : 0.0;
    final double emailCost = _emailConnectionsActive
        ? (_emailConnectionsQty * emailWeeklyPrice)
        : 0.0;
    final double overageCost = _overageCost;
    final double totalWeeklyCharge =
        (pricingMode == 'free' ? 0.0 : phPortalWeekly) +
        supportLineCost +
        storageCost +
        emailCost +
        overageCost;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(context, companyName, isClientActive, clientPro),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client Profile Card
                    _buildClientProfileCard(
                      logo: clientLogo,
                      name: companyName,
                      isActive: isClientActive,
                      type: clientType,
                      since: clientSince,
                      weeklyCharge: totalWeeklyCharge,
                    ),

                    // Tab Bar selector
                    _buildTabBar(),

                    // Tab Body
                    if (_activeTab == 0) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 16.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // PH Portal Black Banner
                            _buildPHPortalBanner(
                              overageCost,
                              phPortalWeekly: phPortalWeekly,
                            ),
                            SizedBox(height: 20.h),

                            // Usage & Configuration Header
                            _buildSectionHeader(
                              title: "Usage & Configuration",
                              subtitle: "${clientPro.currentClientBillingTabs?.week.label ?? 'May 25-31, 2026'} - Admin only",
                            ),
                            SizedBox(height: 4.h),
                            _buildOverageInfoText(),
                            SizedBox(height: 16.h),

                            // Usage Cards (Stacked vertically on mobile)
                            _buildCallsCard(
                              included: _callsOutIncluded,
                              callsInRate: _callsInRate,
                              callsOutRate: _callsOutRate,
                            ),
                            SizedBox(height: 14.h),
                            _buildSMSCard(
                              included: _smsOutIncluded,
                              smsInRate: _smsInRate,
                              smsOutRate: _smsOutRate,
                            ),
                            SizedBox(height: 14.h),
                            _buildMMSCard(
                              included: _mmsOutIncluded,
                              mmsInRate: _mmsInRate,
                              mmsOutRate: _mmsOutRate,
                            ),
                            SizedBox(height: 14.h),
                            _buildStorageCard(),
                            SizedBox(height: 14.h),
                            _buildSupportLinesCard(
                              supportLineRate: supportLineWeeklyPrice,
                              supportLinesIncluded: _supportLinesIncluded,
                            ),
                            SizedBox(height: 14.h),
                            _buildEmailConnectionsCard(
                              emailRate: emailWeeklyPrice,
                              emailIncluded: _emailIncluded,
                            ),
                            SizedBox(height: 24.h),

                            // Specialist Services Access
                            TextWidget(
                              text: "Specialist Services Access",
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            SizedBox(height: 12.h),
                            _buildSpecialistAccessCard(
                              title: "staff",
                              icon: Icons.business_center,
                              iconColor: Colors.blueGrey,
                              value: _staffAccess,
                              onChanged: (val) {
                                setState(() => _staffAccess = val);
                              },
                            ),
                            SizedBox(height: 10.h),
                            _buildSpecialistAccessCard(
                              title: "Graphic Designer",
                              icon: Icons.palette,
                              iconColor: const Color(0xFF3B82F6),
                              value: _graphicDesignerAccess,
                              onChanged: (val) {
                                setState(() => _graphicDesignerAccess = val);
                              },
                            ),
                            SizedBox(height: 24.h),

                            // Add-ons Section
                            _buildAddonsSection(
                              supportLineCost,
                              storageCost,
                              emailCost,
                            ),
                            SizedBox(height: 20.h),

                            // Bottom Info Warning Banner
                            _buildInfoBanner(),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ] else if (_activeTab == 1) ...[
                      if (_isWeekLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        const DiscountsCreditsMobile(),
                    ] else if (_activeTab == 2) ...[
                      if (_isWeekLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        const ReferralsMobile(),
                    ] else if (_activeTab == 3) ...[
                      if (_isWeekLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          child: _buildWeeklyVolumeTab(),
                        ),
                    ] else if (_activeTab == 4) ...[
                      if (_isWeekLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 16.h,
                          ),
                          child: _buildBillingTab(totalWeeklyCharge, overageCost),
                        ),
                    ] else ...[
                      // Placeholder
                      _buildPlaceholderTab(),
                    ],
                  ],
                ),
              ),
            ),
            if (_activeTab == 0)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFE5E7EB),
                      width: 1.5.h,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: _buildSaveButton(),
              ),
          ],
        ),
      ),
    );
  }

  // Mobile Appbar
  AppBar _buildAppBar(
    BuildContext context,
    String clientName,
    bool isActive,
    ClientPro pro,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: TextWidget(
        text: "Clients / $clientName / Billing",
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.block_flipped,
            color: Color(0xFFEF4444),
            size: 20,
          ),
          onPressed: () =>
              _showToggleStatusDialog(context, clientName, isActive, pro),
        ),
      ],
    );
  }

  // Client Profile Info Card adapted for Mobile
  Widget _buildClientProfileCard({
    required String logo,
    required String name,
    required bool isActive,
    required String type,
    required String since,
    required double weeklyCharge,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23.r),
                  child: logo.isNotEmpty
                      ? ImageWidget(image: logo, fit: BoxFit.cover)
                      : ImageWidget(image: Paths.user, fit: BoxFit.cover),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: name,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    SizedBox(height: 4.h),
                    TextWidget(
                      text: since,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _chip(
                    isActive ? "Active" : "Inactive",
                    isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF3F4F6),
                    isActive ? const Color(0xFF15803D) : Colors.grey.shade700,
                  ),
                  SizedBox(width: 6.w),
                  _chip(type, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    TextWidget(
                      text: "\$${weeklyCharge.toStringAsFixed(2)}/wk",
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
                    ),
                    SizedBox(width: 4.w),
                    TextWidget(
                      text: "CHARGE",
                      fontSize: 8.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF16A34A),
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

  Widget _chip(String text, Color bg, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextWidget(
        text: text,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  // Scrollable Tab bar
  Widget _buildTabBar() {
    final tabs = [
      "Services",
      "Discounts & Credits",
      "My Referrals",
      "Weekly Volume",
      "Billing",
    ];
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final title = tabs[index];
            final isActive = _activeTab == index;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = index;
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: 18.w),
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 2.w),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? const Color(0xFFFACC15)
                          : Colors.transparent,
                      width: 2.h,
                    ),
                  ),
                ),
                child: TextWidget(
                  text: title,
                  fontSize: 13.sp,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Colors.black : Colors.grey.shade500,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // PH Portal Banner adapted for Mobile (stacked/compact layout)
  Widget _buildPHPortalBanner(
    double overages, {
    double phPortalWeekly = 345.40,
  }) {
    final clientPro = Provider.of<ClientPro>(context, listen: false);
    final pricingMode =
        clientPro.currentClientBillingTabs?.billing.pricingMode.toLowerCase() ??
        _pricingMode;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PH PORTAL",
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                padding: EdgeInsets.all(2.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _updatePricingMode("free"),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: pricingMode == "free"
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: pricingMode == "free"
                                  ? Colors.white
                                  : Colors.white70,
                              size: 11.sp,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              "Free w/ Pod",
                              style: GoogleFonts.poppins(
                                fontSize: 9.sp,
                                fontWeight: pricingMode == "free"
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: pricingMode == "free"
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _updatePricingMode("paid"),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: pricingMode != "free"
                              ? const Color(0xFFFEF08A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          "\$${phPortalWeekly.toStringAsFixed(2)}/wk",
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            fontWeight: pricingMode != "free"
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: pricingMode != "free"
                                ? Colors.black
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                () {
                  final syncedDisplay = context
                      .read<ClientPro>()
                      .currentClientBillingTabs
                      ?.billing
                      .twilioUsageSummary
                      .syncedDisplay;
                  if (syncedDisplay != null && syncedDisplay.isNotEmpty) {
                    return "Last synced $syncedDisplay";
                  }
                  return "Not synced yet";
                }(),
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: Colors.grey.shade400,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  setState(() => _isSyncing = true);
                  try {
                    final clientPro = context.read<ClientPro>();
                    final week = clientPro.currentClientBillingTabs?.week;
                    final String startStr =
                        week?.start ?? _calculateCurrentWeekStart();
                    final String endStr;
                    if (week != null && week.end.isNotEmpty) {
                      endStr = week.end;
                    } else {
                      final startDt = DateTime.parse(startStr);
                      final endDt = startDt.add(const Duration(days: 6));
                      endStr =
                          '${endDt.year}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}';
                    }
                    final success = await clientPro.syncUsage(
                      clientId: widget.clientId,
                      weekStart: startStr,
                      weekEnd: endStr,
                    );
                    if (success) {
                      await clientPro.getClientBillingTabs(
                        widget.clientId,
                        startStr,
                        showLoading: false,
                      );
                    }
                  } catch (_) {}
                  if (mounted) {
                    setState(() => _isSyncing = false);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      if (_isSyncing)
                        SizedBox(
                          width: 10.sp,
                          height: 10.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(Icons.sync, color: Colors.white, size: 10.sp),
                      SizedBox(width: 4.w),
                      Text(
                        "Sync Usage",
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(color: Colors.white24, height: 1),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SERVICES THIS WEEK",
                style: GoogleFonts.poppins(
                  fontSize: 9.sp,
                  color: Colors.grey.shade400,
                ),
              ),
              Row(
                children: [
                  Text(
                    "\$${overages.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFDE047),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    "add-ons + over",
                    style: GoogleFonts.poppins(
                      fontSize: 8.sp,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        TextWidget(text: title, fontSize: 16.sp, fontWeight: FontWeight.bold),
        SizedBox(width: 6.w),
        Expanded(
          child: TextWidget(
            text: subtitle,
            fontSize: 10.sp,
            fontWeight: FontWeight.normal,
            color: Colors.grey.shade500,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildOverageInfoText() {
    return Wrap(
      children: [
        TextWidget(
          text: "Defaults from the ",
          fontSize: 11.sp,
          fontWeight: FontWeight.normal,
          color: Colors.grey.shade600,
        ),
        GestureDetector(
          onTap: () => showToast(message: "Services"),
          child: TextWidget(
            text: "Services page",
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2563EB),
            decoration: TextDecoration.underline,
          ),
        ),
        TextWidget(
          text: ". Override overage settings.",
          fontSize: 11.sp,
          fontWeight: FontWeight.normal,
          color: Colors.grey.shade600,
        ),
      ],
    );
  }

  // Cards
  Widget _buildCallsCard({
    int included = 5,
    double callsInRate = 0.05,
    double callsOutRate = 0.07,
  }) {
    final inLimit = _callsInIncluded;
    final outLimit = _callsOutIncluded;
    final bool inOver = _callsIn > inLimit;
    final bool outOver = _callsOut > outLimit;
    final bool isOver = inOver || outOver;
    final double progress = (outLimit > 0)
        ? (_callsOut / outLimit).clamp(0.0, 1.0)
        : 0.0;

    return _buildUsageCardWrapper(
      title: "Calls",
      icon: Icons.call,
      iconColor: isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
      badgeText: isOver ? "Over" : "On track",
      badgeColor: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
      badgeTextColor: isOver
          ? const Color(0xFFB91C1C)
          : const Color(0xFF15803D),
      body: Column(
        children: [
          _buildDirectionalRow(
            incoming: true,
            label:
                "${_formatDouble(_callsIn)} / $inLimit min${inOver ? ' +${_formatDouble(_callsIn - inLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          _buildDirectionalRow(
            incoming: false,
            label:
                "${_formatDouble(_callsOut)} / $outLimit min${outOver ? ' +${_formatDouble(_callsOut - outLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              ),
              minHeight: 5.h,
            ),
          ),
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue:
          "\$${callsInRate.toStringAsFixed(4)} / \$${callsOutRate.toStringAsFixed(4)}/min",
    );
  }

  Widget _buildSMSCard({
    int included = 5,
    double smsInRate = 0.01,
    double smsOutRate = 0.02,
  }) {
    final inLimit = _smsInIncluded;
    final outLimit = _smsOutIncluded;
    final bool inOver = _smsIn > inLimit;
    final bool outOver = _smsOut > outLimit;
    final bool isOver = inOver || outOver;
    final double progress = (outLimit > 0)
        ? (_smsOut / outLimit).clamp(0.0, 1.0)
        : 0.0;

    // Calculate actual estimated overage cost
    final double estOverage = _smsInOverage + _smsOutOverage;

    return _buildUsageCardWrapper(
      title: "SMS",
      icon: Icons.sms,
      iconColor: isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
      badgeText: isOver ? "Over" : "On track",
      badgeColor: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
      badgeTextColor: isOver
          ? const Color(0xFFB91C1C)
          : const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDirectionalRow(
            incoming: true,
            label:
                "${_formatDouble(_smsIn)} / $inLimit msg${inOver ? ' +${_formatDouble(_smsIn - inLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          _buildDirectionalRow(
            incoming: false,
            label:
                "${_formatDouble(_smsOut)} / $outLimit msg${outOver ? ' +${_formatDouble(_smsOut - outLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              ),
              minHeight: 5.h,
            ),
          ),
          if (isOver && estOverage > 0) ...[
            SizedBox(height: 4.h),
            TextWidget(
              text: "Over - est. \$${estOverage.toStringAsFixed(2)}",
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEF4444),
            ),
          ],
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue:
          "\$${smsInRate.toStringAsFixed(4)} / \$${smsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  Widget _buildMMSCard({
    int included = 5,
    double mmsInRate = 0.05,
    double mmsOutRate = 0.10,
  }) {
    final inLimit = _mmsInIncluded;
    final outLimit = _mmsOutIncluded;
    final bool inOver = _mmsIn > inLimit;
    final bool outOver = _mmsOut > outLimit;
    final bool isOver = inOver || outOver;
    final double progress = (outLimit > 0)
        ? (_mmsOut / outLimit).clamp(0.0, 1.0)
        : 0.0;

    return _buildUsageCardWrapper(
      title: "MMS",
      icon: Icons.photo_library,
      iconColor: isOver ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
      badgeText: isOver ? "Over" : "On track",
      badgeColor: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
      badgeTextColor: isOver
          ? const Color(0xFFB91C1C)
          : const Color(0xFF15803D),
      body: Column(
        children: [
          _buildDirectionalRow(
            incoming: true,
            label:
                "${_formatDouble(_mmsIn)} / $inLimit msg${inOver ? ' +${_formatDouble(_mmsIn - inLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          _buildDirectionalRow(
            incoming: false,
            label:
                "${_formatDouble(_mmsOut)} / $outLimit msg${outOver ? ' +${_formatDouble(_mmsOut - outLimit)}' : ''}",
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              ),
              minHeight: 5.h,
            ),
          ),
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue:
          "\$${mmsInRate.toStringAsFixed(4)} / \$${mmsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  Widget _buildStorageCard() {
    final storageAddon = _getAddon('file-storage', 'storage');
    final storageData = storageAddon?.storage ?? {};
    final usedDisplay = (storageData['used_display'] ?? '0 KB').toString();
    final includedDisplay = (storageData['included_display'] ?? '0 GB')
        .toString();
    final remainingDisplay = (storageData['remaining_display'] ?? '0 GB')
        .toString();
    final usagePercent = (storageData['usage_percent'] is num)
        ? (storageData['usage_percent'] as num).toDouble()
        : 0.0;
    final overage = storageData['overage'] as Map<String, dynamic>? ?? {};
    final overageEnabled = overage['enabled'] == true;
    final overageRate = (overage['rate_per_block'] is num)
        ? (overage['rate_per_block'] as num).toDouble()
        : 0.69;
    final blockSizeGb = (storageData['block_size_gb'] is num)
        ? (storageData['block_size_gb'] as num).toInt()
        : 500;

    return _buildUsageCardWrapper(
      title: "Storage",
      icon: Icons.folder,
      iconColor: const Color(0xFF8B5CF6),
      badgeText: "${usagePercent.toStringAsFixed(0)}% used",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextWidget(
                text: usedDisplay,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(width: 4.w),
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: TextWidget(
                  text: "of $includedDisplay included",
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: (usagePercent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                usagePercent > 90
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2563EB),
              ),
              minHeight: 5.h,
            ),
          ),
          SizedBox(height: 6.h),
          TextWidget(
            text: "$remainingDisplay remaining",
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ],
      ),
      overageLabel: "Overage",
      overageValue: overageEnabled ? "" : "",
      bottomLabel:
          "Rate: \$${overageRate.toStringAsFixed(2)}/block (per $blockSizeGb GB)",
    );
  }

  Widget _buildSupportLinesCard({
    double supportLineRate = 0.69,
    int supportLinesIncluded = 1,
  }) {
    final clientPro = context.read<ClientPro>();
    final details =
        clientPro.currentClientBillingTabs?.billing.supportLinesDetails;
    final inUseCount = details?.inUseCount ?? 0;
    final numbers = details?.numbers ?? [];

    return _buildUsageCardWrapper(
      title: "Support Lines",
      icon: Icons.headset_mic,
      iconColor: const Color(0xFF10B981),
      badgeText: "$inUseCount active",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextWidget(
                text: "$inUseCount",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(width: 4.w),
              TextWidget(
                text: inUseCount == 1 ? "line in use" : "lines in use",
                fontSize: 11.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...numbers.map<Widget>((item) {
            final phone = (item['phone_number'] ?? '').toString();
            final isMain = item['is_main'] == true;
            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    TextWidget(
                      text: _formatPhoneNumber(phone),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    if (isMain) ...[
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF08A),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: TextWidget(
                          text: "MAIN",
                          fontSize: 7.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomLabel:
          "Plan includes $supportLinesIncluded line${supportLinesIncluded == 1 ? '' : 's'} · \$${supportLineRate.toStringAsFixed(2)}/wk per extra line",
    );
  }

  /// Formats a raw phone number like "18182808831" into "+1 (818) 280-8831".
  String _formatPhoneNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  Widget _buildEmailConnectionsCard({
    double emailRate = 4.62,
    int emailIncluded = 0,
  }) {
    return _buildUsageCardWrapper(
      title: "Email Connections",
      icon: Icons.email,
      iconColor: const Color(0xFF3B82F6),
      badgeText: "1 active",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextWidget(
                text: "1",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(width: 4.w),
              TextWidget(
                text: "email slots in use",
                fontSize: 11.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextWidget(
              text: "sheenmonawdar@gmail.com",
              fontSize: 11.sp,
              fontWeight: FontWeight.normal,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      bottomLabel:
          "Base plan includes $emailIncluded email slot${emailIncluded == 1 ? '' : 's'} · \$${emailRate.toStringAsFixed(2)}/wk per extra slot",
    );
  }

  Widget _buildUsageCardWrapper({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required Widget body,
    String? overageLabel,
    String? overageValue,
    String? bottomLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 16.sp),
                  SizedBox(width: 6.w),
                  TextWidget(
                    text: title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: TextWidget(
                  text: badgeText,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          body,
          SizedBox(height: 10.h),
          const Divider(height: 1, thickness: 0.5),
          SizedBox(height: 6.h),
          if (overageLabel != null && overageValue != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: overageLabel,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
                TextWidget(
                  text: overageValue,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: TextWidget(
                    text: "Enabled",
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ],
          if (bottomLabel != null) ...[
            if (overageLabel == null) ...[SizedBox(height: 6.h)],
            SizedBox(height: 4.h),
            TextWidget(
              text: bottomLabel,
              fontSize: 10.sp,
              fontWeight: FontWeight.normal,
              color: Colors.grey.shade500,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDirectionalRow({required bool incoming, required String label}) {
    return Row(
      children: [
        Icon(
          incoming ? Icons.arrow_downward : Icons.arrow_upward,
          size: 12.sp,
          color: incoming ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
        ),
        SizedBox(width: 4.w),
        TextWidget(
          text: incoming ? "in" : "out",
          fontSize: 11.sp,
          fontWeight: FontWeight.normal,
          color: Colors.grey.shade500,
        ),
        const Spacer(),
        TextWidget(text: label, fontSize: 11.sp, fontWeight: FontWeight.bold),
      ],
    );
  }

  // Specialist toggle card
  Widget _buildSpecialistAccessCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: TextWidget(
              text: title,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF00a650),
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Add-ons list optimized for mobile cards
  Widget _buildAddonsSection(
    double supportLineCost,
    double storageCost,
    double emailCost,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextWidget(
              text: "Add-ons",
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: TextWidget(
                text: "Admin only",
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        _buildAddonMobileCard(
          icon: Icons.headset_mic,
          iconColor: const Color(0xFFF59E0B),
          title: "Support Lines",
          subtitle: "\$0.69/wk per extra number",
          isActive: _supportLinesActive,
          onActiveChanged: (val) => setState(() => _supportLinesActive = val),
          qty: _supportLinesQty,
          onQtyChanged: (val) => setState(() => _supportLinesQty = val),
          cost: supportLineCost,
        ),
        SizedBox(height: 10.h),
        _buildAddonMobileCard(
          icon: Icons.folder,
          iconColor: const Color(0xFF3B82F6),
          title: "File Storage",
          subtitle: "\$0.69/wk per 500GB/wk",
          isActive: _fileStorageActive,
          onActiveChanged: (val) => setState(() => _fileStorageActive = val),
          qty: _fileStorageQty,
          onQtyChanged: (val) => setState(() => _fileStorageQty = val),
          cost: storageCost,
        ),
        SizedBox(height: 10.h),
        _buildAddonMobileCard(
          icon: Icons.email,
          iconColor: const Color(0xFF10B981),
          title: "Email Connections",
          subtitle: "\$4.62/wk per extra email slot",
          isActive: _emailConnectionsActive,
          onActiveChanged: (val) =>
              setState(() => _emailConnectionsActive = val),
          qty: _emailConnectionsQty,
          onQtyChanged: (val) => setState(() => _emailConnectionsQty = val),
          cost: emailCost,
        ),
      ],
    );
  }

  Widget _buildAddonMobileCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
    required int qty,
    required ValueChanged<int> onQtyChanged,
    required double cost,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    TextWidget(
                      text: subtitle,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeTrackColor: const Color(0xFF00a650),
                activeThumbColor: Colors.white,
                onChanged: onActiveChanged,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1, thickness: 0.5),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: isActive && qty > 0
                        ? () => onQtyChanged(qty - 1)
                        : null,
                    icon: const Icon(Icons.remove, size: 12),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TextWidget(
                    text: qty.toString(),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    onPressed: isActive ? () => onQtyChanged(qty + 1) : null,
                    icon: const Icon(Icons.add, size: 12),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                ],
              ),
              TextWidget(
                text: "\$${cost.toStringAsFixed(2)}/wk",
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: cost > 0 ? Colors.black : Colors.grey.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Info red banner
  Widget _buildInfoBanner() {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFFEF4444), size: 16),
          SizedBox(width: 8.w),
          Expanded(
            child: TextWidget(
              text:
                  "To enable or modify any services, add new specialists, or adjust configuration settings, please contact your Pod Supervisor.",
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  // Save button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        onPressed: _isSaving ? null : _handleSaveConfiguration,
        child: _isSaving
            ? SizedBox(
                width: 14.w,
                height: 14.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const TextWidget(
                text: "Save Configuration",
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
      ),
    );
  }

  Future<void> _handleSaveConfiguration() async {
    setState(() => _isSaving = true);
    final clientPro = context.read<ClientPro>();
    final billing = clientPro.currentClientBillingTabs?.billing;

    final List<Map<String, dynamic>> addonsPayload = [];
    if (billing != null) {
      for (var row in billing.addons) {
        bool isActive = row.isActive;
        int qty = row.quantity;
        if (row.key == 'support_lines') {
          isActive = _supportLinesActive;
          qty = _supportLinesQty;
        } else if (row.key == 'extra_storage') {
          isActive = _fileStorageActive;
          qty = _fileStorageQty;
        } else if (row.key == 'extra_emails') {
          isActive = _emailConnectionsActive;
          qty = _emailConnectionsQty;
        }
        addonsPayload.add({
          "addon_key": row.key,
          "is_active": isActive,
          "quantity": qty,
          "service_addon_id": row.addonId,
        });
      }
    } else {
      addonsPayload.addAll([
        {
          "addon_key": "support_lines",
          "is_active": _supportLinesActive,
          "quantity": _supportLinesQty,
          "service_addon_id": 1,
        },
        {
          "addon_key": "extra_storage",
          "is_active": _fileStorageActive,
          "quantity": _fileStorageQty,
          "service_addon_id": 2,
        },
        {
          "addon_key": "extra_emails",
          "is_active": _emailConnectionsActive,
          "quantity": _emailConnectionsQty,
          "service_addon_id": 3,
        },
        {
          "addon_key": "incoming_call_minutes",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 4,
        },
        {
          "addon_key": "outgoing_call_minutes",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 5,
        },
        {
          "addon_key": "incoming_sms",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 6,
        },
        {
          "addon_key": "outgoing_sms",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 7,
        },
        {
          "addon_key": "incoming_mms",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 8,
        },
        {
          "addon_key": "outgoing_mms",
          "is_active": false,
          "quantity": 0,
          "service_addon_id": 9,
        },
      ]);
    }

    final List<Map<String, dynamic>> specialistsPayload = [];
    if (billing != null) {
      for (var row in billing.specialistRows) {
        bool isEnabled = row.isEnabled;
        if (row.accountTypeId == 2 ||
            row.name.toLowerCase().contains('staff')) {
          isEnabled = _staffAccess;
        } else if (row.accountTypeId == 3 ||
            row.name.toLowerCase().contains('graphic')) {
          isEnabled = _graphicDesignerAccess;
        }
        final int accountTypeId = row.accountTypeId;
        final String serviceKey = "acct_$accountTypeId";
        specialistsPayload.add({
          "service_key": serviceKey,
          "is_enabled": isEnabled,
          "account_type_id": accountTypeId,
        });
      }
    } else {
      specialistsPayload.addAll([
        {
          "service_key": "acct_2",
          "is_enabled": _staffAccess,
          "account_type_id": 2,
        },
        {
          "service_key": "acct_3",
          "is_enabled": _graphicDesignerAccess,
          "account_type_id": 3,
        },
      ]);
    }

    final String mode = billing?.pricingMode.toLowerCase() ?? 'free';

    final success = await clientPro.updateBillingConfiguration(
      clientId: widget.clientId,
      mode: mode,
      addons: addonsPayload,
      specialists: specialistsPayload,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        final currentWeek =
            clientPro.currentClientBillingTabs?.week.start ?? '';
        if (currentWeek.isNotEmpty) {
          await clientPro.getClientBillingTabs(
            widget.clientId,
            currentWeek,
            showLoading: false,
          );
        }
      }
    }
  }

  Widget _buildWeeklyVolumeTab() {
    final clientPro = context.watch<ClientPro>();
    final bool isAnySpecialistEnabled = _staffAccess || _graphicDesignerAccess;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Week Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.chevron_left,
                      size: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: _goToPreviousWeek,
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: clientPro.currentClientBillingTabs?.week.label ?? "May 25-31, 2026",
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    TextWidget(
                      text: "${clientPro.currentClientBillingTabs?.week.isCurrent == true ? 'Current week' : 'Previous week'}  Orders & Jobs from Printobi",
                      fontSize: 9.sp,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
                SizedBox(width: 8.w),
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.chevron_right,
                      size: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: _goToNextWeek,
                  ),
                ),
              ],
            ),
            SizedBox(width: 16.w),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: const Color(
                  0xFF10B981,
                ).withValues(alpha: 0.5),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: (isAnySpecialistEnabled && !_isWeekClosed)
                  ? () {
                      showDialog(
                        context: context,
                        builder: (ctx) => DialogAddEntry(
                          onSave: (entryData) async {
                            final success = await context
                                .read<ClientPro>()
                                .addWeeklyVolumeEntry(
                                  clientId: widget.clientId,
                                  date: entryData['date'],
                                  pricingMode: entryData['pricing_mode'],
                                  orderNo: entryData['orderNo'],
                                  jobNos: entryData['jobNos'],
                                );
                            if (success && mounted) {
                              await _fetchBillingTabs(isWeekChange: true);
                            }
                          },
                        ),
                      );
                    }
                  : null,
              icon: Icon(
                Icons.add,
                size: 14.sp,
                color: (isAnySpecialistEnabled && !_isWeekClosed)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
              label: TextWidget(
                text: "Add Entry",
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: (isAnySpecialistEnabled && !_isWeekClosed)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (!isAnySpecialistEnabled) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: TextWidget(
              text:
                  "Enable at least one Specialist Services Access toggle before adding entries.",
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFEF4444),
            ),
          ),
        ] else ...[
          SizedBox(height: 6.h),
        ],

        // 2. Summary Cards Grid (Stacked on mobile)
        _buildVolumeSummaryCard(
          title: "WHOLESALE THIS WEEK",
          value: clientPro.currentClientBillingTabs?.weeklyVolume.summary.ordersThisWeek.toString() ?? "0",
          subtitle: "Logged by admin",
          topBorderColor: const Color(0xFF3B82F6),
        ),
        SizedBox(height: 12.h),
        _buildVolumeSummaryCard(
          title: "RETAIL THIS WEEK",
          value: clientPro.currentClientBillingTabs?.weeklyVolume.summary.jobsThisWeek.toString() ?? "0",
          subtitle: "Logged by admin",
          topBorderColor: const Color(0xFFFBBF24),
        ),
        SizedBox(height: 12.h),
        _buildVolumeSummaryCard(
          title: "SPECIALISTS INVOLVED",
          value: clientPro.currentClientBillingTabs?.weeklyVolume.summary.specialistsInvolved.toString() ?? "0",
          subtitle: "Marked involvement",
          topBorderColor: const Color(0xFF10B981),
        ),
        SizedBox(height: 16.h),

        // 3. Order & Job Log
        _buildOrderJobLog(),
        SizedBox(height: 16.h),

        // 4. Week Charge Breakdown
        _buildWeekChargeBreakdown(),
      ],
    );
  }

  Widget _buildVolumeSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color topBorderColor,
  }) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, width: double.infinity, color: topBorderColor),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: value,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                SizedBox(height: 4.h),
                TextWidget(
                  text: subtitle,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderJobLog() {
    final clientPro = Provider.of<ClientPro>(context);
    final weeklyVolume = clientPro.currentClientBillingTabs?.weeklyVolume;
    final pagination = weeklyVolume?.pagination ?? {};
    final totalPages = int.tryParse((pagination['last_page'] ?? pagination['lastPage'] ?? 1).toString()) ?? 1;
    final totalEntries = int.tryParse((pagination['total'] ?? 0).toString()) ?? 0;
    final from = int.tryParse((pagination['from'] ?? 0).toString()) ?? 0;
    final to = int.tryParse((pagination['to'] ?? 0).toString()) ?? 0;
    final currentEntries = weeklyVolume?.entries ?? [];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget(
                text: "Order & Job Log",
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              Row(
                children: [
                  _buildDropdown(
                    value: _orderLogTypeFilter,
                    items: const ['All types', 'Wholesale', 'Retail'],
                    onChanged: (val) {
                      setState(() {
                        _orderLogTypeFilter = val;
                      });
                      final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
                      final currentWeek = clientPro.currentClientBillingTabs?.week.start ?? '';
                      if (clientId != 0) {
                        clientPro.getClientBillingTabs(
                          clientId,
                          currentWeek,
                          volumePage: 1,
                          volumeType: val,
                          volumeDay: _orderLogDayFilter,
                        );
                      }
                    },
                  ),
                  SizedBox(width: 8.w),
                  _buildDropdown(
                    value: _orderLogDayFilter,
                    items: const [
                      'All days',
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ],
                    onChanged: (val) {
                      setState(() {
                        _orderLogDayFilter = val;
                      });
                      final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
                      final currentWeek = clientPro.currentClientBillingTabs?.week.start ?? '';
                      if (clientId != 0) {
                        clientPro.getClientBillingTabs(
                          clientId,
                          currentWeek,
                          volumePage: 1,
                          volumeType: _orderLogTypeFilter,
                          volumeDay: val,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 600.w, child: _buildOrderLogTable(currentEntries)),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextWidget(
                text: totalEntries == 0
                    ? "No entries match this view"
                    : "Showing $from-$to of $totalEntries entries",
                fontSize: 9.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade500,
              ),
              _buildPagination(
                currentPage: int.tryParse((pagination['current_page'] ?? pagination['currentPage'] ?? 1).toString()) ?? 1,
                totalPages: totalPages,
                onPageChanged: (page) {
                  final clientId = clientPro.currentClientBillingTabs?.client.id ?? 0;
                  final currentWeek = clientPro.currentClientBillingTabs?.week.start ?? '';
                  if (clientId != 0) {
                    clientPro.getClientBillingTabs(
                      clientId,
                      currentWeek,
                      volumePage: page,
                      volumeType: _orderLogTypeFilter,
                      volumeDay: _orderLogDayFilter,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: Offset(0, 36.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (context) => items.map((item) {
        final isSelected = item == value;
        return PopupMenuItem<String>(
          value: item,
          height: 36.h,
          child: TextWidget(
            text: item,
            fontSize: 11.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.black87,
          ),
        );
      }).toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            TextWidget(
              text: value,
              fontSize: 10.sp,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14.sp,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination({
    required int currentPage,
    required int totalPages,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalPages <= 1) return const SizedBox();

    List<int> pages = [];
    if (totalPages <= 5) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      pages.add(1);
      if (currentPage > 3) pages.add(-1); // ellipsis
      int start = (currentPage - 1).clamp(2, totalPages - 2);
      int end = (currentPage + 1).clamp(2, totalPages - 1);
      for (int i = start; i <= end; i++) {
        pages.add(i);
      }
      if (currentPage < totalPages - 2) pages.add(-1); // ellipsis
      pages.add(totalPages);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pageCircle(
            icon: Icons.keyboard_double_arrow_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(1),
          ),
          _pageCircle(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          SizedBox(width: 4.w),
          ...pages.map((p) {
            if (p == -1) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                child: TextWidget(
                  text: "...",
                  fontSize: 14.sp,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey,
                ),
              );
            }
            final bool isActive = p == currentPage;
            return GestureDetector(
              onTap: () => onPageChanged(p),
              child: Container(
                width: 28.w,
                height: 28.w,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFACC15) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: TextWidget(
                    text: "$p",
                    fontSize: 11.sp,
                    color: isActive ? Colors.black : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          SizedBox(width: 4.w),
          _pageCircle(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
          _pageCircle(
            icon: Icons.keyboard_double_arrow_right,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(totalPages),
          ),
        ],
      ),
    );
  }

  Widget _pageCircle({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28.w,
        height: 28.w,
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 14.sp,
            color: enabled ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderLogTable(List<dynamic> entries) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 2, child: _buildTableHeader("DATE")),
            Expanded(flex: 2, child: _buildTableHeader("TYPE")),
            Expanded(flex: 2, child: _buildTableHeader("ORDER #")),
            Expanded(flex: 2, child: _buildTableHeader("JOB #")),
            Expanded(flex: 3, child: _buildTableHeader("SPECIALISTS INVOLVED")),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildTableHeader("ACTIONS"),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        if (entries.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Center(
              child: TextWidget(
                text: "No entries for this week",
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),
          )
        else
          ...entries.map(
            (entry) => _buildOrderLogRow(
              entry.date,
              entry.pricingMode,
              entry.orderNo,
              entry.jobNo,
            ),
          ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return TextWidget(
      text: text,
      fontSize: 9.sp,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade500,
    );
  }

  Widget _buildOrderLogRow(
    String date,
    String type,
    String orderNo,
    String jobNo,
  ) {
    bool isWholesale = type.toLowerCase() == "wholesale";
    String displayType = type.isNotEmpty
        ? (type[0].toUpperCase() + type.substring(1).toLowerCase())
        : type;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextWidget(
              text: date,
              fontSize: 11.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: isWholesale
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: TextWidget(
                  text: displayType,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: isWholesale
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD97706),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextWidget(
              text: orderNo,
              fontSize: 11.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            flex: 2,
            child: TextWidget(
              text: jobNo,
              fontSize: 11.sp,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "No specialist marked yet",
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: _isWeekClosed
                  ? const SizedBox.shrink()
                  : Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: ImageWidget(
                        image: Paths.delete,
                        color: const Color(0xFFEF4444),
                        width: 12.w,
                        height: 12.h,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChargeBreakdown() {
    final clientPro = context.read<ClientPro>();
    final weekChargeBreakdown = clientPro.currentClientBillingTabs?.weeklyVolume.weekChargeBreakdown;

    int wholesaleQty = 0;
    double wholesaleUnitPrice = 0.0;
    double wholesaleTotal = 0.0;

    int retailQty = 0;
    double retailUnitPrice = 0.0;
    double retailTotal = 0.0;

    final entries = clientPro.currentClientBillingTabs?.weeklyVolume.entries ?? [];
    for (var entry in entries) {
      final isWholesale = entry.pricingMode.toLowerCase() == 'wholesale';
      if (isWholesale) {
        wholesaleQty++;
        wholesaleUnitPrice = entry.unitPrice;
        wholesaleTotal += entry.unitPrice;
      } else {
        retailQty++;
        retailUnitPrice = entry.unitPrice;
        retailTotal += entry.unitPrice;
      }
    }

    final billing = clientPro.currentClientBillingTabs?.billing;
    if (wholesaleUnitPrice == 0.0 && billing != null) {
      wholesaleUnitPrice = billing.wholesalePrice;
    }
    if (retailUnitPrice == 0.0 && billing != null) {
      retailUnitPrice = billing.retailPrice;
    }

    final double phPortalWeeklyVal = billing?.phPortalWeekly ?? 345.40;
    final double supportLineWeeklyPriceVal = _supportLineWeeklyPrice;
    final double storageWeeklyPriceVal = _storageWeeklyPrice;
    final double emailWeeklyPriceVal = _emailWeeklyPrice;

    final double supportLineCostVal = _supportLinesActive
        ? (_supportLinesQty * supportLineWeeklyPriceVal)
        : 0.0;
    final double storageCostVal = _fileStorageActive
        ? (_fileStorageQty * storageWeeklyPriceVal)
        : 0.0;
    final double emailCostVal = _emailConnectionsActive
        ? (_emailConnectionsQty * emailWeeklyPriceVal)
        : 0.0;

    final double baseWeeklyCharge = clientPro.currentClientBillingTabs?.weeklyVolume.summary.thisWeekCharge ?? 0.0;
    final double extraChargesSum = _extraCharges.fold<double>(
      0.0,
      (sum, e) => sum + (double.tryParse(e.amountController.text) ?? 0.0),
    );

    final double totalChargeWithExtras;
    if (weekChargeBreakdown != null) {
      if (_hasEditedExtraCharges || _extraCharges.isNotEmpty) {
        totalChargeWithExtras = weekChargeBreakdown.weekSubtotal - weekChargeBreakdown.creditsApplied + extraChargesSum;
      } else {
        totalChargeWithExtras = weekChargeBreakdown.weekTotal;
      }
    } else {
      totalChargeWithExtras = baseWeeklyCharge + extraChargesSum;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: "WEEK CHARGE BREAKDOWN",
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
          ),
          SizedBox(height: 16.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 500.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: const SizedBox()),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.center,
                          child: _buildTableHeader("QTY"),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildTableHeader("UNIT PRICE"),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildTableHeader("AMOUNT"),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF3F4F6),
                  ),
                  SizedBox(height: 8.h),

                  if (weekChargeBreakdown != null)
                    ...weekChargeBreakdown.rows.where((row) => !row.key.startsWith('extra-charge')).map((row) {
                      Color? amountColor;
                      if (row.tone == 'success') {
                        amountColor = const Color(0xFF10B981);
                      } else if (row.tone == 'danger' || row.tone == 'error') {
                        amountColor = const Color(0xFFEF4444);
                      }
                      return _buildChargeRow(
                        row.label,
                        row.qty?.toString() ?? "—",
                        row.unitPriceLabel,
                        "\$${row.amount.toStringAsFixed(2)}",
                        amountColor: amountColor,
                      );
                    })
                  else ...[
                    _buildChargeRow(
                      "The Pod - Wholesale",
                      "$wholesaleQty",
                      "\$${wholesaleUnitPrice.toStringAsFixed(2)}",
                      "\$${wholesaleTotal.toStringAsFixed(2)}",
                    ),
                    _buildChargeRow(
                      "The Pod - Retail",
                      "$retailQty",
                      "\$${retailUnitPrice.toStringAsFixed(2)}",
                      "\$${retailTotal.toStringAsFixed(2)}",
                    ),
                    _buildChargeRow(
                      "PH Portal",
                      "—",
                      "\$${phPortalWeeklyVal.toStringAsFixed(2)}/wk",
                      "\$${phPortalWeeklyVal.toStringAsFixed(2)}",
                      amountColor: const Color(0xFF10B981),
                    ),
                    _buildChargeRow(
                      "Support Lines",
                      "$_supportLinesQty",
                      "\$${supportLineWeeklyPriceVal.toStringAsFixed(2)}/per extra phone number",
                      "\$${supportLineCostVal.toStringAsFixed(2)}",
                    ),
                    _buildChargeRow(
                      "File Storage",
                      "$_fileStorageQty",
                      "\$${storageWeeklyPriceVal.toStringAsFixed(2)}/per 500GB/wk",
                      "\$${storageCostVal.toStringAsFixed(2)}",
                    ),
                    _buildChargeRow(
                      "Email Connections",
                      "$_emailConnectionsQty",
                      "\$${emailWeeklyPriceVal.toStringAsFixed(2)}/per extra email slot",
                      "\$${emailCostVal.toStringAsFixed(2)}",
                    ),
                    _buildChargeRow(
                      "SMS Overage",
                      _smsOut > _smsOutIncluded ? "${(_smsOut - _smsOutIncluded).toInt()}" : "0",
                      "\$${_smsOutRate.toStringAsFixed(2)}",
                      "\$${_smsOutOverage.toStringAsFixed(2)}",
                      amountColor: const Color(0xFFEF4444),
                    ),
                  ],

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isWeekClosed ? Colors.grey.shade200 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                      ),
                      onPressed: _isWeekClosed
                          ? null
                          : () {
                              setState(() {
                                _hasEditedExtraCharges = true;
                                _extraCharges.add(
                                  ExtraChargeItem(description: '', amount: 0.0),
                                );
                              });
                            },
                      icon: Icon(
                        Icons.add,
                        size: 12.sp,
                        color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      label: TextWidget(
                        text: "Add Extra Charge",
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),

                  ..._extraCharges.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      key: ObjectKey(item),
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 38.h,
                              child: TextField(
                                controller: item.descController,
                                readOnly: _isWeekClosed,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: _isWeekClosed ? Colors.grey.shade600 : Colors.black87,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Description",
                                  hintStyle: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade400,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 8.h,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _hasEditedExtraCharges = true;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          SizedBox(
                            width: 100.w,
                            height: 38.h,
                            child: TextField(
                              controller: item.amountController,
                              readOnly: _isWeekClosed,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _isWeekClosed ? Colors.grey.shade600 : Colors.black87,
                                ),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _hasEditedExtraCharges = true;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 20.w),
                          GestureDetector(
                            onTap: _isWeekClosed
                                ? null
                                : () {
                                    setState(() {
                                      _hasEditedExtraCharges = true;
                                      item.descController.dispose();
                                      item.amountController.dispose();
                                      _extraCharges.removeAt(index);
                                    });
                                  },
                            child: Container(
                              width: 38.w,
                              height: 38.h,
                              decoration: BoxDecoration(
                                color: _isWeekClosed ? Colors.grey.shade100 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Center(
                                child: ImageWidget(
                                  image: Paths.delete,
                                  color: _isWeekClosed ? Colors.grey.shade400 : const Color(0xFFEF4444),
                                  width: 18.w,
                                  height: 18.h,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  _buildChargeRow(
                    "Credits Applied",
                    "",
                    "",
                    "\$${(weekChargeBreakdown?.creditsApplied ?? 0.0).toStringAsFixed(2)}",
                    amountColor: const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12.h),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          SizedBox(height: 16.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextWidget(
                text: "Week Total",
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              TextWidget(
                text: "\$${totalChargeWithExtras.toStringAsFixed(2)}",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: (_isSaving || _isWeekClosed)
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          setState(() => _isSaving = true);
                          final clientPro = context.read<ClientPro>();
                          final weekStart = clientPro.currentClientBillingTabs?.week.start ?? _selectedWeek;
                          String weekEndVal = clientPro.currentClientBillingTabs?.week.end ?? "";
                          if (weekEndVal.isEmpty) {
                            try {
                              final parsed = DateTime.parse(weekStart);
                              final end = parsed.add(const Duration(days: 6));
                              weekEndVal = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
                            } catch (_) {}
                          }

                          final items = _extraCharges.map((e) => {
                            "description": e.descController.text.trim(),
                            "amount": double.tryParse(e.amountController.text.trim()) ?? 0.0,
                          }).toList();

                          final success = await clientPro.saveExtraCharges(
                            clientId: widget.clientId,
                            weekStart: weekStart,
                            weekEnd: weekEndVal,
                            items: items,
                          );

                          if (mounted) {
                            setState(() {
                              _isSaving = false;
                              if (success) {
                                _hasEditedExtraCharges = false;
                              }
                            });
                            if (success) {
                              await _fetchBillingTabs(isWeekChange: false);
                            }
                          }
                        },
                  icon: _isSaving
                      ? SizedBox(
                          width: 14.sp,
                          height: 14.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          Icons.lock_outline,
                          size: 14.sp,
                          color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                  label: TextWidget(
                    text: _isSaving ? "Saving..." : "Save Changes",
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: _isWeekClosed ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    disabledBackgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: (weekChargeBreakdown == null || _isWeekClosed)
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          final weekStart = clientPro.currentClientBillingTabs?.week.start ?? _selectedWeek;
                          String weekEndVal = clientPro.currentClientBillingTabs?.week.end ?? "";
                          if (weekEndVal.isEmpty) {
                            try {
                              final parsed = DateTime.parse(weekStart);
                              final end = parsed.add(const Duration(days: 6));
                              weekEndVal = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
                            } catch (_) {}
                          }

                          int ordersQty = 0;
                          int jobsQty = 0;
                          int podQty = 0;
                          double addonsSum = 0.0;

                          for (var row in weekChargeBreakdown.rows) {
                            if (row.key == 'pod-orders') {
                              ordersQty = row.qty ?? 0;
                            } else if (row.key == 'pod-jobs') {
                              jobsQty = row.qty ?? 0;
                            } else if (row.key == 'ph-portal') {
                              podQty = row.qty ?? (row.amount > 0 ? 1 : 0);
                            } else if (row.key.startsWith('addon-')) {
                              addonsSum += row.amount;
                            }
                          }

                          final extrasAmount = weekChargeBreakdown.extraChargesTotal;
                          final creditAmount = weekChargeBreakdown.creditsApplied;
                          final totalAmount = weekChargeBreakdown.weekTotal;

                          final success = await clientPro.closeWeek(
                            clientId: widget.clientId,
                            weekStart: weekStart,
                            weekEnd: weekEndVal,
                            orders: ordersQty,
                            jobs: jobsQty,
                            pod: podQty,
                            addons: addonsSum,
                            extras: extrasAmount,
                            credit: creditAmount,
                            total: totalAmount,
                          );

                          if (success && mounted) {
                            await _fetchBillingTabs(isWeekChange: false);
                          }
                        },
                  icon: Icon(
                    _isWeekClosed ? Icons.lock : Icons.lock_open,
                    size: 14.sp,
                    color: _isWeekClosed ? Colors.black38 : Colors.black,
                  ),
                  label: TextWidget(
                    text: _isWeekClosed ? "Week Closed" : "Close Week & Record Charge",
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: _isWeekClosed ? Colors.black38 : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow(
    String label,
    String qty,
    String unitPrice,
    String amount, {
    Color? amountColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextWidget(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.center,
              child: TextWidget(
                text: qty,
                fontSize: 10.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextWidget(
                text: unitPrice,
                fontSize: 10.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextWidget(
                text: amount,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: amountColor ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab() {
    return Container(
      height: 200.h,
      alignment: Alignment.center,
      child: TextWidget(
        text: "Coming soon",
        fontSize: 13.sp,
        fontWeight: FontWeight.normal,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildBillingTab(double totalWeeklyCharge, double overageCost) {
    final clientPro = context.read<ClientPro>();
    final invoiceHistory = clientPro.currentClientBillingTabs?.billing.invoiceHistory ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: TextWidget(
              text: "INVOICE HISTORY",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 960.w,
              child: Column(
                children: [
                  // Header row
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 16.w,
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _buildTableHeader("WEEK")),
                        Expanded(flex: 2, child: _buildTableHeader("ORDERS")),
                        Expanded(flex: 2, child: _buildTableHeader("JOBS")),
                        Expanded(flex: 2, child: _buildTableHeader("POD")),
                        Expanded(flex: 2, child: _buildTableHeader("ADD-ONS")),
                        Expanded(flex: 2, child: _buildTableHeader("EXTRAS")),
                        Expanded(flex: 2, child: _buildTableHeader("CREDIT")),
                        Expanded(flex: 2, child: _buildTableHeader("TOTAL")),
                        Expanded(flex: 2, child: _buildTableHeader("STATUS")),
                        Expanded(
                          flex: 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildTableHeader("ACTIONS"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dynamic rows
                  if (invoiceHistory.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: TextWidget(
                          text: "No invoice history yet",
                          fontSize: 12.sp,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    ...invoiceHistory.map((inv) => _buildInvoiceHistoryRow(inv)),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFACC15),
                  ),
                ),
                SizedBox(width: 6.w),
                TextWidget(
                  text: "Yellow = closed but not yet paid",
                  fontSize: 11.sp,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceHistoryRow(InvoiceHistoryItemModel inv) {
    final isClosed = inv.status.toLowerCase() == 'closed';
    final isPaid = inv.status.toLowerCase() == 'paid';

    // Row background: yellow tint for closed-not-paid
    final rowBg = (isClosed && !isPaid) ? const Color(0xFFFFFBEB) : Colors.white;

    // Status badge visuals
    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    if (isPaid) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
      badgeLabel = "Paid";
    } else if (isClosed) {
      badgeBg = const Color(0xFFE5E7EB);
      badgeText = const Color(0xFF374151);
      badgeLabel = "Closed";
    } else {
      badgeBg = const Color(0xFFFEF9C3);
      badgeText = const Color(0xFF854D0E);
      badgeLabel = "Open";
    }

    String fmt(double v) => v == 0 ? "\$0.00" : "\$${v.toStringAsFixed(2)}";
    String fmtCredit(double v) => v == 0 ? "-" : "-\$${v.toStringAsFixed(2)}";

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Week label
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: inv.weekLabel,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                if (inv.isCurrent) ...[
                  SizedBox(height: 2.h),
                  TextWidget(
                    text: "Current",
                    fontSize: 9.sp,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey.shade500,
                  ),
                ],
              ],
            ),
          ),
          // Orders
          Expanded(
            flex: 2,
            child: TextWidget(
              text: inv.orders.toString(),
              fontSize: 12.sp,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          // Jobs
          Expanded(
            flex: 2,
            child: TextWidget(
              text: inv.jobs.toString(),
              fontSize: 12.sp,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          // POD
          Expanded(
            flex: 2,
            child: TextWidget(
              text: fmt(inv.pod),
              fontSize: 12.sp,
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          // Add-ons (green)
          Expanded(
            flex: 2,
            child: TextWidget(
              text: inv.addons > 0 ? "\$${inv.addons.toStringAsFixed(2)}" : "-",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: inv.addons > 0 ? const Color(0xFF2563EB) : Colors.grey.shade400,
            ),
          ),
          // Extras
          Expanded(
            flex: 2,
            child: TextWidget(
              text: inv.extras > 0 ? fmt(inv.extras) : "-",
              fontSize: 12.sp,
              fontWeight: FontWeight.normal,
              color: inv.extras > 0 ? Colors.black87 : Colors.grey.shade400,
            ),
          ),
          // Credit (negative/red)
          Expanded(
            flex: 2,
            child: TextWidget(
              text: inv.credit > 0 ? fmtCredit(inv.credit) : "-",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: inv.credit > 0 ? const Color(0xFFEF4444) : Colors.grey.shade400,
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: TextWidget(
              text: fmt(inv.total),
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: TextWidget(
                  text: badgeLabel,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: badgeText,
                ),
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Invoice button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {},
                    icon: Icon(Icons.receipt_long_outlined, size: 11.sp, color: Colors.grey.shade600),
                    label: TextWidget(
                      text: "Invoice",
                      fontSize: 9.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  // Mark Paid button (only for closed-not-paid)
                  if (isClosed && !isPaid) ...[
                    SizedBox(width: 6.w),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {},
                      child: TextWidget(
                        text: "Mark Paid",
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showToggleStatusDialog(
    BuildContext context,
    String clientName,
    bool isActive,
    ClientPro pro,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: TextWidget(
          text: isActive ? "Deactivate Client" : "Activate Client",
          fontWeight: FontWeight.bold,
          fontSize: 15.sp,
        ),
        content: TextWidget(
          text:
              "Are you sure you want to ${isActive ? 'deactivate' : 'activate'} $clientName?",
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: TextWidget(
              text: "Cancel",
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.red : Colors.green,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await pro.toggleStatus(widget.clientId, !isActive, context);
              if (context.mounted) {
                pro.getClients(ctx: context, page: pro.currentPage);
              }
            },
            child: TextWidget(
              text: "Confirm",
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ExtraChargeItem {
  final TextEditingController descController;
  final TextEditingController amountController;

  ExtraChargeItem({required String description, required double amount})
      : descController = TextEditingController(text: description),
        amountController = TextEditingController(
          text: amount == 0.0
              ? ''
              : (amount % 1 == 0 ? amount.toInt().toString() : amount.toString()),
        );
}
