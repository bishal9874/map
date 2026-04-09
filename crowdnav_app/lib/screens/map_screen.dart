import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/search_panel.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/diversion_dialog.dart';
import '../widgets/alert_banner.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _showSearchPanel = true;
  bool _diversionDialogShown = false;
  NavigationState? _lastState;

  // Default center (can be updated with user location)
  LatLng _mapCenter = const LatLng(28.6139, 77.2090); // New Delhi

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  void _initializeMap() {
    final nav = context.read<NavigationProvider>();
    if (nav.currentLocation != null) {
      setState(() {
        _mapCenter = nav.currentLocation!;
      });
      _animatedMapMove(_mapCenter, 15.0);
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavigationProvider>(
        builder: (context, nav, _) {
          // Handle diversion state change
          _handleStateChange(nav);

          return Stack(
            children: [
              // Map layer
              _buildMap(nav),

              // Top safe area gradient
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: MediaQuery.of(context).padding.top + 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Alert banner (top)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: const AlertBanner(),
              ),

              // Search panel (top)
              if (_showSearchPanel &&
                  (nav.state == NavigationState.idle ||
                      nav.state == NavigationState.searching))
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0,
                  right: 0,
                  child: SearchPanel(
                    onRouteGenerated: () {
                      setState(() => _showSearchPanel = false);
                      if (nav.currentRoute != null) {
                        _fitRouteBounds(nav);
                      }
                    },
                  ),
                ),

              // Error message
              if (nav.errorMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: _buildErrorBanner(nav.errorMessage!),
                ),

              // Navigation panel (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: NavigationPanel(
                  onStopNavigation: () {
                    setState(() {
                      _showSearchPanel = true;
                      _diversionDialogShown = false;
                    });
                  },
                ),
              ),

              // Floating action buttons
              _buildFloatingButtons(nav),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(NavigationProvider nav) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: 14.0,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onTap: (_, __) {
          FocusScope.of(context).unfocus();
        },
      ),
      children: [
        // Map tiles - OSM
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.crowdnav.app',
          maxZoom: 19,
          tileBuilder: _darkModeTileBuilder,
        ),

        // Route polyline
        if (nav.currentRoute != null)
          PolylineLayer(
            polylines: [
              // Main route
              Polyline(
                points: nav.currentRoute!.coordinates,
                color: AppTheme.primary.withOpacity(0.9),
                strokeWidth: 6.0,
                borderColor: AppTheme.primaryDark.withOpacity(0.5),
                borderStrokeWidth: 2.0,
              ),
              // Route glow effect
              Polyline(
                points: nav.currentRoute!.coordinates,
                color: AppTheme.primary.withOpacity(0.2),
                strokeWidth: 14.0,
              ),
            ],
          ),

        // Report markers
        if (nav.nearbyReports.isNotEmpty)
          MarkerLayer(
            markers: nav.nearbyReports.map((report) {
              final color =
                  AppTheme.reportColors[report.reason] ?? AppTheme.warning;
              final icon =
                  AppTheme.reportIcons[report.reason] ?? Icons.warning_rounded;

              return Marker(
                point: report.location,
                width: 40,
                height: 40,
                child: _buildReportMarker(color, icon, report.confidenceScore),
              );
            }).toList(),
          ),

        // User location marker
        if (nav.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: nav.currentLocation!,
                width: 60,
                height: 60,
                child: _buildUserLocationMarker(),
              ),
            ],
          ),

        // Source marker
        if (nav.sourceLocation != null &&
            nav.sourceLocation != nav.currentLocation)
          MarkerLayer(
            markers: [
              Marker(
                point: nav.sourceLocation!,
                width: 40,
                height: 50,
                child: _buildPinMarker(AppTheme.success, 'A'),
              ),
            ],
          ),

        // Destination marker
        if (nav.destinationLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: nav.destinationLocation!,
                width: 40,
                height: 50,
                child: _buildPinMarker(AppTheme.accent, 'B'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _darkModeTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.2, -0.7, -0.08, 0, 255,
        -0.2, -0.7, -0.08, 0, 255,
        -0.2, -0.7, -0.08, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse ring
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.15),
          ),
        ),
        // Middle ring
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.25),
          ),
        ),
        // Inner dot
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinMarker(Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 10),
          painter: _TrianglePainter(color),
        ),
      ],
    );
  }

  Widget _buildReportMarker(Color color, IconData icon, double confidence) {
    final opacity = 0.5 + (confidence * 0.5);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _buildFloatingButtons(NavigationProvider nav) {
    return Positioned(
      right: 16,
      bottom: nav.state == NavigationState.idle ? 100 : 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle search
          if (!_showSearchPanel &&
              (nav.state == NavigationState.idle ||
                  nav.state == NavigationState.routeReady))
            _buildFAB(
              icon: Icons.search_rounded,
              color: AppTheme.primary,
              onTap: () => setState(() => _showSearchPanel = true),
              heroTag: 'search',
            ),
          const SizedBox(height: 10),

          // Center on user
          _buildFAB(
            icon: Icons.my_location_rounded,
            color: AppTheme.surfaceCard,
            onTap: () {
              if (nav.currentLocation != null) {
                _animatedMapMove(nav.currentLocation!, 16.0);
              }
            },
            heroTag: 'location',
          ),
          const SizedBox(height: 10),

          // Zoom controls
          _buildFAB(
            icon: Icons.add_rounded,
            color: AppTheme.surfaceCard,
            onTap: () {
              final zoom = _mapController.camera.zoom + 1;
              _mapController.move(_mapController.camera.center, zoom);
            },
            heroTag: 'zoomin',
            mini: true,
          ),
          const SizedBox(height: 6),
          _buildFAB(
            icon: Icons.remove_rounded,
            color: AppTheme.surfaceCard,
            onTap: () {
              final zoom = _mapController.camera.zoom - 1;
              _mapController.move(_mapController.camera.center, zoom);
            },
            heroTag: 'zoomout',
            mini: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String heroTag,
    bool mini = false,
  }) {
    return Container(
      width: mini ? 40 : 48,
      height: mini ? 40 : 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Icon(
            icon,
            color: AppTheme.textPrimary,
            size: mini ? 18 : 22,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.error.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
            onPressed: () {
              // Clear error would need a method on provider
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _handleStateChange(NavigationProvider nav) {
    if (_lastState != nav.state) {
      _lastState = nav.state;

      if (nav.state == NavigationState.diverted && !_diversionDialogShown) {
        _diversionDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showDiversionDialog();
        });
      }

      if (nav.state == NavigationState.navigating) {
        _diversionDialogShown = false;
        _showSearchPanel = false;
      }

      if (nav.state == NavigationState.arrived) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showArrivedDialog();
        });
      }
    }
  }

  void _showDiversionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DiversionDialog(
        onSubmit: (reason, reasonText) {
          final nav = context.read<NavigationProvider>();
          nav.submitDiversionReport(reason, reasonText: reasonText ?? '');
          _diversionDialogShown = false;
        },
        onDismiss: () {
          _diversionDialogShown = false;
        },
      ),
    );
  }

  void _showArrivedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withOpacity(0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppTheme.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You\'ve Arrived! 🎉',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thanks for using CrowdNav!',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fitRouteBounds(NavigationProvider nav) {
    if (nav.currentRoute == null) return;

    final bounds = LatLngBounds.fromPoints(nav.currentRoute!.coordinates);

    // Use camera fit with padding
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 200),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
