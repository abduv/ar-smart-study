class ScanResult {
  final String id;
  final String recognizedText;
  final String explanation;
  final String? imagePath;
  final DateTime createdAt;
  final String subject;

  ScanResult({
    required this.id,
    required this.recognizedText,
    required this.explanation,
    this.imagePath,
    required this.createdAt,
    this.subject = 'Жалпы',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recognizedText': recognizedText,
      'explanation': explanation,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'subject': subject,
    };
  }

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] as String,
      recognizedText: json['recognizedText'] as String,
      explanation: json['explanation'] as String,
      imagePath: json['imagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      subject: json['subject'] as String? ?? 'Жалпы',
    );
  }
}
