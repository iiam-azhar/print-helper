class StandardRuleModel {
  final int id;
  final int? categoryId;
  final String ruleType;
  final String icon;
  final String iconColor;
  final String? colorHex;
  final String? iconSvgUrl;
  final String title;
  final String description;
  final int sortOrder;
  final bool isActive;
  final String? categoryName;

  const StandardRuleModel({
    required this.id,
    required this.categoryId,
    required this.ruleType,
    required this.icon,
    required this.iconColor,
    required this.colorHex,
    required this.iconSvgUrl,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.isActive,
    required this.categoryName,
  });

  factory StandardRuleModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return StandardRuleModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      categoryId: json['category_id'] == null
          ? null
          : int.tryParse('${json['category_id']}'),
      ruleType: (json['rule_type'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      iconColor: (json['icon_color'] ?? '').toString(),
      colorHex: json['color_hex']?.toString(),
      iconSvgUrl: json['icon_svg_url']?.toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      sortOrder: (json['sort_order'] is int)
          ? json['sort_order'] as int
          : int.tryParse('${json['sort_order']}') ?? 0,
      isActive: json['is_active'] == true,
      categoryName: category?['name']?.toString(),
    );
  }

  StandardRuleModel copyWith({
    int? id,
    int? categoryId,
    String? ruleType,
    String? icon,
    String? iconColor,
    String? colorHex,
    String? iconSvgUrl,
    String? title,
    String? description,
    int? sortOrder,
    bool? isActive,
    String? categoryName,
  }) {
    return StandardRuleModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      ruleType: ruleType ?? this.ruleType,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      colorHex: colorHex ?? this.colorHex,
      iconSvgUrl: iconSvgUrl ?? this.iconSvgUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
