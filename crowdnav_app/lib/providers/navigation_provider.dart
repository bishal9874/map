import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../models/report_model.dart';
import '../models/geocoding_result.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

enum NavigationState {
  idle,
  searching,
  routeReady,
  navigating,
  diverted,
  arrived,
}

class NavigationProvider with ChangeNotifier {
  // State
  NavigationState _state = NavigationState.idle;
  NavigationState get state => _state;

  // Location
  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  // Route
  RouteModel? _currentRoute;
  RouteModel? get currentRoute => _currentRoute;
  RouteModel? _originalRoute;

  // Search
  LatLng? _sourceLocation;
  LatLng? get sourceLocation => _sourceLocation;
  String _sourceText = '';
  String get sourceText => _sourceText;

  LatLng? _destinationLocation;
  LatLng? get destinationLocation => _destinationLocation;
  String _destinationText = '';
  String get destinationText => _destinationText;

  List<GeocodingResult> _searchResults = [];
  List<GeocodingResult> get searchResults => _searchResults;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  // Reports & Alerts
  List<ReportModel> _nearbyReports = [];
  List<ReportModel> get nearbyReports => _nearbyReports;
  List<AlertModel> _activeAlerts = [];
  List<AlertModel> get activeAlerts => _activeAlerts;

  // Diversion detection
  bool _isDiverted = false;
  bool get isDiverted => _isDiverted;
  double _deviationDistance = 0;
  double get deviationDistance => _deviationDistance;
  static const double _diversionThreshold = 50.0; // meters

  // Navigation info
  double _distanceRemaining = 0;
  double get distanceRemaining => _distanceRemaining;
  double _durationRemaining = 0;
  double get durationRemaining => _durationRemaining;

  // Loading states
  bool _isLoadingRoute = false;
  bool get isLoadingRoute => _isLoadingRoute;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Warnings from smart routing
  List<Map<String, dynamic>> _routeWarnings = [];
  List<Map<String, dynamic>> get routeWarnings => _routeWarnings;

  // Tracking
  StreamSubscription<LatLng>? _locationSubscription;
  Timer? _alertCheckTimer;
  Timer? _reportCheckTimer;

  NavigationProvider() {
    _initLocation();
  }

  Future<void> _initLocation() async {
    _currentLocation = await LocationService.getCurrentLocation();
    if (_currentLocation != null) {
      _sourceLocation = _currentLocation;
      _sourceText = 'Current Location';
    }
    notifyListeners();
  }

  // ============ SEARCH ============

  Future<void> searchPlaces(String query) async {
    if (query.length < 2) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _searchResults = await ApiService.searchPlaces(query);
    _isSearching = false;
    notifyListeners();
  }

  void setSource(GeocodingResult result) {
    _sourceLocation = LatLng(result.latitude, result.longitude);
    _sourceText = result.shortName;
    _searchResults = [];
    notifyListeners();
  }

  void setSourceFromCurrentLocation() {
    if (_currentLocation != null) {
      _sourceLocation = _currentLocation;
      _sourceText = 'Current Location';
      notifyListeners();
    }
  }

  void setDestination(GeocodingResult result) {
    _destinationLocation = LatLng(result.latitude, result.longitude);
    _destinationText = result.shortName;
    _searchResults = [];
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  // ============ ROUTING ============

  Future<void> generateRoute() async {
    if (_sourceLocation == null || _destinationLocation == null) {
      _errorMessage = 'Please set both source and destination';
      notifyListeners();
      return;
    }

    _isLoadingRoute = true;
    _errorMessage = null;
    _state = NavigationState.searching;
    notifyListeners();

    try {
      final route = await ApiService.getRoute(
        _sourceLocation!.latitude, _sourceLocation!.longitude,
        _destinationLocation!.latitude, _destinationLocation!.longitude,
      );

      if (route != null) {
        _currentRoute = route;
        _originalRoute = route;
        _distanceRemaining = route.distance;
        _durationRemaining = route.duration;
        _state = NavigationState.routeReady;
        _routeWarnings = [];

        // Fetch reports along route
        _loadRouteReports();
      } else {
        _errorMessage = 'Could not find a route. Please try different locations.';
        _state = NavigationState.idle;
      }
    } catch (e) {
      _errorMessage = 'Route generation failed: $e';
      _state = NavigationState.idle;
    }

    _isLoadingRoute = false;
    notifyListeners();
  }

  Future<void> generateSmartRoute() async {
    if (_sourceLocation == null || _destinationLocation == null) return;

    _isLoadingRoute = true;
    notifyListeners();

    try {
      final result = await ApiService.getSmartRoute(
        _sourceLocation!.latitude, _sourceLocation!.longitude,
        _destinationLocation!.latitude, _destinationLocation!.longitude,
      );

      if (result != null && result['success'] == true) {
        _currentRoute = RouteModel.fromJson(result['route']);
        _routeWarnings = List<Map<String, dynamic>>.from(result['warnings'] ?? []);
        _state = NavigationState.routeReady;
      }
    } catch (e) {
      _errorMessage = 'Smart route failed: $e';
    }

    _isLoadingRoute = false;
    notifyListeners();
  }

  // ============ NAVIGATION ============

  void startNavigation() {
    if (_currentRoute == null) return;

    _state = NavigationState.navigating;
    _isDiverted = false;

    // Start GPS tracking
    LocationService.startTracking(
      onLocationUpdate: _onLocationUpdate,
    );

    // Subscribe to location stream
    _locationSubscription = LocationService.locationStream.listen(_onLocationUpdate);

    // Start periodic alert checking
    _alertCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkForAlerts(),
    );

    _reportCheckTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _loadNearbyReports(),
    );

    notifyListeners();
  }

  void stopNavigation() {
    _state = NavigationState.idle;
    _locationSubscription?.cancel();
    _alertCheckTimer?.cancel();
    _reportCheckTimer?.cancel();
    LocationService.stopTracking();
    _isDiverted = false;
    _currentRoute = null;
    _originalRoute = null;
    _nearbyReports = [];
    _activeAlerts = [];
    _routeWarnings = [];
    notifyListeners();
  }

  void _onLocationUpdate(LatLng position) {
    _currentLocation = position;

    if (_state == NavigationState.navigating && _currentRoute != null) {
      // Check for diversion
      _deviationDistance = LocationService.distanceToRoute(
        position, _currentRoute!.coordinates,
      );

      if (_deviationDistance > _diversionThreshold && !_isDiverted) {
        _isDiverted = true;
        _state = NavigationState.diverted;
        notifyListeners();
        return;
      }

      if (_deviationDistance <= _diversionThreshold && _isDiverted) {
        _isDiverted = false;
        _state = NavigationState.navigating;
      }

      // Check if arrived (within 50m of destination)
      if (_destinationLocation != null) {
        final distToEnd = LocationService.distanceBetween(
          position, _destinationLocation!,
        );
        if (distToEnd < 50) {
          _state = NavigationState.arrived;
          stopNavigation();
          _state = NavigationState.arrived;
        }
      }

      // Update remaining distance
      _updateRemainingDistance(position);
    }

    notifyListeners();
  }

  void _updateRemainingDistance(LatLng position) {
    if (_currentRoute == null || _destinationLocation == null) return;

    _distanceRemaining = LocationService.distanceBetween(
      position, _destinationLocation!,
    );

    // Rough duration estimate based on remaining distance
    if (_currentRoute!.distance > 0) {
      _durationRemaining = (_distanceRemaining / _currentRoute!.distance) *
          _currentRoute!.duration;
    }
  }

  // ============ REPORTS ============

  Future<void> submitDiversionReport(String reason, {String reasonText = ''}) async {
    if (_currentLocation == null) return;

    final result = await ApiService.submitReport(
      latitude: _currentLocation!.latitude,
      longitude: _currentLocation!.longitude,
      reason: reason,
      reasonText: reasonText,
    );

    if (result != null) {
      // Re-route from current position
      _sourceLocation = _currentLocation;
      _sourceText = 'Current Location';
      await generateRoute();

      if (_currentRoute != null) {
        _state = NavigationState.navigating;
        _isDiverted = false;
      }
    }

    notifyListeners();
  }

  Future<void> quickReport(String reason) async {
    if (_currentLocation == null) return;

    await ApiService.submitReport(
      latitude: _currentLocation!.latitude,
      longitude: _currentLocation!.longitude,
      reason: reason,
    );

    _loadNearbyReports();
  }

  Future<void> _loadRouteReports() async {
    if (_currentRoute == null || _currentLocation == null) return;

    _nearbyReports = await ApiService.getNearbyReports(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      radius: 5000,
    );
    notifyListeners();
  }

  Future<void> _loadNearbyReports() async {
    if (_currentLocation == null) return;

    _nearbyReports = await ApiService.getNearbyReports(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    );
    notifyListeners();
  }

  Future<void> _checkForAlerts() async {
    if (_currentLocation == null) return;

    _activeAlerts = await ApiService.getAlerts(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    );
    notifyListeners();
  }

  // ============ CLEANUP ============

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alertCheckTimer?.cancel();
    _reportCheckTimer?.cancel();
    LocationService.stopTracking();
    super.dispose();
  }
}
