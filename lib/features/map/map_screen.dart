import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../models/landmark.dart';
import '../../models/custom_location.dart';
import '../../models/namtang_stop.dart';
import '../../models/crowd_report.dart';
import '../../models/route_result.dart';
import '../../providers/providers.dart';
import '../../repositories/favorites_repository.dart';
import '../search/search_view_model.dart';
import '../utility/route_calculating_overlay.dart';

import '../../core/constants/translation_helper.dart';
import 'widgets/namtang_stops_layer.dart';
import 'widgets/map_search_overlay.dart';
import 'painters/station_marker_painter.dart';
import 'painters/custom_map_pin.dart';
import 'widgets/station_details_card.dart';
import 'widgets/custom_location_card.dart';
import 'widgets/namtang_stop_card.dart';
import 'widgets/active_journey_panel.dart';
import 'widgets/map_prefetch_widget.dart';

import 'widgets/route_result_banner.dart';
import '../route_result/route_result_sheet.dart';
import '../../providers/route_tracker.dart';
import '../favorites/favorites_view_model.dart';
import 'cached_tile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

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
  NamtangStop? _selectedNamtangStop;
  Position? _userPosition;
  bool _isLocating = false;
  bool _isPrefetchExpanded = true;
  final ValueNotifier<double> _currentZoom = ValueNotifier(12.0);
  bool _isOfflineMapInitializing = false;

  // Caches for Map Layer Optimization
  List<Polyline> _cachedPolylines = [];
  RouteResult? _lastRouteResultForPolylines;
  Brightness? _lastBrightnessForPolylines;

  List<Marker> _cachedBaseMarkers = [];
  RouteResult? _lastRouteResultForMarkers;
  Brightness? _lastBrightnessForMarkers;
  String? _lastCurrentStationId;
  double? _lastZoomForMarkers;

  @override
  void initState() {
    super.initState();
    // Clear Flutter's memory image cache to force reloading fresh tiles from disk
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _fetchUserLocation();
    _initOfflineMap();

    // Trigger Namtang stops loading when map is opened
    // Added a small delay to ensure UI remains responsive during transition
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) ref.read(transitRepositoryProvider).loadNamtangStops();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final routeResult = ref.read(searchViewModelProvider).routeResult;
        if (routeResult != null) {
          _fitRouteBounds(routeResult);
        }
        // Register listener once — not every build()
        ref.listenManual<SearchState>(searchViewModelProvider, (
          previous,
          next,
        ) {
          if (next.routeResult != null &&
              next.routeResult != previous?.routeResult) {
            _fitRouteBounds(next.routeResult!);
          }
        });
      }
    });
  }

  Future<void> _initOfflineMap() async {
    if (kIsWeb) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    setState(() {
      _isOfflineMapInitializing = true;
    });
    try {
      await CachedTileProvider.getCachePath();
    } catch (e) {
      AppLogger.error('Failed to initialize offline map: $e', error: e);
    } finally {
      if (mounted) {
        setState(() {
          _isOfflineMapInitializing = false;
        });
      }
    }
  }

  void _startMapPrefetch() {
    final stations = ref.read(transitRepositoryProvider).stations;
    CachedTileProvider.prefetchBangkokTiles(
      stations,
      onStart: (total) {
        ref.read(mapPrefetchProvider.notifier).startPrefetch(total);
      },
      onProgress: (current, success, cached, error) {
        ref
            .read(mapPrefetchProvider.notifier)
            .updateProgress(
              current: current,
              success: success,
              cached: cached,
              error: error,
            );
      },
      onFinish: (completed, lostConnection) async {
        if (completed) {
          ref.read(mapPrefetchProvider.notifier).finishPrefetch();
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          if (mounted) {
            setState(() {});
          }
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('map_prefetch_completed_v6_greater', true);
          } catch (e) {
            AppLogger.error(
              'Failed to save prefetching completion status: $e',
              error: e,
            );
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitRouteBounds(RouteResult routeResult) {
    final points = <LatLng>[];
    final originLat = routeResult.origin is Landmark
        ? (routeResult.origin as Landmark).routeLat
        : routeResult.origin.lat;
    final originLng = routeResult.origin is Landmark
        ? (routeResult.origin as Landmark).routeLng
        : routeResult.origin.lng;
    points.add(LatLng(originLat, originLng));

    final destLat = routeResult.destination is Landmark
        ? (routeResult.destination as Landmark).routeLat
        : routeResult.destination.lat;
    final destLng = routeResult.destination is Landmark
        ? (routeResult.destination as Landmark).routeLng
        : routeResult.destination.lng;
    points.add(LatLng(destLat, destLng));

    for (final segment in routeResult.segments) {
      if (segment.lineId == 'WALK' &&
          segment.walkingPath != null &&
          segment.walkingPath!.isNotEmpty) {
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

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

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
      final hasPermission =
          hasMock || await locationService.isLocationPermissionGranted();
      if (hasPermission) {
        final pos = await locationService.getCurrentPosition();
        if (pos != null && mounted) {
          setState(() => _userPosition = pos);
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching location: $e', error: e);
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
    final t = ref.watch(translationsProvider);
    final transitRepo = ref.watch(transitRepositoryProvider);
    final favoritesRepo = ref.watch(favoritesRepositoryProvider);
    final routeResult = ref.watch(
      searchViewModelProvider.select((s) => s.routeResult),
    );
    final isRouteActive = routeResult != null;
    final localeCode = ref.watch(localeProvider);
    final isTrackingActive = ref.watch(
      routeTrackerProvider.select((s) => s.isActive),
    );
    final trackerState = isTrackingActive
        ? ref.watch(routeTrackerProvider)
        : null;
    final prefetchState = ref.watch(mapPrefetchProvider);

    // Build Polylines for transit lines
    final themeBrightness = theme.brightness;
    if (_lastRouteResultForPolylines != routeResult ||
        _lastBrightnessForPolylines != themeBrightness) {
      _lastRouteResultForPolylines = routeResult;
      _lastBrightnessForPolylines = themeBrightness;
      final newPolylines = <Polyline>[];
      if (isRouteActive) {
        // Highlight ONLY the active route
        for (final segment in routeResult.segments) {
          final isWalk = segment.lineId == 'WALK';
          final points = <LatLng>[];
          if (isWalk &&
              segment.walkingPath != null &&
              segment.walkingPath!.isNotEmpty) {
            points.addAll(segment.walkingPath!);
          } else {
            points.add(
              LatLng(segment.fromStation.lat, segment.fromStation.lng),
            );
            for (final s in segment.intermediateStations) {
              points.add(LatLng(s.lat, s.lng));
            }
            points.add(LatLng(segment.toStation.lat, segment.toStation.lng));
          }

          newPolylines.add(
            Polyline(
              points: points,
              color: isWalk
                  ? Colors.grey
                  : TransitColors.getLineColor(segment.lineId),
              strokeWidth: isWalk ? 3.5 : 6.0,
              pattern: isWalk
                  ? const StrokePattern.dotted()
                  : const StrokePattern.solid(),
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
        _lastCurrentStationId != currentStationId ||
        _lastZoomForMarkers != _currentZoom.value) {
      _lastRouteResultForMarkers = routeResult;
      _lastBrightnessForMarkers = themeBrightness;
      _lastCurrentStationId = currentStationId;
      _lastZoomForMarkers = _currentZoom.value;
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
          final point = LatLng(station.lat, station.lng);

          final lineColor = TransitColors.getLineColor(station.lineId);
          final isInterchange = station.interchange.isNotEmpty;
          final isCurrentStation =
              isTrackingActive &&
              trackerState?.currentStation?.id == station.id;

          final double scale = (0.80 + (_currentZoom.value - 11.5) * 0.14)
              .clamp(0.80, 1.2);
          final double baseSize = isCurrentStation
              ? 44.0
              : (isInterchange ? 32.0 : 24.0);
          final double sizeValue = baseSize * scale;

          newMarkers.add(
            Marker(
              point: point,
              width: sizeValue,
              height: sizeValue,
              alignment: Alignment.center,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedStation = station);
                  },
                  child: CustomPaint(
                    size: Size(sizeValue, sizeValue),
                    painter: StationMarkerPainter(
                      lineColor: lineColor,
                      isInterchange: isInterchange,
                      brightness: theme.brightness,
                      isCurrentStation: isCurrentStation,
                      scale: scale,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Add Station Exit Markers
        for (final segment in routeResult.segments) {
          if (segment.lineId == 'WALK' && segment.exit != null) {
            // Exits are only shown at destination (where we walk from station: fromStation is Station), not at origin (where we walk to station: toStation is Station)
            if (segment.fromStation is! Station) continue;

            final exit = segment.exit!;
            final point = LatLng(exit.lat, exit.lng);

            newMarkers.add(
              Marker(
                point: point,
                width: 32,
                height: 32,
                alignment: Alignment.center,
                child: RepaintBoundary(
                  child: Tooltip(
                    message: t.routeResult.exitLabel(exit.exitCode),
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
              ),
            );
          }
        }
      } else {
        // Show all stations
        for (final station in transitRepo.stations) {
          final point = LatLng(station.lat, station.lng);

          final lineColor = TransitColors.getLineColor(station.lineId);
          final isInterchange = station.interchange.isNotEmpty;
          final double scale = (0.80 + (_currentZoom.value - 11.5) * 0.14)
              .clamp(0.80, 1.2);
          final double sizeValue = (isInterchange ? 32.0 : 24.0) * scale;

          newMarkers.add(
            Marker(
              point: point,
              width: sizeValue,
              height: sizeValue,
              alignment: Alignment.center,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedStation = station);
                  },
                  child: CustomPaint(
                    size: Size(sizeValue, sizeValue),
                    painter: StationMarkerPainter(
                      lineColor: lineColor,
                      isInterchange: isInterchange,
                      brightness: themeBrightness,
                      scale: scale,
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

    final dynamicMarkers = <Marker>[];

    if (isRouteActive) {
      // Add custom origin/destination pins
      // Origin Pin (Green)
      final originLat = routeResult.origin.routeLat;
      final originLng = routeResult.origin.routeLng;
      dynamicMarkers.add(
        Marker(
          point: LatLng(originLat, originLng),
          width: 40,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            child: Tooltip(
              message: routeResult.origin.displayName(
                isEnglish: localeCode == 'en',
              ),
              child: CustomMapPin(
                color: Colors.green.shade600,
                icon: Icons.trip_origin_rounded,
              ),
            ),
          ),
        ),
      );

      // Destination Pin (Red)
      final destLat = routeResult.destination.routeLat;
      final destLng = routeResult.destination.routeLng;
      dynamicMarkers.add(
        Marker(
          point: LatLng(destLat, destLng),
          width: 40,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            child: Tooltip(
              message: routeResult.destination.displayName(
                isEnglish: localeCode == 'en',
              ),
              child: CustomMapPin(
                color: Colors.red.shade600,
                icon: Icons.flag_rounded,
              ),
            ),
          ),
        ),
      );

      // Add walking path direction markers
      for (final segment in routeResult.segments) {
        if (segment.lineId == 'WALK' &&
            segment.walkingPath != null &&
            segment.walkingPath!.isNotEmpty) {
          final path = segment.walkingPath!;
          for (int idx = 0; idx < path.length - 1; idx++) {
            final p1 = path[idx];
            final p2 = path[idx + 1];
            final dist = Geolocator.distanceBetween(
              p1.latitude,
              p1.longitude,
              p2.latitude,
              p2.longitude,
            );
            if (dist > 10.0) {
              final midpoint = LatLng(
                (p1.latitude + p2.latitude) / 2,
                (p1.longitude + p2.longitude) / 2,
              );

              // Calculate bearing in radians
              final lat1 = p1.latitude * math.pi / 180.0;
              final lon1 = p1.longitude * math.pi / 180.0;
              final lat2 = p2.latitude * math.pi / 180.0;
              final lon2 = p2.longitude * math.pi / 180.0;
              final dLon = lon2 - lon1;
              final y = math.sin(dLon) * math.cos(lat2);
              final x =
                  math.cos(lat1) * math.sin(lat2) -
                  math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
              final bearing = math.atan2(y, x);

              dynamicMarkers.add(
                Marker(
                  point: midpoint,
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  child: RepaintBoundary(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white30
                                : Colors.black12,
                            width: 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.rotate(
                            angle: bearing,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 11,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }
      }
    }

    // Add Namtang stops overlay when zoomed in
    // Optimization for mobile: Filter only visible markers within viewport
    // Zoom threshold: only show bus stops when zoomed in (>= 15.0) to avoid DOM overload in HTML renderer
    if (_currentZoom.value >= 15.0 && !isRouteActive) {
      try {
        final bounds = _mapController.camera.visibleBounds;
        for (final stop in transitRepo.namtangStops) {
          final stopPoint = LatLng(stop.lat, stop.lng);
          if (bounds.contains(stopPoint)) {
            dynamicMarkers.add(
              Marker(
                point: stopPoint,
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: RepaintBoundary(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedNamtangStop = stop;
                        _selectedStation = null;
                        _customSelectedLocation = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: themeBrightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: stop.type == 'boat'
                              ? Colors.blue.shade700
                              : (stop.type == 'commuter_train'
                                    ? Colors.red.shade700
                                    : Colors.green.shade700),
                          width: 2.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          stop.type == 'boat'
                              ? Icons.directions_boat_rounded
                              : (stop.type == 'commuter_train'
                                    ? Icons.train_rounded
                                    : Icons.directions_bus_rounded),
                          size: 12,
                          color: stop.type == 'boat'
                              ? Colors.blue.shade700
                              : (stop.type == 'commuter_train'
                                    ? Colors.red.shade700
                                    : Colors.green.shade700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } catch (e) {
        AppLogger.error('Error rendering Namtang stops: $e', error: e);
      }
    }

    // User location marker
    if (_userPosition != null) {
      dynamicMarkers.add(
        Marker(
          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: RepaintBoundary(
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
        ),
      );
    }

    // Custom pinned location marker
    if (_customSelectedLocation != null) {
      dynamicMarkers.add(
        Marker(
          point: LatLng(
            _customSelectedLocation!.lat,
            _customSelectedLocation!.lng,
          ),
          width: 40,
          height: 44,
          alignment: Alignment.bottomCenter,
          child: RepaintBoundary(
            child: CustomMapPin(
              color: theme.colorScheme.primary,
              icon: Icons.push_pin_rounded,
            ),
          ),
        ),
      );
    }

    // Add Search Results
    final searchState = ref.watch(searchViewModelProvider);
    if (searchState.searchResults.isNotEmpty &&
        searchState.query.length >= 3 &&
        _selectedStation == null &&
        _customSelectedLocation == null) {
      for (final item in searchState.searchResults) {
        if (item is Landmark) {
          dynamicMarkers.add(
            Marker(
              point: LatLng(item.lat, item.lng),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(
                Icons.place_rounded,
                color: Colors.purple,
                size: 28,
              ),
            ),
          );
        }
      }
    }

    final isBottomCardVisible =
        _selectedStation != null ||
        _customSelectedLocation != null ||
        _selectedNamtangStop != null ||
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
                    backgroundColor: themeBrightness == Brightness.dark
                        ? const Color(0xFF111111)
                        : const Color(0xFFE4E3DF),
                    initialCenter: const LatLng(13.7563, 100.5018),
                    initialZoom: 12.0,
                    minZoom: 10.5,
                    maxZoom: 19.0,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: LatLngBounds(
                        const LatLng(13.20, 100.00),
                        const LatLng(14.25, 101.00),
                      ),
                    ),
                    onPositionChanged: (position, hasGesture) {
                      if ((position.zoom - _currentZoom.value).abs() > 0.05) {
                        setState(() {
                          _currentZoom.value = position.zoom;
                        });
                      }
                    },
                    onTap: (position, point) {
                      if (_selectedStation != null) {
                        setState(() => _selectedStation = null);
                      }
                      if (_selectedNamtangStop != null) {
                        setState(() => _selectedNamtangStop = null);
                      }

                      final nearest = _findNearestStation(
                        point,
                        transitRepo.stations,
                      );
                      if (nearest != null) {
                        final dist = Geolocator.distanceBetween(
                          point.latitude,
                          point.longitude,
                          nearest.lat,
                          nearest.lng,
                        );
                        final walkMin = (dist / 80.0).clamp(1.0, 30.0);

                        setState(() {
                          _selectedStation = null;
                          _selectedNamtangStop = null;
                          _customSelectedLocation = CustomLocation(
                            id: 'CUSTOM_${point.latitude.toStringAsFixed(6)}_${point.longitude.toStringAsFixed(6)}',
                            nameTh:
                                '${t.search.customLocation} (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
                            nameEn:
                                '${t.search.customLocation} (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
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
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      userAgentPackageName:
                          'com.bkktransit.bkk_transit_planner',
                      tileProvider: _tileProvider,
                      retinaMode: true,
                      maxNativeZoom: 18,
                      keepBuffer: 4,
                      panBuffer: 2,
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 300),
                      ),
                    ),
                    PolylineLayer(polylines: polylines),
                    MarkerLayer(markers: _cachedBaseMarkers),
                    MarkerLayer(markers: dynamicMarkers),
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
                      return _buildTopSearchCard(
                        context,
                        searchState,
                        t,
                        localeCode,
                      );
                    },
                  ),
                  if (prefetchState.isPrefetching) ...[
                    const SizedBox(height: 8),
                    MapPrefetchWidget(
                      prefetchState: prefetchState,
                      theme: theme,
                      t: t,
                      isExpanded: _isPrefetchExpanded,
                      onToggleExpand: () => setState(
                        () => _isPrefetchExpanded = !_isPrefetchExpanded,
                      ),
                      onStartPrefetch: _startMapPrefetch,
                    ),
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
          Positioned(
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _selectedStation != null ? 1.0 : 0.0,
              child: _selectedStation != null
                  ? StationDetailsCard(
                      station: _selectedStation!,
                      localeCode: localeCode,
                      onClose: () => setState(() => _selectedStation = null),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // ─── Custom Selected Location Details Popup Card ───
          if (_customSelectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: CustomLocationCard(
                location: _customSelectedLocation!,
                theme: theme,
                t: t,
                localeCode: localeCode,
                onClose: () => setState(() => _customSelectedLocation = null),
                onOpenSearchOverlay: (focus) =>
                    _openSearchOverlay(context, focusDestination: focus),
              ),
            ),

          // ─── Namtang Stop Details Popup Card ───
          if (_selectedNamtangStop != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: NamtangStopCard(
                stop: _selectedNamtangStop!,
                theme: theme,
                t: t,
                localeCode: localeCode,
                onClose: () => setState(() => _selectedNamtangStop = null),
                onOpenSearchOverlay: (focus) =>
                    _openSearchOverlay(context, focusDestination: focus),
              ),
            ),

          // ─── Route Result Banner ───
          if (isRouteActive &&
              !isTrackingActive &&
              _selectedStation == null &&
              _customSelectedLocation == null &&
              _selectedNamtangStop == null)
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
          if (isTrackingActive &&
              _selectedStation == null &&
              _customSelectedLocation == null &&
              _selectedNamtangStop == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: ActiveJourneyPanel(
                tracker: trackerState!,
                theme: theme,
                t: t,
                localeCode: localeCode,
              ),
            ),

          // ─── Route Calculating Overlay ───
          Consumer(
            builder: (context, ref, child) {
              final isCalculating = ref.watch(
                searchViewModelProvider.select((s) => s.isCalculating),
              );
              if (!isCalculating) return const SizedBox.shrink();
              return RouteCalculatingOverlay(theme: theme, t: t);
            },
          ),

          if (_isOfflineMapInitializing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            t.settings.offlineMapPreparing,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Station? _findNearestStation(LatLng point, List<Station> stations) {
    if (stations.isEmpty) return null;
    Station? closest;
    double minDist = double.infinity;
    for (final s in stations) {
      final dist = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        s.lat,
        s.lng,
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
      return Hero(
        tag: 'search_bar_card',
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                      t.search.searchPlaceholder,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (hasOrigin && hasDest) {
      return Hero(
        tag: 'search_bar_card',
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: t.search.clearRoute,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.trip_origin_rounded,
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  searchState.origin!.displayName(
                                    isEnglish: localeCode == 'en',
                                  ),
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
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  searchState.destination!.displayName(
                                    isEnglish: localeCode == 'en',
                                  ),
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
                  icon: Icon(
                    Icons.swap_vert_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  tooltip: t.search.swapTooltip,
                  onPressed: () {
                    ref.read(searchViewModelProvider.notifier).swapStations();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Only one is set
    final setItem = hasOrigin ? searchState.origin : searchState.destination;
    final isOrigin = hasOrigin;

    return Hero(
      tag: 'search_bar_card',
      child: Card(
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
                  isOrigin
                      ? Icons.trip_origin_rounded
                      : Icons.location_on_rounded,
                  color: isOrigin ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${isOrigin ? t.search.fromPrefix : t.search.toPrefix} '
                    '${setItem!.displayName(isEnglish: localeCode == 'en')}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOrigin ? t.search.chooseDest : t.search.chooseOrigin,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchOverlay(
    BuildContext context, {
    bool focusDestination = false,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MapSearchOverlay(focusDestination: focusDestination),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      ),
    );
  }
}
