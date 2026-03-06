/// Customer data received from CRM lookup
class CustomerData {
  final String number;
  final String contactName;
  final String company;
  final String contactLink;
  final Map<String, dynamic> customFields;

  CustomerData({
    required this.number,
    this.contactName = '',
    this.company = '',
    this.contactLink = '',
    this.customFields = const {},
  });

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    final crmInfo = json['crm_info'] as Map<String, dynamic>? ?? {};
    return CustomerData(
      number: crmInfo['number'] as String? ?? '',
      contactName: crmInfo['contact_name'] as String? ?? '',
      company: crmInfo['company'] as String? ?? '',
      contactLink: crmInfo['contact_link'] as String? ?? '',
      customFields: Map<String, dynamic>.from(
        json['custom_fields'] as Map? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'contact_name': contactName,
      'company': company,
      'contact_link': contactLink,
      'custom_fields': customFields,
    };
  }

  CustomerData copyWith({
    String? number,
    String? contactName,
    String? company,
    String? contactLink,
    Map<String, dynamic>? customFields,
  }) {
    return CustomerData(
      number: number ?? this.number,
      contactName: contactName ?? this.contactName,
      company: company ?? this.company,
      contactLink: contactLink ?? this.contactLink,
      customFields: customFields ?? this.customFields,
    );
  }

  bool get hasContactLink => contactLink.isNotEmpty;
  bool get hasData => contactName.isNotEmpty || company.isNotEmpty;

  @override
  String toString() => 'CustomerData(name: $contactName, company: $company, number: $number)';
}
