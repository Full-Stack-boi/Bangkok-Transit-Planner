import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../models/custom_location.dart';
import '../../models/crowd_report.dart';
import '../../models/route_result.dart';
import '../../providers/providers.dart';
import '../../repositories/favorites_repository.dart';
import '../search/search_view_model.dart';
import '../../core/constants/translation_helper.dart';
import 'widgets/map_search_overlay.dart';
import 'widgets/route_result_banner.dart';
import '../route_result/route_result_sheet.dart';
import '../../providers/route_tracker.dart';
import 'cached_tile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map screen showing an interactive transit map with overlays
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final _tileProvider = CachedTileProvider();
  Station? _selectedStation;
  CustomLocation? _customSelectedLocation;
  Position? _userPosition;
  bool _isLocating = false;
  bool _isPrefetchExpanded = true;

  // Caches for Map Layer Optimization
  List<Polyline> _cachedPolylines = [];
  RouteResult? _lastRouteResultForPolylines;
  Brightness? _lastBrightnessForPolylines;

  List<Marker> _cachedBaseMarkers = [];
  RouteResult? _lastRouteResultForMarkers;
  Brightness? _lastBrightnessForMarkers;
  String? _lastCurrentStationId;

  @override
  void initState() {
    super.initState();
    // Clear Flutter's memory image cache to force reloading fresh tiles from disk
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _fetchUserLocation();
    _initOfflineMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final routeResult = ref.read(searchViewModelProvider).routeResult;
        if (routeResult != null) {
          _fitRouteBounds(routeResult);
        }
        // Register listener once — not every build()
        ref.listenManual<SearchState>(searchViewModelProvider, (previous, next) {
          if (next.routeResult != null && next.routeResult != previous?.routeResult) {
            _fitRouteBounds(next.routeResult!);
          }
        });
      }
    });
  }

  Future<void> _initOfflineMap() async {
    try {
      await CachedTileProvider.getCachePath();
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final isPrefetched = prefs.getBool('map_prefetch_completed') ?? false;

        if (!isPrefetched) {
          final stations = ref.read(transitRepositoryProvider).stations;
          // Prefetch tiles in background (non-blocking)
          CachedTileProvider.prefetchBangkokTiles(
            stations,
            onStart: (total) {
              ref.read(mapPrefetchProvider.notifier).startPrefetch(total);
            },
            onProgress: (current, success, cached, error) {
              ref.read(mapPrefetchProvider.notifier).updateProgress(
                    current: current,
                    success: success,
                    cached: cached,
                    error: error,
                  );
            },
            onFinish: (completed, lostConnection) async {
              if (completed) {
                ref.read(mapPrefetchProvider.notifier).finishPrefetch();
                // Clear cache and rebuild map when prefetch completes to immediately show high-res tiles
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                if (mounted) {
                  setState(() {});
                }
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('map_prefetch_completed', true);
                } catch (e) {
                  print('Failed to save prefetching completion status: $e');
                }
              } else {
                ref.read(mapPrefetchProvider.notifier).pausePrefetch();
                if (lostConnection && mounted) {
                  final t = ref.read(translationsProvider);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.errors.errorNoInternet,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
          );
        }
      }
    } catch (e) {
      print('Failed to initialize offline map prefetching: $e');
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitRouteBounds(RouteResult routeResult) {
    final points = <LatLng>[];
    points.add(LatLng(routeResult.origin.lat, routeResult.origin.lng));
    points.add(LatLng(routeResult.destination.lat, routeResult.destination.lng));

    for (final segment in routeResult.segments) {
      if (segment.lineId == 'WALK' && segment.walkingPath != null && segment.walkingPath!.isNotEmpty) {
        points.addAll(segment.walkingPath!);
      } else {
        points.add(LatLng(segment.fromStation.lat, segment.fromStation.lng));
        points.add(LatLng(segment.toStation.lat, segment.toStation.lng));
        for (final s in segment.intermediateStations) {
          points.add(LatLng(s.lat, s.lng));
        }
      }
    }

    if (points.isEmpty) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.only(
              left: 50.0,
              right: 50.0,
              top: 80.0,
              bottom: 260.0,
            ),
          ),
        );
      }
    });
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _isLocating = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final hasMock = kDebugMode && ref.read(mockLocationProvider) != null;
      final hasPermission = hasMock || await locationService.isLocationPermissionGranted();
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
    final routeResult = ref.watch(searchViewModelProvider.select((s) => s.routeResult));
    final isRouteActive = routeResult != null;
    final localeCode = ref.watch(localeProvider);
    final isTrackingActive = ref.watch(routeTrackerProvider.select((s) => s.isActive));
    final trackerState = isTrackingActive ? ref.watch(routeTrackerProvider) : null;
    final prefetchState = ref.watch(mapPrefetchProvider);

    // Build Polylines for transit lines
    final themeBrightness = theme.brightness;
    if (_lastRouteResultForPolylines != routeResult || _lastBrightnessForPolylines != themeBrightness) {
      _lastRouteResultForPolylines = routeResult;
      _lastBrightnessForPolylines = themeBrightness;
      final newPolylines = <Polyline>[];
      if (isRouteActive) {
        // Highlight ONLY the active route
        for (final segment in routeResult.segments) {
          final points = <LatLng>[];
          if (segment.lineId == 'WALK' && segment.walkingPath != null && segment.walkingPath!.isNotEmpty) {
            points.addAll(segment.walkingPath!);
          } else {
            points.add(LatLng(segment.fromStation.lat, segment.fromStation.lng));
            for (final s in segment.intermediateStations) {
              points.add(LatLng(s.lat, s.lng));
            }
            points.add(LatLng(segment.toStation.lat, segment.toStation.lng));
          }

          final isWalk = segment.lineId == 'WALK';
          newPolylines.add(
            Polyline(
              points: points,
              color: isWalk ? Colors.grey : TransitColors.getLineColor(segment.lineId),
              strokeWidth: isWalk ? 3.5 : 6.0,
              pattern: isWalk ? const StrokePattern.dotted() : const StrokePattern.solid(),
              borderColor: isWalk 
                  ? Colors.transparent 
                  : (themeBrightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.3)),
              borderStrokeWidth: isWalk ? 0.0 : 1.5,
            ),
          );
        }
      } else {
        // Show all lines
        for (final line in transitRepo.lines) {
          final points = line.stationIds.map((id) {
            final station = transitRepo.getStation(id);
            return LatLng(station!.lat, station.lng);
          }).toList();

          newPolylines.add(
            Polyline(
              points: points,
              color: TransitColors.getLineColor(line.id),
              strokeWidth: 4.5,
              borderColor: themeBrightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.3),
              borderStrokeWidth: 1.0,
            ),
          );
        }
      }
      _cachedPolylines = newPolylines;
    }
    final polylines = _cachedPolylines;

    // Build Station Markers
    final currentStationId = trackerState?.currentStation?.id;
    if (_lastRouteResultForMarkers != routeResult || 
        _lastBrightnessForMarkers != themeBrightness || 
        _lastCurrentStationId != currentStationId) {
      _lastRouteResultForMarkers = routeResult;
      _lastBrightnessForMarkers = themeBrightness;
      _lastCurrentStationId = currentStationId;
      final newMarkers = <Marker>[];
      
      if (isRouteActive) {
      // Find all transit stations on the route
      final routeStations = <Station>[];
      for (final segment in routeResult.segments) {
        if (segment.fromStation is Station) {
          final s = segment.fromStation as Station;
          if (!routeStations.any((x) => x.id == s.id)) routeStations.add(s);
        }
        for (final s in segment.intermediateStations) {
          if (!routeStations.any((x) => x.id == s.id)) routeStations.add(s);
        }
        if (segment.toStation is Station) {
          final s = segment.toStation as Station;
          if (!routeStations.any((x) => x.id == s.id)) routeStations.add(s);
        }
      }

      // Add markers for only these stations
      for (final station in routeStations) {
        final lineColor = TransitColors.getLineColor(station.lineId);
        final isInterchange = station.interchange.isNotEmpty;
        final isCurrentStation = isTrackingActive && trackerState?.currentStation?.id == station.id;

        newMarkers.add(
          Marker(
            point: LatLng(station.lat, station.lng),
            width: isCurrentStation ? 44 : (isInterchange ? 32 : 24),
            height: isCurrentStation ? 44 : (isInterchange ? 32 : 24),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStation = station);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isCurrentStation 
                      ? Colors.green 
                      : (theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrentStation ? Colors.white : lineColor,
                    width: isCurrentStation ? 4.0 : (isInterchange ? 4.0 : 3.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isCurrentStation ? Colors.green.withValues(alpha: 0.5) : Colors.black26,
                      blurRadius: isCurrentStation ? 8 : 4,
                      spreadRadius: isCurrentStation ? 2 : 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: isCurrentStation
                      ? const Icon(Icons.navigation_rounded, size: 20, color: Colors.white)
                      : (isInterchange
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
                            )),
                ),
              ),
            ),
          ),
        );
      }

      // Add Station Exit Markers
      for (final segment in routeResult.segments) {
        if (segment.lineId == 'WALK' && segment.exit != null) {
          final exit = segment.exit!;
          newMarkers.add(
            Marker(
              point: LatLng(exit.lat, exit.lng),
              width: 32,
              height: 32,
              child: Tooltip(
                message: localeCode == 'en' ? 'Exit ${exit.exitCode}' : 'ทางออก ${exit.exitCode}',
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      exit.exitCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

        // Add custom origin/destination pins
        // Origin Pin (Green)
        newMarkers.add(
          Marker(
            point: LatLng(routeResult.origin.lat, routeResult.origin.lng),
            width: 40,
            height: 44,
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: routeResult.origin.displayName(isEnglish: localeCode == 'en'),
              child: CustomMapPin(
                color: Colors.green.shade600,
                icon: Icons.trip_origin_rounded,
              ),
            ),
          ),
        );

        // Destination Pin (Red)
        newMarkers.add(
          Marker(
            point: LatLng(routeResult.destination.lat, routeResult.destination.lng),
            width: 40,
            height: 44,
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: routeResult.destination.displayName(isEnglish: localeCode == 'en'),
              child: CustomMapPin(
                color: Colors.red.shade600,
                icon: Icons.flag_rounded,
              ),
            ),
          ),
        );
      } else {
        // Show all stations
      for (final station in transitRepo.stations) {
        final lineColor = TransitColors.getLineColor(station.lineId);
        final isInterchange = station.interchange.isNotEmpty;

        newMarkers.add(
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
                  color: themeBrightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
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
                          color: themeBrightness == Brightness.dark ? Colors.white : Colors.black,
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
    }
    _cachedBaseMarkers = newMarkers;
    }
    
    final markers = List<Marker>.from(_cachedBaseMarkers);

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
          height: 44,
          alignment: Alignment.topCenter,
          child: CustomMapPin(
            color: theme.colorScheme.primary,
            icon: Icons.push_pin_rounded,
          ),
        ),
      );
    }

    final t = ref.watch(translationsProvider);

    final isBottomCardVisible = _selectedStation != null ||
        _customSelectedLocation != null ||
        (isRouteActive && !isTrackingActive) ||
        isTrackingActive;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Map Layer ───
          RepaintBoundary(
            child: ColoredBox(
              color: themeBrightness == Brightness.dark
                  ? const Color(0xFF111111) // Matches CartoDB Dark Matter theme
                  : const Color(0xFFE4E3DF), // Matches CartoDB Voyager theme
              child: ExcludeSemantics(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(13.7563, 100.5018),
                    initialZoom: 12.0,
                    minZoom: 10.5,
                    maxZoom: 16.0,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: LatLngBounds(
                        const LatLng(13.20, 100.00),
                        const LatLng(14.25, 101.00),
                      ),
                    ),
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
                      tileProvider: _tileProvider,
                      maxNativeZoom: 18,
                      keepBuffer: 4,
                      panBuffer: 2,
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 300),
                      ),
                    ),
                    PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
          ),

          // ─── Floating Top Search Card & Prefetch Indicator ───
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final searchState = ref.watch(searchViewModelProvider);
                      return _buildTopSearchCard(context, searchState, t, localeCode);
                    },
                  ),
                  if (prefetchState.isPrefetching) ...[
                    const SizedBox(height: 8),
                    _buildMapPrefetchWidget(context, prefetchState, theme, t),
                  ],
                ],
              ),
            ),
          ),

          // ─── Floating GPS Button ───
          Positioned(
            right: 16,
            bottom: isBottomCardVisible ? 180 : 24,
            child: FloatingActionButton.small(
              heroTag: 'map_gps_fab',
              onPressed: _centerOnUser,
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
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

          // ─── Route Result Banner ───
          if (isRouteActive && !isTrackingActive && _selectedStation == null && _customSelectedLocation == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: RouteResultBanner(
                result: routeResult,
                t: t,
                onTap: () => _showRouteDetail(context),
              ),
            ),

          // ─── Active Journey Tracking Panel ───
          if (isTrackingActive && _selectedStation == null && _customSelectedLocation == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildActiveJourneyPanel(
                context,
                trackerState!,
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
                    style: TextStyle(
                      color: TransitColors.getLineTextColor(station.lineId),
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setOrigin(station);
                      setState(() => _selectedStation = null);
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.destination == null) {
                        _openSearchOverlay(context, focusDestination: true);
                      }
                    },
                    icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                    label: Text(t.favorites.setOriginBtn),
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
                      setState(() => _selectedStation = null);
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.origin == null) {
                        _openSearchOverlay(context, focusDestination: false);
                      }
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                    label: Text(t.favorites.setDestBtn),
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

  void _showRouteDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const RouteResultSheet(),
    );
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
                        t.proximity.nearStationWalk(nearestName, '${walkMin.toInt()}'),
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
                      setState(() => _customSelectedLocation = null);
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.destination == null) {
                        _openSearchOverlay(context, focusDestination: true);
                      }
                    },
                    icon: const Icon(Icons.trip_origin_rounded, size: 16, color: Colors.green),
                    label: Text(t.favorites.setOriginBtn),
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
                      setState(() => _customSelectedLocation = null);
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.origin == null) {
                        _openSearchOverlay(context, focusDestination: false);
                      }
                    },
                    icon: const Icon(Icons.location_on_rounded, size: 16, color: Colors.red),
                    label: Text(t.favorites.setDestBtn),
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

  Widget _buildActiveJourneyPanel(
    BuildContext context,
    RouteTrackerState tracker,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final segment = tracker.currentSegment;
    if (segment == null) return const SizedBox.shrink();

    final isWalk = segment.lineId == 'WALK';
    final lineColor = isWalk ? Colors.grey : TransitColors.getLineColor(segment.lineId);
    final stations = tracker.currentSegmentStations;

    if (tracker.hasArrived) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                t.journey.arrivedLabel,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  ref.read(routeTrackerProvider.notifier).stopTracking();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(t.journey.endJourneyBtn),
              ),
            ],
          ),
        ),
      );
    }

    final currentStationName = tracker.currentStation?.displayName(isEnglish: localeCode == 'en') ?? '';
    final nextStationName = tracker.nextStation?.displayName(isEnglish: localeCode == 'en') ?? '';

    // Calculate progress
    double progress = 1.0;
    if (stations.isNotEmpty) {
      progress = (tracker.currentStationIndex + 1) / stations.length;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Line Badge and Segment progress
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isWalk ? t.journey.walkToLabel : segment.lineName,
                    style: TextStyle(
                      color: isWalk ? Colors.white : TransitColors.getLineTextColor(segment.lineId),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWalk 
                        ? '~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}'
                        : '${stations.length} ${t.journey.stationsCount}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (tracker.isSimulation) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.amber.shade700, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.journey.simulationMode,
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: lineColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(lineColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 16),

            // Current & Next station details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.journey.currentStationLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStationName.isNotEmpty ? currentStationName : (isWalk ? segment.fromStation.displayName(isEnglish: localeCode == 'en') : ''),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 20),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.journey.nextStationLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextStationName.isNotEmpty ? nextStationName : (isWalk ? segment.toStation.displayName(isEnglish: localeCode == 'en') : '-'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Buttons: Simulation Step & End Journey
            Row(
              children: [
                if (tracker.isSimulation) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(routeTrackerProvider.notifier).advanceSimulation();
                      },
                      icon: const Icon(Icons.skip_next_rounded, size: 20),
                      label: Text(t.journey.nextSimulationBtn),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(routeTrackerProvider.notifier).stopTracking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(t.journey.endJourneyBtn),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSearchCard(
    BuildContext context,
    SearchState searchState,
    AppLocalizations t,
    String localeCode,
  ) {
    final theme = Theme.of(context);
    final hasOrigin = searchState.origin != null;
    final hasDest = searchState.destination != null;

    if (!hasOrigin && !hasDest) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            _openSearchOverlay(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.localeCode == 'th' ? 'ค้นหาเส้นทาง...' : 'Plan a Journey...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (hasOrigin && hasDest) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: t.localeCode == 'th' ? 'ล้างเส้นทาง' : 'Clear Route',
                onPressed: () {
                  ref.read(searchViewModelProvider.notifier).clear();
                },
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _openSearchOverlay(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.trip_origin_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                searchState.origin!.displayName(isEnglish: localeCode == 'en'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.red, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                searchState.destination!.displayName(isEnglish: localeCode == 'en'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded),
                tooltip: t.localeCode == 'th' ? 'สลับต้นทาง/ปลายทาง' : 'Swap Origin/Destination',
                onPressed: () {
                  ref.read(searchViewModelProvider.notifier).swapStations();
                },
              ),
            ],
          ),
        ),
      );
    }

    // Only one is set
    final setItem = hasOrigin ? searchState.origin : searchState.destination;
    final isOrigin = hasOrigin;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          _openSearchOverlay(context, focusDestination: isOrigin);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isOrigin ? Icons.trip_origin_rounded : Icons.location_on_rounded,
                color: isOrigin ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${isOrigin ? (t.localeCode == 'th' ? 'ต้นทาง: ' : 'From: ') : (t.localeCode == 'th' ? 'ปลายทาง: ' : 'To: ')}'
                  '${setItem!.displayName(isEnglish: localeCode == 'en')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isOrigin
                    ? (t.localeCode == 'th' ? 'เลือกปลายทาง...' : 'Choose destination...')
                    : (t.localeCode == 'th' ? 'เลือกต้นทาง...' : 'Choose origin...'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPrefetchWidget(
    BuildContext context,
    MapPrefetchProgress prefetchState,
    ThemeData theme,
    AppLocalizations t,
  ) {
    final isTh = t.localeCode == 'th';
    final percentage = (prefetchState.progress * 100).toInt();
    final showDetails = _isPrefetchExpanded && !prefetchState.isPaused;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Control Button (Larger 44x44px button with custom progress border)
        CustomPaint(
          foregroundPainter: _RoundedRectangleProgressPainter(
            progress: prefetchState.progress,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            strokeWidth: 3.0,
            borderRadius: 8.0,
          ),
          child: GestureDetector(
            onTap: () {
              if (prefetchState.isPaused) {
                // Resume
                CachedTileProvider.isPaused = false;
                ref.read(mapPrefetchProvider.notifier).resumePrefetch();
                setState(() {
                  _isPrefetchExpanded = true;
                });
                _initOfflineMap();
              } else {
                if (!_isPrefetchExpanded) {
                  // If collapsed but downloading, tapping expands it
                  setState(() {
                    _isPrefetchExpanded = true;
                  });
                } else {
                  // If expanded, tapping pauses and collapses
                  CachedTileProvider.isPaused = true;
                  ref.read(mapPrefetchProvider.notifier).pausePrefetch();
                  setState(() {
                    _isPrefetchExpanded = false;
                  });
                }
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  prefetchState.isPaused ? Icons.play_arrow : Icons.pause,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        // Animated Details Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: showDetails ? 288 : 0,
          height: showDetails ? 104 : 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 288,
              maxWidth: 288,
              minHeight: 104,
              maxHeight: 104,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 280,
                  height: 104,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isTh ? 'ดาวน์โหลดแผนที่ออฟไลน์' : 'Downloading Offline Map',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isPrefetchExpanded = false;
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prefetchState.progress,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isTh 
                                ? 'ดาวน์โหลดแล้ว ${prefetchState.currentTile} / ${prefetchState.totalTiles} รูป' 
                                : 'Downloaded ${prefetchState.currentTile} / ${prefetchState.totalTiles} tiles',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTh
                            ? 'เก็บในเครื่องแล้ว: ${prefetchState.cachedCount} รูป | โหลดใหม่: ${prefetchState.successCount} รูป'
                            : 'Cached: ${prefetchState.cachedCount} | New: ${prefetchState.successCount} tiles',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openSearchOverlay(BuildContext context, {bool focusDestination = false}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MapSearchOverlay(focusDestination: focusDestination),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }
}

class CustomMapPin extends StatelessWidget {
  final Color color;
  final IconData icon;

  const CustomMapPin({
    super.key,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pin Bubble
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        // Pin Tip (Teardrop pointer)
        Transform.translate(
          offset: const Offset(0, -1.5), // overlap slightly to merge borders
          child: CustomPaint(
            size: const Size(10, 5),
            painter: _TrianglePainter(color: color),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw triangle pointing down
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    // Draw white borders for the triangle to match the bubble border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final borderPath = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);

    canvas.drawPath(path, paint);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundedRectangleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double borderRadius;

  _RoundedRectangleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 3.0,
    this.borderRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Paint background border
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, bgPaint);

    // 2. Paint progress border
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = ui.Path()..addRRect(rrect);
      final pathMetrics = path.computeMetrics();
      for (final metric in pathMetrics) {
        final extractPath = metric.extractPath(0.0, metric.length * progress);
        canvas.drawPath(extractPath, progressPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedRectangleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}


