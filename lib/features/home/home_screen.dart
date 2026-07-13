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
import '../../models/location_permission_status.dart';
import 'widgets/nearest_stations_sheet.dart';
import 'widgets/in_app_notification_banner.dart';
import 'widgets/animated_indexed_stack.dart';

const double _kRailWidth = 100.0;
const double _kRailHeight = 350.0;
const double _kRailRadius = 28.0;
const double _kRailOpacity = 0.75;
const double _kRailIconSize = 28.0;
const double _kRailFontSize = 13.0;
const double _kRailPadding = 16.0;

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

  // Dwell Time geofence tracking variables
  String? _currentStationId;
  DateTime? _enteredStationAt;
  bool _promptShownForCurrentPresence = false;

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
          final status = await locationService.requestLocationPermission();
          if (status != LocationPermissionStatus.granted) {
            if (mounted) {
              final t = ref.read(translationsProvider);
              if (status == LocationPermissionStatus.permanentlyDenied) {
                // User selected "Don't ask again" — must open Settings
                await locationService.openSettings();
              } else {
                _showPermissionDialog(context, locationService, t);
              }
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
          final stationId = closestStation.id;

          if (_currentStationId != stationId) {
            _currentStationId = stationId;
            _enteredStationAt = DateTime.now();
            _promptShownForCurrentPresence = false;
          } else {
            if (_enteredStationAt != null && !_promptShownForCurrentPresence) {
              final duration = DateTime.now().difference(_enteredStationAt!);
              // In debug or mock location mode, set threshold to 1 minute to simplify testing.
              // In production, set to 10 minutes.
              final thresholdMinutes =
                  (kDebugMode || ref.read(mockLocationProvider) != null)
                  ? 1
                  : 10;

              if (duration.inMinutes >= thresholdMinutes) {
                _promptShownForCurrentPresence = true;

                final notifier = ref.read(notificationServiceProvider);
                notifier.showNotification(
                  id: 999,
                  title: t.proximity.promptDelayAtStation(
                    t.isTh ? closestStation.nameTh : closestStation.nameEn,
                  ),
                  body: t.proximity.promptDelayBody,
                  payload: 'prompt_report:$stationId',
                );
              }
            }
          }

          await crowdRepo.reportPresence(
            stationId: stationId,
            accuracy: position.accuracy,
          );
        } else {
          _currentStationId = null;
          _enteredStationAt = null;
          _promptShownForCurrentPresence = false;
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: theme.colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.settings.locationPermissionRequired,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(t.settings.openSettingsBtn),
            ),
          ],
        );
      },
    );
  }

  void _showProactiveReportBottomSheet(BuildContext context, Station station) {
    final theme = Theme.of(context);
    final t = ref.read(translationsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(
                  Icons.report_problem_outlined,
                  color: theme.colorScheme.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  t.isTh
                      ? 'คุณติดอยู่ที่สถานี ${station.nameTh} หรือไม่?'
                      : 'Are you delayed at ${station.nameEn}?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  t.isTh
                      ? 'ระบบตรวจพบว่าคุณอยู่ที่สถานีนี้นานกว่าปกติ โปรดช่วยยืนยันสถานะการเดินรถเพื่อแจ้งเพื่อนผู้โดยสารท่านอื่น'
                      : 'You have been at this station longer than usual. Please help confirm transit status for other passengers.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.proximity.normalStatusLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final crowdRepo = ref.read(crowdRepositoryProvider);
                          await crowdRepo.submitCrowdReport(
                            stationId: station.id,
                            level: 4, // High delay/crowd
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t.proximity.thankYouReportLabel),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          // Refresh the line status provider
                          ref.invalidate(transitLineStatusProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(t.proximity.yesDelayedLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for proactive report triggers from local notifications
    ref.listen<String?>(activeNotificationPayloadProvider, (previous, next) {
      if (next != null && next.startsWith('prompt_report:')) {
        final stationId = next.replaceFirst('prompt_report:', '');

        final transitRepo = ref.read(transitRepositoryProvider);
        final station = transitRepo.stations.firstWhere(
          (s) => s.id == stationId,
          orElse: () => Station(
            id: stationId,
            code: '',
            nameTh: stationId,
            nameEn: stationId,
            lineId: '',
            lat: 0,
            lng: 0,
          ),
        );

        ref.read(activeNotificationPayloadProvider.notifier).setPayload(null);
        _showProactiveReportBottomSheet(context, station);
      }
    });

    // Listen for mock location updates to re-trigger proximity checks instantly
    ref.listen(mockLocationProvider, (previous, next) {
      _initGPSProximityCheck();
    });

    final initState = ref.watch(transitInitProvider);
    final currentIndex = ref.watch(homeTabIndexProvider);
    final t = ref.watch(translationsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final content = initState.when(
      data: (_) => Stack(
        children: [
          AnimatedIndexedStack(
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
      final double leftContentPadding = currentIndex == 1 ? 0.0 : _kRailWidth;
      return Scaffold(
        body: Stack(
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              padding: EdgeInsets.only(left: leftContentPadding),
              child: content,
            ),
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AppNavigationRail(),
            ),
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
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double verticalMargin = (screenHeight - _kRailHeight) / 2;

    final activeColors = [
      theme.colorScheme.primary, // Seafoam Sage for Transit Lines
      theme.appColors.routeColor ??
          const Color(0xFF818CF8), // Soft Lavender for Map
      theme.appColors.favoriteColor ??
          const Color(0xFFF472B6), // Coral Pink for Favorites (Heart)
      theme.appColors.timeColor ??
          const Color(0xFFF59E0B), // Warm Amber for Settings
    ];
    final activeColor = activeColors[currentIndex];
    final isFloating = currentIndex == 1; // Float only on Map Screen (tab 1)

    final BorderRadius borderRadius = isFloating
        ? BorderRadius.circular(_kRailRadius)
        : BorderRadius.zero;

    // Use uniform Border.all in both states to prevent Flutter paint assertions,
    // fading the color to transparent when solid.
    final BoxBorder border = Border.all(
      color: isFloating
          ? theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08)
          : Colors.transparent,
    );

    final List<BoxShadow>? boxShadow = isFloating
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(4, 4),
            ),
          ]
        : null;

    final EdgeInsets margin = isFloating
        ? EdgeInsets.fromLTRB(
            _kRailPadding,
            verticalMargin > 0 ? verticalMargin : 0.0,
            0,
            verticalMargin > 0 ? verticalMargin : 0.0,
          )
        : EdgeInsets.zero;

    return Theme(
      data: theme.copyWith(
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          backgroundColor: Colors.transparent,
          indicatorColor: activeColor.withValues(alpha: 0.15),
          selectedIconTheme: IconThemeData(
            color: activeColor,
            size: _kRailIconSize,
          ),
          selectedLabelTextStyle: GoogleFonts.outfit(
            color: activeColor,
            fontSize: _kRailFontSize,
            fontWeight: FontWeight.w600,
          ),
          unselectedIconTheme: const IconThemeData(
            color: Color(0xFF64748B),
            size: _kRailIconSize,
          ),
          unselectedLabelTextStyle: GoogleFonts.outfit(
            color: Color(0xFF64748B),
            fontSize: _kRailFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: SizedBox(
        width:
            _kRailWidth + _kRailPadding + 8.0, // Dynamic parent container width
        height: screenHeight,
        child: Stack(
          children: [
            // 1. Animated background decoration
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: _kRailWidth,
              height: isFloating ? _kRailHeight : screenHeight,
              margin: margin,
              decoration: BoxDecoration(
                color: isFloating
                    ? theme.colorScheme.surface.withValues(alpha: _kRailOpacity)
                    : theme.colorScheme.surface,
                borderRadius: borderRadius,
                border: border,
                boxShadow: boxShadow,
              ),
            ),

            // 2. Animated position, but static layout size for NavigationRail
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: isFloating ? _kRailPadding : 0.0,
              top: isFloating ? verticalMargin : 0.0,
              width: _kRailWidth,
              height: isFloating ? _kRailHeight : screenHeight,
              child: NavigationRail(
                groupAlignment:
                    0.0, // Keep vertical position identical to prevent item shifting
                backgroundColor: Colors.transparent,
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  ref.read(homeTabIndexProvider.notifier).setTab(index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    selectedIcon: Icon(
                      Icons.dashboard_customize,
                      color: activeColors[0],
                    ),
                    label: Text(t.navigation.utilityTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: Icon(
                      Icons.map_rounded,
                      color: activeColors[1],
                    ),
                    label: Text(t.navigation.mapTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.favorite_outline_rounded),
                    selectedIcon: Icon(
                      Icons.favorite_rounded,
                      color: activeColors[2],
                    ),
                    label: Text(t.navigation.favoritesTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: Icon(
                      Icons.settings_rounded,
                      color: activeColors[3],
                    ),
                    label: Text(t.navigation.settingsTitle),
                  ),
                ],
              ),
            ),

            // 3. Right edge border line for solid sidebar state
            Positioned(
              left:
                  _kRailWidth - 1.0, // Dynamic right edge align for solid state
              top: 0,
              bottom: 0,
              width: 1.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isFloating ? 0.0 : 1.0,
                child: Container(
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                ),
              ),
            ),
          ],
        ),
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
      theme.appColors.routeColor ??
          const Color(0xFF818CF8), // Soft Lavender for Map
      theme.appColors.favoriteColor ??
          const Color(0xFFF472B6), // Coral Pink for Favorites (Heart)
      theme.appColors.timeColor ??
          const Color(0xFFF59E0B), // Warm Amber for Settings
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
            selectedIcon: Icon(
              Icons.dashboard_customize,
              color: activeColors[0],
            ),
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
        return const Center(child: CircularProgressIndicator(strokeWidth: 3));
      },
    );
  }
}
