import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../utils/app_theme.dart';

class SearchPanel extends StatefulWidget {
  final VoidCallback? onRouteGenerated;
  
  const SearchPanel({super.key, this.onRouteGenerated});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> with SingleTickerProviderStateMixin {
  final _sourceController = TextEditingController();
  final _destController = TextEditingController();
  bool _isSearchingSource = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    
    // Set initial source text
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = context.read<NavigationProvider>();
      if (nav.sourceText.isNotEmpty) {
        _sourceController.text = nav.sourceText;
      }
    });
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Plan Your Route',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // Search fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Source
                  _buildSearchField(
                    controller: _sourceController,
                    hint: 'Start location',
                    icon: Icons.radio_button_checked_rounded,
                    iconColor: AppTheme.success,
                    isSource: true,
                    onChanged: (val) {
                      _isSearchingSource = true;
                      context.read<NavigationProvider>().searchPlaces(val);
                    },
                  ),
                  
                  // Connection line
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.success.withOpacity(0.6),
                                AppTheme.accent.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Destination
                  _buildSearchField(
                    controller: _destController,
                    hint: 'Where to?',
                    icon: Icons.location_on_rounded,
                    iconColor: AppTheme.accent,
                    isSource: false,
                    onChanged: (val) {
                      _isSearchingSource = false;
                      context.read<NavigationProvider>().searchPlaces(val);
                    },
                  ),
                ],
              ),
            ),
            
            // Search results
            Consumer<NavigationProvider>(
              builder: (context, nav, _) {
                if (nav.searchResults.isNotEmpty) {
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: nav.searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        color: AppTheme.textMuted.withOpacity(0.2),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final result = nav.searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.place_rounded,
                            color: _isSearchingSource ? AppTheme.success : AppTheme.accent,
                            size: 20,
                          ),
                          title: Text(
                            result.shortName,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.displayName,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            if (_isSearchingSource) {
                              nav.setSource(result);
                              _sourceController.text = result.shortName;
                            } else {
                              nav.setDestination(result);
                              _destController.text = result.shortName;
                            }
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            // Route button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Consumer<NavigationProvider>(
                builder: (context, nav, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: nav.isLoadingRoute
                          ? null
                          : () async {
                              FocusScope.of(context).unfocus();
                              await nav.generateRoute();
                              widget.onRouteGenerated?.call();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 6,
                        shadowColor: AppTheme.primary.withOpacity(0.4),
                      ),
                      child: nav.isLoadingRoute
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.route_rounded, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Find Route',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isSource,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: onChanged,
            ),
          ),
          if (isSource)
            IconButton(
              icon: const Icon(Icons.my_location_rounded, color: AppTheme.primary, size: 20),
              onPressed: () {
                final nav = context.read<NavigationProvider>();
                nav.setSourceFromCurrentLocation();
                controller.text = 'Current Location';
              },
            ),
        ],
      ),
    );
  }
}
