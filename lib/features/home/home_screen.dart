import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../utility/utility_screen.dart';
import '../map/map_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/constants/translation_helper.dart';
import '../../services/location_service.dart';
import '../../models/station.dart';
import 'widgets/nearest_stations_sheet.dart';
import 'widgets/in_app_notification_banner.dart';

/// Main home screen with bottom navigation
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showInAppBanner = false;
  String _bannerTitle = '';
  String _bannerBody = '';
  List<MapEntry<Station, double>> _nearestStations = [];
  double _gpsAccuracy = 10.0;

  void _onBannerTap() {
    setState(() {
      _showInAppBanner = false;
    });
    _showNearestStationsBottomSheet();
  }

  void _onBannerDismiss() {
    setState(() {
      _showInAppBanner = false;
    });
  }

  void _showNearestStationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NearestStationsSheet(
        nearestEntries: _nearestStations,
        accuracy: _gpsAccuracy,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Start passive GPS check-in after data finishes loading
    Future.microtask(() => _initGPSProximityCheck());
  }

  Future<void> _initGPSProximityCheck() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final crowdRepo = ref.read(crowdRepositoryProvider);
      final transitRepo = ref.read(transitRepositoryProvider);

      // Request notification permission silently for Android 13+
      await locationService.requestNotificationPermission();

      // Check if simulation is active (bypass permission checks in debug)
      final hasMock = kDebugMode && ref.read(mockLocationProvider) != null;
      if (!hasMock) {
        // Check location permission
        final isGranted = await locationService.isLocationPermissionGranted();
        if (!isGranted) {
          // Request permission
          final requested = await locationService.requestLocationPermission();
          if (!requested) {
            // Show alert dialog to guide user to open Settings directly
            if (mounted) {
              final t = ref.read(translationsProvider);
              _showPermissionDialog(context, locationService, t);
            }
            return;
          }
        }
      }

      // Get current user position
      final position = await locationService.getCurrentPosition();
      if (position == null) return;

      // Find the relative nearest stations in Bangkok (up to 5 within relative threshold)
      final nearestEntries = locationService.findRelativeNearestStations(
        position,
        transitRepo.stations,
        maxCount: 5,
      );

      if (nearestEntries.isNotEmpty) {
        final t = ref.read(translationsProvider);

        setState(() {
          _nearestStations = nearestEntries;
          _gpsAccuracy = position.accuracy;
          _bannerTitle = t.proximity.inAppNotifTitle;
          _bannerBody = t.proximity.inAppNotifBody(nearestEntries.length);
          _showInAppBanner = true;
        });

        // 1. Report presence passively only if the user is within 50 meters (strictly inside the station)
        final closestEntry = nearestEntries.first;
        final closestStation = closestEntry.key;
        final distance = closestEntry.value;
        
        if (distance <= 50.0) {
          await crowdRepo.reportPresence(
            stationId: closestStation.id,
            accuracy: position.accuracy,
          );
        }
      }
    } catch (e) {
      print('Failed to perform passive GPS proximity check: $e');
    }
  }

  void _showPermissionDialog(
    BuildContext context,
    LocationService locationService,
    AppLocalizations t,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.location_off_rounded, color: theme.colorScheme.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.settings.locationPermissionRequired,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            t.settings.locationPermissionDesc,
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                t.common.laterBtn,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                locationService.openSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(t.settings.openSettingsBtn),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for mock location updates to re-trigger proximity checks instantly
    ref.listen(mockLocationProvider, (previous, next) {
      _initGPSProximityCheck();
    });

    final initState = ref.watch(transitInitProvider);
    final currentIndex = ref.watch(homeTabIndexProvider);
    final t = ref.watch(translationsProvider);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: initState.when(
              data: (_) => Stack(
                children: [
                  IndexedStack(
                    index: currentIndex,
                    children: [
                      UtilityScreen(key: ValueKey('utility_${t.localeCode}')),
                      MapScreen(key: ValueKey('map_${t.localeCode}')),
                      FavoritesScreen(key: ValueKey('favorites_${t.localeCode}')),
                      SettingsScreen(key: ValueKey('settings_${t.localeCode}')),
                    ],
                  ),
                  if (_showInAppBanner)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: InAppNotificationBanner(
                        title: _bannerTitle,
                        body: _bannerBody,
                        onTap: _onBannerTap,
                        onDismiss: _onBannerDismiss,
                      ),
                    ),
                ],
              ),
              loading: () => _LoadingView(t: t),
              error: (error, _) => _ErrorView(error: error.toString(), t: t),
            ),
          ),
          // Clean Navigation Bar that reacts directly to the global state.
          // Using a unique key per locale forces a clean redraw without scoped conflicts.
          const AppBottomNavigationBar(),
        ],
      ),
    );
  }
}

class AppBottomNavigationBar extends ConsumerWidget {
  const AppBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Explicitly watch the locale and translations at this level.
    final currentIndex = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations(locale);

    return NavigationBar(
      key: ValueKey('nav_bar_$locale'),
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        // Use the root provider container to ensure the tab change
        // propagates correctly even if the local scope is being rebuilt.
        ref.read(homeTabIndexProvider.notifier).setTab(index);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_customize_outlined),
          selectedIcon: const Icon(Icons.dashboard_customize),
          label: t.navigation.utilityTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.map_outlined),
          selectedIcon: const Icon(Icons.map_rounded),
          label: t.navigation.mapTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.favorite_outline_rounded),
          selectedIcon: const Icon(Icons.favorite_rounded),
          label: t.navigation.favoritesTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: t.navigation.settingsTitle,
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  final AppLocalizations t;
  const _LoadingView({required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            t.search.loadingStations,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final AppLocalizations t;
  const _ErrorView({required this.error, required this.t});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              t.common.errorOccurred,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
