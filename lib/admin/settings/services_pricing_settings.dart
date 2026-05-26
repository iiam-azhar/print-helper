import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:print_helper/providers/client_pro.dart';
import 'package:print_helper/models/billing_models.dart';

import '../../constants/colors.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/toasts.dart';

class ServicesPricingSettingsMobile extends StatefulWidget {
  const ServicesPricingSettingsMobile({super.key});

  @override
  State<ServicesPricingSettingsMobile> createState() =>
      _ServicesPricingSettingsMobileState();
}

class _ServicesPricingSettingsMobileState
    extends State<ServicesPricingSettingsMobile> {
  bool _isSaving = false;
  bool _isLoading = true;

  // --- Specialists Rates State ---
  late List<SpecialistConfig> _specialists;

  // --- PH Portal State ---
  final TextEditingController _weeklyPriceController =
      TextEditingController(text: '345.4');

  // --- Add-on Services State ---
  late List<AddonServiceConfig> _addons;

  // --- DPC Launch Service State ---
  late List<LaunchPackageConfig> _launchPackages;

  // --- Specialist Earnings Floor State ---
  final Map<String, TextEditingController> _floorControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeFallback(); // populate with defaults first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData().then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }).catchError((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    });
  }

  Future<void> _refreshData() async {
    final clientPro = context.read<ClientPro>();
    await clientPro.fetchServicesPricing();
    final pricing = clientPro.servicesPricing;
    if (pricing != null && mounted) {
      _loadFromApi(pricing);
    }
  }

  /// Populates all controllers from the live API response.
  void _loadFromApi(ServicesPricingModel pricing) {
    // PH Portal weekly price
    _weeklyPriceController.text = pricing.phPortalWeekly.toStringAsFixed(2);

    // Specialist rate cards
    _specialists.clear();
    for (final group in pricing.rateCardGroups) {
      final ws = group.wholesale;
      final rt = group.retail;
      _specialists.add(
        SpecialistConfig(
          name: group.accountTypeName,
          wholesaleBase: ws.basePrice,
          wholesaleDiscount: ws.volumeDiscount,
          wholesalePercentages: ws.levelPercentages
              .map((k, v) => MapEntry(_capitalise(k), v)),
          wholesaleIconSvg: ws.iconSvg,
          retailBase: rt.basePrice,
          retailDiscount: rt.volumeDiscount,
          retailPercentages: rt.levelPercentages
              .map((k, v) => MapEntry(_capitalise(k), v)),
          retailIconSvg: rt.iconSvg,
        ),
      );
    }

    // Add-ons
    _addons.clear();
    for (final a in pricing.addons) {
      _addons.add(AddonServiceConfig(
        name: a.name,
        unit: a.billingUnit,
        included: a.included,
        price: a.weeklyPrice,
      ));
    }

    // DPC launch packages
    _launchPackages.clear();
    for (final d in pricing.dpcTerms) {
      _launchPackages.add(LaunchPackageConfig(months: d.months, total: d.totalPrice));
    }

    // Earnings floors
    for (final f in pricing.levelFloors) {
      final key = _capitalise(f.level);
      if (_floorControllers.containsKey(key)) {
        _floorControllers[key]!.text = f.weeklyMinimum.toStringAsFixed(0);
      } else {
        _floorControllers[key] = TextEditingController(
          text: f.weeklyMinimum.toStringAsFixed(0),
        );
      }
    }

    setState(() {});
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _initializeFallback() {
    _specialists = [
      SpecialistConfig(
        name: 'staff',
        wholesaleBase: 0.0,
        wholesaleDiscount: 0.0,
        wholesalePercentages: {
          'Associate': 20.0,
          'Silver': 25.0,
          'Gold': 28.0,
          'Platinum': 30.0,
          'Diamond': 32.0,
          'Partner': 35.0,
        },
        retailBase: 0.0,
        retailDiscount: 0.0,
        retailPercentages: {
          'Associate': 20.0,
          'Silver': 25.0,
          'Gold': 28.0,
          'Platinum': 30.0,
          'Diamond': 32.0,
          'Partner': 35.0,
        },
      ),
      SpecialistConfig(
        name: 'Graphic Designer',
        wholesaleBase: 30.0,
        wholesaleDiscount: 0.2,
        wholesalePercentages: {
          'Associate': 20.0,
          'Silver': 25.0,
          'Gold': 28.0,
          'Platinum': 30.0,
          'Diamond': 32.0,
          'Partner': 35.0,
        },
        retailBase: 30.0,
        retailDiscount: 0.8,
        retailPercentages: {
          'Associate': 20.0,
          'Silver': 25.0,
          'Gold': 28.0,
          'Platinum': 30.0,
          'Diamond': 110.0,
          'Partner': 35.0,
        },
      ),
    ];

    _addons = [
      AddonServiceConfig(name: 'File Storage', unit: 'per 500GB/wk', included: 0, price: 0.69),
      AddonServiceConfig(name: 'Email Connections', unit: 'per extra email slot', included: 0, price: 4.62),
      AddonServiceConfig(name: 'Support Lines', unit: 'per extra phone number', included: 1, price: 0.69),
      AddonServiceConfig(name: 'Incoming Call Minutes', unit: 'per extra minute', included: 5, price: 0.05),
      AddonServiceConfig(name: 'Outgoing Call Minutes', unit: 'per extra minute', included: 5, price: 0.07),
      AddonServiceConfig(name: 'Incoming SMS', unit: 'per extra SMS', included: 5, price: 0.01),
      AddonServiceConfig(name: 'Outgoing SMS', unit: 'per extra SMS', included: 5, price: 0.02),
      AddonServiceConfig(name: 'Incoming MMS', unit: 'per extra MMS', included: 5, price: 0.05),
      AddonServiceConfig(name: 'Outgoing MMS', unit: 'per extra MMS', included: 5, price: 0.1),
    ];

    _launchPackages = [
      LaunchPackageConfig(months: 6, total: 299.0),
      LaunchPackageConfig(months: 12, total: 549.0),
    ];

    _floorControllers['Associate'] = TextEditingController(text: '100');
    _floorControllers['Silver'] = TextEditingController(text: '200');
    _floorControllers['Gold'] = TextEditingController(text: '120');
    _floorControllers['Platinum'] = TextEditingController(text: '140');
    _floorControllers['Diamond'] = TextEditingController(text: '160');
    _floorControllers['Partner'] = TextEditingController(text: '200');
  }

  @override
  void dispose() {
    _weeklyPriceController.dispose();
    for (final c in _floorControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildPricingPayload() {
    final pricing = context.read<ClientPro>().servicesPricing;
    if (pricing == null) return {};

    // 1. Ph Portal Weekly
    final phPortalWeekly = double.tryParse(_weeklyPriceController.text) ?? pricing.phPortalWeekly;

    // 2. Rate Card Groups
    final List<Map<String, dynamic>> rateCardGroupsJson = [];
    for (final group in pricing.rateCardGroups) {
      // Find the specialist in UI state
      SpecialistConfig? spec;
      try {
        spec = _specialists.firstWhere(
          (s) => s.name.toLowerCase() == group.accountTypeName.toLowerCase(),
        );
      } catch (_) {
        spec = null;
      }

      // Wholesale card
      final double wsBase = spec != null
          ? (double.tryParse(spec.wholesaleBaseCtrl.text) ?? group.wholesale.basePrice)
          : group.wholesale.basePrice;
      final double wsDiscount = spec != null
          ? (double.tryParse(spec.wholesaleDiscountCtrl.text) ?? group.wholesale.volumeDiscount)
          : group.wholesale.volumeDiscount;
      final Map<String, dynamic> wsPercentages = {};
      group.wholesale.levelPercentages.forEach((key, val) {
        final uiKey = _capitalise(key);
        final pctCtrl = spec?.wholesalePercentagesCtrls[uiKey];
        wsPercentages[key] = pctCtrl != null ? (double.tryParse(pctCtrl.text) ?? val) : val;
      });

      final List<Map<String, dynamic>> wsVolumes = [];
      for (int i = 0; i < group.wholesale.volumes.length; i++) {
        final vol = group.wholesale.volumes[i];
        final double clientPrice = wsBase - (i * wsDiscount);
        wsVolumes.add({
          "id": vol.id,
          "client_price": clientPrice < 0 ? 0.0 : clientPrice,
        });
      }

      // Retail card
      final double rtBase = spec != null
          ? (double.tryParse(spec.retailBaseCtrl.text) ?? group.retail.basePrice)
          : group.retail.basePrice;
      final double rtDiscount = spec != null
          ? (double.tryParse(spec.retailDiscountCtrl.text) ?? group.retail.volumeDiscount)
          : group.retail.volumeDiscount;
      final Map<String, dynamic> rtPercentages = {};
      group.retail.levelPercentages.forEach((key, val) {
        final uiKey = _capitalise(key);
        final pctCtrl = spec?.retailPercentagesCtrls[uiKey];
        rtPercentages[key] = pctCtrl != null ? (double.tryParse(pctCtrl.text) ?? val) : val;
      });

      final List<Map<String, dynamic>> rtVolumes = [];
      for (int i = 0; i < group.retail.volumes.length; i++) {
        final vol = group.retail.volumes[i];
        final double clientPrice = rtBase - (i * rtDiscount);
        rtVolumes.add({
          "id": vol.id,
          "client_price": clientPrice < 0 ? 0.0 : clientPrice,
        });
      }

      rateCardGroupsJson.add({
        "account_type_id": group.accountTypeId,
        "account_type_name": group.accountTypeName,
        "wholesale": {
          "id": group.wholesale.id,
          "base_price": wsBase,
          "volume_discount": wsDiscount,
          "level_percentages": wsPercentages,
          "volumes": wsVolumes,
        },
        "retail": {
          "id": group.retail.id,
          "base_price": rtBase,
          "volume_discount": rtDiscount,
          "level_percentages": rtPercentages,
          "volumes": rtVolumes,
        }
      });
    }

    // 3. Add-ons
    final List<Map<String, dynamic>> addonsJson = [];
    for (int i = 0; i < pricing.addons.length; i++) {
      final addon = pricing.addons[i];
      AddonServiceConfig? uiAddon;
      if (i < _addons.length) {
        uiAddon = _addons[i];
      }
      final String includedVal = uiAddon != null ? uiAddon.includedCtrl.text : addon.included.toString();
      final double priceVal = uiAddon != null
          ? (double.tryParse(uiAddon.priceCtrl.text) ?? addon.weeklyPrice)
          : addon.weeklyPrice;

      addonsJson.add({
        "id": addon.id,
        "included": includedVal,
        "weekly_price": priceVal,
      });
    }

    // 4. Dpc Terms
    final List<Map<String, dynamic>> dpcTermsJson = [];
    for (int i = 0; i < pricing.dpcTerms.length; i++) {
      final term = pricing.dpcTerms[i];
      LaunchPackageConfig? uiTerm;
      if (i < _launchPackages.length) {
        uiTerm = _launchPackages[i];
      }
      final double totalVal = uiTerm != null
          ? (double.tryParse(uiTerm.totalCtrl.text) ?? term.totalPrice)
          : term.totalPrice;

      dpcTermsJson.add({
        "id": term.id,
        "months": term.months,
        "total_price": totalVal,
      });
    }

    // 5. Weekly Bonuses
    final List<Map<String, dynamic>> weeklyBonusesJson = pricing.weeklyBonuses.map((b) => {
      "id": b.id,
      "amounts": b.amounts,
    }).toList();

    // 6. One-time Bonuses
    final List<Map<String, dynamic>> onetimeBonusesJson = pricing.onetimeBonuses.map((b) => {
      "id": b.id,
      "amounts": b.amounts,
    }).toList();

    // 7. Supervisor Bonuses
    final List<Map<String, dynamic>> supervisorBonusesJson = pricing.supervisorBonuses.map((b) => {
      "id": b.id,
      "amount_per_point": b.amountPerPoint,
    }).toList();

    // 8. Level Floors
    final List<Map<String, dynamic>> levelFloorsJson = [];
    for (final floor in pricing.levelFloors) {
      final uiKey = _capitalise(floor.level);
      final floorCtrl = _floorControllers[uiKey];
      final double minVal = floorCtrl != null ? (double.tryParse(floorCtrl.text) ?? floor.weeklyMinimum) : floor.weeklyMinimum;

      levelFloorsJson.add({
        "id": floor.id,
        "weekly_minimum": minVal,
      });
    }

    return {
      "data": {
        "rateCardGroups": rateCardGroupsJson,
        "addons": addonsJson,
        "dpcTerms": dpcTermsJson,
        "weeklyBonuses": weeklyBonusesJson,
        "onetimeBonuses": onetimeBonusesJson,
        "supervisorBonuses": supervisorBonusesJson,
        "levelFloors": levelFloorsJson,
        "phPortalWeekly": phPortalWeekly,
      }
    };
  }

  Future<void> _saveAllSettings() async {
    final payload = _buildPricingPayload();
    if (payload.isEmpty) {
      showToast(message: 'No services pricing settings loaded to save.');
      return;
    }

    setState(() => _isSaving = true);
    final startTime = DateTime.now();
    final clientPro = context.read<ClientPro>();
    final success = await clientPro.updateServicesPricing(payload);

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed.inMilliseconds < 800) {
      await Future.delayed(Duration(milliseconds: 800 - elapsed.inMilliseconds));
    }
    setState(() => _isSaving = false);

    if (success) {
      showToast(message: 'Services and Pricing saved successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 80.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Subtitle
                  TextWidget(
                    text: 'Services & Pricing',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                  SizedBox(height: 4.h),
                  TextWidget(
                    text: 'Configure all rates, bonuses and add-on pricing in one place.',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFF4B5563),
                  ),
                  SizedBox(height: 14.h),

                  // Warning Banner
                  _buildWarningBanner(),
                  SizedBox(height: 20.h),

                  // Section 1: The Pod
                  _buildSpecialistsHeader(),
                  SizedBox(height: 12.h),

                  // Specialists List
                  for (final spec in _specialists) ...[
                    _buildSpecialistColumn(spec),
                    SizedBox(height: 16.h),
                  ],

                  // Section 2: PH Portal
                  _buildSectionHeader('PH Portal'),
                  SizedBox(height: 10.h),
                  _buildWeeklyPriceCard(),
                  SizedBox(height: 20.h),

                  // Section 3: Recurring Add-on Services
                  _buildSectionHeader('Recurring Add-on Services'),
                  SizedBox(height: 2.h),
                  TextWidget(
                    text: 'These are charged weekly to clients who activate them.',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFF6B7280),
                  ),
                  SizedBox(height: 10.h),
                  _buildAddonsTable(),
                  SizedBox(height: 20.h),

                  // Section 4: DPC Launch Service
                  _buildSectionHeader('DPC Launch Service'),
                  SizedBox(height: 2.h),
                  TextWidget(
                    text: 'Service packages finalized for contract terms.',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFF6B7280),
                  ),
                  SizedBox(height: 10.h),
                  _buildLaunchPackagesSection(),
                  SizedBox(height: 20.h),

                  // Section 5: Specialist Earnings Floor
                  _buildSectionHeader('Specialist Earnings Floor (Per Level)'),
                  SizedBox(height: 2.h),
                  TextWidget(
                    text: 'Print Helpers covers the difference if weekly earnings fall below minimums.',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.normal,
                    color: const Color(0xFF6B7280),
                  ),
                  SizedBox(height: 12.h),
                  _buildFloorGrid(),
                  SizedBox(height: 8.h),
                  TextWidget(
                    text: 'Example: If Gold specialist earns \$110 (below \$120), Print Helpers adds \$10.',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ),

          // Save Button
          Positioned(
            bottom: 16.h,
            right: 16.w,
            child: FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveAllSettings,
              backgroundColor: _isSaving ? Colors.grey : AppColors.primary,
              icon: const Icon(Icons.save_rounded, color: Colors.black),
              label: Text(
                'Save Settings',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),

          // Local Loader Overlay Blocker
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.55),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3.w,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Saving settings...',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Local Initial Loading Overlay Blocker
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3.w,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Loading settings...',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFD97706), size: 18.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Changing rates updates specialist compensation, client pricing, and audit tool instantly after saving.',
              style: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFF92400E),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialistsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'The Pod',
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF111827),
        ),
        SizedBox(height: 2.h),
        TextWidget(
          text: 'Manage specialists in Settings -> Account Type.',
          fontSize: 11.sp,
          fontWeight: FontWeight.normal,
          color: const Color(0xFF6B7280),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return TextWidget(
      text: title,
      fontSize: 15.sp,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF111827),
    );
  }

  Widget _buildSpecialistColumn(SpecialistConfig spec) {
    return Column(
      children: [
        _buildSpecialistCard(
          title: '${spec.name} - Wholesale',
          subtitle: 'Charged per order',
          icon: Icons.people_outline_rounded,
          iconSvg: spec.wholesaleIconSvg,
          baseController: spec.wholesaleBaseCtrl,
          discountController: spec.wholesaleDiscountCtrl,
          percentageControllers: spec.wholesalePercentagesCtrls,
          isWholesale: true,
          onChanged: () => setState(() {}),
        ),
        SizedBox(height: 12.h),
        _buildSpecialistCard(
          title: '${spec.name} - Retail',
          subtitle: 'Charged per job',
          icon: Icons.person_outline_rounded,
          iconSvg: spec.retailIconSvg,
          baseController: spec.retailBaseCtrl,
          discountController: spec.retailDiscountCtrl,
          percentageControllers: spec.retailPercentagesCtrls,
          isWholesale: false,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSpecialistCard({
    required String title,
    required String subtitle,
    required IconData icon,
    String iconSvg = '',
    required TextEditingController baseController,
    required TextEditingController discountController,
    required Map<String, TextEditingController> percentageControllers,
    required bool isWholesale,
    required VoidCallback onChanged,
  }) {
    final double basePrice = double.tryParse(baseController.text) ?? 0.0;
    final double discount = double.tryParse(discountController.text) ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Black Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: title,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      SizedBox(height: 1.h),
                      TextWidget(
                        text: subtitle,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
                if (iconSvg.isNotEmpty)
                  SvgPicture.string(
                    iconSvg,
                    colorFilter: ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
                    width: 18.w,
                    height: 18.w,
                  )
                else
                  Icon(icon, color: Colors.grey.shade400, size: 18.w),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Base Price and Volume Discount
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        label: 'BASE PRICE',
                        controller: baseController,
                        prefixText: '\$ ',
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildInputField(
                        label: 'VOLUME DISCOUNT',
                        controller: discountController,
                        prefixText: '\$ ',
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Percentages Grid - 3 columns, 2 rows
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        label: 'Assoc %',
                        controller: percentageControllers['Associate']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: _buildInputField(
                        label: 'Silver %',
                        controller: percentageControllers['Silver']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: _buildInputField(
                        label: 'Gold %',
                        controller: percentageControllers['Gold']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        label: 'Plat %',
                        controller: percentageControllers['Platinum']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: _buildInputField(
                        label: 'Diam %',
                        controller: percentageControllers['Diamond']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: _buildInputField(
                        label: 'Part %',
                        controller: percentageControllers['Partner']!,
                        centerText: true,
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Calculated Price Table
                TextWidget(
                  text: 'AUTO-CALCULATED PRICE TABLE (SWIPE)',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF374151),
                ),
                SizedBox(height: 6.h),

                // Horizontal scrollable table container
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 540.w, // fits all columns comfortably in scroll view
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2), // Volume
                          1: FlexColumnWidth(1.4), // Client Price
                          2: FlexColumnWidth(1.2), // Associate
                          3: FlexColumnWidth(1.0), // Silver
                          4: FlexColumnWidth(1.0), // Gold
                          5: FlexColumnWidth(1.2), // Platinum
                          6: FlexColumnWidth(1.2), // Diamond
                          7: FlexColumnWidth(1.2), // Partner
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                            ),
                            children: [
                              _buildTableHeaderCell('Volume'),
                              _buildTableHeaderCell('Client Price'),
                              _buildTableHeaderCell('Associate'),
                              _buildTableHeaderCell('Silver'),
                              _buildTableHeaderCell('Gold'),
                              _buildTableHeaderCell('Platinum'),
                              _buildTableHeaderCell('Diamond'),
                              _buildTableHeaderCell('Partner'),
                            ],
                          ),
                          for (int i = 0; i < 4; i++)
                            _buildCalculationRow(
                              index: i,
                              isWholesale: isWholesale,
                              basePrice: basePrice,
                              discount: discount,
                              percentageCtrls: percentageControllers,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
      child: TextWidget(
        text: label,
        fontSize: 9.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF4B5563),
      ),
    );
  }

  TableRow _buildCalculationRow({
    required int index,
    required bool isWholesale,
    required double basePrice,
    required double discount,
    required Map<String, TextEditingController> percentageCtrls,
  }) {
    final String volumeLabel = isWholesale
        ? '${(index + 1) * 50}/wk'
        : index == 0
            ? '10/wk'
            : index == 1
                ? '20/wk'
                : index == 2
                    ? '50/wk'
                    : '100/wk';

    final double clientPrice = double.parse((basePrice - (index * discount)).toStringAsFixed(3));
    final double displayClientPrice = clientPrice < 0 ? 0.0 : clientPrice;

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
          child: TextWidget(
            text: volumeLabel,
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
          child: TextWidget(
            text: '\$${displayClientPrice.toStringAsFixed(3)}',
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        for (final rank in percentageCtrls.keys)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
            child: Builder(builder: (context) {
              final double pct = double.tryParse(percentageCtrls[rank]!.text) ?? 0.0;
              final double share = displayClientPrice * (pct / 100.0);
              return TextWidget(
                text: '\$${share.toStringAsFixed(3)}',
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4B5563),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildWeeklyPriceCard() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'WEEKLY PRICE',
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF374151),
          ),
          SizedBox(height: 6.h),
          SizedBox(
            width: 140.w,
            child: _buildInputField(
              label: '',
              controller: _weeklyPriceController,
              prefixText: '\$ ',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(4.5), // Service + Unit combined
          1: FlexColumnWidth(2.5), // Included
          2: FlexColumnWidth(3.0), // Price
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            children: [
              _buildTableHeaderCellWithPadding('SERVICE / UNIT'),
              _buildTableHeaderCellWithPadding('INCL.'),
              _buildTableHeaderCellWithPadding('PRICE'),
            ],
          ),
          for (final addon in _addons)
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              children: [
                // Combined Service & Billing Unit
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: addon.name,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                      SizedBox(height: 2.h),
                      TextWidget(
                        text: addon.unit,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.normal,
                        color: const Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
                // Included Input
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                  child: SizedBox(
                    height: 34.h,
                    child: TextField(
                      controller: addon.includedCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                // Price Input
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                  child: SizedBox(
                    height: 34.h,
                    child: TextField(
                      controller: addon.priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCellWithPadding(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: TextWidget(
        text: label,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF374151),
      ),
    );
  }

  Widget _buildLaunchPackagesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Table header bar with "+ Add Term"
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            color: const Color(0xFFF9FAFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextWidget(
                  text: 'LAUNCH PACKAGES',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF374151),
                ),
                GestureDetector(
                  onTap: _showAddTermDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 12.w),
                        SizedBox(width: 2.w),
                        TextWidget(
                          text: 'Add Term',
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Package Cards layout (better than squishing on mobile)
          if (_launchPackages.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.w),
              child: TextWidget(
                text: 'No launch terms configured.',
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
                color: Colors.grey,
              ),
            ),

          for (final pkg in _launchPackages) ...[
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget(
                        text: '${pkg.months} Months Term',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111827),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: const Color(0xFFEF4444), size: 18.w),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _launchPackages.remove(pkg);
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: 'TOTAL PRICE',
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B7280),
                            ),
                            SizedBox(height: 4.h),
                            SizedBox(
                              height: 34.h,
                              child: TextField(
                                controller: pkg.totalCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  prefixText: '\$ ',
                                  prefixStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                    borderSide: const BorderSide(color: AppColors.primary),
                                  ),
                                ),
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
                            TextWidget(
                              text: 'MONTHLY',
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B7280),
                            ),
                            SizedBox(height: 6.h),
                            Builder(builder: (context) {
                              final double total = double.tryParse(pkg.totalCtrl.text) ?? 0.0;
                              final double monthly = total / pkg.months;
                              return TextWidget(
                                text: '\$${monthly.toStringAsFixed(2)}',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF111827),
                              );
                            }),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: 'WEEKLY',
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B7280),
                            ),
                            SizedBox(height: 6.h),
                            Builder(builder: (context) {
                              final double total = double.tryParse(pkg.totalCtrl.text) ?? 0.0;
                              final double monthly = total / pkg.months;
                              final double weekly = monthly / 4.33;
                              return TextWidget(
                                text: '\$${weekly.toStringAsFixed(2)}',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF111827),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (pkg != _launchPackages.last)
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddTermDialog() async {
    final termCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: 'Add Contract Term',
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: termCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Contract Term (Months)',
                  hintText: 'e.g. 24',
                ),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Price (\$)',
                  hintText: 'e.g. 999',
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 8.w),
                  ElevatedButton(
                    onPressed: () {
                      final int months = int.tryParse(termCtrl.text) ?? 0;
                      final double total = double.tryParse(priceCtrl.text) ?? 0.0;
                      if (months <= 0 || total <= 0) {
                        showToast(message: 'Invalid values entered');
                        return;
                      }
                      setState(() {
                        _launchPackages.add(LaunchPackageConfig(months: months, total: total));
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorGrid() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'ASSOC MINIMUM',
                  controller: _floorControllers['Associate']!,
                  prefixText: '\$ ',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildInputField(
                  label: 'SILVER MINIMUM',
                  controller: _floorControllers['Silver']!,
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'GOLD MINIMUM',
                  controller: _floorControllers['Gold']!,
                  prefixText: '\$ ',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildInputField(
                  label: 'PLATINUM MINIMUM',
                  controller: _floorControllers['Platinum']!,
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'DIAMOND MINIMUM',
                  controller: _floorControllers['Diamond']!,
                  prefixText: '\$ ',
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildInputField(
                  label: 'PARTNER MINIMUM',
                  controller: _floorControllers['Partner']!,
                  prefixText: '\$ ',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? prefixText,
    bool centerText = false,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          TextWidget(
            text: label,
            fontSize: 9.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4B5563),
          ),
          SizedBox(height: 4.h),
        ],
        SizedBox(
          height: 36.h,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: centerText ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
            onChanged: (_) {
              if (onChanged != null) onChanged();
            },
            decoration: InputDecoration(
              isDense: true,
              prefixText: prefixText,
              prefixStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500),
              contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Helper Data Structures ---

class SpecialistConfig {
  final String name;
  final double wholesaleBase;
  final double wholesaleDiscount;
  final Map<String, double> wholesalePercentages;
  final String wholesaleIconSvg;

  final double retailBase;
  final double retailDiscount;
  final Map<String, double> retailPercentages;
  final String retailIconSvg;

  late final TextEditingController wholesaleBaseCtrl;
  late final TextEditingController wholesaleDiscountCtrl;
  final Map<String, TextEditingController> wholesalePercentagesCtrls = {};

  late final TextEditingController retailBaseCtrl;
  late final TextEditingController retailDiscountCtrl;
  final Map<String, TextEditingController> retailPercentagesCtrls = {};

  SpecialistConfig({
    required this.name,
    required this.wholesaleBase,
    required this.wholesaleDiscount,
    required this.wholesalePercentages,
    required this.retailBase,
    required this.retailDiscount,
    required this.retailPercentages,
    this.wholesaleIconSvg = '',
    this.retailIconSvg = '',
  }) {
    wholesaleBaseCtrl = TextEditingController(text: wholesaleBase.toStringAsFixed(0));
    wholesaleDiscountCtrl = TextEditingController(text: wholesaleDiscount.toStringAsFixed(1));
    for (final rank in wholesalePercentages.keys) {
      final ctrl = TextEditingController(text: wholesalePercentages[rank]!.toStringAsFixed(0));
      _addPercentageClampListener(ctrl);
      wholesalePercentagesCtrls[rank] = ctrl;
    }

    retailBaseCtrl = TextEditingController(text: retailBase.toStringAsFixed(0));
    retailDiscountCtrl = TextEditingController(text: retailDiscount.toStringAsFixed(1));
    for (final rank in retailPercentages.keys) {
      final ctrl = TextEditingController(text: retailPercentages[rank]!.toStringAsFixed(0));
      _addPercentageClampListener(ctrl);
      retailPercentagesCtrls[rank] = ctrl;
    }
  }

  void _addPercentageClampListener(TextEditingController ctrl) {
    ctrl.addListener(() {
      final text = ctrl.text;
      if (text.isEmpty) return;
      final val = double.tryParse(text);
      if (val != null && val > 100) {
        ctrl.value = TextEditingValue(
          text: '100',
          selection: const TextSelection.collapsed(offset: 3),
        );
      }
    });
  }
}

class AddonServiceConfig {
  final String name;
  final String unit;
  final int included;
  final double price;

  late final TextEditingController includedCtrl;
  late final TextEditingController priceCtrl;

  AddonServiceConfig({
    required this.name,
    required this.unit,
    required this.included,
    required this.price,
  }) {
    includedCtrl = TextEditingController(text: included.toString());
    priceCtrl = TextEditingController(text: price.toString());
  }
}

class LaunchPackageConfig {
  final int months;
  final double total;

  late final TextEditingController totalCtrl;

  LaunchPackageConfig({
    required this.months,
    required this.total,
  }) {
    totalCtrl = TextEditingController(text: total.toStringAsFixed(0));
  }
}
