class ContractTemplateModel {
  final int id;
  final String name;
  final String type;
  final String version;
  final String? content;
  final List<String> variables;
  final List<String> clauses;
  final bool isActive;

  const ContractTemplateModel({
    required this.id,
    required this.name,
    required this.type,
    required this.version,
    required this.content,
    required this.variables,
    required this.clauses,
    required this.isActive,
  });

  factory ContractTemplateModel.fromJson(Map<String, dynamic> json) {
    return ContractTemplateModel(
      id: (json['id'] is int)
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      version: (json['version'] ?? '').toString(),
      content: json['content']?.toString(),
      variables: (json['variables'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      clauses: (json['clauses'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isActive: json['is_active'] == true,
    );
  }

  String get variablesText => variables.join(', ');
  String get clausesText => clauses.join(' · ');
  String get statusLabel => isActive ? 'Active' : 'Inactive';
  String get versionLabel => version.startsWith('v') ? version : 'v$version';
}
