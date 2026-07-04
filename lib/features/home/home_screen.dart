import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../utility/utility_screen.dart';
import '../../core/theme/app_theme.dart';
import '../map/map_screen.dart' deferred as map_screen;
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
      debugPrint('Failed to perform passive GPS proximity check: $e');
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
    final isWide = MediaQuery.of(context).size.width >= 900;

    final content = initState.when(
      data: (_) => Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              UtilityScreen(),
              _DeferredMapScreen(),
              FavoritesScreen(),
              SettingsScreen(),
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
    );

    if (isWide && initState.hasValue) {
      return Scaffold(
        body: Row(
          children: [
            const AppNavigationRail(),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: const AppBottomNavigationBar(),
    );
  }
}

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations(locale);
    final theme = Theme.of(context);

    final activeColors = [
      theme.colorScheme.primary, // Seafoam Sage for Transit Lines
      theme.appColors.routeColor ?? const Color(0xFF818CF8), // Soft Lavender for Map
      theme.appColors.favoriteColor ?? const Color(0xFFF472B6), // Coral Pink for Favorites (Heart)
      theme.appColors.timeColor ?? const Color(0xFFF59E0B), // Warm Amber for Settings
    ];
    final activeColor = activeColors[currentIndex];

    return Theme(
      data: theme.copyWith(
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          indicatorColor: activeColor.withValues(alpha: 0.15),
          selectedIconTheme: IconThemeData(color: activeColor, size: 24),
          selectedLabelTextStyle: GoogleFonts.outfit(
            color: activeColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedIconTheme: const IconThemeData(
            color: Color(0xFF64748B),
            size: 24,
          ),
          unselectedLabelTextStyle: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(homeTabIndexProvider.notifier).setTab(index);
        },
        labelType: NavigationRailLabelType.all,
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize, color: activeColors[0]),
            label: Text(t.navigation.utilityTitle),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: activeColors[1]),
            label: Text(t.navigation.mapTitle),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: activeColors[2]),
            label: Text(t.navigation.favoritesTitle),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: activeColors[3]),
            label: Text(t.navigation.settingsTitle),
          ),
        ],
      ),
    );
  }
}

class AppBottomNavigationBar extends ConsumerWidget {
  const AppBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations(locale);
    final theme = Theme.of(context);

    final activeColors = [
      theme.colorScheme.primary, // Seafoam Sage for Transit Lines
      theme.appColors.routeColor ?? const Color(0xFF818CF8), // Soft Lavender for Map
      theme.appColors.favoriteColor ?? const Color(0xFFF472B6), // Coral Pink for Favorites (Heart)
      theme.appColors.timeColor ?? const Color(0xFFF59E0B), // Warm Amber for Settings
    ];
    final activeColor = activeColors[currentIndex];

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: activeColor.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.outfit(
                color: activeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }
            return GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
      ),
      child: NavigationBar(
        height: 66.0,
        key: ValueKey('nav_bar_$locale'),
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(homeTabIndexProvider.notifier).setTab(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize, color: activeColors[0]),
            label: t.navigation.utilityTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: activeColors[1]),
            label: t.navigation.mapTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: activeColors[2]),
            label: t.navigation.favoritesTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: activeColors[3]),
            label: t.navigation.settingsTitle,
          ),
        ],
      ),
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

class _DeferredMapScreen extends StatefulWidget {
  const _DeferredMapScreen();

  @override
  State<_DeferredMapScreen> createState() => _DeferredMapScreenState();
}

class _DeferredMapScreenState extends State<_DeferredMapScreen> {
  bool _loaded = false;
  Future<void>? _loadFuture;

  void _load() {
    if (_loadFuture != null) return;
    _loadFuture = map_screen.loadLibrary().then((_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) {
      return map_screen.MapScreen();
    }

    return Consumer(
      builder: (context, ref, child) {
        final currentIndex = ref.watch(homeTabIndexProvider);
        if (currentIndex == 1) {
          _load();
        }
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 3),
        );
      },
    );
  }
}
