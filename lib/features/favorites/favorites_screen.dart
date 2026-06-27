import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/crowd_report.dart';
import '../../models/searchable_item.dart';
import '../../models/station.dart';
import '../../models/custom_location.dart';
import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import 'favorites_view_model.dart';
import '../../core/constants/translation_helper.dart';
import '../../repositories/transit_repository.dart';

/// Favorites screen showing favorite stations and saved routes with language localization
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _resolvedItems = <String, SearchableItem?>{};

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
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.navigation.favoritesTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.favorite_rounded),
                text: t.favorites.favStationsTab,
              ),
              Tab(
                icon: const Icon(Icons.route_rounded),
                text: t.favorites.favRoutesTab,
              ),
            ],
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        body: TabBarView(
          children: [
            _buildStationsTab(context, state, vm, theme, t, localeCode),
            _buildRoutesTab(context, state, vm, theme, t, localeCode),
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
    AppLocalizations t,
    String localeCode,
  ) {
    if (state.favoriteStations.isEmpty) {
      return _buildEmptyState(
        context: context,
        icon: Icons.favorite_outline_rounded,
        title: t.favorites.emptyFavTitle,
        subtitle: t.favorites.emptyFavSubtitle,
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

        final String stationName = localeCode == 'th' ? station.nameTh : station.nameEn;

        final String trainStatusText;
        if (minutesUntilNext == null) {
          trainStatusText = t.routeResult.serviceEnded;
        } else if (minutesUntilNext == 0) {
          trainStatusText = t.routeResult.trainArriving;
        } else {
          trainStatusText = '${t.routeResult.nextTrain}: ~$minutesUntilNext ${t.common.minutesUnit}';
        }

        String getCrowdLevelText(CrowdLevel level) {
          switch (level) {
            case CrowdLevel.low:
              return t.routeResult.crowdLow;
            case CrowdLevel.medium:
              return t.routeResult.crowdMedium;
            case CrowdLevel.high:
              return t.routeResult.crowdHigh;
            case CrowdLevel.unknown:
              return t.routeResult.crowdUnknown;
          }
        }

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
                        style: TextStyle(
                          color: TransitColors.getLineTextColor(station.lineId),
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
                            stationName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            localeCode == 'th' ? station.nameEn : station.nameTh,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      onPressed: () {
                        vm.toggleFavoriteStation(station.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.favorites.stationRemovedFav)),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Next Train & Crowd Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Next Train
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trainStatusText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: minutesUntilNext == 0 ? Colors.amber.shade700 : null,
                                fontWeight: minutesUntilNext == 0 ? FontWeight.bold : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                          '${t.routeResult.crowdLevel}: ${getCrowdLevelText(crowdInfo.level)} (~${crowdInfo.presenceCount} ${localeCode == 'th' ? 'คน' : 'pax'})',
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
                          ref.read(homeTabIndexProvider.notifier).setTab(1); // Switch to Map Screen (search is on Map)
                        },
                        icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                        label: Text(t.favorites.setOriginBtn),
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
                          ref.read(homeTabIndexProvider.notifier).setTab(1); // Switch to Map Screen (search is on Map)
                        },
                        icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                        label: Text(t.favorites.setDestBtn),
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

  SearchableItem? _resolveSearchableItem(
    String id,
    String nameTh,
    String nameEn,
    String? latStr,
    String? lngStr,
    TransitRepository transitRepo,
  ) {
    if (id.isEmpty) return null;
    final cacheKey = '${id}_${latStr}_$lngStr';
    if (_resolvedItems.containsKey(cacheKey)) {
      return _resolvedItems[cacheKey];
    }

    // 1. Check if it's a station
    final station = transitRepo.getStation(id);
    if (station != null) {
      _resolvedItems[cacheKey] = station;
      return station;
    }

    // 2. Check if it's a landmark
    for (final l in transitRepo.landmarks) {
      if (l.id == id) {
        _resolvedItems[cacheKey] = l;
        return l;
      }
    }

    // 3. Check if we have stored coordinates
    double? lat;
    double? lng;
    if (latStr != null && latStr.isNotEmpty && lngStr != null && lngStr.isNotEmpty) {
      lat = double.tryParse(latStr);
      lng = double.tryParse(lngStr);
    }

    // 4. If no stored coordinates, try to parse from ID (for CUSTOM_lat_lng or OSM_type_id_lat_lng)
    if (lat == null || lng == null) {
      if (id.startsWith('CUSTOM_')) {
        final parts = id.split('_');
        if (parts.length >= 3) {
          lat = double.tryParse(parts[1]);
          lng = double.tryParse(parts[2]);
        }
      } else if (id.startsWith('OSM_')) {
        final parts = id.split('_');
        if (parts.length >= 5) {
          lat = double.tryParse(parts[3]);
          lng = double.tryParse(parts[4]);
        }
      }
    }

    // 5. If we resolved coordinates, create a CustomLocation
    if (lat != null && lng != null) {
      // Find nearest station
      Station? nearest;
      double minDist = double.infinity;
      for (final s in transitRepo.stations) {
        final dist = Geolocator.distanceBetween(lat, lng, s.lat, s.lng);
        if (dist < minDist) {
          minDist = dist;
          nearest = s;
        }
      }
      final walkMin = nearest != null
          ? (minDist / 80.0).clamp(1.0, 30.0)
          : 5.0;

      final loc = CustomLocation(
        id: id,
        nameTh: nameTh,
        nameEn: nameEn,
        nearestStationId: nearest?.id ?? '',
        walkingMinutes: walkMin,
        lat: lat,
        lng: lng,
      );
      _resolvedItems[cacheKey] = loc;
      return loc;
    }

    _resolvedItems[cacheKey] = null;
    return null;
  }

  Widget _buildRoutesTab(
    BuildContext context,
    FavoritesState state,
    FavoritesViewModel vm,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    if (state.savedRoutes.isEmpty) {
      return _buildEmptyState(
        context: context,
        icon: Icons.alt_route_rounded,
        title: t.favorites.emptyRouteTitle,
        subtitle: t.favorites.emptyRouteSubtitle,
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
        final String? routeName = route['name'];
        final String routeDisplayName = (routeName == null || routeName.isEmpty || routeName == 'เส้นทางไม่มีชื่อ')
            ? t.favorites.unnamedRoute
            : routeName;
        String originName = route['origin_name'] ?? '';
        String destinationName = route['destination_name'] ?? '';
        if (originName.isEmpty || destinationName.isEmpty) {
          final nameParts = (route['name'] ?? '').split(' - ');
          if (nameParts.length >= 2) {
            if (originName.isEmpty) originName = nameParts[0];
            if (destinationName.isEmpty) destinationName = nameParts[1];
          }
        }
        final originLatStr = route['origin_lat'];
        final originLngStr = route['origin_lng'];
        final destLatStr = route['destination_lat'];
        final destLngStr = route['destination_lng'];

        final originItem = _resolveSearchableItem(
          originId,
          originName,
          originName,
          originLatStr,
          originLngStr,
          transitRepo,
        );

        final destItem = _resolveSearchableItem(
          destinationId,
          destinationName,
          destinationName,
          destLatStr,
          destLngStr,
          transitRepo,
        );

        final String originDisplayName = originItem != null
            ? (localeCode == 'th' ? originItem.nameTh : originItem.nameEn)
            : originName;
        final String destDisplayName = destItem != null
            ? (localeCode == 'th' ? destItem.nameTh : destItem.nameEn)
            : destinationName;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.route_rounded, color: theme.colorScheme.primary),
            ),
            title: Text(
              routeDisplayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$originDisplayName → $destDisplayName',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () {
                    vm.deleteRoute(originId, destinationId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.routeResult.routeDeletedSuccess)),
                    );
                  },
                ),
              ],
            ),
            onTap: () async {
              if (originItem != null && destItem != null) {
                await searchVm.setRoute(originItem, destItem);
                ref.read(homeTabIndexProvider.notifier).setTab(1); // Switch to Map Screen
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
