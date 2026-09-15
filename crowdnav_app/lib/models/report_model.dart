import 'package:latlong2/latlong.dart';

class ReportModel {
  final String reportId;
  final String userId;
  final LatLng location;
  final String reason;
  final String reasonText;
  final int severity;
  final double confidenceScore;
  final int corroborations;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  ReportModel({
    required this.reportId,
    this.userId = 'anonymous',
    required this.location,
    required this.reason,
    this.reasonText = '',
    this.severity = 3,
    this.confidenceScore = 0.5,
    this.corroborations = 1,
    this.isActive = true,
    required this.createdAt,
    this.expiresAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final coords = json['location']?['coordinates'] as List?;
    return ReportModel(
      reportId: json['reportId'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? 'anonymous',
      location: coords != null
          ? LatLng(coords[1].toDouble(), coords[0].toDouble())
          : LatLng(0, 0),
      reason: json['reason'] ?? 'other',
      reasonText: json['reasonText'] ?? '',
      severity: json['severity'] ?? 3,
      confidenceScore: (json['confidenceScore'] ?? 0.5).toDouble(),
      corroborations: json['corroborations'] ?? 1,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'reason': reason,
        'reasonText': reasonText,
        'severity': severity,
      };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class AlertModel {
  final String id;
  final String type;
  final LatLng location;
  final String message;
  final int severity;
  final double confidence;

  AlertModel({
    required this.id,
    required this.type,
    required this.location,
    required this.message,
    this.severity = 3,
    this.confidence = 0.5,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final coords = json['location'] as List?;
    return AlertModel(
      id: json['id'] ?? '',
      type: json['type'] ?? 'other',
      location: coords != null
          ? LatLng(coords[1].toDouble(), coords[0].toDouble())
          : LatLng(0, 0),
      message: json['message'] ?? 'Caution ahead',
      severity: json['severity'] ?? 3,
      confidence: (json['confidence'] ?? 0.5).toDouble(),
    );
  }
}
