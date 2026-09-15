class GeocodingResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.type = '',
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['displayName'] ?? json['display_name'] ?? '',
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lon'] ?? 0).toDouble(),
      type: json['type'] ?? '',
    );
  }

  String get shortName {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return displayName;
  }
}
