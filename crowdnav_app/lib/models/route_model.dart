import 'package:latlong2/latlong.dart';

class RouteModel {
  final List<LatLng> coordinates;
  final double duration; // in seconds
  final double distance; // in meters
  final List<RouteStep> steps;
  final List<RouteModel> alternatives;

  RouteModel({
    required this.coordinates,
    required this.duration,
    required this.distance,
    this.steps = const [],
    this.alternatives = const [],
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final coords = (geometry['coordinates'] as List)
        .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
        .toList();

    final steps = (json['steps'] as List?)
            ?.map((s) => RouteStep.fromJson(s))
            .toList() ??
        [];

    final alternatives = (json['alternatives'] as List?)
            ?.map((a) => RouteModel.fromJson(a))
            .toList() ??
        [];

    return RouteModel(
      coordinates: coords,
      duration: (json['duration'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      steps: steps,
      alternatives: alternatives,
    );
  }

  String get durationText {
    final mins = (duration / 60).round();
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remainMins = mins % 60;
    return '${hours}h ${remainMins}m';
  }

  String get distanceText {
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }
}

class RouteStep {
  final String instruction;
  final double distance;
  final double duration;
  final String modifier;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.modifier = '',
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] ?? {};
    return RouteStep(
      instruction: json['name'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toDouble(),
      modifier: maneuver['modifier'] ?? '',
    );
  }
}
