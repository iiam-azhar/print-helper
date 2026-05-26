import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/constants/paths.dart';
import 'package:print_helper/models/client_models.dart';
import 'package:print_helper/widgets/image_widget.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:print_helper/widgets/toasts.dart';
import 'package:print_helper/admin/client/discounts_credits_mobile.dart';
import 'package:print_helper/admin/client/referrals_mobile.dart';

class ClientBillingScreen extends StatefulWidget {
  final int clientId;

  const ClientBillingScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientBillingScreen> createState() => _ClientBillingScreenState();
}

class _ClientBillingScreenState extends State<ClientBillingScreen> {
  int _activeTab = 4; // default is Billing tab (index 4)
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
    final clientSince = client != null ? "Client since ${client.createdDate}" : "Client since May 20, 2026";

    // Weekly charge calculations (hardcoded until client billing API is connected)
    const double phPortalWeekly        = 345.40;
    const double supportLineWeeklyPrice = 0.69;
    const double storageWeeklyPrice     = 0.69;
    const double emailWeeklyPrice       = 4.62;
    const int    smsIncluded            = 5;
    const double smsOutRate             = 0.02;

    final double supportLineCost = _supportLinesActive ? (_supportLinesQty * supportLineWeeklyPrice) : 0.0;
    final double storageCost     = _fileStorageActive  ? (_fileStorageQty  * storageWeeklyPrice)     : 0.0;
    final double emailCost       = _emailConnectionsActive ? (_emailConnectionsQty * emailWeeklyPrice) : 0.0;
    final double smsOverage      = _smsOut > smsIncluded ? ((_smsOut - smsIncluded) * smsOutRate) : 0.0;
    final double overageCost     = smsOverage;
    final double totalWeeklyCharge = phPortalWeekly + supportLineCost + storageCost + emailCost + overageCost;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildAppBar(context, companyName, isClientActive, clientPro),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
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
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PH Portal Black Banner
                      _buildPHPortalBanner(overageCost, phPortalWeekly: phPortalWeekly),
                      SizedBox(height: 20.h),

                      // Usage & Configuration Header
                      _buildSectionHeader(
                        title: "Usage & Configuration",
                        subtitle: "May 25-31, 2026 - Admin only",
                      ),
                      SizedBox(height: 4.h),
                      _buildOverageInfoText(),
                      SizedBox(height: 16.h),

                      // Usage Cards (Stacked vertically on mobile)
                      _buildCallsCard(
                        included: 5,
                        callsInRate: 0.05,
                        callsOutRate: 0.07,
                      ),
                      SizedBox(height: 14.h),
                      _buildSMSCard(
                        included: 5,
                        smsInRate: 0.01,
                        smsOutRate: 0.02,
                      ),
                      SizedBox(height: 14.h),
                      _buildMMSCard(
                        included: 5,
                        mmsInRate: 0.05,
                        mmsOutRate: 0.10,
                      ),
                      SizedBox(height: 14.h),
                      _buildStorageCard(),
                      SizedBox(height: 14.h),
                      _buildSupportLinesCard(),
                      SizedBox(height: 14.h),
                      _buildEmailConnectionsCard(),
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
                      _buildAddonsSection(supportLineCost, storageCost, emailCost),
                      SizedBox(height: 20.h),

                      // Bottom Info Warning Banner
                      _buildInfoBanner(),
                      SizedBox(height: 24.h),

                      // Save button
                      _buildSaveButton(),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ] else if (_activeTab == 1) ...[
                const DiscountsCreditsMobile(),
              ] else if (_activeTab == 2) ...[
                const ReferralsMobile(),
              ] else if (_activeTab == 3) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: _buildWeeklyVolumeTab(),
                ),
              ] else if (_activeTab == 4) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
    );
  }

  // Mobile Appbar
  AppBar _buildAppBar(BuildContext context, String clientName, bool isActive, ClientPro pro) {
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
          icon: const Icon(Icons.block_flipped, color: Color(0xFFEF4444), size: 20),
          onPressed: () => _showToggleStatusDialog(context, clientName, isActive, pro),
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
                    isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                    isActive ? const Color(0xFF15803D) : Colors.grey.shade700,
                  ),
                  SizedBox(width: 6.w),
                  _chip(
                    type,
                    const Color(0xFFEFF6FF),
                    const Color(0xFF2563EB),
                  ),
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
    final tabs = ["Services", "Discounts & Credits", "My Referrals", "Weekly Volume", "Billing"];
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
                      color: isActive ? const Color(0xFFFACC15) : Colors.transparent,
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
  Widget _buildPHPortalBanner(double overages, {double phPortalWeekly = 345.40}) {
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      "Free w/ Pod",
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      "\$${phPortalWeekly.toStringAsFixed(2)}/wk",
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Synced: today 8:14 AM",
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: Colors.grey.shade400,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  setState(() => _isSyncing = true);
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) {
                    setState(() => _isSyncing = false);
                    showToast(message: "Synced");
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
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

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Row(
      children: [
        TextWidget(
          text: title,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
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
          _buildDirectionalRow(incoming: true, label: "$_callsIn / $included min"),
          SizedBox(height: 6.h),
          _buildDirectionalRow(incoming: false, label: "$_callsOut / $included min"),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
              minHeight: 5.h,
            ),
          ),
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue: "\$${callsInRate.toStringAsFixed(4)} / \$${callsOutRate.toStringAsFixed(4)}/min",
    );
  }

  Widget _buildSMSCard({int included = 5, double smsInRate = 0.01, double smsOutRate = 0.02}) {
    double progress = (_smsOut / included).clamp(0.0, 1.0);
    bool isOver = _smsOut > included;
    return _buildUsageCardWrapper(
      title: "SMS",
      icon: Icons.sms,
      iconColor: const Color(0xFFEF4444),
      badgeText: isOver ? "Over" : "On track",
      badgeColor: isOver ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
      badgeTextColor: isOver ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDirectionalRow(incoming: true, label: "$_smsIn / $included"),
          SizedBox(height: 6.h),
          _buildDirectionalRow(incoming: false, label: "$_smsOut / $included +${_smsOut - included}"),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(isOver ? const Color(0xFFEF4444) : const Color(0xFF2563EB)),
              minHeight: 5.h,
            ),
          ),
          if (isOver) ...[
            SizedBox(height: 4.h),
            TextWidget(
              text: "Over - est. \$0.02",
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEF4444),
            ),
          ],
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue: "\$${smsInRate.toStringAsFixed(4)} / \$${smsOutRate.toStringAsFixed(4)}/msg",
    );
  }

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
          SizedBox(height: 6.h),
          _buildDirectionalRow(incoming: false, label: "$_mmsOut / $included msg"),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
              minHeight: 5.h,
            ),
          ),
        ],
      ),
      overageLabel: "In/Out rates",
      overageValue: "\$${mmsInRate.toStringAsFixed(4)} / \$${mmsOutRate.toStringAsFixed(4)}/msg",
    );
  }

  Widget _buildStorageCard() {
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
              TextWidget(
                text: "0.08 MB",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(width: 4.w),
              TextWidget(
                text: "–",
                fontSize: 14.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: 0.0,
              backgroundColor: Colors.grey.shade200,
              minHeight: 5.h,
            ),
          ),
          SizedBox(height: 6.h),
          TextWidget(
            text: "No storage configured",
            fontSize: 10.sp,
            fontWeight: FontWeight.normal,
            color: Colors.grey.shade500,
          ),
        ],
      ),
      overageLabel: "Rate",
      overageValue: "\$0.69/block (per 500 GB)",
    );
  }

  Widget _buildSupportLinesCard() {
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
            children: [
              TextWidget(
                text: "1",
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(width: 4.w),
              TextWidget(
                text: "line in use",
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextWidget(
                  text: "+1 (323) 402-6244",
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
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
            ),
          ),
        ],
      ),
      bottomLabel: "Plan: 1 line - \$0.69/wk per extra",
    );
  }

  Widget _buildEmailConnectionsCard() {
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
      bottomLabel: "Base plan: 2 slots - \$4.62/wk extra",
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
          ] else if (bottomLabel != null) ...[
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
        TextWidget(
          text: label,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
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
  Widget _buildAddonsSection(double supportLineCost, double storageCost, double emailCost) {
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
          onActiveChanged: (val) => setState(() => _emailConnectionsActive = val),
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
                    onPressed: isActive && qty > 0 ? () => onQtyChanged(qty - 1) : null,
                    icon: const Icon(Icons.remove, size: 12),
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
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
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
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
              text: "To enable or modify any services, add new specialists, or adjust configuration settings, please contact your Pod Supervisor.",
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
                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isSaving = false);
      showToast(message: "Saved configuration");
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
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.chevron_left, size: 16.sp, color: Colors.grey.shade600),
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: "May 25-31, 2026",
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    TextWidget(
                      text: "Current week  Orders & Jobs from Printobi",
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
                    icon: Icon(Icons.chevron_right, size: 16.sp, color: Colors.grey.shade600),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () {},
              icon: Icon(Icons.add, size: 14.sp, color: Colors.white),
              label: TextWidget(
                text: "Add Entry",
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),

        // 2. Summary Cards Grid (Stacked on mobile)
        _buildVolumeSummaryCard(
          title: "WHOLESALE THIS WEEK",
          value: "102",
          subtitle: "Logged by admin",
          topBorderColor: const Color(0xFF3B82F6),
        ),
        SizedBox(height: 12.h),
        _buildVolumeSummaryCard(
          title: "RETAIL THIS WEEK",
          value: "1",
          subtitle: "Logged by admin",
          topBorderColor: const Color(0xFFFBBF24),
        ),
        SizedBox(height: 12.h),
        _buildVolumeSummaryCard(
          title: "SPECIALISTS INVOLVED",
          value: "0",
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
          Container(
            height: 3,
            width: double.infinity,
            color: topBorderColor,
          ),
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
                  _buildDropdown("All types"),
                  SizedBox(width: 8.w),
                  _buildDropdown("All days"),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 600.w,
              child: _buildOrderLogTable(),
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextWidget(
                text: "Showing 1-10 of 103 filtered entries (103 this week)",
                fontSize: 9.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade500,
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          TextWidget(
            text: hint,
            fontSize: 10.sp,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
          SizedBox(width: 4.w),
          Icon(Icons.keyboard_arrow_down, size: 14.sp, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFBBF24) : Colors.white,
        border: Border.all(color: isActive ? Colors.transparent : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Center(
        child: Icon(icon, size: 12.sp, color: isActive ? Colors.white : Colors.grey.shade600),
      ),
    );
  }

  Widget _buildPaginationNumber(String number, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFBBF24) : Colors.white,
        border: Border.all(color: isActive ? Colors.transparent : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Center(
        child: TextWidget(
          text: number,
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.white : Colors.black87,
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
            Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader("ACTIONS"))),
          ],
        ),
        SizedBox(height: 12.h),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#234", "1"),
        _buildOrderLogRow("05/25/2026", "Retail", "#235", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#234", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "1"),
        _buildOrderLogRow("05/25/2026", "Wholesale", "#23478", "2"),
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

  Widget _buildOrderLogRow(String date, String type, String orderNo, String jobNo) {
    bool isWholesale = type == "Wholesale";
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
                  color: isWholesale ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: TextWidget(
                  text: type,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  color: isWholesale ? const Color(0xFF2563EB) : const Color(0xFFD97706),
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
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  size: 14.sp,
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
                      Expanded(flex: 1, child: Align(alignment: Alignment.center, child: _buildTableHeader("QTY"))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader("UNIT PRICE"))),
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader("AMOUNT"))),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                  SizedBox(height: 8.h),
                  _buildChargeRow("The Pod - Orders", "102", "\$40.00", "\$4080.00"),
                  _buildChargeRow("The Pod - Jobs", "1", "\$40.00", "\$40.00"),
                  _buildChargeRow("PH Portal", "—", "\$345.40/wk", "\$345.40", amountColor: const Color(0xFF10B981)),
                  _buildChargeRow("Support Lines", "0", "\$0.69/per extra phone number", "\$0.00"),
                  _buildChargeRow("File Storage", "0", "\$0.69/per 500GB/wk", "\$0.00"),
                  _buildChargeRow("Email Connections", "0", "\$4.62/per extra email slot", "\$0.00"),
                  _buildChargeRow("SMS Overage", "1", "\$0.02", "\$0.02", amountColor: const Color(0xFFEF4444)),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.r)),
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      ),
                      onPressed: () {},
                      icon: Icon(Icons.add, size: 12.sp, color: Colors.grey.shade600),
                      label: TextWidget(
                        text: "Add Extra Charge",
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  
                  _buildChargeRow("Credits Applied", "", "", "\$0.00", amountColor: const Color(0xFF10B981)),
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
                text: "\$4465.42",
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.lock_outline, size: 14.sp, color: Colors.grey.shade700),
                  label: TextWidget(
                    text: "Save Changes",
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.lock, size: 14.sp, color: Colors.black),
                  label: TextWidget(
                    text: "Close Week & Record Charge",
                    fontSize: 11.sp,
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

  Widget _buildChargeRow(String label, String qty, String unitPrice, String amount, {Color? amountColor}) {
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
              width: 800.w,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
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
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader("ACTIONS"))),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text: "May 25–31",
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              SizedBox(height: 2.h),
                              TextWidget(
                                text: "Current",
                                fontSize: 10.sp,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "102",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "1",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "\$345.40",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "\$21.69",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "—",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "—",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextWidget(
                            text: "\$4487.09",
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF9C3),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: TextWidget(
                                text: "Open",
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF854D0E),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextWidget(
                              text: "—",
                              fontSize: 13.sp,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey.shade400,
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
          text: "Are you sure you want to ${isActive ? 'deactivate' : 'activate'} $clientName?",
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
