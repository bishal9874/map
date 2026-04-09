import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/app_theme.dart';

class NavigationPanel extends StatelessWidget {
  final VoidCallback? onStopNavigation;

  const NavigationPanel({super.key, this.onStopNavigation});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, nav, _) {
        if (nav.state == NavigationState.idle) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border.all(
              color: _getBorderColor(nav.state).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status bar
              _buildStatusBar(nav),

              // Route info
              if (nav.currentRoute != null) _buildRouteInfo(nav),

              // Warnings
              if (nav.routeWarnings.isNotEmpty) _buildWarnings(nav),

              // Active alerts
              if (nav.activeAlerts.isNotEmpty) _buildAlerts(nav),

              // Action buttons
              _buildActions(context, nav),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(NavigationProvider nav) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(nav.state).withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          _buildStatusIcon(nav.state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(nav.state),
                  style: TextStyle(
                    color: _getStatusColor(nav.state),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (nav.state == NavigationState.diverted)
                  Text(
                    'Deviation: ${nav.deviationDistance.round()}m from route',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (nav.state == NavigationState.navigating ||
              nav.state == NavigationState.diverted)
            _buildLiveIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(NavigationState state) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getStatusColor(state).withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getStatusIcon(state),
        color: _getStatusColor(state),
        size: 20,
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: AppTheme.error, size: 10),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(NavigationProvider nav) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildInfoChip(
            icon: Icons.timer_outlined,
            label: nav.currentRoute!.durationText,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          _buildInfoChip(
            icon: Icons.straighten_rounded,
            label: nav.currentRoute!.distanceText,
            color: AppTheme.accent,
          ),
          if (nav.state == NavigationState.navigating) ...[
            const SizedBox(width: 12),
            _buildInfoChip(
              icon: Icons.near_me_rounded,
              label: _formatDistance(nav.distanceRemaining),
              color: AppTheme.success,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarnings(NavigationProvider nav) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Column(
        children: nav.routeWarnings.take(3).map((w) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w['message'] ?? 'Caution ahead',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlerts(NavigationProvider nav) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        children: nav.activeAlerts.take(2).map((alert) {
          final color = AppTheme.reportColors[alert.type] ?? AppTheme.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  AppTheme.reportIcons[alert.type] ?? Icons.warning_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.message,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActions(BuildContext context, NavigationProvider nav) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (nav.state == NavigationState.routeReady) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => nav.startNavigation(),
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text('Start Navigation',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (nav.state == NavigationState.navigating ||
              nav.state == NavigationState.diverted) ...[
            // Quick report button
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => _showQuickReport(context, nav),
                icon: const Icon(Icons.report_rounded, color: AppTheme.warning),
                tooltip: 'Quick Report',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  nav.stopNavigation();
                  onStopNavigation?.call();
                },
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text('Stop',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (nav.state == NavigationState.arrived) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  nav.stopNavigation();
                  onStopNavigation?.call();
                },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showQuickReport(BuildContext context, NavigationProvider nav) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quick Report',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _quickReportChip(ctx, nav, 'road_blocked', Icons.block_rounded, 'Road Blocked', AppTheme.error),
                _quickReportChip(ctx, nav, 'traffic', Icons.traffic_rounded, 'Traffic', AppTheme.warning),
                _quickReportChip(ctx, nav, 'accident', Icons.car_crash_rounded, 'Accident', const Color(0xFFFF5722)),
                _quickReportChip(ctx, nav, 'other', Icons.warning_amber_rounded, 'Other Issue', AppTheme.textMuted),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickReportChip(
    BuildContext context,
    NavigationProvider nav,
    String reason,
    IconData icon,
    String label,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          nav.quickReport(reason);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('$label reported! Thanks for helping others.'),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(NavigationState state) {
    switch (state) {
      case NavigationState.navigating:
        return AppTheme.success;
      case NavigationState.diverted:
        return AppTheme.accent;
      case NavigationState.arrived:
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  Color _getStatusColor(NavigationState state) {
    switch (state) {
      case NavigationState.searching:
        return AppTheme.primary;
      case NavigationState.routeReady:
        return AppTheme.primary;
      case NavigationState.navigating:
        return AppTheme.success;
      case NavigationState.diverted:
        return AppTheme.accent;
      case NavigationState.arrived:
        return AppTheme.success;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _getStatusIcon(NavigationState state) {
    switch (state) {
      case NavigationState.searching:
        return Icons.search_rounded;
      case NavigationState.routeReady:
        return Icons.route_rounded;
      case NavigationState.navigating:
        return Icons.navigation_rounded;
      case NavigationState.diverted:
        return Icons.alt_route_rounded;
      case NavigationState.arrived:
        return Icons.flag_rounded;
      default:
        return Icons.explore_rounded;
    }
  }

  String _getStatusText(NavigationState state) {
    switch (state) {
      case NavigationState.searching:
        return 'Finding route...';
      case NavigationState.routeReady:
        return 'Route Ready';
      case NavigationState.navigating:
        return 'Navigating';
      case NavigationState.diverted:
        return 'Route Changed!';
      case NavigationState.arrived:
        return 'You\'ve Arrived! 🎉';
      default:
        return '';
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m left';
    return '${(meters / 1000).toStringAsFixed(1)}km left';
  }
}
