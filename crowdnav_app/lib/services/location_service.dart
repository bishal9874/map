import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static final _locationController = StreamController<LatLng>.broadcast();

  static Stream<LatLng> get locationStream => _locationController.stream;
  static LatLng? _lastKnownLocation;
  static LatLng? get lastKnownLocation => _lastKnownLocation;

  /// Check and request location permissions
  static Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location
  static Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownLocation = latLng;
      return latLng;
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  /// Start continuous location tracking
  static void startTracking({
    int distanceFilter = 10,
    Function(LatLng)? onLocationUpdate,
  }) {
    stopTracking();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final latLng = LatLng(position.latitude, position.longitude);
      _lastKnownLocation = latLng;
      _locationController.add(latLng);
      onLocationUpdate?.call(latLng);
    });
  }

  /// Stop location tracking
  static void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  /// Calculate distance between two points in meters
  static double distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude, a.longitude,
      b.latitude, b.longitude,
    );
  }

  /// Find the closest point on a route to the user's position
  static double distanceToRoute(LatLng position, List<LatLng> routePoints) {
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length - 1; i++) {
      final dist = _distanceToSegment(
        position, routePoints[i], routePoints[i + 1],
      );
      if (dist < minDistance) {
        minDistance = dist;
      }
    }

    return minDistance;
  }

  /// Distance from a point to a line segment
  static double _distanceToSegment(LatLng point, LatLng segStart, LatLng segEnd) {
    final dx = segEnd.longitude - segStart.longitude;
    final dy = segEnd.latitude - segStart.latitude;

    if (dx == 0 && dy == 0) {
      return distanceBetween(point, segStart);
    }

    double t = ((point.longitude - segStart.longitude) * dx +
            (point.latitude - segStart.latitude) * dy) /
        (dx * dx + dy * dy);

    t = t.clamp(0.0, 1.0);

    final nearest = LatLng(
      segStart.latitude + t * dy,
      segStart.longitude + t * dx,
    );

    return distanceBetween(point, nearest);
  }

  static void dispose() {
    stopTracking();
    _locationController.close();
  }
}
