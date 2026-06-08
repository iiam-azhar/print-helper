import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/client_models.dart';
import '../tab_widgets/tab_image_widget.dart';
import '../tab_widgets/tab_toasts.dart';
import 'discounts_credits_tablet.dart';
import 'referrals_tablet.dart';
import 'package:print_helper/models/client_billing_tabs_model.dart';
import 'package:print_helper/admin/client/dialog_add_entry.dart';

class TabClientBillingScreen extends StatefulWidget {
  final int clientId;
  final VoidCallback? onBack;

  const TabClientBillingScreen({
    super.key,
    required this.clientId,
    this.onBack,
  });

  @override
  State<TabClientBillingScreen> createState() => _TabClientBillingScreenState();
}

class _TabClientBillingScreenState extends State<TabClientBillingScreen> {
  int _activeTab = 0; // default is Services tab (index 0)
  String _orderLogTypeFilter = 'All types';
  String _orderLogDayFilter = 'All days';
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _isInitialLoading = true;
  bool _isWeekLoading = false;

  bool get _isWeekClosed {
    final clientPro = context.read<ClientPro>();
    return clientPro.currentClientBillingTabs?.week.isClosed ?? false;
  }

  ClientBillingUsageBreakdownModel? get _breakdown =>
      _clientPro.currentClientBillingTabs?.usage.breakdown;

  double get _callsIn => _breakdown?.calls.incoming.used ?? 0.0;
  double get _callsOut => _breakdown?.calls.outgoing.used ?? 3.0;

  double get _smsIn => _breakdown?.sms.incoming.used ?? 0.0;
  double get _smsOut => _breakdown?.sms.outgoing.used ?? 6.0;

  double get _mmsIn => _breakdown?.mms.incoming.used ?? 0.0;
  double get _mmsOut => _breakdown?.mms.outgoing.used ?? 1.0;

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
  final List<ExtraChargeItem> _extraCharges = [];
  bool _hasEditedExtraCharges = false;

  // initState moved below with week calculation

  late String _selectedWeek;

  String _calculateCurrentWeekStart() {
    final now = DateTime.now();
    // Find Monday of current week (weekday: 1=Mon, 7=Sun)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
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

  ClientPro get _clientPro => Provider.of<ClientPro>(context, listen: true);

  String get _pricingMode =>
      _clientPro.currentClientBillingTabs?.billing.pricingMode.toLowerCase() ??
      'free';

  Future<void> _updatePricingMode(String mode) async {
    final clientPro = context.read<ClientPro>();
    final currentMode =
        clientPro.currentClientBillingTabs?.billing.pricingMode.toLowerCase() ??
        'free';
    if (currentMode == mode) return;
    final success = await clientPro.updatePricingMode(
      clientId: widget.clientId,
      mode: mode,
    );
    // After a successful pricing mode change, reload billing tabs to get
    // updated prices, charges, and addon values that depend on the active mode.
    if (success && mounted) {
      final currentWeek =
          clientPro.currentClientBillingTabs?.week.start ?? _selectedWeek;
      await clientPro.getClientBillingTabs(
        widget.clientId,
        currentWeek,
        showLoading: false,
      );
      // Re-sync local state from the fresh API data
      _syncLocalStateFromBilling(clientPro);
    }
    if (mounted) setState(() {});
  }

  /// Syncs local widget state (addon toggles/quantities, specialist access)
  /// from the current provider billing data.
  void _syncLocalStateFromBilling(ClientPro clientPro) {
    final billing = clientPro.currentClientBillingTabs?.billing;
    if (billing == null) return;
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

  ClientBillingAddonModel? _getAddon(String slug, String namePattern) {
    final addons = _clientPro.currentClientBillingTabs?.billing.addons;
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
      _clientPro.currentClientBillingTabs?.billing.phPortalWeekly ?? 345.40;

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

  double get _storageRate => _storageWeeklyPrice;
  double get _supportLineRate => _supportLineWeeklyPrice;
  double get _emailRate => _emailWeeklyPrice;

  double get _supportLineCost =>
      _supportLinesActive ? (_supportLinesQty * _supportLineWeeklyPrice) : 0.0;
  double get _storageCost =>
      _fileStorageActive ? (_fileStorageQty * _storageWeeklyPrice) : 0.0;
  double get _emailCost => _emailConnectionsActive
      ? (_emailConnectionsQty * _emailWeeklyPrice)
      : 0.0;
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
  int get _callsIncluded => _callsOutIncluded;
  int get _smsIncluded => _smsOutIncluded;
  int get _mmsIncluded => _mmsOutIncluded;
  double get _smsOverage => _smsOutOverage;
  double get _totalWeeklyCharge =>
      (_pricingMode == 'free' ? 0.0 : _phPortalWeekly) +
      _supportLineCost +
      _storageCost +
      _emailCost +
      _overageCost;

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

    final clientPro = _clientPro;
    ClientModel? client;
    try {
      client = clientPro.clients.firstWhere((c) => c.id == widget.clientId);
    } catch (_) {
      client = null;
    }

    final apiClient = clientPro.currentClientBillingTabs?.client;
    final companyName = apiClient?.companyName ?? client?.companyName ?? "Tron";
    final isClientActive = apiClient?.status ?? client?.status ?? true;
    final clientLogo = apiClient?.imageUrl ?? client?.logo ?? "";
    final clientType =
        apiClient?.companyType ?? client?.companyType ?? "Client Ltd";
    final clientSince = apiClient?.clientSince != null
        ? "Client since ${apiClient!.clientSince}"
        : client != null
        ? "Client since ${client.createdDate}"
        : "Client since May 20, 2026";

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // 1. Breadcrumbs / Header Bar
            _buildHeader(context, companyName, isClientActive, clientPro),

            // Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Client Profile Info Card
                    _buildClientProfileCard(
                      logo: clientLogo,
                      name: companyName,
                      isActive: isClientActive,
                      type: clientType,
                      since: clientSince,
                      weeklyCharge: _totalWeeklyCharge,
                    ),
                    const SizedBox(height: 12),

                    // 3. Tab Bar selector
                    _buildTabBar(),
                    const SizedBox(height: 12),

                    // 4. Tab Body
                    if (_activeTab == 0) ...[
                      // PH Portal Black Banner
                      _buildPHPortalBanner(
                        _overageCost,
                        phPortalWeekly: _phPortalWeekly,
                      ),
                      const SizedBox(height: 16),

                      // Usage & Configuration
                      _buildUsageConfigurationSection(
                        callsIncluded: _callsIncluded,
                        smsIncluded: _smsIncluded,
                        mmsIncluded: _mmsIncluded,
                        callsInRate: _callsInRate,
                        callsOutRate: _callsOutRate,
                        smsInRate: _smsInRate,
                        smsOutRate: _smsOutRate,
                        mmsInRate: _mmsInRate,
                        mmsOutRate: _mmsOutRate,
                        storageRate: _storageRate,
                        supportLineRate: _supportLineRate,
                        emailRate: _emailRate,
                        supportLinesIncluded: _supportLinesIncluded,
                        emailIncluded: _emailIncluded,
                      ),
                      const SizedBox(height: 12),

                      // Specialist Services Access
                      _buildSpecialistAccessSection(),
                      const SizedBox(height: 16),

                      // Add-ons Section
                      _buildAddonsSection(
                        _supportLineCost,
                        _storageCost,
                        _emailCost,
                        supportLineRate: _supportLineWeeklyPrice,
                        storageRate: _storageWeeklyPrice,
                        emailRate: _emailWeeklyPrice,
                      ),
                      const SizedBox(height: 16),

                      // Bottom Info warning banner
                      _buildInfoBanner(),
                      const SizedBox(height: 16),
                    ] else if (_activeTab == 1) ...[
                      if (_isWeekLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        const DiscountsCreditsTablet(),
                    ] else if (_activeTab == 2) ...[
                      if (_isWeekLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        const ReferralsTablet(),
                    ] else if (_activeTab == 3) ...[
                      if (_isWeekLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        _buildWeeklyVolumeTab(clientPro),
                    ] else if (_activeTab == 4) ...[
                      if (_isWeekLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFACC15),
                            ),
                          ),
                        )
                      else
                        _buildBillingTab(clientPro),
                    ] else ...[
                      // Placeholder if other tabs are clicked
                      _buildPlaceholderTab(),
                    ],
                  ],
                ),
              ),
            ),
            if (_activeTab == 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: _buildSaveRow(),
              ),
          ],
        ),
      ),
    );
  }

  // Header Row
  Widget _buildHeader(
    BuildContext context,
    String clientName,
    bool isActive,
    ClientPro pro,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.black,
            ),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  "Clients",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  " / ",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                Text(
                  clientName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  " / ",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                Text(
                  "Billing",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () =>
                _showToggleStatusDialog(context, clientName, isActive, pro),
            icon: const Icon(
              Icons.block_flipped,
              color: Color(0xFFEF4444),
              size: 16,
            ),
            label: Text(
              isActive ? "Deactivate" : "Activate",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Client Profile Info Card
  Widget _buildClientProfileCard({
    required String logo,
    required String name,
    required bool isActive,
    required String type,
    required String since,
    required double weeklyCharge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: logo.isNotEmpty
                  ? ImageWidget(image: logo, fit: BoxFit.cover)
                  : ImageWidget(image: Paths.user, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
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
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? const Color(0xFF22C55E)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? "Active" : "Inactive",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? const Color(0xFF15803D)
                                  : Colors.grey.shade700,
                            ),
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      since,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: Colors.grey.shade500,
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

  // Tab bar (horizontal list of pages)
  Widget _buildTabBar() {
    final tabs = [
      "Services",
      "Discounts & Credits",
      "My Referrals",
      "Weekly Volume",
      "Billing",
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? const Color(0xFFFACC15)
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? Colors.black : Colors.grey.shade500,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // PH Portal Banner component
  Widget _buildPHPortalBanner(
    double overages, {
    double phPortalWeekly = 345.40,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "PH PORTAL",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _updatePricingMode("free"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _pricingMode == "free"
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: _pricingMode == "free"
                                  ? Colors.white
                                  : Colors.white70,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Free w/ Pod",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: _pricingMode == "free"
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _pricingMode == "free"
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _pricingMode != "free"
                              ? const Color(0xFFFEF08A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "\$${phPortalWeekly.toStringAsFixed(2)}/wk",
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: _pricingMode != "free"
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _pricingMode != "free"
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
          Row(
            children: [
              Text(
                _clientPro
                            .currentClientBillingTabs
                            ?.billing
                            .twilioUsageSummary
                            .syncedDisplay
                            .isNotEmpty ==
                        true
                    ? "Last synced ${_clientPro.currentClientBillingTabs!.billing.twilioUsageSummary.syncedDisplay}"
                    : "Not synced yet",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                onPressed: () async {
                  setState(() => _isSyncing = true);
                  try {
                    final week = context
                        .read<ClientPro>()
                        .currentClientBillingTabs
                        ?.week;
                    final String startStr = week?.start ?? _selectedWeek;
                    final String endStr;
                    if (week != null && week.end.isNotEmpty) {
                      endStr = week.end;
                    } else {
                      final startDt = DateTime.parse(_selectedWeek);
                      final endDt = startDt.add(const Duration(days: 6));
                      endStr =
                          '${endDt.year}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}';
                    }
                    final success = await context.read<ClientPro>().syncUsage(
                      clientId: widget.clientId,
                      weekStart: startStr,
                      weekEnd: endStr,
                    );
                    if (success) {
                      await context.read<ClientPro>().getClientBillingTabs(
                        widget.clientId,
                        _selectedWeek,
                        showLoading: false,
                      );
                    }
                  } catch (_) {}
                  if (mounted) {
                    setState(() => _isSyncing = false);
                  }
                },
                icon: _isSyncing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      )
                    : const Icon(Icons.sync, color: Colors.white, size: 12),
                label: Text(
                  "Sync Usage",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "SERVICES THIS WEEK",
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                "\$${overages.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFDE047),
                ),
              ),
              Text(
                "add-ons + overages",
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Usage & Configuration
  Widget _buildUsageConfigurationSection({
    int callsIncluded = 5,
    int smsIncluded = 5,
    int mmsIncluded = 5,
    double callsInRate = 0.05,
    double callsOutRate = 0.07,
    double smsInRate = 0.01,
    double smsOutRate = 0.02,
    double mmsInRate = 0.05,
    double mmsOutRate = 0.10,
    double storageRate = 0.69,
    double supportLineRate = 0.69,
    double emailRate = 4.62,
    int supportLinesIncluded = 1,
    int emailIncluded = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Usage & Configuration",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${_clientPro.currentClientBillingTabs?.week.label ?? 'May 25-31, 2026'} - Admin only",
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              "Defaults from the ",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            GestureDetector(
              onTap: () {
                showToast(message: "Navigating to global services settings");
              },
              child: Text(
                "Services page",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ". Override overage settings per client here.",
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of Cards (3 cards per row on Tablet)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCallsCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildSMSCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildMMSCard()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStorageCard(storageRate: storageRate)),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSupportLinesCard(
                  supportLineRate: supportLineRate,
                  supportLinesIncluded: supportLinesIncluded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmailConnectionsCard(
                  emailRate: emailRate,
                  emailIncluded: emailIncluded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Card 1: Calls
  Widget _buildCallsCard() {
    final int inLimit = _callsInIncluded;
    final int outLimit = _callsOutIncluded;
    final bool inOverLimit = _callsIn > inLimit;
    final bool outOverLimit = _callsOut > outLimit;
    final bool isOver = inOverLimit || outOverLimit;

    final double inOverage = inOverLimit ? (_callsIn - inLimit) : 0.0;
    final double outOverage = outOverLimit ? (_callsOut - outLimit) : 0.0;
    final double overageCost =
        (inOverage * _callsInRate) + (outOverage * _callsOutRate);

    final double inProgress = (_callsIn / inLimit).clamp(0.0, 1.0);
    final double outProgress = (_callsOut / outLimit).clamp(0.0, 1.0);

    final String inLabel =
        "${_formatDouble(_callsIn)} / $inLimit min${inOverLimit ? ' +${_formatDouble(inOverage)}' : ''}";
    final String outLabel =
        "${_formatDouble(_callsOut)} / $outLimit min${outOverLimit ? ' +${_formatDouble(outOverage)}' : ''}";

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDirectionalRow(
            incoming: true,
            label: inLabel,
            progress: inProgress,
            isOverLimit: inOverLimit,
          ),
          const SizedBox(height: 10),
          _buildDirectionalRow(
            incoming: false,
            label: outLabel,
            progress: outProgress,
            isOverLimit: outOverLimit,
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text(
              "Over - est. \$${overageCost.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue:
          "\$${_callsInRate.toStringAsFixed(4)}/min\n\$${_callsOutRate.toStringAsFixed(4)}/min",
    );
  }

  // Card 2: SMS
  Widget _buildSMSCard() {
    final int inLimit = _smsInIncluded;
    final int outLimit = _smsOutIncluded;
    final bool inOverLimit = _smsIn > inLimit;
    final bool outOverLimit = _smsOut > outLimit;
    final bool isOver = inOverLimit || outOverLimit;

    final double inOverage = inOverLimit ? (_smsIn - inLimit) : 0.0;
    final double outOverage = outOverLimit ? (_smsOut - outLimit) : 0.0;
    final double overageCost =
        (inOverage * _smsInRate) + (outOverage * _smsOutRate);

    final double inProgress = (_smsIn / inLimit).clamp(0.0, 1.0);
    final double outProgress = (_smsOut / outLimit).clamp(0.0, 1.0);

    final String inLabel =
        "${_formatDouble(_smsIn)} / $inLimit${inOverLimit ? ' +${_formatDouble(inOverage)}' : ''}";
    final String outLabel =
        "${_formatDouble(_smsOut)} / $outLimit${outOverLimit ? ' +${_formatDouble(outOverage)}' : ''}";

    return _buildUsageCardWrapper(
      title: "SMS",
      icon: Icons.sms,
      iconColor: const Color(0xFFEF4444),
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
            label: inLabel,
            progress: inProgress,
            isOverLimit: inOverLimit,
          ),
          const SizedBox(height: 10),
          _buildDirectionalRow(
            incoming: false,
            label: outLabel,
            progress: outProgress,
            isOverLimit: outOverLimit,
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text(
              "Over - est. \$${overageCost.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue:
          "\$${_smsInRate.toStringAsFixed(4)}/msg\n\$${_smsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  // Card 3: MMS
  Widget _buildMMSCard() {
    final int inLimit = _mmsInIncluded;
    final int outLimit = _mmsOutIncluded;
    final bool inOverLimit = _mmsIn > inLimit;
    final bool outOverLimit = _mmsOut > outLimit;
    final bool isOver = inOverLimit || outOverLimit;

    final double inOverage = inOverLimit ? (_mmsIn - inLimit) : 0.0;
    final double outOverage = outOverLimit ? (_mmsOut - outLimit) : 0.0;
    final double overageCost =
        (inOverage * _mmsInRate) + (outOverage * _mmsOutRate);

    final double inProgress = (_mmsIn / inLimit).clamp(0.0, 1.0);
    final double outProgress = (_mmsOut / outLimit).clamp(0.0, 1.0);

    final String inLabel =
        "${_formatDouble(_mmsIn)} / $inLimit msg${inOverLimit ? ' +${_formatDouble(inOverage)}' : ''}";
    final String outLabel =
        "${_formatDouble(_mmsOut)} / $outLimit msg${outOverLimit ? ' +${_formatDouble(outOverage)}' : ''}";

    return _buildUsageCardWrapper(
      title: "MMS",
      icon: Icons.photo_library,
      iconColor: const Color(0xFFF59E0B),
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
            label: inLabel,
            progress: inProgress,
            isOverLimit: inOverLimit,
          ),
          const SizedBox(height: 10),
          _buildDirectionalRow(
            incoming: false,
            label: outLabel,
            progress: outProgress,
            isOverLimit: outOverLimit,
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text(
              "Over - est. \$${overageCost.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue:
          "\$${_mmsInRate.toStringAsFixed(4)}/msg\n\$${_mmsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  // Card 4: Storage
  Widget _buildStorageCard({double storageRate = 0.69}) {
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
        : storageRate;
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
              Text(
                usedDisplay,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  "of $includedDisplay included",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (usagePercent / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                usagePercent > 90
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2563EB),
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "$remainingDisplay remaining",
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
      overageLabel: "Overage",
      overageValue: overageEnabled ? "" : "",
      bottomLabel:
          "Rate: \$${overageRate.toStringAsFixed(2)}/block (per $blockSizeGb GB)",
    );
  }

  // Card 5: Support Lines
  Widget _buildSupportLinesCard({
    double supportLineRate = 0.69,
    int supportLinesIncluded = 1,
  }) {
    final details =
        _clientPro.currentClientBillingTabs?.billing.supportLinesDetails;
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$inUseCount",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  inUseCount == 1 ? "line in use" : "lines in use",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...numbers.map<Widget>((num) {
            final phone = (num['phone_number'] ?? '').toString();
            final isMain = num['is_main'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
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
                    const SizedBox(width: 6),
                    Text(
                      _formatPhoneNumber(phone),
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (isMain) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF08A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "MAIN",
                          style: GoogleFonts.poppins(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
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
    return raw; // fallback: return as-is
  }

  // Card 6: Email Connections
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "1",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  "email slots in use",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "sheenmonawdar@gmail.com",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomLabel:
          "Base plan includes $emailIncluded email slot${emailIncluded == 1 ? '' : 's'} · \$${emailRate.toStringAsFixed(2)}/wk per extra slot",
    );
  }

  // Usage Card structure Wrapper
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
    final bool isOver = badgeText == "Over";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOver ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOver ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: iconColor, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              body,
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (overageLabel != null && overageValue != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: overageLabel
                          .split('\n')
                          .map(
                            (l) => Text(
                              l,
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: overageValue
                          .split('\n')
                          .map(
                            (v) => Text(
                              v,
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Enabled",
                        style: GoogleFonts.poppins(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (bottomLabel != null) ...[
                const SizedBox(height: 8),
                if (overageLabel == null) ...[
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 8),
                ],
                Text(
                  bottomLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Helper row inside usage card
  Widget _buildDirectionalRow({
    required bool incoming,
    required String label,
    required double progress,
    required bool isOverLimit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              incoming ? Icons.arrow_downward : Icons.arrow_upward,
              size: 12,
              color: incoming
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 4),
            Text(
              incoming ? "in" : "out",
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isOverLimit ? const Color(0xFFEF4444) : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              isOverLimit ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // Specialist Services Access
  Widget _buildSpecialistAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Specialist Services Access",
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSpecialistAccessCard(
                title: "staff",
                icon: Icons.business_center,
                iconColor: Colors.blueGrey,
                value: _staffAccess,
                onChanged: (val) {
                  setState(() => _staffAccess = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSpecialistAccessCard(
                title: "Graphic Designer",
                icon: Icons.palette,
                iconColor: const Color(0xFF3B82F6),
                value: _graphicDesignerAccess,
                onChanged: (val) {
                  setState(() => _graphicDesignerAccess = val);
                },
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Transform.scale(
            scaleX: 0.7,
            scaleY: 0.7,
            child: Switch(
              value: value,
              activeTrackColor: const Color(0xFF00a650),
              activeThumbColor: Colors.white,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // Add-ons section
  Widget _buildAddonsSection(
    double supportLineCost,
    double storageCost,
    double emailCost, {
    double supportLineRate = 0.69,
    double storageRate = 0.69,
    double emailRate = 4.62,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Add-ons",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Admin only",
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(4.5), // Add-on details
              1: FlexColumnWidth(2.0), // Active toggle
              2: FlexColumnWidth(2.5), // Quantity
              3: FlexColumnWidth(2.0), // Cost
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                children: [
                  _buildTableHeaderCell(
                    "ADD-ON",
                    alignment: Alignment.centerLeft,
                  ),
                  _buildTableHeaderCell("ACTIVE", alignment: Alignment.center),
                  _buildTableHeaderCell("QTY", alignment: Alignment.center),
                  _buildTableHeaderCell(
                    "COST/WK",
                    alignment: Alignment.centerRight,
                    rightPadding: 14,
                  ),
                ],
              ),
              // Row 1: Support Lines
              TableRow(
                children: [
                  _buildAddonNameCell(
                    icon: Icons.headset_mic,
                    iconColor: const Color(0xFFF59E0B),
                    title: "Support Lines",
                    subtitle:
                        "\$${supportLineRate.toStringAsFixed(2)}/wk per extra phone number",
                  ),
                  TableCell(
                    child: Center(
                      child: Transform.scale(
                        scaleX: 0.7,
                        scaleY: 0.7,
                        child: Switch(
                          value: _supportLinesActive,
                          activeTrackColor: const Color(0xFF00a650),
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              _supportLinesActive = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: _buildQuantitySelector(
                      value: _supportLinesQty,
                      enabled: _supportLinesActive,
                      onChanged: (val) {
                        setState(() => _supportLinesQty = val);
                      },
                    ),
                  ),
                  _buildCostCell(supportLineCost),
                ],
              ),
              // Row 2: File Storage
              TableRow(
                children: [
                  _buildAddonNameCell(
                    icon: Icons.folder,
                    iconColor: const Color(0xFF3B82F6),
                    title: "File Storage",
                    subtitle:
                        "\$${storageRate.toStringAsFixed(2)}/wk per 500GB/wk",
                  ),
                  TableCell(
                    child: Center(
                      child: Transform.scale(
                        scaleX: 0.7,
                        scaleY: 0.7,
                        child: Switch(
                          value: _fileStorageActive,
                          activeTrackColor: const Color(0xFF00a650),
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              _fileStorageActive = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: _buildQuantitySelector(
                      value: _fileStorageQty,
                      enabled: _fileStorageActive,
                      onChanged: (val) {
                        setState(() => _fileStorageQty = val);
                      },
                    ),
                  ),
                  _buildCostCell(storageCost),
                ],
              ),
              // Row 3: Email Connections
              TableRow(
                children: [
                  _buildAddonNameCell(
                    icon: Icons.email,
                    iconColor: const Color(0xFF10B981),
                    title: "Email Connections",
                    subtitle:
                        "\$${emailRate.toStringAsFixed(2)}/wk per extra email slot",
                  ),
                  TableCell(
                    child: Center(
                      child: Transform.scale(
                        scaleX: 0.7,
                        scaleY: 0.7,
                        child: Switch(
                          value: _emailConnectionsActive,
                          activeTrackColor: const Color(0xFF00a650),
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              _emailConnectionsActive = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: _buildQuantitySelector(
                      value: _emailConnectionsQty,
                      enabled: _emailConnectionsActive,
                      onChanged: (val) {
                        setState(() => _emailConnectionsQty = val);
                      },
                    ),
                  ),
                  _buildCostCell(emailCost),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(
    String text, {
    Alignment alignment = Alignment.centerLeft,
    double rightPadding = 0,
  }) {
    return TableCell(
      child: Padding(
        padding: EdgeInsets.only(
          left: 10,
          top: 8,
          bottom: 8,
          right: rightPadding > 0 ? rightPadding : 10,
        ),
        child: Align(
          alignment: alignment,
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddonNameCell({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector({
    required int value,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 12),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: enabled ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 12),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostCell(double cost) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            "\$${cost.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cost > 0 ? Colors.black : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  // Info red banner
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Color(0xFFEF4444), size: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "To enable or modify any services, add new specialists, or adjust configuration settings, please contact your Pod Supervisor.",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Save button
  Widget _buildSaveRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        onPressed: _isSaving ? null : _handleSaveConfiguration,
        icon: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check, color: Colors.white, size: 14),
        label: Text(
          "Save Configuration",
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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
        await _fetchBillingTabs(isWeekChange: false);
      }
    }
  }

  Widget _buildWeeklyVolumeTab(ClientPro clientPro) {
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
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.chevron_left,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: _goToPreviousWeek,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientPro.currentClientBillingTabs?.week.label ??
                          "May 25-31, 2026",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "${clientPro.currentClientBillingTabs?.week.isCurrent == true ? 'Current week' : 'Previous week'}  Wholesale & Retail from Printobi",
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: _goToNextWeek,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                disabledBackgroundColor: const Color(
                  0xFF10B981,
                ).withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                size: 14,
                color: (isAnySpecialistEnabled && !_isWeekClosed)
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
              ),
              label: Text(
                "Add Entry",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: (isAnySpecialistEnabled && !_isWeekClosed)
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!isAnySpecialistEnabled) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "Enable at least one Specialist Services Access toggle before adding entries.",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],

        // 2. Summary Cards Grid
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "ORDERS THIS WEEK",
                  value:
                      clientPro
                          .currentClientBillingTabs
                          ?.weeklyVolume
                          .summary
                          .ordersThisWeek
                          .toString() ??
                      "0",
                  subtitle: "Logged by admin",
                  topBorderColor: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "JOBS THIS WEEK",
                  value:
                      clientPro
                          .currentClientBillingTabs
                          ?.weeklyVolume
                          .summary
                          .jobsThisWeek
                          .toString() ??
                      "0",
                  subtitle: "Logged by admin",
                  topBorderColor: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "SPECIALISTS INVOLVED",
                  value:
                      clientPro
                          .currentClientBillingTabs
                          ?.weeklyVolume
                          .summary
                          .specialistsInvolved
                          .toString() ??
                      "0",
                  subtitle: "Marked involvement",
                  topBorderColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Order & Job Log
        _buildOrderJobLog(clientPro),
        const SizedBox(height: 10),

        // 4. Week Charge Breakdown
        _buildWeekChargeBreakdown(clientPro),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, width: double.infinity, color: topBorderColor),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderJobLog(ClientPro clientPro) {
    final weeklyVolume = clientPro.currentClientBillingTabs?.weeklyVolume;
    final pagination = weeklyVolume?.pagination ?? {};
    final totalPages = int.tryParse((pagination['last_page'] ?? pagination['lastPage'] ?? 1).toString()) ?? 1;
    final totalEntries = int.tryParse((pagination['total'] ?? 0).toString()) ?? 0;
    final from = int.tryParse((pagination['from'] ?? 0).toString()) ?? 0;
    final to = int.tryParse((pagination['to'] ?? 0).toString()) ?? 0;
    final currentEntries = weeklyVolume?.entries ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Wholesale & Retail Log",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  _buildFilterDropdown(
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
                  const SizedBox(width: 6),
                  _buildFilterDropdown(
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
          const SizedBox(height: 10),
          _buildOrderLogTable(currentEntries),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalEntries == 0
                    ? "No entries match this view"
                    : "Showing $from-$to of $totalEntries entries",
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  color: Colors.grey.shade500,
                ),
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      elevation: 4,
      itemBuilder: (context) => items.map((item) {
        final isSelected = item == value;
        return PopupMenuItem<String>(
          value: item,
          height: 36,
          child: Text(
            item,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.black87,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
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
    if (totalPages <= 7) {
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

    return Row(
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
        const SizedBox(width: 8),
        ...pages.map((p) {
          if (p == -1) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                "...",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }
          final bool isActive = p == currentPage;
          return GestureDetector(
            onTap: () => onPageChanged(p),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFACC15) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Center(
                child: Text(
                  "$p",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isActive ? Colors.black : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
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
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
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
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              "No entries for this week",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
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
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _buildOrderLogRow(
    String date,
    String pricingMode,
    String orderNo,
    String jobNo,
  ) {
    bool isWholesale = pricingMode.toLowerCase() == "wholesale";
    String displayType = pricingMode.isNotEmpty
        ? (pricingMode[0].toUpperCase() +
              pricingMode.substring(1).toLowerCase())
        : pricingMode;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isWholesale
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayType,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isWholesale
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFD97706),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              orderNo,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              jobNo,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "No specialist marked yet",
              style: GoogleFonts.poppins(
                fontSize: 11,
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const ImageWidget(
                        image: Paths.delete,
                        color: Color(0xFFEF4444),
                        width: 12,
                        height: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekChargeBreakdown(ClientPro clientPro) {
    final weekChargeBreakdown = clientPro.currentClientBillingTabs?.weeklyVolume.weekChargeBreakdown;
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
      totalChargeWithExtras = (clientPro.currentClientBillingTabs?.weeklyVolume.summary.thisWeekCharge ?? 0.0) + extraChargesSum;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WEEK CHARGE BREAKDOWN",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 6),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 6),

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
              "The Pod - Orders",
              "${clientPro.currentClientBillingTabs?.weeklyVolume.summary.ordersThisWeek ?? 0}",
              "\$40.00",
              "\$${((clientPro.currentClientBillingTabs?.weeklyVolume.summary.ordersThisWeek ?? 0) * 40.0).toStringAsFixed(2)}",
            ),
            _buildChargeRow(
              "The Pod - Jobs",
              "${clientPro.currentClientBillingTabs?.weeklyVolume.summary.jobsThisWeek ?? 0}",
              "\$40.00",
              "\$${((clientPro.currentClientBillingTabs?.weeklyVolume.summary.jobsThisWeek ?? 0) * 40.0).toStringAsFixed(2)}",
            ),
            _buildChargeRow(
              "PH Portal",
              "—",
              "\$${_phPortalWeekly.toStringAsFixed(2)}/wk",
              "\$${_phPortalWeekly.toStringAsFixed(2)}",
              amountColor: const Color(0xFF10B981),
            ),
            _buildChargeRow(
              "Support Lines",
              "$_supportLinesQty",
              "\$${_supportLineWeeklyPrice.toStringAsFixed(2)}/per extra phone number",
              "\$${_supportLineCost.toStringAsFixed(2)}",
            ),
            _buildChargeRow(
              "File Storage",
              "$_fileStorageQty",
              "\$${_storageWeeklyPrice.toStringAsFixed(2)}/per 500GB/wk",
              "\$${_storageCost.toStringAsFixed(2)}",
            ),
            _buildChargeRow(
              "Email Connections",
              "$_emailConnectionsQty",
              "\$${_emailWeeklyPrice.toStringAsFixed(2)}/per extra email slot",
              "\$${_emailCost.toStringAsFixed(2)}",
            ),
            _buildChargeRow(
              "SMS Overage",
              _smsOut > _smsIncluded ? "${_smsOut - _smsIncluded}" : "0",
              "\$${_smsOutRate.toStringAsFixed(2)}",
              "\$${_smsOverage.toStringAsFixed(2)}",
              amountColor: const Color(0xFFEF4444),
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _isWeekClosed ? Colors.grey.shade200 : Colors.grey.shade300,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
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
                size: 12,
                color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              label: Text(
                "Add Extra Charge",
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ),

          ..._extraCharges.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              key: ObjectKey(item),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: item.descController,
                        readOnly: _isWeekClosed,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _isWeekClosed ? Colors.grey.shade600 : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Description",
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 30),
                  SizedBox(
                    width: 110,
                    height: 38,
                    child: TextField(
                      controller: item.amountController,
                      readOnly: _isWeekClosed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isWeekClosed ? Colors.grey.shade600 : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 30),
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
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isWeekClosed ? Colors.grey.shade100 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: ImageWidget(
                          image: Paths.delete,
                          color: _isWeekClosed ? Colors.grey.shade400 : const Color(0xFFEF4444),
                          width: 18,
                          height: 18,
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

          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Week Total",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                "\$${totalChargeWithExtras.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: _isWeekClosed ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                label: Text(
                  _isSaving ? "Saving..." : "Save Changes",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isWeekClosed ? Colors.grey.shade400 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  disabledBackgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                  size: 14,
                  color: _isWeekClosed ? Colors.black38 : Colors.black,
                ),
                label: Text(
                  _isWeekClosed ? "Week Closed" : "Close Week & Record Charge",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
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

  String _getUnitSuffix(String key) {
    switch (key) {
      case 'support_lines':
        return '/per extra phone number';
      case 'extra_storage':
        return '/per 500GB/wk';
      case 'extra_emails':
        return '/per extra email slot';
      case 'incoming_call_minutes':
      case 'outgoing_call_minutes':
        return '/per extra minute';
      case 'incoming_sms':
      case 'outgoing_sms':
        return '/per extra SMS';
      case 'incoming_mms':
      case 'outgoing_mms':
        return '/per extra MMS';
      default:
        return '';
    }
  }

  Widget _buildChargeRow(
    String label,
    String qty,
    String unitPrice,
    String amount, {
    Color? amountColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.center,
              child: Text(
                qty,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                unitPrice,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                amount,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: amountColor ?? Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab() {
    return Container(
      height: 300,
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        "Sub-tab content is coming soon",
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildBillingTab(ClientPro clientPro) {
    final invoiceHistory = clientPro.currentClientBillingTabs?.billing.invoiceHistory ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              "INVOICE HISTORY",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 960,
              child: Column(
                children: [
                  // Header
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                          flex: 3,
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
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          "No invoice history yet",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFACC15),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "Yellow = closed but not yet paid",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey.shade600,
                  ),
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

    final rowBg = (isClosed && !isPaid) ? const Color(0xFFFFFBEB) : Colors.white;

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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Week
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.weekLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                if (inv.isCurrent) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Current",
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Orders
          Expanded(
            flex: 2,
            child: Text(
              inv.orders.toString(),
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black87),
            ),
          ),
          // Jobs
          Expanded(
            flex: 2,
            child: Text(
              inv.jobs.toString(),
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black87),
            ),
          ),
          // POD
          Expanded(
            flex: 2,
            child: Text(
              fmt(inv.pod),
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black87),
            ),
          ),
          // Add-ons (blue)
          Expanded(
            flex: 2,
            child: Text(
              inv.addons > 0 ? "\$${inv.addons.toStringAsFixed(2)}" : "-",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: inv.addons > 0 ? const Color(0xFF2563EB) : Colors.grey.shade400,
              ),
            ),
          ),
          // Extras
          Expanded(
            flex: 2,
            child: Text(
              inv.extras > 0 ? fmt(inv.extras) : "-",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: inv.extras > 0 ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
          // Credit (red)
          Expanded(
            flex: 2,
            child: Text(
              inv.credit > 0 ? fmtCredit(inv.credit) : "-",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: inv.credit > 0 ? const Color(0xFFEF4444) : Colors.grey.shade400,
              ),
            ),
          ),
          // Total
          Expanded(
            flex: 2,
            child: Text(
              fmt(inv.total),
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                children: [
                  // Invoice button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {},
                    icon: Icon(Icons.receipt_long_outlined, size: 11, color: Colors.grey.shade600),
                    label: Text(
                      "Invoice",
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  // Mark Paid (only for closed-not-paid)
                  if (isClosed && !isPaid) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {},
                      child: Text(
                        "Mark Paid",
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),         // Row
              ),         // FittedBox
            ),           // Align
          ),             // Expanded
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
        title: Text(
          isActive ? "Deactivate Client" : "Activate Client",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          "Are you sure you want to ${isActive ? 'deactivate' : 'activate'} $clientName?",
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
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
            child: Text(
              "Confirm",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
