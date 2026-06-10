import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../../repositories/favorites_repository.dart';
import '../search/search_view_model.dart';

/// Map screen showing an interactive transit map with overlays
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Station? _selectedStation;
  Position? _userPosition;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _isLocating = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final hasPermission = await locationService.isLocationPermissionGranted();
      if (hasPermission) {
        final pos = await locationService.getCurrentPosition();
        if (pos != null && mounted) {
          setState(() => _userPosition = pos);
        }
      }
    } catch (e) {
      print('Error fetching location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _centerOnUser() {
    if (_userPosition != null) {
      _mapController.move(
        LatLng(_userPosition!.latitude, _userPosition!.longitude),
        14.0,
      );
    } else {
      _fetchUserLocation().then((_) {
        if (_userPosition != null) {
          _mapController.move(
            LatLng(_userPosition!.latitude, _userPosition!.longitude),
            14.0,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transitRepo = ref.watch(transitRepositoryProvider);
    final favoritesRepo = ref.watch(favoritesRepositoryProvider);

    // Build Polylines for transit lines
    final polylines = <Polyline>[];
    for (final line in transitRepo.lines) {
      final points = line.stationIds.map((id) {
        final station = transitRepo.getStation(id);
        return LatLng(station!.lat, station.lng);
      }).toList();

      if (line.isLoop && points.isNotEmpty) {
        points.add(points.first); // Close the circle for MRT Blue Line
      }

      polylines.add(
        Polyline(
          points: points,
          color: TransitColors.getLineColor(line.id),
          strokeWidth: 4.5,
          borderColor: theme.brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.3),
          borderStrokeWidth: 1.0,
        ),
      );
    }

    // Build Station Markers
    final markers = <Marker>[];
    for (final station in transitRepo.stations) {
      final lineColor = TransitColors.getLineColor(station.lineId);
      final isInterchange = station.interchange.isNotEmpty;

      markers.add(
        Marker(
          point: LatLng(station.lat, station.lng),
          width: isInterchange ? 32 : 24,
          height: isInterchange ? 32 : 24,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedStation = station);
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: lineColor,
                  width: isInterchange ? 4.0 : 3.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isInterchange
                    ? Icon(
                        Icons.swap_horiz_rounded,
                        size: 14,
                        color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                      )
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: lineColor,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    // User location marker
    if (_userPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent,
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('แผนที่รถไฟฟ้า'),
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            onPressed: _centerOnUser,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ─── Map Layer ───
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(13.7563, 100.5018),
              initialZoom: 12.0,
              minZoom: 10.0,
              maxZoom: 17.0,
              onTap: (_, __) {
                // Dismiss details card when tapping on empty map space
                if (_selectedStation != null) {
                  setState(() => _selectedStation = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: theme.brightness == Brightness.dark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.bkktransit.bkk_transit_planner',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // ─── Station Details Popup Card ───
          if (_selectedStation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildStationDetailsCard(
                context,
                _selectedStation!,
                favoritesRepo,
                theme,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStationDetailsCard(
    BuildContext context,
    Station station,
    FavoritesRepository favoritesRepo,
    ThemeData theme,
  ) {
    final lineColor = TransitColors.getLineColor(station.lineId);
    final scheduleService = ref.watch(scheduleServiceProvider);
    final crowdService = ref.watch(crowdServiceProvider);
    final searchVm = ref.read(searchViewModelProvider.notifier);

    final isFav = favoritesRepo.isFavoriteStation(station.id);
    final crowdInfo = crowdService.getCrowdInfo(station.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(station.lineId);

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Name + Close Button)
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
                const SizedBox(width: 8),
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
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isFav ? Colors.red : null,
                  ),
                  onPressed: () async {
                    await favoritesRepo.toggleFavoriteStation(station.id);
                    setState(() {}); // Rebuild to toggle icon
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() => _selectedStation = null);
                  },
                ),
              ],
            ),
            const Divider(height: 16),

            // Next Train & Crowd Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Next Train
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
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
                      size: 16,
                      color: crowdInfo.level == CrowdLevel.high
                          ? Colors.red
                          : (crowdInfo.level == CrowdLevel.medium ? Colors.orange : Colors.green),
                    ),
                    const SizedBox(width: 6),
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setOrigin(station);
                      ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                      setState(() => _selectedStation = null);
                    },
                    icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                    label: const Text('ตั้งเป็นต้นทาง'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setDestination(station);
                      ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                      setState(() => _selectedStation = null);
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                    label: const Text('ตั้งเป็นปลายทาง'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
