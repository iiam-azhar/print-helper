class ContractAgreementModel {
  final String id;
  final String name;
  final String subtitle;
  final String type;
  final String? signedAt;
  final String? ipAddress;
  final String template;
  final bool isSigned;
  final String? pdfUrl;

  const ContractAgreementModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.type,
    required this.signedAt,
    required this.ipAddress,
    required this.template,
    required this.isSigned,
    this.pdfUrl,
  });

  factory ContractAgreementModel.fromJson(Map<String, dynamic> json) {
    return ContractAgreementModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      signedAt: json['signed_at']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      template: (json['template'] ?? '').toString(),
      isSigned: json['is_signed'] == true,
      pdfUrl: json['pdf_url']?.toString(),
    );
  }
}
