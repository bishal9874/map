import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../models/report_model.dart';
import '../models/geocoding_result.dart';

class ApiService {
  // Change this to your backend URL
  // For Android emulator: 10.0.2.2:3000
  // For physical device: your computer's IP:3000
  static const String _baseUrl = 'http://10.0.2.2:3000/api';
  
  // Direct OSRM and Nominatim APIs as fallback
  static const String _osrmUrl = 'https://router.project-osrm.org';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';

  // ============ ROUTING ============

  /// Get route from OSRM directly (works without backend)
  static Future<RouteModel?> getRoute(
    double fromLat, double fromLon,
    double toLat, double toLon,
  ) async {
    try {
      // Try backend first
      final backendRoute = await _getRouteFromBackend(fromLat, fromLon, toLat, toLon);
      if (backendRoute != null) return backendRoute;
    } catch (_) {}
    
    // Fallback to direct OSRM
    return _getRouteFromOSRM(fromLat, fromLon, toLat, toLon);
  }

  static Future<RouteModel?> _getRouteFromBackend(
    double fromLat, double fromLon, double toLat, double toLon,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/route?fromLat=$fromLat&fromLon=$fromLon&toLat=$toLat&toLon=$toLon'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return RouteModel.fromJson(data['route']);
      }
    }
    return null;
  }

  static Future<RouteModel?> _getRouteFromOSRM(
    double fromLat, double fromLon, double toLat, double toLon,
  ) async {
    final url = '$_osrmUrl/route/v1/driving/$fromLon,$fromLat;$toLon,$toLat'
        '?overview=full&geometries=geojson&steps=true&alternatives=true';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'CrowdNav/1.0'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        return RouteModel(
          coordinates: (route['geometry']['coordinates'] as List)
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList(),
          duration: (route['duration'] ?? 0).toDouble(),
          distance: (route['distance'] ?? 0).toDouble(),
          steps: (route['legs']?[0]?['steps'] as List?)
                  ?.map((s) => RouteStep.fromJson(s))
                  .toList() ??
              [],
          alternatives: (data['routes'] as List).length > 1
              ? (data['routes'] as List).skip(1).map((r) => RouteModel(
                    coordinates: (r['geometry']['coordinates'] as List)
                        .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                        .toList(),
                    duration: (r['duration'] ?? 0).toDouble(),
                    distance: (r['distance'] ?? 0).toDouble(),
                  )).toList()
              : [],
        );
      }
    }
    return null;
  }

  /// Get smart route avoiding problem areas
  static Future<Map<String, dynamic>?> getSmartRoute(
    double fromLat, double fromLon, double toLat, double toLon,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/route/smart'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fromLat': fromLat, 'fromLon': fromLon,
          'toLat': toLat, 'toLon': toLon,
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Smart route error: $e');
    }
    return null;
  }

  // ============ GEOCODING ============

  /// Search for places using Nominatim
  static Future<List<GeocodingResult>> searchPlaces(String query) async {
    try {
      // Try backend first
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/geocode?q=${Uri.encodeComponent(query)}'),
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            return (data['results'] as List)
                .map((r) => GeocodingResult.fromJson(r))
                .toList();
          }
        }
      } catch (_) {}
      
      // Direct Nominatim fallback
      final url = '$_nominatimUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CrowdNav/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) => GeocodingResult(
          displayName: item['display_name'] ?? '',
          latitude: double.tryParse(item['lat']?.toString() ?? '0') ?? 0,
          longitude: double.tryParse(item['lon']?.toString() ?? '0') ?? 0,
          type: item['type'] ?? '',
        )).toList();
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  /// Reverse geocode coordinates to address
  static Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final url = '$_nominatimUrl/reverse?lat=$lat&lon=$lon&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CrowdNav/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      print('Reverse geocode error: $e');
    }
    return null;
  }

  // ============ REPORTS ============

  /// Submit a diversion report
  static Future<Map<String, dynamic>?> submitReport({
    required double latitude,
    required double longitude,
    required String reason,
    String reasonText = '',
    int severity = 3,
    String userId = 'anonymous',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/reports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'reason': reason,
          'reasonText': reasonText,
          'severity': severity,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Submit report error: $e');
    }
    return null;
  }

  /// Get nearby reports
  static Future<List<ReportModel>> getNearbyReports(
    double lat, double lon, {int radius = 2000}
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/reports/nearby?lat=$lat&lon=$lon&radius=$radius'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['reports'] as List)
              .map((r) => ReportModel.fromJson(r))
              .toList();
        }
      }
    } catch (e) {
      print('Nearby reports error: $e');
    }
    return [];
  }

  // ============ ALERTS ============

  /// Get alerts for current location
  static Future<List<AlertModel>> getAlerts(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/alerts?lat=$lat&lon=$lon'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['alerts'] as List)
              .map((a) => AlertModel.fromJson(a))
              .toList();
        }
      }
    } catch (e) {
      print('Alerts error: $e');
    }
    return [];
  }

  // ============ HOTSPOTS ============

  /// Get hotspot areas
  static Future<List<Map<String, dynamic>>> getHotspots(
    double lat, double lon, {int radius = 5000}
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/hotspots?lat=$lat&lon=$lon&radius=$radius'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['hotspots']);
        }
      }
    } catch (e) {
      print('Hotspots error: $e');
    }
    return [];
  }
}
