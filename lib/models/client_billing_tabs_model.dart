class ClientBillingTabsModel {
  final List<String> tabs;
  final ClientBillingClientModel client;
  final ClientBillingWeekModel week;
  final ClientBillingWeeklyVolumeModel weeklyVolume;
  final ClientBillingModel billing;
  final ClientBillingDiscountsCreditsModel discountsCredits;
  final ClientBillingMyReferralsModel myReferrals;
  final ClientBillingUsageModel usage;

  const ClientBillingTabsModel({
    required this.tabs,
    required this.client,
    required this.week,
    required this.weeklyVolume,
    required this.billing,
    required this.discountsCredits,
    required this.myReferrals,
    required this.usage,
  });

  factory ClientBillingTabsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return ClientBillingTabsModel(
      tabs: data['tabs'] is List ? (data['tabs'] as List<dynamic>).map((e) => e.toString()).toList() : [],
      client: ClientBillingClientModel.fromJson(data['client'] ?? {}),
      week: ClientBillingWeekModel.fromJson(data['week'] ?? {}),
      weeklyVolume: ClientBillingWeeklyVolumeModel.fromJson(data['weekly_volume'] ?? {}),
      billing: ClientBillingModel.fromJson(data['billing'] ?? {}),
      discountsCredits: ClientBillingDiscountsCreditsModel.fromJson(data['discounts_credits'] ?? {}),
      myReferrals: ClientBillingMyReferralsModel.fromJson(data['my_referrals'] ?? {}),
      usage: ClientBillingUsageModel.fromJson(data['usage'] ?? {}),
    );
  }

  ClientBillingTabsModel copyWithBilling(ClientBillingModel updatedBilling) {
    return ClientBillingTabsModel(
      tabs: tabs,
      client: client,
      week: week,
      weeklyVolume: weeklyVolume,
      billing: updatedBilling,
      discountsCredits: discountsCredits,
      myReferrals: myReferrals,
      usage: usage,
    );
  }
}

class ClientBillingClientModel {
  final int id;
  final String companyName;
  final bool status;
  final String companyType;
  final String clientSince;
  final String imageUrl;

  const ClientBillingClientModel({
    required this.id,
    required this.companyName,
    required this.status,
    required this.companyType,
    required this.clientSince,
    required this.imageUrl,
  });

  factory ClientBillingClientModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingClientModel(
      id: _toInt(json['id']),
      companyName: (json['company_name'] ?? '').toString(),
      status: json['status'] == true || json['status'] == 1,
      companyType: (json['company_type'] ?? '').toString(),
      clientSince: (json['client_since'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }
}

class ClientBillingWeekModel {
  final String start;
  final String end;
  final String label;
  final bool isCurrent;
  final bool isClosed;
  final String previous;
  final String next;

  const ClientBillingWeekModel({
    required this.start,
    required this.end,
    required this.label,
    required this.isCurrent,
    required this.isClosed,
    required this.previous,
    required this.next,
  });

  factory ClientBillingWeekModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingWeekModel(
      start: (json['start'] ?? '').toString(),
      end: (json['end'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      isCurrent: json['is_current'] == true || json['is_current'] == 1,
      isClosed: json['is_closed'] == true || json['is_closed'] == 1,
      previous: (json['previous'] ?? '').toString(),
      next: (json['next'] ?? '').toString(),
    );
  }
}

class ClientBillingWeeklyVolumeModel {
  final List<ClientBillingWeeklyEntryModel> entries;
  final ClientBillingWeeklySummaryModel summary;
  final Map<String, dynamic> filters;
  final Map<String, dynamic> pagination;
  final ClientWeekChargeBreakdownModel? weekChargeBreakdown;

  const ClientBillingWeeklyVolumeModel({
    required this.entries,
    required this.summary,
    required this.filters,
    required this.pagination,
    this.weekChargeBreakdown,
  });

  factory ClientBillingWeeklyVolumeModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingWeeklyVolumeModel(
      entries: json['entries'] is List
          ? (json['entries'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientBillingWeeklyEntryModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      summary: ClientBillingWeeklySummaryModel.fromJson(json['summary'] ?? {}),
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      pagination: json['pagination'] as Map<String, dynamic>? ?? {},
      weekChargeBreakdown: json['week_charge_breakdown'] != null
          ? ClientWeekChargeBreakdownModel.fromJson(json['week_charge_breakdown'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ClientBillingWeeklyEntryModel {
  final int id;
  final String date;
  final String type;
  final String pricingMode;
  final String orderNo;
  final String jobNo;
  final double unitPrice;
  final List<dynamic> specialists;

  const ClientBillingWeeklyEntryModel({
    required this.id,
    required this.date,
    required this.type,
    required this.pricingMode,
    required this.orderNo,
    required this.jobNo,
    required this.unitPrice,
    required this.specialists,
  });

  factory ClientBillingWeeklyEntryModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingWeeklyEntryModel(
      id: _toInt(json['id']),
      date: (json['date'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      pricingMode: (json['pricing_mode'] ?? '').toString(),
      orderNo: (json['order_no'] ?? '').toString(),
      jobNo: (json['job_no'] ?? '').toString(),
      unitPrice: _toDouble(json['unit_price']),
      specialists: json['specialists'] as List<dynamic>? ?? [],
    );
  }
}

class ClientBillingWeeklySummaryModel {
  final int ordersThisWeek;
  final int jobsThisWeek;
  final int specialistsInvolved;
  final int totalEntriesWeek;
  final double thisWeekCharge;

  const ClientBillingWeeklySummaryModel({
    required this.ordersThisWeek,
    required this.jobsThisWeek,
    required this.specialistsInvolved,
    required this.totalEntriesWeek,
    required this.thisWeekCharge,
  });

  factory ClientBillingWeeklySummaryModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingWeeklySummaryModel(
      ordersThisWeek: _toInt(json['ordersThisWeek']),
      jobsThisWeek: _toInt(json['jobsThisWeek']),
      specialistsInvolved: _toInt(json['specialistsInvolved']),
      totalEntriesWeek: _toInt(json['totalEntriesWeek']),
      thisWeekCharge: _toDouble(json['thisWeekCharge']),
    );
  }
}

class ClientBillingModel {
  final String pricingMode;
  final ClientBillingOverageModel overage;
  final Map<String, dynamic> clientAddonStates;
  final Map<String, dynamic> clientSpecialistStates;
  final List<ClientBillingAddonModel> addons;
  final List<ClientBillingSpecialistRowModel> specialistRows;
  final ClientBillingTwilioUsageSummaryModel twilioUsageSummary;
  final ClientBillingSupportLinesDetailsModel supportLinesDetails;
  final double wholesalePrice;
  final double retailPrice;
  final double phPortalWeekly;
  final int ordersThisWeek;
  final int jobsThisWeek;
  final int specialistsInvolved;
  final int totalEntriesWeek;
  final double thisWeekCharge;
  final List<InvoiceHistoryItemModel> invoiceHistory;
  final Map<String, dynamic> invoiceHistoryPagination;

  const ClientBillingModel({
    required this.pricingMode,
    required this.overage,
    required this.clientAddonStates,
    required this.clientSpecialistStates,
    required this.addons,
    required this.specialistRows,
    required this.twilioUsageSummary,
    required this.supportLinesDetails,
    required this.wholesalePrice,
    required this.retailPrice,
    required this.phPortalWeekly,
    required this.ordersThisWeek,
    required this.jobsThisWeek,
    required this.specialistsInvolved,
    required this.totalEntriesWeek,
    required this.thisWeekCharge,
    required this.invoiceHistory,
    required this.invoiceHistoryPagination,
  });

  factory ClientBillingModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingModel(
      pricingMode: (json['pricing_mode'] ?? '').toString(),
      overage: ClientBillingOverageModel.fromJson(json['overage'] ?? {}),
      clientAddonStates: json['client_addon_states'] as Map<String, dynamic>? ?? {},
      clientSpecialistStates: json['client_specialist_states'] as Map<String, dynamic>? ?? {},
      addons: json['addons'] is List
          ? (json['addons'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientBillingAddonModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      specialistRows: json['specialist_rows'] is List
          ? (json['specialist_rows'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientBillingSpecialistRowModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      twilioUsageSummary: ClientBillingTwilioUsageSummaryModel.fromJson(json['twilio_usage_summary'] ?? {}),
      supportLinesDetails: ClientBillingSupportLinesDetailsModel.fromJson(json['support_lines_details'] ?? {}),
      wholesalePrice: _toDouble(json['wholesale_price']),
      retailPrice: _toDouble(json['retail_price']),
      phPortalWeekly: _toDouble(json['ph_portal_weekly']),
      ordersThisWeek: _toInt(json['orders_this_week'] ?? json['ordersThisWeek']),
      jobsThisWeek: _toInt(json['jobs_this_week'] ?? json['jobsThisWeek']),
      specialistsInvolved: _toInt(json['specialists_involved'] ?? json['specialistsInvolved']),
      totalEntriesWeek: _toInt(json['total_entries_week'] ?? json['totalEntriesWeek']),
      thisWeekCharge: _toDouble(json['this_week_charge'] ?? json['thisWeekCharge']),
      invoiceHistory: json['invoice_history'] is List
          ? (json['invoice_history'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => InvoiceHistoryItemModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      invoiceHistoryPagination: json['invoice_history_pagination'] as Map<String, dynamic>? ?? {},
    );
  }

  ClientBillingModel copyWithPricingMode(String newPricingMode) {
    return ClientBillingModel(
      pricingMode: newPricingMode,
      overage: overage,
      clientAddonStates: clientAddonStates,
      clientSpecialistStates: clientSpecialistStates,
      addons: addons,
      specialistRows: specialistRows,
      twilioUsageSummary: twilioUsageSummary,
      supportLinesDetails: supportLinesDetails,
      wholesalePrice: wholesalePrice,
      retailPrice: retailPrice,
      phPortalWeekly: phPortalWeekly,
      ordersThisWeek: ordersThisWeek,
      jobsThisWeek: jobsThisWeek,
      specialistsInvolved: specialistsInvolved,
      totalEntriesWeek: totalEntriesWeek,
      thisWeekCharge: thisWeekCharge,
      invoiceHistory: invoiceHistory,
      invoiceHistoryPagination: invoiceHistoryPagination,
    );
  }
}

class InvoiceHistoryItemModel {
  final int id;
  final String weekStart;
  final String weekEnd;
  final String weekLabel;
  final int orders;
  final int jobs;
  final double pod;
  final double addons;
  final double extras;
  final double credit;
  final double total;
  final String status;
  final bool isCurrent;

  const InvoiceHistoryItemModel({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.weekLabel,
    required this.orders,
    required this.jobs,
    required this.pod,
    required this.addons,
    required this.extras,
    required this.credit,
    required this.total,
    required this.status,
    required this.isCurrent,
  });

  factory InvoiceHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceHistoryItemModel(
      id: _toInt(json['id']),
      weekStart: (json['weekStart'] ?? '').toString(),
      weekEnd: (json['weekEnd'] ?? '').toString(),
      weekLabel: (json['weekLabel'] ?? '').toString(),
      orders: _toInt(json['orders']),
      jobs: _toInt(json['jobs']),
      pod: _toDouble(json['pod']),
      addons: _toDouble(json['addons']),
      extras: _toDouble(json['extras']),
      credit: _toDouble(json['credit']),
      total: _toDouble(json['total']),
      status: (json['status'] ?? '').toString(),
      isCurrent: json['isCurrent'] == true || json['isCurrent'] == 1,
    );
  }
}

class ClientBillingOverageModel {
  final bool enabled;
  final Map<String, dynamic> calls;
  final Map<String, dynamic> sms;
  final Map<String, dynamic> mms;

  const ClientBillingOverageModel({
    required this.enabled,
    required this.calls,
    required this.sms,
    required this.mms,
  });

  factory ClientBillingOverageModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingOverageModel(
      enabled: json['enabled'] == true || json['enabled'] == 1,
      calls: json['calls'] as Map<String, dynamic>? ?? {},
      sms: json['sms'] as Map<String, dynamic>? ?? {},
      mms: json['mms'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ClientBillingAddonModel {
  final int id;
  final String slug;
  final String name;
  final String billingUnit;
  final String included;
  final double weeklyPrice;
  final int inUseCount;
  final List<dynamic> numbers;
  final String key;
  final int addonId;
  final String label;
  final bool isActive;
  final int quantity;
  final double cost;
  final int usage;
  final Map<String, dynamic> storage;

  const ClientBillingAddonModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.billingUnit,
    required this.included,
    required this.weeklyPrice,
    required this.inUseCount,
    required this.numbers,
    required this.key,
    required this.addonId,
    required this.label,
    required this.isActive,
    required this.quantity,
    required this.cost,
    required this.usage,
    required this.storage,
  });

  factory ClientBillingAddonModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingAddonModel(
      id: _toInt(json['id']),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      billingUnit: (json['billing_unit'] ?? '').toString(),
      included: (json['included'] ?? '').toString(),
      weeklyPrice: _toDouble(json['weekly_price']),
      inUseCount: _toInt(json['in_use_count']),
      numbers: json['numbers'] is List ? (json['numbers'] as List<dynamic>) : [],
      key: (json['key'] ?? '').toString(),
      addonId: _toInt(json['addon_id'] ?? json['id']),
      label: (json['label'] ?? '').toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      quantity: _toInt(json['quantity']),
      cost: _toDouble(json['cost']),
      usage: _toInt(json['usage']),
      storage: json['storage'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ClientBillingSpecialistRowModel {
  final String key;
  final int accountTypeId;
  final String name;
  final bool isEnabled;
  final String icon;
  final String iconBg;
  final String iconText;

  const ClientBillingSpecialistRowModel({
    required this.key,
    required this.accountTypeId,
    required this.name,
    required this.isEnabled,
    required this.icon,
    required this.iconBg,
    required this.iconText,
  });

  factory ClientBillingSpecialistRowModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingSpecialistRowModel(
      key: (json['key'] ?? '').toString(),
      accountTypeId: _toInt(json['account_type_id']),
      name: (json['name'] ?? '').toString(),
      isEnabled: json['is_enabled'] == true || json['is_enabled'] == 1,
      icon: (json['icon'] ?? '').toString(),
      iconBg: (json['icon_bg'] ?? '').toString(),
      iconText: (json['icon_text'] ?? '').toString(),
    );
  }
}

class ClientBillingTwilioUsageSummaryModel {
  final int supportLines;
  final int emailConnections;
  final List<dynamic> emailConnectionEmails;
  final Map<String, dynamic> calls;
  final Map<String, dynamic> sms;
  final Map<String, dynamic> mms;
  final int storageUsedBytes;
  final double storageUsedGb;
  final String syncedAt;
  final String syncedDate;
  final String syncedTime;
  final String syncedDisplay;
  final String timezone;

  const ClientBillingTwilioUsageSummaryModel({
    required this.supportLines,
    required this.emailConnections,
    required this.emailConnectionEmails,
    required this.calls,
    required this.sms,
    required this.mms,
    required this.storageUsedBytes,
    required this.storageUsedGb,
    required this.syncedAt,
    required this.syncedDate,
    required this.syncedTime,
    required this.syncedDisplay,
    required this.timezone,
  });

  factory ClientBillingTwilioUsageSummaryModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingTwilioUsageSummaryModel(
      supportLines: _toInt(json['supportLines']),
      emailConnections: _toInt(json['emailConnections']),
      emailConnectionEmails: json['emailConnectionEmails'] is List ? (json['emailConnectionEmails'] as List<dynamic>) : [],
      calls: json['calls'] as Map<String, dynamic>? ?? {},
      sms: json['sms'] as Map<String, dynamic>? ?? {},
      mms: json['mms'] as Map<String, dynamic>? ?? {},
      storageUsedBytes: _toInt(json['storage_used_bytes']),
      storageUsedGb: _toDouble(json['storage_used_gb']),
      syncedAt: (json['synced_at'] ?? '').toString(),
      syncedDate: (json['synced_date'] ?? '').toString(),
      syncedTime: (json['synced_time'] ?? '').toString(),
      syncedDisplay: (json['synced_display'] ?? '').toString(),
      timezone: (json['timezone'] ?? '').toString(),
    );
  }
}

class ClientBillingSupportLinesDetailsModel {
  final int inUseCount;
  final List<dynamic> numbers;

  const ClientBillingSupportLinesDetailsModel({
    required this.inUseCount,
    required this.numbers,
  });

  factory ClientBillingSupportLinesDetailsModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingSupportLinesDetailsModel(
      inUseCount: _toInt(json['in_use_count']),
      numbers: json['numbers'] is List ? (json['numbers'] as List<dynamic>) : [],
    );
  }
}

class ClientBillingDiscountsCreditsModel {
  final List<ClientBillingCreditHistoryModel> items;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> pagination;

  const ClientBillingDiscountsCreditsModel({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  factory ClientBillingDiscountsCreditsModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingDiscountsCreditsModel(
      items: json['items'] is List
          ? (json['items'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientBillingCreditHistoryModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      summary: json['summary'] as Map<String, dynamic>? ?? {},
      pagination: json['pagination'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ClientBillingCreditHistoryModel {
  final int id;
  final double amount;
  final double remainingAmount;
  final String reason;
  final String createdAt;
  final String appliedTo;
  final String status;
  final bool isUsed;
  final String addedBy;

  const ClientBillingCreditHistoryModel({
    required this.id,
    required this.amount,
    required this.remainingAmount,
    required this.reason,
    required this.createdAt,
    required this.appliedTo,
    required this.status,
    required this.isUsed,
    required this.addedBy,
  });

  factory ClientBillingCreditHistoryModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingCreditHistoryModel(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      remainingAmount: _toDouble(json['remaining_amount']),
      reason: (json['reason'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      appliedTo: (json['applied_to'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      isUsed: json['is_used'] == true || json['is_used'] == 1,
      addedBy: (json['added_by'] ?? '').toString(),
    );
  }
}

class ClientBillingMyReferralsModel {
  final List<dynamic> items;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> pagination;

  const ClientBillingMyReferralsModel({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  factory ClientBillingMyReferralsModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingMyReferralsModel(
      items: json['items'] is List ? (json['items'] as List<dynamic>) : [],
      summary: json['summary'] as Map<String, dynamic>? ?? {},
      pagination: json['pagination'] as Map<String, dynamic>? ?? {},
    );
  }
}

class ClientBillingUsageModel {
  final ClientBillingUsageBreakdownModel breakdown;

  const ClientBillingUsageModel({
    required this.breakdown,
  });

  factory ClientBillingUsageModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingUsageModel(
      breakdown: ClientBillingUsageBreakdownModel.fromJson(json['breakdown'] ?? {}),
    );
  }
}

class ClientBillingUsageBreakdownModel {
  final ClientBillingUsageBreakdownServiceDetailsModel calls;
  final ClientBillingUsageBreakdownServiceDetailsModel sms;
  final ClientBillingUsageBreakdownServiceDetailsModel mms;

  const ClientBillingUsageBreakdownModel({
    required this.calls,
    required this.sms,
    required this.mms,
  });

  factory ClientBillingUsageBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingUsageBreakdownModel(
      calls: ClientBillingUsageBreakdownServiceDetailsModel.fromJson(json['calls'] ?? {}),
      sms: ClientBillingUsageBreakdownServiceDetailsModel.fromJson(json['sms'] ?? {}),
      mms: ClientBillingUsageBreakdownServiceDetailsModel.fromJson(json['mms'] ?? {}),
    );
  }
}

class ClientBillingUsageBreakdownServiceDetailsModel {
  final ClientBillingUsageBreakdownLimitDetailsModel incoming;
  final ClientBillingUsageBreakdownLimitDetailsModel outgoing;
  final ClientBillingUsageBreakdownOverageModel overage;

  const ClientBillingUsageBreakdownServiceDetailsModel({
    required this.incoming,
    required this.outgoing,
    required this.overage,
  });

  factory ClientBillingUsageBreakdownServiceDetailsModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingUsageBreakdownServiceDetailsModel(
      incoming: ClientBillingUsageBreakdownLimitDetailsModel.fromJson(json['in'] ?? {}),
      outgoing: ClientBillingUsageBreakdownLimitDetailsModel.fromJson(json['out'] ?? {}),
      overage: ClientBillingUsageBreakdownOverageModel.fromJson(json['overage'] ?? {}),
    );
  }
}

class ClientBillingUsageBreakdownLimitDetailsModel {
  final double used;
  final double included;
  final String unit;
  final String display;

  const ClientBillingUsageBreakdownLimitDetailsModel({
    required this.used,
    required this.included,
    required this.unit,
    required this.display,
  });

  factory ClientBillingUsageBreakdownLimitDetailsModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingUsageBreakdownLimitDetailsModel(
      used: _toDouble(json['used']),
      included: _toDouble(json['included']),
      unit: (json['unit'] ?? '').toString(),
      display: (json['display'] ?? '').toString(),
    );
  }
}

class ClientBillingUsageBreakdownOverageModel {
  final bool enabled;
  final double inRate;
  final double outRate;
  final String unit;

  const ClientBillingUsageBreakdownOverageModel({
    required this.enabled,
    required this.inRate,
    required this.outRate,
    required this.unit,
  });

  factory ClientBillingUsageBreakdownOverageModel.fromJson(Map<String, dynamic> json) {
    return ClientBillingUsageBreakdownOverageModel(
      enabled: json['enabled'] == true || json['enabled'] == 1,
      inRate: _toDouble(json['in_rate']),
      outRate: _toDouble(json['out_rate']),
      unit: (json['unit'] ?? '').toString(),
    );
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

class ClientAddedExtraChargeModel {
  final int id;
  final String description;
  final double amount;
  final String weekStart;
  final String weekEnd;

  const ClientAddedExtraChargeModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.weekStart,
    required this.weekEnd,
  });

  factory ClientAddedExtraChargeModel.fromJson(Map<String, dynamic> json) {
    return ClientAddedExtraChargeModel(
      id: _toInt(json['id']),
      description: (json['description'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      weekStart: (json['week_start'] ?? '').toString(),
      weekEnd: (json['week_end'] ?? '').toString(),
    );
  }
}

class ClientWeekChargeBreakdownModel {
  final List<ClientWeekChargeBreakdownRowModel> rows;
  final List<ClientAddedExtraChargeModel> addedExtraCharges;
  final double extraChargesTotal;
  final double creditsAppliedTotal;
  final double creditsApplied;
  final double weekSubtotal;
  final double weekTotal;

  const ClientWeekChargeBreakdownModel({
    required this.rows,
    required this.addedExtraCharges,
    required this.extraChargesTotal,
    required this.creditsAppliedTotal,
    required this.creditsApplied,
    required this.weekSubtotal,
    required this.weekTotal,
  });

  factory ClientWeekChargeBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ClientWeekChargeBreakdownModel(
      rows: json['rows'] is List
          ? (json['rows'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientWeekChargeBreakdownRowModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      addedExtraCharges: json['added_extra_charges'] is List
          ? (json['added_extra_charges'] as List<dynamic>)
              .whereType<Map>()
              .map((e) => ClientAddedExtraChargeModel.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [],
      extraChargesTotal: _toDouble(json['extra_charges_total']),
      creditsAppliedTotal: _toDouble(json['credits_applied_total'] ?? json['credits_applied']),
      creditsApplied: _toDouble(json['credits_applied']),
      weekSubtotal: _toDouble(json['week_subtotal']),
      weekTotal: _toDouble(json['week_total']),
    );
  }
}

class ClientWeekChargeBreakdownRowModel {
  final String key;
  final String label;
  final int? qty;
  final double unitPrice;
  final String unitPriceLabel;
  final double amount;
  final String tone;

  const ClientWeekChargeBreakdownRowModel({
    required this.key,
    required this.label,
    this.qty,
    required this.unitPrice,
    required this.unitPriceLabel,
    required this.amount,
    required this.tone,
  });

  factory ClientWeekChargeBreakdownRowModel.fromJson(Map<String, dynamic> json) {
    return ClientWeekChargeBreakdownRowModel(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      qty: json['qty'] != null ? _toInt(json['qty']) : null,
      unitPrice: _toDouble(json['unit_price']),
      unitPriceLabel: (json['unit_price_label'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      tone: (json['tone'] ?? 'default').toString(),
    );
  }
}
