import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import 'favorites_view_model.dart';

/// Favorites screen showing favorite stations and saved routes
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh favorites data whenever the tab is entered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(favoritesViewModelProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesViewModelProvider);
    final vm = ref.read(favoritesViewModelProvider.notifier);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('รายการโปรด'),
          bottom: TabBar(
            tabs: const [
              Tab(
                icon: Icon(Icons.favorite_rounded),
                text: 'สถานีโปรด',
              ),
              Tab(
                icon: Icon(Icons.route_rounded),
                text: 'เส้นทางที่บันทึก',
              ),
            ],
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        body: TabBarView(
          children: [
            _buildStationsTab(context, state, vm, theme),
            _buildRoutesTab(context, state, vm, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStationsTab(
    BuildContext context,
    FavoritesState state,
    FavoritesViewModel vm,
    ThemeData theme,
  ) {
    if (state.favoriteStations.isEmpty) {
      return _buildEmptyState(
        context: context,
        icon: Icons.favorite_outline_rounded,
        title: 'ยังไม่มีสถานีโปรด',
        subtitle: 'ค้นหาสถานีและกดรูปหัวใจเพื่อบันทึกสถานีที่ใช้เป็นประจำ',
        theme: theme,
      );
    }

    final scheduleService = ref.watch(scheduleServiceProvider);
    final crowdService = ref.watch(crowdServiceProvider);
    final searchVm = ref.read(searchViewModelProvider.notifier);

    return ListView.builder(
      itemCount: state.favoriteStations.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final station = state.favoriteStations[index];
        final lineColor = TransitColors.getLineColor(station.lineId);
        final crowdInfo = crowdService.getCrowdInfo(station.id);
        final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(station.lineId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Code + Name + Delete)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        station.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.nameTh,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            station.nameEn,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () => vm.toggleFavoriteStation(station.id),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Next Train & Crowd Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Next Train
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          minutesUntilNext == null
                              ? 'หมดระยะบริการ'
                              : (minutesUntilNext == 0 ? 'รถกำลังเข้าสถานี' : 'ขบวนถัดไป: ~$minutesUntilNext นาที'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: minutesUntilNext == 0 ? Colors.amber.shade700 : null,
                            fontWeight: minutesUntilNext == 0 ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),

                    // Crowd Level
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 14,
                          color: crowdInfo.level == CrowdLevel.high
                              ? Colors.red
                              : (crowdInfo.level == CrowdLevel.medium ? Colors.orange : Colors.green),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'คนรอ: ${crowdInfo.levelTextTh} (~${crowdInfo.presenceCount} คน)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: crowdInfo.level == CrowdLevel.high
                                ? Colors.red.shade400
                                : (crowdInfo.level == CrowdLevel.medium
                                    ? Colors.orange.shade400
                                    : Colors.green.shade400),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          searchVm.setOrigin(station);
                          ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                        },
                        icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                        label: const Text('ตั้งเป็นต้นทาง'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          searchVm.setDestination(station);
                          ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                        },
                        icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                        label: const Text('ตั้งเป็นปลายทาง'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
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

  Widget _buildRoutesTab(
    BuildContext context,
    FavoritesState state,
    FavoritesViewModel vm,
    ThemeData theme,
  ) {
    if (state.savedRoutes.isEmpty) {
      return _buildEmptyState(
        context: context,
        icon: Icons.alt_route_rounded,
        title: 'ยังไม่มีเส้นทางที่บันทึก',
        subtitle: 'คุณสามารถบันทึกเส้นทางที่ใช้ประจำหลังจากคำนวณเส้นทางแล้ว',
        theme: theme,
      );
    }

    final searchVm = ref.read(searchViewModelProvider.notifier);
    final transitRepo = ref.read(transitRepositoryProvider);

    return ListView.builder(
      itemCount: state.savedRoutes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final route = state.savedRoutes[index];
        final originId = route['origin_id'] ?? '';
        final destinationId = route['destination_id'] ?? '';
        final routeName = route['name'] ?? 'เส้นทางไม่มีชื่อ';
        final originName = route['origin_name'] ?? '';
        final destinationName = route['destination_name'] ?? '';

        final originStation = transitRepo.getStation(originId);
        final destStation = transitRepo.getStation(destinationId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.route_rounded, color: theme.colorScheme.primary),
            ),
            title: Text(
              routeName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$originName → $destinationName',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => vm.deleteRoute(originId, destinationId),
                ),
              ],
            ),
            onTap: () {
              if (originStation != null && destStation != null) {
                searchVm.setOrigin(originStation);
                searchVm.setDestination(destStation);
                ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
