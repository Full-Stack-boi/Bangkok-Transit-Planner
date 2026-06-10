import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../search/search_screen.dart';
import '../map/map_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';

/// Main home screen with bottom navigation
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _screens = const [
    SearchScreen(),
    MapScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

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

      // Check location permission
      final isGranted = await locationService.isLocationPermissionGranted();
      if (!isGranted) {
        // Request permission silently
        final requested = await locationService.requestLocationPermission();
        if (!requested) return;
      }

      // Get current user position
      final position = await locationService.getCurrentPosition();
      if (position == null) return;

      // Find nearby station within 200m
      final nearbyStation = locationService.findNearbyStation(
        position,
        transitRepo.stations,
        thresholdMeters: 200.0,
      );

      if (nearbyStation != null) {
        // Passive report presence
        await crowdRepo.reportPresence(
          stationId: nearbyStation.id,
          accuracy: position.accuracy,
        );
      }
    } catch (e) {
      print('Failed to perform passive GPS proximity check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(transitInitProvider);
    final currentIndex = ref.watch(homeTabIndexProvider);

    return Scaffold(
      body: initState.when(
        data: (_) => IndexedStack(
          index: currentIndex,
          children: _screens,
        ),
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(error: error.toString()),
      ),
      bottomNavigationBar: _buildBottomNav(context, currentIndex),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        ref.read(homeTabIndexProvider.notifier).state = index;
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.search_rounded),
          label: 'ค้นหา',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map_rounded),
          label: 'แผนที่',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_outline_rounded),
          selectedIcon: Icon(Icons.favorite_rounded),
          label: 'รายการโปรด',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'ตั้งค่า',
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

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
            'กำลังโหลดข้อมูลสถานี...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

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
              'เกิดข้อผิดพลาด',
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
