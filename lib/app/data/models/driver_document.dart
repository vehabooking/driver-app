/// A single uploaded file attached to a document.
class DocFile {
  const DocFile({required this.url, this.filename, this.mimeType});

  final String url;
  final String? filename;
  final String? mimeType;

  bool get isImage => (mimeType ?? '').startsWith('image/');

  factory DocFile.fromJson(Map<String, dynamic> json) => DocFile(
    url: json['url']?.toString() ?? '',
    filename: json['filename']?.toString(),
    mimeType: json['mime_type']?.toString(),
  );
}

/// Read-only driver document (Personal ID / Driving License).
class DriverDocument {
  const DriverDocument({
    required this.type,
    required this.label,
    this.status,
    this.statusLabel,
    this.cardNumber,
    this.issuedAt,
    this.expiredAt,
    this.rejectionReason,
    this.files = const [],
  });

  /// Dummy document so the Documents skeleton has cards to trace.
  factory DriverDocument.placeholder() => const DriverDocument(
    type: 'placeholder',
    label: 'Document name',
    status: 'pending',
    statusLabel: 'Status',
  );

  final String type;
  final String label;
  final String? status;
  final String? statusLabel;
  final String? cardNumber;
  final String? issuedAt;
  final String? expiredAt;
  final String? rejectionReason;
  final List<DocFile> files;

  bool get isLicense => type == 'driver_license_file';

  factory DriverDocument.fromJson(Map<String, dynamic> json) => DriverDocument(
    type: json['type']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    status: json['status']?.toString(),
    statusLabel: json['status_label']?.toString(),
    cardNumber: json['card_number']?.toString(),
    issuedAt: json['issued_at']?.toString(),
    expiredAt: json['expired_at']?.toString(),
    rejectionReason: json['rejection_reason']?.toString(),
    files: (json['files'] as List? ?? [])
        .map((e) => DocFile.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
