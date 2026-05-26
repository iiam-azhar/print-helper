class ChecklistModel {
  final int id;
  final String icon;
  final String iconName;
  final String iconSvgUrl;
  final String iconColor;
  final String colorHex;
  final String name;
  final String listType;
  final String userType;
  final List<String> items;
  final int itemsCount;
  final int sortOrder;

  ChecklistModel({
    required this.id,
    required this.icon,
    required this.iconName,
    required this.iconSvgUrl,
    required this.iconColor,
    required this.colorHex,
    required this.name,
    required this.listType,
    required this.userType,
    required this.items,
    required this.itemsCount,
    required this.sortOrder,
  });

  factory ChecklistModel.fromJson(Map<String, dynamic> json) {
    return ChecklistModel(
      id: json['id'] ?? 0,
      icon: json['icon'] ?? '',
      iconName: json['icon_name'] ?? '',
      iconSvgUrl: json['icon_svg_url'] ?? '',
      iconColor: json['icon_color'] ?? '',
      colorHex: json['color_hex'] ?? '',
      name: json['name'] ?? '',
      listType: json['list_type'] ?? '',
      userType: json['user_type'] != null
          ? json['user_type'].toString()
          : (json['user_types'] as List<dynamic>?)?.join(', ') ?? '',
      items: (json['items'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      itemsCount: json['items_count'] ?? 0,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
