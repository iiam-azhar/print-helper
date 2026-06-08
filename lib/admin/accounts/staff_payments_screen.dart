import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:print_helper/models/accounts_models.dart';
import 'package:print_helper/utils/formatter.dart';
import 'package:print_helper/widgets/text_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:print_helper/providers/admin_pro.dart';
import 'package:print_helper/models/staff_payments/staff_payments_tabs_model.dart';

import '../../widgets/loaders.dart';

class StaffPaymentsScreen extends StatefulWidget {
  final AccountModel account;

  const StaffPaymentsScreen({super.key, required this.account});

  @override
  State<StaffPaymentsScreen> createState() => _StaffPaymentsScreenState();
}

class _StaffPaymentsScreenState extends State<StaffPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedLevelKey;
  Set<int> _selectedWholesaleIds = {};
  String _selectedType = 'All types';
  String _selectedDay = 'All days';
  String _selectedStatus = 'All statuses';

  // Missed Interaction controllers
  final TextEditingController _miHoursCtrl = TextEditingController();
  final TextEditingController _miMinutesCtrl = TextEditingController();

  // Business Working Hour state
  TimeOfDay? _bwhFrom;
  TimeOfDay? _bwhTo;

  // Save loading states
  bool _isSavingMI = false;
  bool _isSavingBWH = false;
  bool _isDayOperationLoading = false;

  // Track loaded day for state initialization
  String? _lastInitializedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminPro>().getStaffPaymentCompensation(widget.account.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _miHoursCtrl.dispose();
    _miMinutesCtrl.dispose();
    super.dispose();
  }

  String _getFullName() {
    return '${widget.account.name} ${widget.account.lastName}'.trim();
  }

  String _getDaysSinceStart() {
    try {
      final startDate = DateTime.parse(widget.account.createdAt);
      final difference = DateTime.now().difference(startDate).inDays;
      final formattedDate = Frmtr.frmtDate(
        date: widget.account.createdAt,
        outForm: 'MMM dd, yyyy',
      );
      return 'Started $formattedDate - $difference days';
    } catch (_) {
      return 'Started ${widget.account.createdAt}';
    }
  }

  bool _isCurrentWeek(String weekStart, String weekEnd, String today) {
    try {
      if (weekStart.isEmpty || weekEnd.isEmpty || today.isEmpty) return true;
      final start = DateTime.parse(weekStart);
      final end = DateTime.parse(weekEnd);
      final current = DateTime.parse(today);
      return (current.isAfter(start) || current.isAtSameMomentAs(start)) &&
          (current.isBefore(end.add(const Duration(days: 1))));
    } catch (_) {
      return true;
    }
  }

  String _formatWeekRange(String? startStr, String? endStr) {
    if (startStr == null ||
        startStr.isEmpty ||
        endStr == null ||
        endStr.isEmpty)
      return '';
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);

      final startMonth = DateFormat('MMMM').format(start);
      final endMonth = DateFormat('MMMM').format(end);
      final startDay = start.day;
      final endDay = end.day;
      final year = start.year;

      if (startMonth == endMonth) {
        return "$startMonth $startDay–$endDay, $year";
      } else {
        return "$startMonth $startDay – $endMonth $endDay, $year";
      }
    } catch (_) {
      return "${startStr ?? ''} – ${endStr ?? ''}";
    }
  }

  String _formatSingleDay(String? dayStr) {
    if (dayStr == null || dayStr.isEmpty) return 'Tuesday, May 26, 2026';
    try {
      final parsed = DateTime.parse(dayStr);
      return DateFormat('EEEE, MMMM dd, yyyy').format(parsed);
    } catch (_) {
      return dayStr;
    }
  }

  void _updateWholesaleRetailFilters({
    String? type,
    String? dayFilter,
    String? status,
    int? page,
  }) {
    final t = type ?? _selectedType;
    final d = dayFilter ?? _selectedDay;
    final s = status ?? _selectedStatus;

    final typeParam = t.toLowerCase() == 'all types' ? 'all' : t.toLowerCase();
    final dayParam = d.toLowerCase() == 'all days'
        ? 'all'
        : (d.toLowerCase() == 'today' ? 'selected' : 'yesterday');
    final statusParam = s.toLowerCase() == 'all statuses'
        ? 'all'
        : s.toLowerCase();

    final selectedDayStr = context
        .read<AdminPro>()
        .currentPaymentResponse
        ?.tabs
        ?.selectedDay;

    context.read<AdminPro>().getStaffPaymentCompensation(
      widget.account.id,
      day: selectedDayStr,
      wholesaleRetailPage: page ?? 1,
      type: typeParam,
      dayFilter: dayParam,
      status: statusParam,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.black87, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextWidget(
                text: '${_getFullName()} / Payments',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildTabBar(),
            const SizedBox(height: 16),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Consumer<AdminPro>(
      builder: (context, provider, child) {
        final data = provider.currentPaymentResponse?.data;
        final levelText =
            (data?.currentLevel != null && data!.currentLevel.isNotEmpty)
            ? data.currentLevel
            : 'Associate';

        final roleText = widget.account.roleName.isNotEmpty
            ? widget.account.roleName
            : 'Graphic Designer';

        final statusText = widget.account.status ? 'Active' : 'Inactive';
        final statusColor = widget.account.status
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444);

        double? weeklyRate;
        if (data != null) {
          final currentLevelKey = data.currentLevel;
          final floorVal = data.levelFloors[currentLevelKey];
          if (floorVal != null) {
            weeklyRate = floorVal.toDouble();
          }
        }
        final earningsText = weeklyRate != null
            ? '\$${weeklyRate.toStringAsFixed(2)}/wk'
            : '\$100.00/wk';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name & Active Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFullName(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildTag(
                          icon: Icons.circle,
                          iconColor: statusColor,
                          text: statusText,
                          bgColor: Colors.white,
                          borderColor: const Color(0xFFE2E8F0),
                          textColor: statusColor,
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTag(
                    icon: Icons.emoji_events,
                    iconColor: const Color(0xFFD97706),
                    text: levelText,
                    bgColor: const Color(0xFFFEF3C7),
                    borderColor: Colors.transparent,
                    textColor: const Color(0xFFD97706),
                  ),
                  _buildTag(
                    text: roleText,
                    bgColor: const Color(0xFFDBEAFE),
                    borderColor: Colors.transparent,
                    textColor: const Color(0xFF2563EB),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _getDaysSinceStart(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Earnings
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      earningsText,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "THIS WEEK'S EARNINGS",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF22C55E),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag({
    IconData? icon,
    Color? iconColor,
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor == Colors.transparent
              ? Colors.transparent
              : borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 4,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Compensation'),
          Tab(text: 'Wholesale & Retail'),
          Tab(text: 'Performance'),
          Tab(text: 'Payment'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 0:
            return _buildCompensationTab();
          case 1:
            return _buildWholesaleRetailTab();
          case 2:
            return _buildPerformanceTab();
          case 3:
            return _buildPaymentTab();
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _buildCompensationTab() {
    return Consumer<AdminPro>(
      builder: (context, provider, child) {
        if (provider.paymentCompensationLoad) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32.0), child: showLoader()),
          );
        }

        final data = provider.currentPaymentResponse?.data;
        if (data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No compensation data available."),
            ),
          );
        }

        final levelKeys = data.levels.keys.toList();
        if (_selectedLevelKey == null && levelKeys.isNotEmpty) {
          _selectedLevelKey = data.currentLevel;
          if (!levelKeys.contains(_selectedLevelKey)) {
            _selectedLevelKey = levelKeys.first;
          }
        }

        final currentLevelData = data.levels[data.currentLevel];
        final selectedLevelData = data.levels[_selectedLevelKey];
        final floorValue = data.levelFloors[_selectedLevelKey] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Yellow Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${currentLevelData?.name ?? data.currentLevel} — Your Current Level',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.accountTypeName ?? "Unknown Role"} • Select a level below to explore its rate card',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Level Selectors
                  Text(
                    'Viewing rate card for:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: levelKeys.map((key) {
                      final isSelected = key == _selectedLevelKey;
                      final isCurrent = key == data.currentLevel;
                      final levelName = data.levels[key]?.name ?? key;

                      Color selectedColor = const Color(0xFFFBBF24);

                      if (data.levels[key]?.border != null) {
                        if (data.levels[key]!.border.contains("slate")) {
                          selectedColor = const Color(0xFF94A3B8); // slate-400
                        } else if (data.levels[key]!.border.contains(
                          "yellow",
                        )) {
                          selectedColor = const Color(0xFFFACC15); // yellow-400
                        } else if (data.levels[key]!.border.contains(
                          "violet",
                        )) {
                          selectedColor = const Color(0xFFA78BFA); // violet-400
                        } else if (data.levels[key]!.border.contains("sky")) {
                          selectedColor = const Color(0xFF38BDF8); // sky-400
                        } else if (data.levels[key]!.border.contains(
                          "orange",
                        )) {
                          selectedColor = const Color(0xFFFB923C); // orange-400
                        } else if (data.levels[key]!.border.contains("gray")) {
                          selectedColor = const Color(0xFF9CA3AF); // gray-400
                        }
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLevelKey = key;
                          });
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? selectedColor : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? selectedColor
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCurrent ? '$levelName (My Level)' : levelName,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Weekly Floor Guarantee Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shield,
                                color: Color(0xFF22C55E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'WEEKLY FLOOR GUARANTEE',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF16A34A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${floorValue.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '/ week minimum',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If weekly earnings fall below \$${floorValue.toStringAsFixed(2)}, Print Helpers covers the difference regardless of order volume.',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (selectedLevelData != null)
              // Rate Card For Associate Level
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF64748B), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RATE CARD FOR',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      selectedLevelData.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF64748B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Rates calculate automatically based on the selected level. Tiers reflect weekly volume — higher volume uses that tier's rate for all units that week.",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vertically stacked columns for mobile
                    _buildRateColumn(
                      badgeText: 'Wholesale',
                      badgeColor: const Color(0xFFFBBF24),
                      title: 'Compensation per order',
                      cards: selectedLevelData.wholesale.map((row) {
                        return _buildRateCard(
                          row.isNotEmpty ? row[0] : '',
                          row.length > 1 ? row[1] : '',
                          row.length > 2 ? 'Est. weekly : ${row[2]}' : '',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _buildRateColumn(
                      badgeText: 'Retail',
                      badgeColor: const Color(0xFFFBBF24),
                      title: 'Compensation per job',
                      cards: selectedLevelData.retail.map((row) {
                        return _buildRateCard(
                          row.isNotEmpty ? row[0] : '',
                          row.length > 1 ? row[1] : '',
                          row.length > 2 ? 'Est. weekly : ${row[2]}' : '',
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRateColumn({
    required String badgeText,
    required Color badgeColor,
    required String title,
    required List<Widget> cards,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cards,
      ],
    );
  }

  Widget _buildRateCard(String subtitle, String price, String est) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            est,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return Consumer<AdminPro>(
      builder: (context, provider, child) {
        if (provider.paymentCompensationLoad) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32.0), child: showLoader()),
          );
        }

        final tabsData = provider.currentPaymentResponse?.tabs;
        final data = tabsData?.performance;
        if (tabsData == null || data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No performance data available."),
            ),
          );
        }

        if (_lastInitializedDay != tabsData.selectedDay) {
          _miHoursCtrl.text =
              data.missedInteractionsHours?.toString() ??
              '${(data.missedInteractions / 60).floor()}';
          _miMinutesCtrl.text =
              data.missedInteractionsMinutes?.toString() ??
              '${data.missedInteractions % 60}';

          if (data.businessWorkingHourFromTime != null &&
              data.businessWorkingHourFromTime!.isNotEmpty) {
            final parts = data.businessWorkingHourFromTime!.split(':');
            if (parts.length == 2) {
              _bwhFrom = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          } else {
            _bwhFrom = null;
          }
          if (data.businessWorkingHourToTime != null &&
              data.businessWorkingHourToTime!.isNotEmpty) {
            final parts = data.businessWorkingHourToTime!.split(':');
            if (parts.length == 2) {
              _bwhTo = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          } else {
            _bwhTo = null;
          }
          _lastInitializedDay = tabsData.selectedDay;
        }

        String formatCurrency(num val) => '\$${val.toStringAsFixed(2)}';
        final isThisWeekSelected = _isCurrentWeek(
          data.weekStart,
          data.weekEnd,
          tabsData.day?.today ?? '',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header
            Text(
              _formatWeekRange(data.weekStart, data.weekEnd),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Current week \u2013 in progress',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            // Nav buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOutlinedBtn(
                  '< Previous',
                  Colors.black87,
                  const Color(0xFFE2E8F0),
                  onPressed: () {
                    try {
                      final currentStart = DateTime.parse(data.weekStart);
                      final prevStart = currentStart.subtract(
                        const Duration(days: 7),
                      );
                      final prevStartStr =
                          "${prevStart.year}-${prevStart.month.toString().padLeft(2, '0')}-${prevStart.day.toString().padLeft(2, '0')}";
                      context.read<AdminPro>().getStaffPaymentCompensation(
                        widget.account.id,
                        day: prevStartStr,
                      );
                    } catch (e) {
                      print(e);
                    }
                  },
                ),
                _buildOutlinedBtn(
                  'This Week',
                  const Color(0xFFD97706),
                  const Color(0xFFFBBF24),
                  isSelected: isThisWeekSelected,
                  onPressed: () {
                    final todayStr = tabsData.day?.today ?? '';
                    context.read<AdminPro>().getStaffPaymentCompensation(
                      widget.account.id,
                      day: todayStr.isNotEmpty ? todayStr : null,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.lock, size: 14),
                label: Text(
                  'Close Week',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Streak cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZERO COMPLAINTS STREAK',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.zeroComplaintsStreakDays} days',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No active streak yet',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '4-WEEK STREAK',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data.fourWeekStreakProgress} / 4',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${4 - data.fourWeekStreakProgress} more week needed',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Missed Interaction card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missed Interaction',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Editable inputs + Save
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _miHoursCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Hours',
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _miMinutesCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Minutes',
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (tabsData != null && !tabsData.wholesaleRetail.isWeekClosed) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSavingMI
                              ? null
                              : () async {
                                  final h =
                                      int.tryParse(_miHoursCtrl.text.trim()) ?? 0;
                                  final m =
                                      int.tryParse(_miMinutesCtrl.text.trim()) ??
                                      0;
                                  setState(() => _isSavingMI = true);
                                  await context
                                      .read<AdminPro>()
                                      .savePerformanceMetric(
                                        widget.account.id,
                                        day: tabsData.day?.date ?? '',
                                        metric: 'missed_interactions',
                                        hours: h,
                                        minutes: m,
                                      );
                                  if (mounted)
                                    setState(() => _isSavingMI = false);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            disabledBackgroundColor: const Color(
                              0xFFFBBF24,
                            ).withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSavingMI
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black54,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.save, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Save',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Color(0xFFEF4444),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reply SLA: ${data.missedInteractionsHours ?? (data.missedInteractions / 60).floor()} hr ${data.missedInteractionsMinutes ?? (data.missedInteractions % 60)} min',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'INTERACTED IN TIME',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF059669),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.interactionRepliedWithinSlaCount}',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'MISSED',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFDC2626),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${data.interactionMissedCount}',
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFDC2626),
                                ),
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
            const SizedBox(height: 12),
            // Business Working Hour card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Working Hour',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  // Editable time pickers + Save
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _buildTappableTimeField(
                          label: 'From time',
                          value: _bwhFrom,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _bwhFrom ?? TimeOfDay.now(),
                            );
                            if (t != null) setState(() => _bwhFrom = t);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTappableTimeField(
                          label: 'To time',
                          value: _bwhTo,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _bwhTo ?? TimeOfDay.now(),
                            );
                            if (t != null) setState(() => _bwhTo = t);
                          },
                        ),
                      ),
                      if (tabsData != null && !tabsData.wholesaleRetail.isWeekClosed) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              (_bwhFrom != null &&
                                  _bwhTo != null &&
                                  !_isSavingBWH)
                              ? () async {
                                  String tod(TimeOfDay t) =>
                                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                  setState(() => _isSavingBWH = true);
                                  await context
                                      .read<AdminPro>()
                                      .savePerformanceMetric(
                                        widget.account.id,
                                        day: tabsData.day?.date ?? '',
                                        metric: 'average_reply_time_minutes',
                                        fromTime: tod(_bwhFrom!),
                                        toTime: tod(_bwhTo!),
                                      );
                                  if (mounted)
                                    setState(() => _isSavingBWH = false);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            disabledBackgroundColor: const Color(
                              0xFFFBBF24,
                            ).withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSavingBWH
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black54,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.save, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Save',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Business working hours this week: ${formatTimeStr(data.businessWorkingHourFromTime)} to ${formatTimeStr(data.businessWorkingHourToTime)} \u2713',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Estimated Earnings
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Earnings This Week',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Calculated from claimed wholesale and retail entries. Final amount is confirmed when admin closes week.',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                            ),
                            children: [
                              TextSpan(
                                text:
                                    provider
                                        .currentPaymentResponse
                                        ?.data
                                        ?.currentLevel ??
                                    'Level',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                  fontSize: 10,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' payout % applies to each rate card\u2019s client price for your account type. Volume tiers use this week\u2019s claim counts separately. ${data.weekWholesaleClaimCount} wholesale, ${data.weekRetailClaimCount} retail.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        children: data.days
                            .map((day) => _buildMobileDayRow(day))
                            .toList(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      children: [
                        _buildMobileTotalRow(
                          'Wholesale jobs total',
                          '(${data.weekWholesaleClaimCount} \u00d7 avg)',
                          formatCurrency(data.wholesaleTotal),
                          valueColor: const Color(0xFF059669),
                        ),
                        const SizedBox(height: 6),
                        _buildMobileTotalRow(
                          'Retail jobs total',
                          '(${data.weekRetailClaimCount} \u00d7 avg)',
                          formatCurrency(data.retailTotal),
                          valueColor: const Color(0xFF059669),
                        ),
                        const SizedBox(height: 6),
                        _buildMobileTotalRow(
                          'Total Earnings (Mon-Sun)',
                          null,
                          formatCurrency(data.baseTotal),
                        ),
                        const SizedBox(height: 6),
                        _buildMobileTotalRow(
                          'Floor top-up',
                          null,
                          formatCurrency(data.floorTopup),
                          valueColor: const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estimated Total',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        Text(
                          formatCurrency(data.estimatedTotal),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Final amount confirmed after admin closes and approves the week.',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentTab() {
    return Consumer<AdminPro>(
      builder: (context, provider, child) {
        if (provider.paymentCompensationLoad) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32.0), child: showLoader()),
          );
        }

        final tabsData = provider.currentPaymentResponse?.tabs;
        final data = tabsData?.payment;
        if (tabsData == null || data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No payment data available."),
            ),
          );
        }

        String formatCurrency(num val) => '\$${val.toStringAsFixed(2)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSummaryCard(
              title: 'TOTAL PAID (ALL TIME)',
              amount: formatCurrency(data.summary.totalPaid),
              borderColor: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              title: 'THIS WEEK (PENDING)',
              amount: formatCurrency(data.summary.pendingThisWeek),
              borderColor: const Color(0xFFFDE047),
            ),
            const SizedBox(height: 12),
            _buildSummaryCard(
              title: 'AVG WEEKLY',
              amount: formatCurrency(data.summary.weeklyAverage),
              borderColor: const Color(0xFFBFDBFE),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT HISTORY',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...data.rows.map((row) {
                    final isPending = row.status.toLowerCase() == 'pending';
                    final bgColor = isPending
                        ? const Color(0xFFFEFCE8)
                        : const Color(0xFFF0FDF4);
                    final borderColor = isPending
                        ? const Color(0xFFFEF08A)
                        : const Color(0xFF86EFAC);
                    final badgeColor = isPending
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFD1FAE5);
                    final badgeTextColor = isPending
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  row.weekLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    row.status,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: badgeTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Divider(height: 20, color: borderColor),
                            _buildMobileDetailRow(
                              'EARNINGS',
                              formatCurrency(row.base),
                              false,
                            ),
                            const SizedBox(height: 6),
                            _buildMobileDetailRow(
                              'BONUS',
                              '+${formatCurrency(row.bonus)}',
                              false,
                            ),
                            const SizedBox(height: 6),
                            _buildMobileDetailRow(
                              'FLOOR',
                              '+${formatCurrency(row.floor)}',
                              false,
                            ),
                            const SizedBox(height: 6),
                            _buildMobileDetailRow(
                              'TOTAL',
                              formatCurrency(row.total),
                              true,
                            ),
                            const SizedBox(height: 6),
                            _buildMobileDetailRow(
                              'METHOD',
                              row.method.isNotEmpty ? row.method : '–',
                              false,
                            ),
                            const SizedBox(height: 6),
                            _buildMobileDetailRow(
                              'TRANSACTION',
                              row.transaction.isNotEmpty
                                  ? row.transaction
                                  : '–',
                              false,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (isPending)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF22C55E,
                                        ),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: Text(
                                        'Pay',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isPending) const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {},
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      'Details',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Pagination
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          (data.pagination?.total ?? 0) == 0
                              ? "No payments logged"
                              : "Showing ${data.pagination?.from ?? 1}-${data.pagination?.to ?? data.rows.length} of ${data.pagination?.total ?? data.rows.length} entries",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      _buildTablePagination(
                        currentPage: data.pagination?.currentPage ?? 1,
                        totalPages: data.pagination?.lastPage ?? 1,
                        onPageChanged: (page) {
                          context.read<AdminPro>().getStaffPaymentCompensation(
                            widget.account.id,
                            day: tabsData.selectedDay,
                            paymentPage: page,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String amount,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDetailRow(String label, String value, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? const Color(0xFFD97706) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildWholesaleRetailTab() {
    return Consumer<AdminPro>(
      builder: (context, provider, child) {
        if (provider.paymentCompensationLoad) {
          return Center(
            child: Padding(padding: EdgeInsets.all(32.0), child: showLoader()),
          );
        }

        final tabsData = provider.currentPaymentResponse?.tabs;
        final data = tabsData?.wholesaleRetail;
        if (tabsData == null || data == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No wholesale & retail data available."),
            ),
          );
        }

        final selectedDayStr = _formatSingleDay(tabsData.selectedDay);

        // Filter logic could be applied here if needed
        final entries = data.entries;
        final availableEntries = entries
            .where((e) => e.status.toLowerCase() == 'available')
            .toList();
        final allAvailableIds = availableEntries.map((e) => e.id).toSet();
        final bool isAllSelected =
            availableEntries.isNotEmpty &&
            _selectedWholesaleIds.containsAll(allAvailableIds) &&
            _selectedWholesaleIds.length == allAvailableIds.length;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                selectedDayStr,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Claim the wholesale and retail entries you worked on today.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              // Action Buttons Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildOutlinedBtn(
                    '< Prev',
                    Colors.black87,
                    const Color(0xFFE2E8F0),
                    onPressed:
                        tabsData.day?.previous != null &&
                            tabsData.day!.previous.isNotEmpty
                        ? () {
                            setState(() {
                              _selectedType = 'All types';
                              _selectedDay = 'All days';
                              _selectedStatus = 'All statuses';
                            });
                            context
                                .read<AdminPro>()
                                .getStaffPaymentCompensation(
                                  widget.account.id,
                                  day: tabsData.day!.previous,
                                );
                          }
                        : null,
                  ),
                  _buildOutlinedBtn(
                    'Today',
                    const Color(0xFFD97706),
                    const Color(0xFFFBBF24),
                    isSelected: tabsData.day?.isToday ?? true,
                    onPressed: () {
                      setState(() {
                        _selectedType = 'All types';
                        _selectedDay = 'All days';
                        _selectedStatus = 'All statuses';
                      });
                      context.read<AdminPro>().getStaffPaymentCompensation(
                        widget.account.id,
                        day: tabsData.day?.today,
                      );
                    },
                  ),
                  _buildOutlinedBtn(
                    'Next >',
                    Colors.black87,
                    const Color(0xFFE2E8F0),
                    onPressed:
                        tabsData.day?.next != null &&
                            tabsData.day!.next.isNotEmpty
                        ? () {
                            setState(() {
                              _selectedType = 'All types';
                              _selectedDay = 'All days';
                              _selectedStatus = 'All statuses';
                            });
                            context
                                .read<AdminPro>()
                                .getStaffPaymentCompensation(
                                  widget.account.id,
                                  day: tabsData.day!.next,
                                );
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDayOperationLoading
                      ? null
                      : (data.isDayClosed
                          ? (data.isWeekClosed
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Open Day'),
                                      content: const Text('Are you sure you want to open this day?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(dialogCtx);
                                            setState(() => _isDayOperationLoading = true);
                                            try {
                                              await context.read<AdminPro>().openDay(
                                                widget.account.id,
                                                tabsData.day?.date ?? '',
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() => _isDayOperationLoading = false);
                                              }
                                            }
                                          },
                                          child: const Text('Open'),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                          : () {
                              showDialog(
                                context: context,
                                builder: (dialogCtx) => AlertDialog(
                                  title: const Text('Close Day'),
                                  content: const Text('Are you sure you want to close this day?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(dialogCtx);
                                        setState(() => _isDayOperationLoading = true);
                                        try {
                                          await context.read<AdminPro>().closeDay(
                                            widget.account.id,
                                            tabsData.day?.date ?? '',
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isDayOperationLoading = false);
                                          }
                                        }
                                      },
                                      child: const Text('Close', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: data.isDayClosed
                        ? const Color(0xFF10B981)
                        : const Color(0xFFFBBF24),
                    foregroundColor:
                        data.isDayClosed ? Colors.white : Colors.black87,
                    disabledBackgroundColor: _isDayOperationLoading
                        ? (data.isDayClosed ? const Color(0xFF10B981) : const Color(0xFFFBBF24))
                        : Colors.grey.shade300,
                    disabledForegroundColor: _isDayOperationLoading
                        ? (data.isDayClosed ? Colors.white70 : Colors.black54)
                        : Colors.grey.shade500,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _isDayOperationLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: data.isDayClosed ? Colors.white : Colors.black87,
                          ),
                        )
                      : Icon(
                          data.isDayClosed ? Icons.lock_open : Icons.lock,
                          size: 14,
                        ),
                  label: Text(
                    _isDayOperationLoading
                        ? (data.isDayClosed ? 'Opening Day...' : 'Closing Day...')
                        : (data.isDayClosed
                            ? (data.isWeekClosed ? 'Day Closed' : 'Open Day')
                            : 'Close Day'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Info Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info,
                        color: Color(0xFF3B82F6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Claim the wholesale or retail entries you worked on today. Each entry can only be claimed by one specialist of each type. If already claimed by another specialist it will show as locked.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Dropdowns
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDropdown(
                    _selectedType,
                    ['All types', 'Wholesale', 'Retail'],
                    (v) {
                      setState(() => _selectedType = v!);
                      _updateWholesaleRetailFilters(type: v);
                    },
                  ),
                  _buildDropdown(
                    _selectedDay,
                    ['All days', 'Today', 'Yesterday'],
                    (v) {
                      setState(() => _selectedDay = v!);
                      _updateWholesaleRetailFilters(dayFilter: v);
                    },
                  ),
                  _buildDropdown(
                    _selectedStatus,
                    ['All statuses', 'Available', 'Claimed'],
                    (v) {
                      setState(() => _selectedStatus = v!);
                      _updateWholesaleRetailFilters(status: v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Selection Bar
              if (!(data.isDayClosed || data.isWeekClosed) && allAvailableIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: isAllSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedWholesaleIds.addAll(allAvailableIds);
                                } else {
                                  _selectedWholesaleIds.clear();
                                }
                              });
                            },
                            activeColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select all visible available',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Text(
                            '${_selectedWholesaleIds.length} selected',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedWholesaleIds.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _selectedWholesaleIds.isNotEmpty
                              ? () async {
                                  final success = await context
                                      .read<AdminPro>()
                                      .claimEntriesBulk(
                                        widget.account.id,
                                        _selectedWholesaleIds.toList(),
                                        tabsData.selectedDay,
                                      );
                                  if (success) {
                                    setState(() {
                                      _selectedWholesaleIds.clear();
                                    });
                                  }
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6EE7B7),
                            disabledBackgroundColor: const Color(0xFFA7F3D0),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 12),
                          label: Text(
                            'Claim',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // List of Cards (Mobile alternative to table)
              ...entries.map((entry) {
                final isAvailable = entry.status.toLowerCase() == 'available';
                final isClaimed = entry.status.toLowerCase() == 'claimed';
                final isLocked = entry.lockedBy != null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isAvailable && !isLocked && !(data.isDayClosed || data.isWeekClosed))
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _selectedWholesaleIds.contains(entry.id),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedWholesaleIds.add(entry.id);
                                    } else {
                                      _selectedWholesaleIds.remove(entry.id);
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                          else if (isLocked)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.lock,
                                color: Color(0xFF64748B),
                                size: 16,
                              ),
                            )
                          else
                            const SizedBox(
                              width: 24,
                              child: Text(
                                '—',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _formatEntryDate(entry.date),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: entry.type.toLowerCase() == 'wholesale'
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.type,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: entry.type.toLowerCase() == 'wholesale'
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMobileField('CLIENT', entry.client),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMobileField('ORDER #', entry.orderNo),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMobileField('JOB #', entry.jobNo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (isAvailable && !isLocked)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (data.isDayClosed || data.isWeekClosed)
                                ? null
                                : () async {
                                    await context.read<AdminPro>().claimEntry(
                                          widget.account.id,
                                          entry.id,
                                          tabsData.selectedDay,
                                        );
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF10B981)),
                              foregroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 14),
                            label: Text(
                              'Claim',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else if (isClaimed && !isLocked)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF10B981),
                                  ),
                                  foregroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 14),
                                label: Text(
                                  'Claimed',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: (data.isDayClosed || data.isWeekClosed)
                                    ? null
                                    : () async {
                                        await context.read<AdminPro>().unclaimEntry(
                                              widget.account.id,
                                              entry.id,
                                              tabsData.selectedDay,
                                            );
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFEF4444),
                                  ),
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'Undo',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (isLocked)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Locked by ${entry.lockedBy}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (data.pagination?.total ?? 0) == 0
                                ? ""
                                : "Showing ${data.pagination?.from ?? 1}-${data.pagination?.to ?? entries.length} of ${data.pagination?.total ?? entries.length} entries today",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        _buildTablePagination(
                          currentPage: data.pagination?.currentPage ?? 1,
                          totalPages: data.pagination?.lastPage ?? 1,
                          onPageChanged: (page) {
                            _updateWholesaleRetailFilters(page: page);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileDayRow(PerformanceDay day) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatEntryDate(day.date),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wholesale jobs',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '(${day.wholesaleCount})',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Retail jobs',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '(${day.retailCount})',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  Widget _buildMobileTotalRow(
    String label,
    String? sub,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.black87),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildOutlinedBtn(
    String text,
    Color textColor,
    Color borderColor, {
    bool isSelected = false,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: borderColor, width: 1.5),
        backgroundColor: isSelected ? const Color(0xFFFEF3C7) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildTablePagination({
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageCircle(
          icon: Icons.keyboard_double_arrow_left,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(1),
        ),
        const SizedBox(width: 4),
        _pageCircle(
          icon: Icons.chevron_left,
          enabled: currentPage > 1,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        const SizedBox(width: 8),
        ...pages.map((p) {
          if (p == -1) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("...", style: TextStyle(color: Colors.grey)),
            );
          }
          final bool isActive = p == currentPage;
          return GestureDetector(
            onTap: () => onPageChanged(p),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFBBF24) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  "$p",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isActive ? Colors.black87 : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
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
        const SizedBox(width: 4),
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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

  Widget _buildDropdown(
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF64748B),
            size: 16,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMobileField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTimeField(String label, [String? value]) {
    String displayTime = '--:-- --';
    if (value != null) {
      final int minutes = int.tryParse(value) ?? 0;
      final int h = minutes ~/ 60;
      final int m = minutes % 60;
      final String ampm = h >= 12 ? 'PM' : 'AM';
      final int displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      displayTime =
          '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayTime,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: value != null
                      ? Colors.black87
                      : const Color(0xFF94A3B8),
                ),
              ),
              const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatEntryDate(String dateStr) {
    if (dateStr.isEmpty) return dateStr;
    try {
      return Frmtr.frmtDate(date: dateStr, outForm: 'EEE MMM dd');
    } catch (e) {
      return dateStr;
    }
  }

  String formatTimeStr(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '—';
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return timeStr;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final hr = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';
      return '${hr.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeStr;
    }
  }

  Widget _buildTappableTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    final hrStr = value != null
        ? (value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod)
              .toString()
              .padLeft(2, '0')
        : '';
    final display = value != null
        ? '$hrStr:${value.minute.toString().padLeft(2, '0')} ${value.period == DayPeriod.am ? 'AM' : 'PM'}'
        : '--:-- --';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  display,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: value != null
                        ? Colors.black87
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
