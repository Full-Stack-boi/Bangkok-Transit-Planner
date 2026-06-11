import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../models/custom_location.dart';
import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../../repositories/favorites_repository.dart';
import '../search/search_view_model.dart';
import '../../core/constants/translation_helper.dart';

/// Map screen showing an interactive transit map with overlays
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Station? _selectedStation;
  CustomLocation? _customSelectedLocation;
  Position? _userPosition;
  bool _isLocating = false;
  double _currentZoom = 12.0;

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

      // Always show full custom-designed interactive markers
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

    // Custom pinned location marker
    if (_customSelectedLocation != null) {
      markers.add(
        Marker(
          point: LatLng(_customSelectedLocation!.lat, _customSelectedLocation!.lng),
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_on_rounded,
            color: theme.colorScheme.error,
            size: 36,
          ),
        ),
      );
    }

    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('map_title')),
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
              minZoom: 10.5,
              maxZoom: 16.0,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(13.48, 100.32),
                  const LatLng(14.00, 100.82),
                ),
              ),
              onPositionChanged: (position, hasGesture) {
                if (position.zoom != null) {
                  _currentZoom = position.zoom!;
                }
              },
              onTap: (position, point) {
                if (_selectedStation != null) {
                  setState(() => _selectedStation = null);
                }
                
                final nearest = _findNearestStation(point, transitRepo.stations);
                if (nearest != null) {
                  final dist = Geolocator.distanceBetween(
                    point.latitude, point.longitude, nearest.lat, nearest.lng
                  );
                  final walkMin = (dist / 80.0).clamp(1.0, 30.0);

                  setState(() {
                    _selectedStation = null;
                    _customSelectedLocation = CustomLocation(
                      id: 'CUSTOM_${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}',
                      nameTh: 'จุดที่เลือก (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
                      nameEn: 'Selected Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
                      nearestStationId: nearest.id,
                      walkingMinutes: walkMin,
                      lat: point.latitude,
                      lng: point.longitude,
                    );
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: theme.brightness == Brightness.dark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bkktransit.bkk_transit_planner',
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
                t,
                localeCode,
              ),
            ),

          // ─── Custom Selected Location Details Popup Card ───
          if (_customSelectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildCustomLocationDetailsCard(
                context,
                _customSelectedLocation!,
                theme,
                t,
                localeCode,
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
    AppLocalizations t,
    String localeCode,
  ) {
    final transitRepo = ref.read(transitRepositoryProvider);
    final lineColor = TransitColors.getLineColor(station.lineId);
    final scheduleService = ref.watch(scheduleServiceProvider);
    final crowdService = ref.watch(crowdServiceProvider);
    final searchVm = ref.read(searchViewModelProvider.notifier);

    final isFav = favoritesRepo.isFavoriteStation(station.id);
    final crowdInfo = crowdService.getCrowdInfo(station.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(station.lineId);

    final stationName = localeCode == 'th' ? station.nameTh : station.nameEn;
    final stationSubName = localeCode == 'th' ? station.nameEn : station.nameTh;

    // Find all stations in the same interchange hub
    final hubStations = <Station>[station];
    for (final interchangeId in station.interchange) {
      final s = transitRepo.getStation(interchangeId);
      if (s != null && !hubStations.contains(s)) {
        hubStations.add(s);
      }
    }
    hubStations.sort((a, b) {
      // Prioritize BTS over MRT over ARL
      int getPriority(String lineId) {
        if (lineId.startsWith('BTS')) return 0;
        if (lineId.startsWith('MRT')) return 1;
        return 2;
      }
      final pA = getPriority(a.lineId);
      final pB = getPriority(b.lineId);
      if (pA != pB) return pA.compareTo(pB);
      return a.id.compareTo(b.id);
    });

    final String trainStatusText;
    if (minutesUntilNext == null) {
      trainStatusText = t.get('service_ended');
    } else if (minutesUntilNext == 0) {
      trainStatusText = t.get('train_arriving');
    } else {
      trainStatusText = '${t.get('next_train')}: ~$minutesUntilNext ${t.get('minutes_unit')}';
    }

    String getCrowdLevelText(CrowdLevel level) {
      switch (level) {
        case CrowdLevel.low:
          return t.get('crowd_low');
        case CrowdLevel.medium:
          return t.get('crowd_medium');
        case CrowdLevel.high:
          return t.get('crowd_high');
        case CrowdLevel.unknown:
          return t.get('crowd_unknown');
      }
    }

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
                        stationName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stationSubName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
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
            if (hubStations.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: hubStations.map((hubStation) {
                    final hubLine = transitRepo.getLine(hubStation.lineId);
                    final hubLineColor = TransitColors.getLineColor(hubStation.lineId);
                    final isSelected = hubStation.id == station.id;
                    final hubLineName = hubLine != null
                        ? (localeCode == 'th' ? hubLine.nameTh : hubLine.nameEn)
                        : hubStation.lineId;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          '${hubStation.code} - $hubLineName',
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white 
                                : hubLineColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: hubLineColor,
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade100,
                        checkmarkColor: Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: hubLineColor,
                            width: 1.5,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStation = hubStation;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const Divider(height: 16),

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
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
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
                      size: 16,
                      color: crowdInfo.level == CrowdLevel.high
                          ? Colors.red
                          : (crowdInfo.level == CrowdLevel.medium ? Colors.orange : Colors.green),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${t.get('crowd_level')}: ${getCrowdLevelText(crowdInfo.level)} (~${crowdInfo.presenceCount} ${localeCode == 'th' ? 'คน' : 'pax'})',
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
                    label: Text(t.get('set_origin_btn')),
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
                    label: Text(t.get('set_dest_btn')),
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

  Station? _findNearestStation(LatLng point, List<Station> stations) {
    if (stations.isEmpty) return null;
    Station? closest;
    double minDist = double.infinity;
    for (final s in stations) {
      final dist = Geolocator.distanceBetween(
        point.latitude, point.longitude, s.lat, s.lng
      );
      if (dist < minDist) {
        minDist = dist;
        closest = s;
      }
    }
    return closest;
  }

  Widget _buildCustomLocationDetailsCard(
    BuildContext context,
    CustomLocation location,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final searchVm = ref.read(searchViewModelProvider.notifier);
    final transitRepo = ref.read(transitRepositoryProvider);
    final nearest = transitRepo.getStation(location.nearestStationId);
    final nearestName = nearest?.displayName(isEnglish: localeCode == 'en') ?? '';
    final walkMin = location.walkingMinutes.toInt();

    final stationName = localeCode == 'th' ? location.nameTh : location.nameEn;

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  color: theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 8),
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
                        localeCode == 'en'
                            ? 'Near $nearestName station · ~$walkMin min walk'
                            : 'ใกล้สถานี$nearestName · เดิน ~$walkMin นาที',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    setState(() => _customSelectedLocation = null);
                  },
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setOrigin(location);
                      ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                      setState(() => _customSelectedLocation = null);
                    },
                    icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                    label: Text(t.get('set_origin_btn')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setDestination(location);
                      ref.read(homeTabIndexProvider.notifier).state = 0; // Switch to Search Screen
                      setState(() => _customSelectedLocation = null);
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                    label: Text(t.get('set_dest_btn')),
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
