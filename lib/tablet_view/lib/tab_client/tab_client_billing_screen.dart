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
  bool _isSaving = false;
  bool _isSyncing = false;

  int _callsIn = 0;
  int _callsOut = 3;

  int _smsIn = 0;
  int _smsOut = 6;

  int _mmsIn = 0;
  int _mmsOut = 1;

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

  @override
  Widget build(BuildContext context) {
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

    // Weekly charge calculations (hardcoded until client billing API is connected)
    const double phPortalWeekly       = 345.40;
    const double supportLineWeeklyPrice = 0.69;
    const double storageWeeklyPrice     = 0.69;
    const double emailWeeklyPrice       = 4.62;
    const int    supportLinesIncluded   = 1;
    const int    emailIncluded          = 0;
    const int    callsIncluded          = 5;
    const int    smsIncluded            = 5;
    const int    mmsIncluded            = 5;
    const double callsInRate            = 0.05;
    const double callsOutRate           = 0.07;
    const double smsInRate              = 0.01;
    const double smsOutRate             = 0.02;
    const double mmsInRate              = 0.05;
    const double mmsOutRate             = 0.10;
    const double storageRate            = storageWeeklyPrice;
    const double supportLineRate        = supportLineWeeklyPrice;
    const double emailRate              = emailWeeklyPrice;

    final double supportLineCost = _supportLinesActive ? (_supportLinesQty * supportLineWeeklyPrice) : 0.0;
    final double storageCost     = _fileStorageActive  ? (_fileStorageQty  * storageWeeklyPrice)     : 0.0;
    final double emailCost       = _emailConnectionsActive ? (_emailConnectionsQty * emailWeeklyPrice) : 0.0;
    final double smsOverage      = _smsOut > smsIncluded
        ? ((_smsOut - smsIncluded) * smsOutRate)
        : 0.0;
    final double overageCost     = smsOverage;
    final double totalWeeklyCharge = phPortalWeekly + supportLineCost + storageCost + emailCost + overageCost;

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
                      weeklyCharge: totalWeeklyCharge,
                    ),
                    const SizedBox(height: 12),

                    // 3. Tab Bar selector
                    _buildTabBar(),
                    const SizedBox(height: 12),

                    // 4. Tab Body
                    if (_activeTab == 0) ...[
                      // PH Portal Black Banner
                      _buildPHPortalBanner(
                        overageCost,
                        phPortalWeekly: phPortalWeekly,
                      ),
                      const SizedBox(height: 16),

                      // Usage & Configuration
                      _buildUsageConfigurationSection(
                        callsIncluded: callsIncluded,
                        smsIncluded: smsIncluded,
                        mmsIncluded: mmsIncluded,
                        callsInRate: callsInRate,
                        callsOutRate: callsOutRate,
                        smsInRate: smsInRate,
                        smsOutRate: smsOutRate,
                        mmsInRate: mmsInRate,
                        mmsOutRate: mmsOutRate,
                        storageRate: storageRate,
                        supportLineRate: supportLineRate,
                        emailRate: emailRate,
                        supportLinesIncluded: supportLinesIncluded,
                        emailIncluded: emailIncluded,
                      ),
                      const SizedBox(height: 12),

                      // Specialist Services Access
                      _buildSpecialistAccessSection(),
                      const SizedBox(height: 16),

                      // Add-ons Section
                      _buildAddonsSection(
                        supportLineCost,
                        storageCost,
                        emailCost,
                        supportLineRate: supportLineWeeklyPrice,
                        storageRate: storageWeeklyPrice,
                        emailRate: emailWeeklyPrice,
                      ),
                      const SizedBox(height: 16),

                      // Bottom Info warning banner
                      _buildInfoBanner(),
                      const SizedBox(height: 16),

                      // Save button
                      _buildSaveRow(),
                      const SizedBox(height: 16),
                    ] else if (_activeTab == 1) ...[
                      const DiscountsCreditsTablet(),
                    ] else if (_activeTab == 2) ...[
                      const ReferralsTablet(),
                    ] else if (_activeTab == 3) ...[
                      _buildWeeklyVolumeTab(),
                    ] else if (_activeTab == 4) ...[
                      _buildBillingTab(),
                    ] else ...[
                      // Placeholder if other tabs are clicked
                      _buildPlaceholderTab(),
                    ],
                  ],
                ),
              ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "\$${weeklyCharge.toStringAsFixed(2)}/wk",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "THIS WEEK'S CHARGE",
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                    letterSpacing: 0.5,
                  ),
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
  Widget _buildPHPortalBanner(double overages, {double phPortalWeekly = 345.40}) {
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tablet_mac,
                      color: Colors.white70,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Free w/ Pod",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF08A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "\$${phPortalWeekly.toStringAsFixed(2)}/wk",
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                "Last synced today 8:14 AM",
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
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) {
                    setState(() {
                      _isSyncing = false;
                      _smsOut = 6; // Reset/sync mockup
                      _callsOut = 3;
                    });
                    showToast(message: "Usage synced successfully");
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
                  fontSize: 8,
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
              "May 25-31, 2026 - Admin only",
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
              Expanded(child: _buildCallsCard(included: callsIncluded, callsInRate: callsInRate, callsOutRate: callsOutRate)),
              const SizedBox(width: 12),
              Expanded(child: _buildSMSCard(included: smsIncluded, smsInRate: smsInRate, smsOutRate: smsOutRate)),
              const SizedBox(width: 12),
              Expanded(child: _buildMMSCard(included: mmsIncluded, mmsInRate: mmsInRate, mmsOutRate: mmsOutRate)),
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
              Expanded(child: _buildSupportLinesCard(supportLineRate: supportLineRate, supportLinesIncluded: supportLinesIncluded)),
              const SizedBox(width: 12),
              Expanded(child: _buildEmailConnectionsCard(emailRate: emailRate, emailIncluded: emailIncluded)),
            ],
          ),
        ),
      ],
    );
  }

  // Card 1: Calls
  Widget _buildCallsCard({int included = 5, double callsInRate = 0.05, double callsOutRate = 0.07}) {
    double progress = (_callsOut / included).clamp(0.0, 1.0);
    return _buildUsageCardWrapper(
      title: "Calls",
      icon: Icons.call,
      iconColor: const Color(0xFF2563EB),
      badgeText: "On track",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        children: [
          _buildDirectionalRow(
            incoming: true,
            label: "$_callsIn / $included min",
          ),
          const SizedBox(height: 4),
          _buildDirectionalRow(
            incoming: false,
            label: "$_callsOut / $included min",
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
              minHeight: 4,
            ),
          ),
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue: "\$${callsInRate.toStringAsFixed(4)}/min\n\$${callsOutRate.toStringAsFixed(4)}/min",
    );
  }

  // Card 2: SMS
  Widget _buildSMSCard({int included = 5, double smsInRate = 0.01, double smsOutRate = 0.02}) {
    double progress = (_smsOut / included).clamp(0.0, 1.0);
    bool isOver = _smsOut > included;
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
          _buildDirectionalRow(incoming: true, label: "$_smsIn / $included"),
          const SizedBox(height: 4),
          _buildDirectionalRow(
            incoming: false,
            label: "$_smsOut / $included +${_smsOut - included}",
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              ),
              minHeight: 4,
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 4),
            Text(
              "Over - est. \$0.02",
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue: "\$${smsInRate.toStringAsFixed(4)}/msg\n\$${smsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  // Card 3: MMS
  Widget _buildMMSCard({int included = 5, double mmsInRate = 0.05, double mmsOutRate = 0.10}) {
    double progress = (_mmsOut / included).clamp(0.0, 1.0);
    return _buildUsageCardWrapper(
      title: "MMS",
      icon: Icons.photo_library,
      iconColor: const Color(0xFFF59E0B),
      badgeText: "On track",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        children: [
          _buildDirectionalRow(incoming: true, label: "$_mmsIn / $included msg"),
          const SizedBox(height: 4),
          _buildDirectionalRow(
            incoming: false,
            label: "$_mmsOut / $included msg",
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
              minHeight: 4,
            ),
          ),
        ],
      ),
      overageLabel: "In rate\nOut rate",
      overageValue: "\$${mmsInRate.toStringAsFixed(4)}/msg\n\$${mmsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  // Card 4: Storage
  Widget _buildStorageCard({double storageRate = 0.69}) {
    return _buildUsageCardWrapper(
      title: "Storage",
      icon: Icons.folder,
      iconColor: const Color(0xFF8B5CF6),
      badgeText: "0% used",
      badgeColor: const Color(0xFFDCFCE7),
      badgeTextColor: const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "0.08 MB",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "–",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.0,
              backgroundColor: Colors.grey.shade200,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "No included storage configured in Settings",
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
      overageLabel: "Rate",
      overageValue: "\$${storageRate.toStringAsFixed(2)}/block (per 500 GB)",
    );
  }

  // Card 5: Support Lines
  Widget _buildSupportLinesCard({double supportLineRate = 0.69, int supportLinesIncluded = 1}) {
    return _buildUsageCardWrapper(
      title: "Support Lines",
      icon: Icons.headset_mic,
      iconColor: const Color(0xFF10B981),
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
                  "lines in use",
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
                  "+1 (323) 402-6244",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
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
            ),
          ),
        ],
      ),
      bottomLabel: "Plan includes $supportLinesIncluded line${supportLinesIncluded == 1 ? '' : 's'} - \$${supportLineRate.toStringAsFixed(2)}/wk per extra line",
    );
  }

  // Card 6: Email Connections
  Widget _buildEmailConnectionsCard({double emailRate = 4.62, int emailIncluded = 0}) {
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
      bottomLabel: "Base plan includes $emailIncluded email slot${emailIncluded == 1 ? '' : 's'} - \$${emailRate.toStringAsFixed(2)}/wk per extra slot",
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              ] else if (bottomLabel != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),
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
  Widget _buildDirectionalRow({required bool incoming, required String label}) {
    return Row(
      children: [
        Icon(
          incoming ? Icons.arrow_downward : Icons.arrow_upward,
          size: 12,
          color: incoming ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
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
            color: Colors.black,
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
                  _buildTableHeaderCell("ADD-ON", alignment: Alignment.centerLeft),
                  _buildTableHeaderCell("ACTIVE", alignment: Alignment.center),
                  _buildTableHeaderCell("QTY", alignment: Alignment.center),
                  _buildTableHeaderCell("COST/WK", alignment: Alignment.centerRight, rightPadding: 14),
                ],
              ),
              // Row 1: Support Lines
              TableRow(
                children: [
                  _buildAddonNameCell(
                    icon: Icons.headset_mic,
                    iconColor: const Color(0xFFF59E0B),
                    title: "Support Lines",
                    subtitle: "\$${supportLineRate.toStringAsFixed(2)}/wk per extra phone number",
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
                    subtitle: "\$${storageRate.toStringAsFixed(2)}/wk per 500GB/wk",
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
                    subtitle: "\$${emailRate.toStringAsFixed(2)}/wk per extra email slot",
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
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isSaving = false);
      showToast(message: "Configuration saved successfully");
    }
  }

  Widget _buildWeeklyVolumeTab() {
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
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "May 25-31, 2026",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      "Current week  Orders & Jobs from Printobi",
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
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: Text(
                "Add Entry",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. Summary Cards Grid
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "WHOLESALE THIS WEEK",
                  value: "102",
                  subtitle: "Logged by admin",
                  topBorderColor: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "RETAIL THIS WEEK",
                  value: "1",
                  subtitle: "Logged by admin",
                  topBorderColor: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVolumeSummaryCard(
                  title: "SPECIALISTS INVOLVED",
                  value: "0",
                  subtitle: "Marked involvement",
                  topBorderColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Order & Job Log
        _buildOrderJobLog(),
        const SizedBox(height: 10),

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

  Widget _buildOrderJobLog() {
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
                "Order & Job Log",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Row(
                children: [
                  _buildDropdown("All types"),
                  const SizedBox(width: 6),
                  _buildDropdown("All days"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildOrderLogTable(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Showing 1-10 of 103 filtered entries (103 this week)",
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  color: Colors.grey.shade500,
                ),
              ),
              _buildPagination(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(
            hint,
            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.black87),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      children: [
        _buildPaginationButton(Icons.chevron_left, false),
        _buildPaginationNumber("1", true),
        _buildPaginationNumber("2", false),
        _buildPaginationNumber("3", false),
        _buildPaginationNumber("4", false),
        _buildPaginationNumber("5", false),
        _buildPaginationButton(Icons.chevron_right, false),
      ],
    );
  }

  Widget _buildPaginationButton(IconData icon, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFBBF24) : Colors.white,
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 12,
          color: isActive ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildPaginationNumber(String number, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFBBF24) : Colors.white,
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          number,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderLogTable() {
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
        _buildOrderLogRow("05/25/2026", "Wholesale", "#234", "1"),
        _buildOrderLogRow("05/25/2026", "Retail", "#235", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#234", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "2"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "3"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "4"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "5"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "6"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "7"),
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
    String type,
    String orderNo,
    String jobNo,
  ) {
    bool isWholesale = type == "Wholesale";
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
                  type,
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
              child: Container(
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

  Widget _buildWeekChargeBreakdown() {
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
          _buildChargeRow("The Pod - Orders", "102", "\$40.00", "\$4080.00"),
          _buildChargeRow("The Pod - Jobs", "1", "\$40.00", "\$40.00"),
          _buildChargeRow(
            "PH Portal",
            "—",
            "\$345.40/wk",
            "\$345.40",
            amountColor: const Color(0xFF10B981),
          ),
          _buildChargeRow(
            "Support Lines",
            "0",
            "\$0.69/per extra phone number",
            "\$0.00",
          ),
          _buildChargeRow("File Storage", "0", "\$0.69/per 500GB/wk", "\$0.00"),
          _buildChargeRow(
            "Email Connections",
            "0",
            "\$4.62/per extra email slot",
            "\$0.00",
          ),
          _buildChargeRow(
            "SMS Overage",
            "1",
            "\$0.02",
            "\$0.02",
            amountColor: const Color(0xFFEF4444),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              onPressed: () {},
              icon: Icon(Icons.add, size: 12, color: Colors.grey.shade600),
              label: Text(
                "Add Extra Charge",
                style: GoogleFonts.poppins(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),

          _buildChargeRow(
            "Credits Applied",
            "",
            "",
            "\$0.00",
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
                "\$4465.42",
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
                onPressed: () {},
                icon: Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
                label: Text(
                  "Save Changes",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.lock, size: 14, color: Colors.black),
                label: Text(
                  "Close Week & Record Charge",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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

  Widget _buildBillingTab() {
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
              width: 900,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
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
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildTableHeader("ACTIONS"),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "May 25–31",
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Current",
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "102",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "1",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "\$345.40",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "\$21.69",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "—",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "—",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            "\$4487.09",
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF9C3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Open",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF854D0E),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "—",
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade400,
                              ),
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
