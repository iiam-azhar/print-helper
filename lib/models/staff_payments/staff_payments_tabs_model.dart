class StaffPaymentResponseModel {
  final StaffPaymentCompensationModel? data;
  final StaffPaymentTabsModel? tabs;

  StaffPaymentResponseModel({
    this.data,
    this.tabs,
  });

  factory StaffPaymentResponseModel.fromJson(Map<String, dynamic> json) {
    return StaffPaymentResponseModel(
      data: json['data'] != null ? StaffPaymentCompensationModel.fromJson(json['data']) : null,
      tabs: json['tabs'] != null ? StaffPaymentTabsModel.fromJson(json['tabs']) : null,
    );
  }
}

class PaymentPagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int from;
  final int to;

  PaymentPagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.from,
    required this.to,
  });

  factory PaymentPagination.fromJson(Map<String, dynamic> json) {
    return PaymentPagination(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      total: json['total'] ?? 0,
      from: json['from'] ?? 0,
      to: json['to'] ?? 0,
    );
  }
}

class StaffPaymentDayInfo {
  final String date;
  final String label;
  final bool isCurrent;
  final String previous;
  final String next;
  final String today;
  final bool isToday;

  StaffPaymentDayInfo({
    required this.date,
    required this.label,
    required this.isCurrent,
    required this.previous,
    required this.next,
    required this.today,
    required this.isToday,
  });

  factory StaffPaymentDayInfo.fromJson(Map<String, dynamic> json) {
    return StaffPaymentDayInfo(
      date: json['date'] ?? '',
      label: json['label'] ?? '',
      isCurrent: json['is_current'] ?? false,
      previous: json['previous'] ?? '',
      next: json['next'] ?? '',
      today: json['today'] ?? '',
      isToday: json['is_today'] ?? false,
    );
  }
}

class StaffPaymentTabsModel {
  final String selectedDay;
  final StaffPaymentDayInfo? day;
  final WholesaleRetailTab wholesaleRetail;
  final PerformanceTab performance;
  final PaymentTab payment;

  StaffPaymentTabsModel({
    required this.selectedDay,
    this.day,
    required this.wholesaleRetail,
    required this.performance,
    required this.payment,
  });

  factory StaffPaymentTabsModel.fromJson(Map<String, dynamic> json) {
    return StaffPaymentTabsModel(
      selectedDay: json['selected_day'] ?? '',
      day: json['day'] != null ? StaffPaymentDayInfo.fromJson(json['day']) : null,
      wholesaleRetail: WholesaleRetailTab.fromJson(json['wholesale_retail'] ?? {}),
      performance: PerformanceTab.fromJson(json['performance'] ?? {}),
      payment: PaymentTab.fromJson(json['payment'] ?? {}),
    );
  }
}

class WholesaleRetailTab {
  final bool isDayClosed;
  final bool isWeekClosed;
  final int totalToday;
  final int claimedMine;
  final List<WholesaleRetailEntry> entries;
  final PaymentPagination? pagination;

  WholesaleRetailTab({
    required this.isDayClosed,
    required this.isWeekClosed,
    required this.totalToday,
    required this.claimedMine,
    required this.entries,
    this.pagination,
  });

  factory WholesaleRetailTab.fromJson(Map<String, dynamic> json) {
    return WholesaleRetailTab(
      isDayClosed: json['is_day_closed'] ?? false,
      isWeekClosed: json['is_week_closed'] ?? false,
      totalToday: json['total_today'] ?? 0,
      claimedMine: json['claimed_mine'] ?? 0,
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((e) => WholesaleRetailEntry.fromJson(e))
          .toList(),
      pagination: json['pagination'] != null ? PaymentPagination.fromJson(json['pagination']) : null,
    );
  }
}

class WholesaleRetailEntry {
  final int id;
  final String date;
  final String client;
  final String type;
  final String pricingMode;
  final String orderNo;
  final String jobNo;
  final dynamic compensation;
  final String status;
  final String? lockedBy;

  WholesaleRetailEntry({
    required this.id,
    required this.date,
    required this.client,
    required this.type,
    required this.pricingMode,
    required this.orderNo,
    required this.jobNo,
    required this.compensation,
    required this.status,
    this.lockedBy,
  });

  factory WholesaleRetailEntry.fromJson(Map<String, dynamic> json) {
    return WholesaleRetailEntry(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      client: json['client'] ?? '',
      type: json['type'] ?? '',
      pricingMode: json['pricing_mode'] ?? '',
      orderNo: json['order_no']?.toString() ?? '',
      jobNo: json['job_no']?.toString() ?? '',
      compensation: json['compensation'],
      status: json['status'] ?? '',
      lockedBy: json['locked_by']?.toString(),
    );
  }
}

class PerformanceTab {
  final String weekStart;
  final String weekEnd;
  final List<PerformanceDay> days;
  final num baseTotal;
  final num wholesaleTotal;
  final num retailTotal;
  final num bonusTotal;
  final num floorTopup;
  final num estimatedTotal;
  final int weekWholesaleClaimCount;
  final int weekRetailClaimCount;
  final int zeroComplaintsStreakDays;
  final int fourWeekStreakProgress;
  final int missedInteractions;
  final int? missedInteractionsHours;
  final int? missedInteractionsMinutes;
  final int interactionRepliedWithinSlaCount;
  final int interactionMissedCount;
  final num averageReplyTimeMinutes;
  final num? businessWorkingHourFromMinutes;
  final num? businessWorkingHourToMinutes;
  final String? businessWorkingHourFromTime;
  final String? businessWorkingHourToTime;

  PerformanceTab({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.baseTotal,
    required this.wholesaleTotal,
    required this.retailTotal,
    required this.bonusTotal,
    required this.floorTopup,
    required this.estimatedTotal,
    required this.weekWholesaleClaimCount,
    required this.weekRetailClaimCount,
    required this.zeroComplaintsStreakDays,
    required this.fourWeekStreakProgress,
    required this.missedInteractions,
    this.missedInteractionsHours,
    this.missedInteractionsMinutes,
    required this.interactionRepliedWithinSlaCount,
    required this.interactionMissedCount,
    required this.averageReplyTimeMinutes,
    this.businessWorkingHourFromMinutes,
    this.businessWorkingHourToMinutes,
    this.businessWorkingHourFromTime,
    this.businessWorkingHourToTime,
  });

  factory PerformanceTab.fromJson(Map<String, dynamic> json) {
    return PerformanceTab(
      weekStart: json['week_start'] ?? '',
      weekEnd: json['week_end'] ?? '',
      days: (json['days'] as List<dynamic>? ?? [])
          .map((e) => PerformanceDay.fromJson(e))
          .toList(),
      baseTotal: json['base_total'] ?? 0,
      wholesaleTotal: json['wholesale_total'] ?? 0,
      retailTotal: json['retail_total'] ?? 0,
      bonusTotal: json['bonus_total'] ?? 0,
      floorTopup: json['floor_topup'] ?? 0,
      estimatedTotal: json['estimated_total'] ?? 0,
      weekWholesaleClaimCount: json['week_wholesale_claim_count'] ?? 0,
      weekRetailClaimCount: json['week_retail_claim_count'] ?? 0,
      zeroComplaintsStreakDays: json['zero_complaints_streak_days'] ?? 0,
      fourWeekStreakProgress: json['four_week_streak_progress'] ?? 0,
      missedInteractions: json['missed_interactions'] ?? 0,
      missedInteractionsHours: json['missed_interactions_hours'],
      missedInteractionsMinutes: json['missed_interactions_minutes'],
      interactionRepliedWithinSlaCount: json['interaction_replied_within_sla_count'] ?? 0,
      interactionMissedCount: json['interaction_missed_count'] ?? 0,
      averageReplyTimeMinutes: json['average_reply_time_minutes'] ?? 0,
      businessWorkingHourFromMinutes: json['business_working_hour_from_minutes'],
      businessWorkingHourToMinutes: json['business_working_hour_to_minutes'],
      businessWorkingHourFromTime: json['business_working_hour_from_time'],
      businessWorkingHourToTime: json['business_working_hour_to_time'],
    );
  }
}

class PerformanceDay {
  final String date;
  final int wholesaleCount;
  final num wholesaleTotal;
  final num wholesaleUnit;
  final int retailCount;
  final num retailTotal;
  final num retailUnit;
  final num dayTotal;

  PerformanceDay({
    required this.date,
    required this.wholesaleCount,
    required this.wholesaleTotal,
    required this.wholesaleUnit,
    required this.retailCount,
    required this.retailTotal,
    required this.retailUnit,
    required this.dayTotal,
  });

  factory PerformanceDay.fromJson(Map<String, dynamic> json) {
    return PerformanceDay(
      date: json['date'] ?? '',
      wholesaleCount: json['wholesale_count'] ?? 0,
      wholesaleTotal: json['wholesale_total'] ?? 0,
      wholesaleUnit: json['wholesale_unit'] ?? 0,
      retailCount: json['retail_count'] ?? 0,
      retailTotal: json['retail_total'] ?? 0,
      retailUnit: json['retail_unit'] ?? 0,
      dayTotal: json['day_total'] ?? 0,
    );
  }
}

class PaymentTab {
  final List<PaymentRow> rows;
  final PaymentSummary summary;
  final PaymentPagination? pagination;

  PaymentTab({
    required this.rows,
    required this.summary,
    this.pagination,
  });

  factory PaymentTab.fromJson(Map<String, dynamic> json) {
    return PaymentTab(
      rows: (json['rows'] as List<dynamic>? ?? [])
          .map((e) => PaymentRow.fromJson(e))
          .toList(),
      summary: PaymentSummary.fromJson(json['summary'] ?? {}),
      pagination: json['pagination'] != null ? PaymentPagination.fromJson(json['pagination']) : null,
    );
  }
}

class PaymentRow {
  final int id;
  final String weekLabel;
  final String weekStart;
  final String weekEnd;
  final num base;
  final num bonus;
  final num floor;
  final num total;
  final String method;
  final String transaction;
  final String status;
  final PaymentDetails details;

  PaymentRow({
    required this.id,
    required this.weekLabel,
    required this.weekStart,
    required this.weekEnd,
    required this.base,
    required this.bonus,
    required this.floor,
    required this.total,
    required this.method,
    required this.transaction,
    required this.status,
    required this.details,
  });

  factory PaymentRow.fromJson(Map<String, dynamic> json) {
    return PaymentRow(
      id: json['id'] ?? 0,
      weekLabel: json['week_label'] ?? '',
      weekStart: json['week_start'] ?? '',
      weekEnd: json['week_end'] ?? '',
      base: json['base'] ?? 0,
      bonus: json['bonus'] ?? 0,
      floor: json['floor'] ?? 0,
      total: json['total'] ?? 0,
      method: json['method'] ?? '',
      transaction: json['transaction'] ?? '',
      status: json['status'] ?? '',
      details: PaymentDetails.fromJson(json['details'] ?? {}),
    );
  }
}

class PaymentDetails {
  final List<PaymentDayDetails> days;
  final PaymentSummaryDetails summary;
  final List<dynamic> bonuses;

  PaymentDetails({
    required this.days,
    required this.summary,
    required this.bonuses,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      days: (json['days'] as List<dynamic>? ?? [])
          .map((e) => PaymentDayDetails.fromJson(e))
          .toList(),
      summary: PaymentSummaryDetails.fromJson(json['summary'] ?? {}),
      bonuses: json['bonuses'] ?? [],
    );
  }
}

class PaymentDayDetails {
  final String date;
  final String label;
  final int wholesaleCount;
  final num wholesaleUnit;
  final num wholesaleTotal;
  final int retailCount;
  final num retailUnit;
  final num retailTotal;
  final num dayTotal;

  PaymentDayDetails({
    required this.date,
    required this.label,
    required this.wholesaleCount,
    required this.wholesaleUnit,
    required this.wholesaleTotal,
    required this.retailCount,
    required this.retailUnit,
    required this.retailTotal,
    required this.dayTotal,
  });

  factory PaymentDayDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDayDetails(
      date: json['date'] ?? '',
      label: json['label'] ?? '',
      wholesaleCount: json['wholesale_count'] ?? 0,
      wholesaleUnit: json['wholesale_unit'] ?? 0,
      wholesaleTotal: json['wholesale_total'] ?? 0,
      retailCount: json['retail_count'] ?? 0,
      retailUnit: json['retail_unit'] ?? 0,
      retailTotal: json['retail_total'] ?? 0,
      dayTotal: json['day_total'] ?? 0,
    );
  }
}

class PaymentSummaryDetails {
  final num baseTotal;
  final num bonusTotal;
  final num floorTopup;
  final num total;
  final int wholesaleCount;
  final num wholesaleUnit;
  final num wholesaleTotal;
  final int retailCount;
  final num retailUnit;
  final num retailTotal;

  PaymentSummaryDetails({
    required this.baseTotal,
    required this.bonusTotal,
    required this.floorTopup,
    required this.total,
    required this.wholesaleCount,
    required this.wholesaleUnit,
    required this.wholesaleTotal,
    required this.retailCount,
    required this.retailUnit,
    required this.retailTotal,
  });

  factory PaymentSummaryDetails.fromJson(Map<String, dynamic> json) {
    return PaymentSummaryDetails(
      baseTotal: json['base_total'] ?? 0,
      bonusTotal: json['bonus_total'] ?? 0,
      floorTopup: json['floor_topup'] ?? 0,
      total: json['total'] ?? 0,
      wholesaleCount: json['wholesale_count'] ?? 0,
      wholesaleUnit: json['wholesale_unit'] ?? 0,
      wholesaleTotal: json['wholesale_total'] ?? 0,
      retailCount: json['retail_count'] ?? 0,
      retailUnit: json['retail_unit'] ?? 0,
      retailTotal: json['retail_total'] ?? 0,
    );
  }
}

class PaymentSummary {
  final num totalPaid;
  final num pendingThisWeek;
  final num weeklyAverage;

  PaymentSummary({
    required this.totalPaid,
    required this.pendingThisWeek,
    required this.weeklyAverage,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      totalPaid: json['total_paid'] ?? 0,
      pendingThisWeek: json['pending_this_week'] ?? 0,
      weeklyAverage: json['weekly_average'] ?? 0,
    );
  }
}

class StaffPaymentCompensationModel {
  final int accountId;
  final int? accountTypeId;
  final String? accountTypeName;
  final String currentLevel;
  final Map<String, int> levelFloors;
  final WeeklyVolumes weeklyVolumes;
  final Map<String, CompensationLevel> levels;

  StaffPaymentCompensationModel({
    required this.accountId,
    this.accountTypeId,
    this.accountTypeName,
    required this.currentLevel,
    required this.levelFloors,
    required this.weeklyVolumes,
    required this.levels,
  });

  factory StaffPaymentCompensationModel.fromJson(Map<String, dynamic> json) {
    Map<String, int> floors = {};
    if (json['level_floors'] != null) {
      (json['level_floors'] as Map<String, dynamic>).forEach((key, value) {
        floors[key] = int.tryParse(value.toString()) ?? 0;
      });
    }

    Map<String, CompensationLevel> lvls = {};
    if (json['levels'] != null) {
      (json['levels'] as Map<String, dynamic>).forEach((key, value) {
        lvls[key] = CompensationLevel.fromJson(value);
      });
    }

    return StaffPaymentCompensationModel(
      accountId: json['account_id'] ?? 0,
      accountTypeId: json['account_type_id'],
      accountTypeName: json['account_type_name'],
      currentLevel: json['current_level'] ?? '',
      levelFloors: floors,
      weeklyVolumes: WeeklyVolumes.fromJson(json['weekly_volumes'] ?? {}),
      levels: lvls,
    );
  }
}

class WeeklyVolumes {
  final List<int> wholesale;
  final List<int> retail;

  WeeklyVolumes({required this.wholesale, required this.retail});

  factory WeeklyVolumes.fromJson(Map<String, dynamic> json) {
    return WeeklyVolumes(
      wholesale: (json['wholesale'] as List<dynamic>? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList(),
      retail: (json['retail'] as List<dynamic>? ?? []).map((e) => int.tryParse(e.toString()) ?? 0).toList(),
    );
  }
}

class CompensationLevel {
  final String name;
  final String border;
  final String title;
  final List<List<String>> wholesale;
  final List<List<String>> retail;

  CompensationLevel({
    required this.name,
    required this.border,
    required this.title,
    required this.wholesale,
    required this.retail,
  });

  factory CompensationLevel.fromJson(Map<String, dynamic> json) {
    List<List<String>> wList = [];
    if (json['wholesale'] != null) {
      for (var row in json['wholesale']) {
        wList.add((row as List<dynamic>).map((e) => e.toString()).toList());
      }
    }
    List<List<String>> rList = [];
    if (json['retail'] != null) {
      for (var row in json['retail']) {
        rList.add((row as List<dynamic>).map((e) => e.toString()).toList());
      }
    }
    return CompensationLevel(
      name: json['name'] ?? '',
      border: json['border'] ?? '',
      title: json['title'] ?? '',
      wholesale: wList,
      retail: rList,
    );
  }
}
