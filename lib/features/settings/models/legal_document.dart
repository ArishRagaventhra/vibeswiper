enum LegalDocumentType {
  privacyPolicy('privacy_policy'),
  termsConditions('terms_conditions');

  final String value;
  const LegalDocumentType(this.value);

  @override
  String toString() => value;
}

class LegalDocument {
  final String id;
  final String content;
  final int version;
  final DateTime lastUpdated;

  const LegalDocument({
    required this.id,
    required this.content,
    required this.version,
    required this.lastUpdated,
  });

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      content: json['content'] as String,
      version: json['version'] as int,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'version': version,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
