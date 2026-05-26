// Models for GET {{base}}services/pricing API response

class ServicesPricingModel {
  final List<RateCardGroup> rateCardGroups;
  final List<AddonModel> addons;
  final List<DpcTermModel> dpcTerms;
  final List<WeeklyBonusModel> weeklyBonuses;
  final List<OnetimeBonusModel> onetimeBonuses;
  final List<SupervisorBonusModel> supervisorBonuses;
  final List<LevelFloorModel> levelFloors;
  final double phPortalWeekly;
  final List<String> levels;
  final Map<String, String> levelLabels;

  const ServicesPricingModel({
    required this.rateCardGroups,
    required this.addons,
    required this.dpcTerms,
    required this.weeklyBonuses,
    required this.onetimeBonuses,
    required this.supervisorBonuses,
    required this.levelFloors,
    required this.phPortalWeekly,
    required this.levels,
    required this.levelLabels,
  });

  factory ServicesPricingModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;

    return ServicesPricingModel(
      rateCardGroups: (data['rateCardGroups'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => RateCardGroup.fromJson(e.cast<String, dynamic>()))
          .toList(),
      addons: (data['addons'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => AddonModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      dpcTerms: (data['dpcTerms'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => DpcTermModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      weeklyBonuses: (data['weeklyBonuses'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => WeeklyBonusModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      onetimeBonuses: (data['onetimeBonuses'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => OnetimeBonusModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      supervisorBonuses: (data['supervisorBonuses'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => SupervisorBonusModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      levelFloors: (data['levelFloors'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => LevelFloorModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
      phPortalWeekly: _toDouble(data['phPortalWeekly']),
      levels: (data['levels'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      levelLabels: (data['levelLabels'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  /// Convenience: find the addon by its slug (e.g. 'support-lines').
  AddonModel? addonBySlug(String slug) {
    try {
      return addons.firstWhere((a) => a.slug == slug);
    } catch (_) {
      return null;
    }
  }
}

// ─── Rate Card Group ──────────────────────────────────────────────────────────

class RateCardGroup {
  final int accountTypeId;
  final String accountTypeName;
  final RateCardModel wholesale;
  final RateCardModel retail;

  const RateCardGroup({
    required this.accountTypeId,
    required this.accountTypeName,
    required this.wholesale,
    required this.retail,
  });

  factory RateCardGroup.fromJson(Map<String, dynamic> json) {
    return RateCardGroup(
      accountTypeId: _toInt(json['account_type_id']),
      accountTypeName: (json['account_type_name'] ?? '').toString(),
      wholesale: RateCardModel.fromJson(
        (json['wholesale'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      retail: RateCardModel.fromJson(
        (json['retail'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}

// ─── Rate Card ────────────────────────────────────────────────────────────────

class RateCardModel {
  final int id;
  final int accountTypeId;
  final String pricingMode; // 'wholesale' | 'retail'
  final String slug;
  final String name;
  final String chargeUnit;
  final String icon;
  final String iconSvg;
  final double basePrice;
  final double volumeDiscount;
  final Map<String, double> levelPercentages;
  final List<VolumeModel> volumes;

  const RateCardModel({
    required this.id,
    required this.accountTypeId,
    required this.pricingMode,
    required this.slug,
    required this.name,
    required this.chargeUnit,
    required this.icon,
    required this.iconSvg,
    required this.basePrice,
    required this.volumeDiscount,
    required this.levelPercentages,
    required this.volumes,
  });

  factory RateCardModel.fromJson(Map<String, dynamic> json) {
    final percs = (json['level_percentages'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, _toDouble(v)));

    return RateCardModel(
      id: _toInt(json['id']),
      accountTypeId: _toInt(json['account_type_id']),
      pricingMode: (json['pricing_mode'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      chargeUnit: (json['charge_unit'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      iconSvg: (json['icon_svg'] ?? '').toString(),
      basePrice: _toDouble(json['base_price']),
      volumeDiscount: _toDouble(json['volume_discount']),
      levelPercentages: percs,
      volumes: (json['volumes'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => VolumeModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── Volume Tier ─────────────────────────────────────────────────────────────

class VolumeModel {
  final int id;
  final String volumeLabel;
  final double clientPrice;

  const VolumeModel({
    required this.id,
    required this.volumeLabel,
    required this.clientPrice,
  });

  factory VolumeModel.fromJson(Map<String, dynamic> json) {
    return VolumeModel(
      id: _toInt(json['id']),
      volumeLabel: (json['volume_label'] ?? '').toString(),
      clientPrice: _toDouble(json['client_price']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── Add-on ───────────────────────────────────────────────────────────────────

class AddonModel {
  final int id;
  final String slug;
  final String name;
  final String billingUnit;
  /// How many units are included in the plan (e.g. "5" or "0").
  final int included;
  final double weeklyPrice;

  const AddonModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.billingUnit,
    required this.included,
    required this.weeklyPrice,
  });

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    return AddonModel(
      id: _toInt(json['id']),
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      billingUnit: (json['billing_unit'] ?? '').toString(),
      included: _toInt(json['included']),
      weeklyPrice: _toDouble(json['weekly_price']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── DPC Term ─────────────────────────────────────────────────────────────────

class DpcTermModel {
  final int id;
  final int months;
  final double totalPrice;

  const DpcTermModel({
    required this.id,
    required this.months,
    required this.totalPrice,
  });

  factory DpcTermModel.fromJson(Map<String, dynamic> json) {
    return DpcTermModel(
      id: _toInt(json['id']),
      months: _toInt(json['months']),
      totalPrice: _toDouble(json['total_price']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── Weekly Bonus ─────────────────────────────────────────────────────────────

class WeeklyBonusModel {
  final int id;
  final String label;
  final Map<String, double> amounts;

  const WeeklyBonusModel({
    required this.id,
    required this.label,
    required this.amounts,
  });

  factory WeeklyBonusModel.fromJson(Map<String, dynamic> json) {
    final amts = (json['amounts'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, _toDouble(v)));
    return WeeklyBonusModel(
      id: _toInt(json['id']),
      label: (json['label'] ?? '').toString(),
      amounts: amts,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── One-time Bonus ───────────────────────────────────────────────────────────

class OnetimeBonusModel {
  final int id;
  final String label;
  final Map<String, double> amounts;

  const OnetimeBonusModel({
    required this.id,
    required this.label,
    required this.amounts,
  });

  factory OnetimeBonusModel.fromJson(Map<String, dynamic> json) {
    final amts = (json['amounts'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, _toDouble(v)));
    return OnetimeBonusModel(
      id: _toInt(json['id']),
      label: (json['label'] ?? '').toString(),
      amounts: amts,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── Supervisor Bonus ─────────────────────────────────────────────────────────

class SupervisorBonusModel {
  final int id;
  final String label;
  final double amountPerPoint;
  final String frequency;

  const SupervisorBonusModel({
    required this.id,
    required this.label,
    required this.amountPerPoint,
    required this.frequency,
  });

  factory SupervisorBonusModel.fromJson(Map<String, dynamic> json) {
    return SupervisorBonusModel(
      id: _toInt(json['id']),
      label: (json['label'] ?? '').toString(),
      amountPerPoint: _toDouble(json['amount_per_point']),
      frequency: (json['frequency'] ?? '').toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}

// ─── Level Floor ──────────────────────────────────────────────────────────────

class LevelFloorModel {
  final int id;
  final String level;
  final String label;
  final double weeklyMinimum;

  const LevelFloorModel({
    required this.id,
    required this.level,
    required this.label,
    required this.weeklyMinimum,
  });

  factory LevelFloorModel.fromJson(Map<String, dynamic> json) {
    return LevelFloorModel(
      id: _toInt(json['id']),
      level: (json['level'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      weeklyMinimum: _toDouble(json['weekly_minimum']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }
}
