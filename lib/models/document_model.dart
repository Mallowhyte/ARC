/// Document Model
/// Represents a classified document in the system

class DocumentModel {
  final String id;
  final String userId;
  final String filename;
  final String documentType;
  final double confidence;
  final String? extractedText;
  final String storageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? keywords;

  final String? dpmNumber;
  final double? dpmConfidence;
  final String? storageKey;

  // ISO Document Management Fields
  final String? documentNumber;
  final int? versionNumber;
  final String? department;
  final DateTime? effectiveDate;
  final DateTime? reviewDate;
  final int? retentionPeriod; // in days
  final String? currentApprover;
  final String? notes;

  DocumentModel({
    required this.id,
    required this.userId,
    required this.filename,
    required this.documentType,
    required this.confidence,
    this.extractedText,
    required this.storageUrl,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.keywords,
    this.dpmNumber,
    this.dpmConfidence,
    this.storageKey,
    this.documentNumber,
    this.versionNumber,
    this.department,
    this.effectiveDate,
    this.reviewDate,
    this.retentionPeriod,
    this.currentApprover,
    this.notes,
  });

  /// Create DocumentModel from JSON
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      filename: json['original_filename'] ?? json['filename'] ?? '',
      documentType: json['document_type'] ?? 'Unknown',
      confidence: (json['confidence'] is int)
          ? (json['confidence'] as int).toDouble()
          : json['confidence']?.toDouble() ?? 0.0,
      extractedText: json['extracted_text'],
      storageUrl: json['file_path'] ?? json['storage_url'] ?? '',
      status: json['status']?.toLowerCase() ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      keywords: json['keywords'] != null
          ? List<String>.from(json['keywords'])
          : null,
      dpmNumber: json['dpm_number'],
      dpmConfidence: (json['dpm_confidence'] is int)
          ? (json['dpm_confidence'] as int).toDouble()
          : json['dpm_confidence']?.toDouble(),
      storageKey: json['storage_key'],
      documentNumber: json['document_number'],
      versionNumber: json['version_number'] is int
          ? json['version_number']
          : (json['version_number'] is num
                ? (json['version_number'] as num).toInt()
                : 1),
      department: json['department'],
      effectiveDate: json['effective_date'] != null
          ? DateTime.parse(json['effective_date'])
          : null,
      reviewDate: json['review_date'] != null
          ? DateTime.parse(json['review_date'])
          : null,
      retentionPeriod: json['retention_period'] is int
          ? json['retention_period']
          : (json['retention_period'] is num
                ? (json['retention_period'] as num).toInt()
                : null),
      currentApprover: json['current_approver'],
      notes: json['notes'],
    );
  }

  /// Convert DocumentModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'original_filename': filename,
      'document_type': documentType,
      'confidence': confidence,
      'extracted_text': extractedText,
      'file_path': storageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'keywords': keywords,
      'dpm_number': dpmNumber,
      'dpm_confidence': dpmConfidence,
      'storage_key': storageKey,
      'document_number': documentNumber,
      'version_number': versionNumber,
      'department': department,
      'effective_date': effectiveDate?.toIso8601String(),
      'review_date': reviewDate?.toIso8601String(),
      'retention_period': retentionPeriod,
      'current_approver': currentApprover,
      'notes': notes,
    };
  }

  /// Get formatted confidence percentage
  String get confidencePercentage =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  /// Get formatted creation date
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Check if classification is high confidence
  bool get isHighConfidence => confidence >= 0.8;
}

/// Document Type Categories
class DocumentType {
  static const String examForm = 'Exam Form';
  static const String acknowledgementForm = 'Acknowledgement Form';
  static const String clearance = 'Clearance';
  static const String receipt = 'Receipt';
  static const String gradeSheet = 'Grade Sheet';
  static const String enrollmentForm = 'Enrollment Form';
  static const String idApplication = 'ID Application';
  static const String certificateRequest = 'Certificate Request';
  static const String leaveForm = 'Leave Form';
  static const String syllabusReviewForm = 'Syllabus Review Form';
  static const String other = 'Other';

  static const List<String> all = [
    examForm,
    acknowledgementForm,
    clearance,
    receipt,
    gradeSheet,
    enrollmentForm,
    idApplication,
    certificateRequest,
    leaveForm,
    syllabusReviewForm,
    other,
  ];
}
