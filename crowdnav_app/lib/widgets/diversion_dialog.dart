import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class DiversionDialog extends StatefulWidget {
  final Function(String reason, String? reasonText) onSubmit;
  final VoidCallback? onDismiss;

  const DiversionDialog({
    super.key,
    required this.onSubmit,
    this.onDismiss,
  });

  @override
  State<DiversionDialog> createState() => _DiversionDialogState();
}

class _DiversionDialogState extends State<DiversionDialog>
    with SingleTickerProviderStateMixin {
  String? _selectedReason;
  final _otherController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<_ReasonOption> _reasons = [
    _ReasonOption('road_blocked', Icons.block_rounded, 'Road Blocked', Color(0xFFEF5350)),
    _ReasonOption('traffic', Icons.traffic_rounded, 'Heavy Traffic', Color(0xFFFFB300)),
    _ReasonOption('accident', Icons.car_crash_rounded, 'Accident', Color(0xFFFF5722)),
    _ReasonOption('personal_preference', Icons.alt_route_rounded, 'Personal Choice', Color(0xFF66BB6A)),
    _ReasonOption('other', Icons.edit_note_rounded, 'Other', Color(0xFF78909C)),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _otherController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withOpacity(0.15),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: AppTheme.accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Route Changed',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Why did you change your route?',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Reason options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: _reasons.map((reason) {
                    final isSelected = _selectedReason == reason.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selectedReason = reason.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? reason.color.withOpacity(0.15)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? reason.color
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  reason.icon,
                                  color: isSelected
                                      ? reason.color
                                      : AppTheme.textMuted,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  reason.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: reason.color,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Other text input
              if (_selectedReason == 'other')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _otherController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Tell us more...',
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          widget.onDismiss?.call();
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _selectedReason != null
                            ? () {
                                widget.onSubmit(
                                  _selectedReason!,
                                  _selectedReason == 'other'
                                      ? _otherController.text
                                      : null,
                                );
                                Navigator.of(context).pop();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor: AppTheme.surfaceLight,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Report & Re-route',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonOption {
  final String id;
  final IconData icon;
  final String label;
  final Color color;

  _ReasonOption(this.id, this.icon, this.label, this.color);
}
