import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/station.dart';
import '../../models/route_result.dart';
import '../../models/searchable_item.dart';
import '../../models/custom_location.dart';
import '../../models/station_exit.dart';
import '../../models/landmark.dart';
import '../../providers/providers.dart';
import '../../services/dijkstra_planner.dart';
import '../../services/fare_service.dart';
import '../../services/walking_route_service.dart';
import '../../core/constants/transit_constants.dart';

part 'search_view_model.g.dart';

/// State for search feature
class SearchState {
  final String query;
  final List<SearchableItem> searchResults;
  final SearchableItem? origin;
  final SearchableItem? destination;
  final RouteResult? routeResult;
  final RouteResult? regularRoute;
  final RouteResult? saverRoute;
  final String activeRouteType; // 'recommended' or 'saver'
  final bool isCalculating;
  final String? error;

  const SearchState({
    this.query = '',
    this.searchResults = const [],
    this.origin,
    this.destination,
    this.routeResult,
    this.regularRoute,
    this.saverRoute,
    this.activeRouteType = 'recommended',
    this.isCalculating = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchableItem>? searchResults,
    SearchableItem? origin,
    SearchableItem? destination,
    RouteResult? routeResult,
    RouteResult? regularRoute,
    RouteResult? saverRoute,
    String? activeRouteType,
    bool? isCalculating,
    String? error,
    bool clearOrigin = false,
    bool clearDestination = false,
    bool clearRoute = false,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      origin: clearOrigin ? null : (origin ?? this.origin),
      destination: clearDestination ? null : (destination ?? this.destination),
      routeResult: clearRoute ? null : (routeResult ?? this.routeResult),
      regularRoute: clearRoute ? null : (regularRoute ?? this.regularRoute),
      saverRoute: clearRoute ? null : (saverRoute ?? this.saverRoute),
      activeRouteType: activeRouteType ?? this.activeRouteType,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// ViewModel for search feature
@riverpod
class SearchViewModel extends _$SearchViewModel {
  bool _mounted = true;

  @override
  SearchState build() {
    _mounted = true;
    ref.onDispose(() {
      _mounted = false;
    });
    ref.listen(userCardsProvider, (previous, next) {
      if (state.origin != null && state.destination != null) {
        _tryCalculateRoute();
      }
    });
    return const SearchState();
  }

  /// Search stations and landmarks by query, querying online places if needed
  Future<void> search(String query) async {
    state = state.copyWith(query: query, clearError: true);

    final repo = ref.read(transitRepositoryProvider);

    // 1. Search local places (stations + landmarks) instantly
    final localResults = repo.searchLocalPlaces(query);
    state = state.copyWith(searchResults: localResults);

    if (query.trim().length >= 3) {
      // 2. Fetch online places in background
      try {
        final onlineResults = await repo.searchOnlinePlaces(query);

        // Merge without duplicates
        if (state.query == query) {
          final merged = [...localResults];
          for (final online in onlineResults) {
            if (!merged.any(
              (item) =>
                  item.nameTh.toLowerCase() == online.nameTh.toLowerCase() ||
                  (item.lat == online.lat && item.lng == online.lng),
            )) {
              merged.add(online);
            }
          }
          state = state.copyWith(searchResults: merged);
        }
      } catch (e) {
        print('Online place search failed: $e');
      }
    }
  }

  /// Resolve a CustomLocation to find true entrance and path
  Future<SearchableItem> _resolveItem(SearchableItem item) async {
    if (item is! CustomLocation) return item;

    state = state.copyWith(isCalculating: true, clearError: true);
    final repo = ref.read(transitRepositoryProvider);

    // First, try matching with local landmarks (like MBK Center) by name to use curated entrances
    final queryLower = item.nameTh.toLowerCase();
    for (final l in repo.landmarks) {
      if (l.nameTh.toLowerCase() == queryLower ||
          l.nameEn.toLowerCase() == item.nameEn.toLowerCase() ||
          l.nameTh.toLowerCase().contains(queryLower)) {
        return l; // Return the perfectly curated local landmark instead
      }
    }

    // Second, snap to a local landmark if the coordinates are extremely close (e.g., within 250 meters)
    // This catches aliases like "MBK", "มาบุญครอง", or user tapping on the map near the mall.
    for (final l in repo.landmarks) {
      final dist = Geolocator.distanceBetween(item.lat, item.lng, l.lat, l.lng);
      if (dist <= 250.0) {
        return l; // Snap to perfectly curated local landmark
      }
    }

    // Deep resolve via Overpass + OSRM
    final resolved = await repo.resolveOnlinePlaceAsync(item);
    return resolved ?? item;
  }

  /// Set origin station or place
  Future<void> setOrigin(SearchableItem station) async {
    final resolved = await _resolveItem(station);
    if (!_mounted) return;
    state = state.copyWith(
      origin: resolved,
      clearRoute: true,
      clearError: true,
      isCalculating: false,
    );
    _tryCalculateRoute();
  }

  /// Set destination station or place
  Future<void> setDestination(SearchableItem station) async {
    final resolved = await _resolveItem(station);
    if (!_mounted) return;
    state = state.copyWith(
      destination: resolved,
      clearRoute: true,
      clearError: true,
      isCalculating: false,
    );
    _tryCalculateRoute();
  }

  /// Set both origin and destination at the same time (e.g. from saved routes)
  Future<void> setRoute(
    SearchableItem origin,
    SearchableItem destination,
  ) async {
    state = state.copyWith(isCalculating: true, clearError: true);
    final results = await Future.wait([
      _resolveItem(origin),
      _resolveItem(destination),
    ]);
    if (!_mounted) return;
    state = state.copyWith(
      origin: results[0],
      destination: results[1],
      clearRoute: true,
      clearError: true,
      isCalculating: false,
    );
    _tryCalculateRoute();
  }

  /// Swap origin and destination
  void swapStations() {
    final origin = state.origin;
    final destination = state.destination;
    state = state.copyWith(
      origin: destination,
      destination: origin,
      clearRoute: true,
    );
    _tryCalculateRoute();
  }

  /// Clear all selections
  void clear() {
    state = const SearchState();
  }

  /// Calculate route if both origin and destination are set
  void _tryCalculateRoute() {
    final origin = state.origin;
    final destination = state.destination;
    final t = ref.read(translationsProvider);

    if (origin == null || destination == null) return;
    if (origin.id == destination.id) {
      state = state.copyWith(error: t.errors.errorSamePlaces);
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final repo = ref.read(transitRepositoryProvider);
      final fareService = ref.read(fareServiceProvider);

      var resolvedOrigin = origin;
      var resolvedDestination = destination;

      // Dynamic entrance & station resolution for large destination
      if (destination is CustomLocation &&
          destination.entrances != null &&
          destination.entrances!.isNotEmpty) {
        final originStationId = origin.nearestStationId ?? origin.id;

        final candidateStations = <String, LatLng>{};
        for (final entrance in destination.entrances!) {
          final nearest = repo.findNearestStation(
            entrance.latitude,
            entrance.longitude,
          );
          if (nearest != null) {
            final existing = candidateStations[nearest.id];
            if (existing == null) {
              candidateStations[nearest.id] = entrance;
            } else {
              final dNew = Geolocator.distanceBetween(
                entrance.latitude,
                entrance.longitude,
                nearest.lat,
                nearest.lng,
              );
              final dExisting = Geolocator.distanceBetween(
                existing.latitude,
                existing.longitude,
                nearest.lat,
                nearest.lng,
              );
              if (dNew < dExisting) {
                candidateStations[nearest.id] = entrance;
              }
            }
          }
        }

        double minWalkTime = double.infinity;
        String bestStationId = destination.nearestStationId;
        LatLng? bestEntrance;

        for (final entry in candidateStations.entries) {
          final stationId = entry.key;
          final entrance = entry.value;

          if (originStationId == stationId) {
            final walkDist = Geolocator.distanceBetween(
              entrance.latitude,
              entrance.longitude,
              origin.routeLat,
              origin.routeLng,
            );
            final walkMinutes = walkDist / 80.0;
            if (walkMinutes < minWalkTime) {
              minWalkTime = walkMinutes;
              bestStationId = stationId;
              bestEntrance = entrance;
            }
          } else {
            final route = repo.findRoute(originStationId, stationId);
            if (route != null) {
              final station = repo.getStation(stationId);
              final walkDist = station != null
                  ? Geolocator.distanceBetween(
                      entrance.latitude,
                      entrance.longitude,
                      station.lat,
                      station.lng,
                    )
                  : 0.0;
              final walkMinutes = walkDist / 80.0;

              if (walkMinutes < minWalkTime) {
                minWalkTime = walkMinutes;
                bestStationId = stationId;
                bestEntrance = entrance;
              }
            }
          }
        }

        if (bestEntrance != null) {
          // Recalculate walkingMinutes from the newly chosen entrance to the station.
          // Clear stale walkingPath so _hydrateAllRoutes refetches the correct OSRM path.
          final bestStation = repo.getStation(bestStationId);
          final newWalkDist = bestStation != null
              ? Geolocator.distanceBetween(
                  bestEntrance.latitude,
                  bestEntrance.longitude,
                  bestStation.lat,
                  bestStation.lng,
                )
              : 0.0;
          final newWalkMinutes = (newWalkDist / 80.0).clamp(1.0, 30.0);
          resolvedDestination = (resolvedDestination as CustomLocation)
              .copyWith(
                routeLat: bestEntrance.latitude,
                routeLng: bestEntrance.longitude,
                nearestStationId: bestStationId,
                walkingMinutes: newWalkMinutes,
                clearWalkingPath: true,
              );
        }
      }

      // Dynamic entrance & station resolution for large origin
      if (origin is CustomLocation &&
          origin.entrances != null &&
          origin.entrances!.isNotEmpty) {
        final destStationId =
            resolvedDestination.nearestStationId ?? resolvedDestination.id;

        final candidateStations = <String, LatLng>{};
        for (final entrance in origin.entrances!) {
          final nearest = repo.findNearestStation(
            entrance.latitude,
            entrance.longitude,
          );
          if (nearest != null) {
            final existing = candidateStations[nearest.id];
            if (existing == null) {
              candidateStations[nearest.id] = entrance;
            } else {
              final dNew = Geolocator.distanceBetween(
                entrance.latitude,
                entrance.longitude,
                nearest.lat,
                nearest.lng,
              );
              final dExisting = Geolocator.distanceBetween(
                existing.latitude,
                existing.longitude,
                nearest.lat,
                nearest.lng,
              );
              if (dNew < dExisting) {
                candidateStations[nearest.id] = entrance;
              }
            }
          }
        }

        double minWalkTime = double.infinity;
        String bestStationId = origin.nearestStationId;
        LatLng? bestEntrance;

        for (final entry in candidateStations.entries) {
          final stationId = entry.key;
          final entrance = entry.value;

          if (destStationId == stationId) {
            final walkDist = Geolocator.distanceBetween(
              entrance.latitude,
              entrance.longitude,
              resolvedDestination.routeLat,
              resolvedDestination.routeLng,
            );
            final walkMinutes = walkDist / 80.0;
            if (walkMinutes < minWalkTime) {
              minWalkTime = walkMinutes;
              bestStationId = stationId;
              bestEntrance = entrance;
            }
          } else {
            final route = repo.findRoute(stationId, destStationId);
            if (route != null) {
              final station = repo.getStation(stationId);
              final walkDist = station != null
                  ? Geolocator.distanceBetween(
                      entrance.latitude,
                      entrance.longitude,
                      station.lat,
                      station.lng,
                    )
                  : 0.0;
              final walkMinutes = walkDist / 80.0;

              if (walkMinutes < minWalkTime) {
                minWalkTime = walkMinutes;
                bestStationId = stationId;
                bestEntrance = entrance;
              }
            }
          }
        }

        if (bestEntrance != null) {
          // Recalculate walkingMinutes from the newly chosen entrance to the station.
          // Clear stale walkingPath so _hydrateAllRoutes refetches the correct OSRM path.
          final bestStation = repo.getStation(bestStationId);
          final newWalkDist = bestStation != null
              ? Geolocator.distanceBetween(
                  bestEntrance.latitude,
                  bestEntrance.longitude,
                  bestStation.lat,
                  bestStation.lng,
                )
              : 0.0;
          final newWalkMinutes = (newWalkDist / 80.0).clamp(1.0, 30.0);
          resolvedOrigin = (resolvedOrigin as CustomLocation).copyWith(
            routeLat: bestEntrance.latitude,
            routeLng: bestEntrance.longitude,
            nearestStationId: bestStationId,
            walkingMinutes: newWalkMinutes,
            clearWalkingPath: true,
          );
        }
      }

      final originStationId =
          resolvedOrigin.nearestStationId ?? resolvedOrigin.id;
      final destinationStationId =
          resolvedDestination.nearestStationId ?? resolvedDestination.id;

      // In case they resolved to the same station, run exit-to-entrance optimization
      if (originStationId == destinationStationId) {
        if (resolvedDestination is CustomLocation &&
            resolvedDestination.entrances != null &&
            resolvedDestination.entrances!.isNotEmpty) {
          double minDist = double.infinity;
          LatLng? bestEntrance;
          for (final entrance in resolvedDestination.entrances!) {
            final dist = Geolocator.distanceBetween(
              entrance.latitude,
              entrance.longitude,
              resolvedOrigin.routeLat,
              resolvedOrigin.routeLng,
            );
            if (dist < minDist) {
              minDist = dist;
              bestEntrance = entrance;
            }
          }
          if (bestEntrance != null) {
            resolvedDestination = (resolvedDestination).copyWith(
              routeLat: bestEntrance.latitude,
              routeLng: bestEntrance.longitude,
            );
          }
        }
        if (resolvedOrigin is CustomLocation &&
            resolvedOrigin.entrances != null &&
            resolvedOrigin.entrances!.isNotEmpty) {
          double minDist = double.infinity;
          LatLng? bestEntrance;
          for (final entrance in resolvedOrigin.entrances!) {
            final dist = Geolocator.distanceBetween(
              entrance.latitude,
              entrance.longitude,
              resolvedDestination.routeLat,
              resolvedDestination.routeLng,
            );
            if (dist < minDist) {
              minDist = dist;
              bestEntrance = entrance;
            }
          }
          if (bestEntrance != null) {
            resolvedOrigin = (resolvedOrigin).copyWith(
              routeLat: bestEntrance.latitude,
              routeLng: bestEntrance.longitude,
            );
          }
        }
      }

      RouteResult routeResult;

      if (originStationId == destinationStationId) {
        // Direct walk scenario (e.g. between landmarks near same station, or landmark and its station)
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkMinutes =
            (resolvedOrigin.walkingMinutes ?? 0.0) +
            (resolvedDestination.walkingMinutes ?? 0.0);

        Landmark? lm;
        Station? st;
        if (resolvedOrigin is Landmark) {
          lm = resolvedOrigin;
          st = repo.getStation(destinationStationId);
        } else if (resolvedDestination is Landmark) {
          lm = resolvedDestination;
          st = repo.getStation(originStationId);
        }

        if (lm == null) {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == resolvedOrigin.id && l is Landmark) {
              lm = l;
              st = repo.getStation(destinationStationId);
              break;
            } else if (l.id == resolvedDestination.id && l is Landmark) {
              lm = l;
              st = repo.getStation(originStationId);
              break;
            }
          }
        }

        if (lm != null && st != null) {
          final landmark = lm;
          final station = st;
          if (station.id == landmark.nearestStationId &&
              landmark.walkingPath != null) {
            walkingPath = landmark.walkingPath;
            walkMinutes = landmark.walkingMinutes;
            if (landmark.exitCode != null) {
              final exits = repo.getExitsForStation(station.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == landmark.exitCode,
                orElse: () => station.findClosestExit(
                  repo.exits,
                  landmark.routeLat,
                  landmark.routeLng,
                  targetNameTh: landmark.nameTh,
                  targetNameEn: landmark.nameEn,
                ),
              );
            }
          } else if (landmark.alternativeWalks != null &&
              landmark.alternativeWalks!.containsKey(station.id)) {
            final walk = landmark.alternativeWalks![station.id]!;
            walkingPath = walk.walkingPath;
            walkMinutes = walk.walkingMinutes;
            final exits = repo.getExitsForStation(station.id);
            exit = exits.firstWhere(
              (e) => e.exitCode == walk.exitCode,
              orElse: () => station.findClosestExit(
                repo.exits,
                landmark.routeLat,
                landmark.routeLng,
                targetNameTh: landmark.nameTh,
                targetNameEn: landmark.nameEn,
              ),
            );
          }
        }

        exit ??= st?.findClosestExit(
          repo.exits,
          resolvedDestination.routeLat,
          resolvedDestination.routeLng,
          targetNameTh: resolvedDestination.nameTh,
          targetNameEn: resolvedDestination.nameEn,
        );
        walkingPath ??= [
          LatLng(resolvedOrigin.routeLat, resolvedOrigin.routeLng),
          LatLng(resolvedDestination.routeLat, resolvedDestination.routeLng),
        ];

        String direction = t.routeResult.walkToDestination;
        String? instructionsTh;
        String? instructionsEn;
        if (lm != null &&
            st != null &&
            lm.alternativeWalks != null &&
            lm.alternativeWalks!.containsKey(st.id)) {
          final sw = lm.alternativeWalks![st.id]!;
          instructionsTh = sw.instructionsTh;
          instructionsEn = sw.instructionsEn;
          if (instructionsTh != null) {
            direction = instructionsTh;
          }
        }

        final walkSegment = RouteSegment(
          lineId: 'WALK',
          lineName: 'Walk',
          direction: direction,
          boundIndex: 0,
          fromStation: resolvedOrigin,
          toStation: resolvedDestination,
          stationCount: 0,
          estimatedMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
          fareThb: 0,
          standardFareThb: 0,
          walkingPath: walkingPath,
          exit: exit,
          instructionsTh: instructionsTh,
          instructionsEn: instructionsEn,
        );

        routeResult = RouteResult(
          origin: resolvedOrigin,
          destination: resolvedDestination,
          segments: [walkSegment],
          transfers: [],
          totalMinutes: walkMinutes > 0 ? walkMinutes : 5.0,
          totalFareThb: 0,
          totalStandardFareThb: 0,
          totalStations: 0,
          calculatedAt: DateTime.now(),
        );
      } else {
        // Run Dijkstra on transit stations
        final result = repo.findRoute(originStationId, destinationStationId);

        if (result == null) {
          state = state.copyWith(
            isCalculating: false,
            error: t.errors.errorNoRoute,
          );
          return;
        }

        // Build RouteResult from DijkstraResult
        routeResult = _buildRouteResult(
          result,
          resolvedOrigin,
          resolvedDestination,
          repo,
          fareService,
        );
      }

      // Calculate saver route if available
      final saverRoute = _findSaverRoute(
        resolvedOrigin,
        resolvedDestination,
        routeResult,
        repo,
        fareService,
      );

      state = state.copyWith(
        routeResult: routeResult,
        regularRoute: routeResult,
        saverRoute: saverRoute,
        activeRouteType: 'recommended',
        isCalculating: false,
      );

      // Hydrate walking paths asynchronously in the background
      _hydrateAllRoutes(routeResult, saverRoute);
    } catch (e) {
      state = state.copyWith(
        isCalculating: false,
        error: t.errors.errorFailed(e.toString()),
      );
    }
  }

  /// Select active route type ('recommended' or 'saver')
  void selectRouteType(String type) {
    if (type == 'recommended') {
      state = state.copyWith(
        activeRouteType: 'recommended',
        routeResult: state.regularRoute,
      );
    } else if (type == 'saver') {
      state = state.copyWith(
        activeRouteType: 'saver',
        routeResult: state.saverRoute,
      );
    }
  }

  /// Calculate a cheaper/fewer transfers alternative route (Saver option)
  RouteResult? _findSaverRoute(
    SearchableItem origin,
    SearchableItem destination,
    RouteResult regularRoute,
    dynamic repo,
    FareService fareService,
  ) {
    // Only search for saver options if there is an active transit segment
    if (regularRoute.segments.isEmpty ||
        regularRoute.segments.every((s) => s.lineId == 'WALK')) {
      return null;
    }

    final originStationId = origin.nearestStationId ?? origin.id;
    final destinationStationId = destination.nearestStationId ?? destination.id;

    final destLat = destination.routeLat;
    final destLng = destination.routeLng;
    final originLat = origin.routeLat;
    final originLng = origin.routeLng;

    final candidateDestStations =
        <({Station station, LatLng entrance, double walkMinutes})>[];
    for (final station in repo.stations) {
      if (station.id == destinationStationId) continue;

      LatLng targetEntrance = LatLng(destLat, destLng);
      double minDist = Geolocator.distanceBetween(
        destLat,
        destLng,
        station.lat,
        station.lng,
      );

      if (destination is CustomLocation &&
          destination.entrances != null &&
          destination.entrances!.isNotEmpty) {
        double dMin = double.infinity;
        for (final ent in destination.entrances!) {
          final d = Geolocator.distanceBetween(
            ent.latitude,
            ent.longitude,
            station.lat,
            station.lng,
          );
          if (d < dMin) {
            dMin = d;
            targetEntrance = ent;
          }
        }
        minDist = dMin;
      }

      if (minDist <= 700.0) {
        candidateDestStations.add((
          station: station,
          entrance: targetEntrance,
          walkMinutes: (minDist / 80.0).clamp(1.0, 30.0),
        ));
      }
    }

    final candidateOriginStations =
        <({Station station, LatLng entrance, double walkMinutes})>[];
    for (final station in repo.stations) {
      if (station.id == originStationId) continue;

      LatLng targetEntrance = LatLng(originLat, originLng);
      double minDist = Geolocator.distanceBetween(
        originLat,
        originLng,
        station.lat,
        station.lng,
      );

      if (origin is CustomLocation &&
          origin.entrances != null &&
          origin.entrances!.isNotEmpty) {
        double dMin = double.infinity;
        for (final ent in origin.entrances!) {
          final d = Geolocator.distanceBetween(
            ent.latitude,
            ent.longitude,
            station.lat,
            station.lng,
          );
          if (d < dMin) {
            dMin = d;
            targetEntrance = ent;
          }
        }
        minDist = dMin;
      }

      if (minDist <= 700.0) {
        candidateOriginStations.add((
          station: station,
          entrance: targetEntrance,
          walkMinutes: (minDist / 80.0).clamp(1.0, 30.0),
        ));
      }
    }

    RouteResult? bestSaverRoute;

    void evaluateCandidate({
      required String startId,
      required String endId,
      required double startWalkMin,
      required double endWalkMin,
      required double altOriginRouteLat,
      required double altOriginRouteLng,
      required double altDestRouteLat,
      required double altDestRouteLng,
    }) {
      final dijkstraResult = repo.findRoute(startId, endId);
      if (dijkstraResult == null) return;

      // BUG 5 fix: propagate routeLat/routeLng and path data from the resolved items.
      final tempOrigin = CustomLocation(
        id: origin.id,
        nameTh: origin.nameTh,
        nameEn: origin.nameEn,
        nearestStationId: startId,
        walkingMinutes: startWalkMin,
        lat: originLat,
        lng: originLng,
        routeLat: altOriginRouteLat,
        routeLng: altOriginRouteLng,
        entrances: origin is CustomLocation ? (origin).entrances : null,
        walkingPath: origin is CustomLocation ? (origin).walkingPath : null,
      );

      final tempDest = CustomLocation(
        id: destination.id,
        nameTh: destination.nameTh,
        nameEn: destination.nameEn,
        nearestStationId: endId,
        walkingMinutes: endWalkMin,
        lat: destLat,
        lng: destLng,
        routeLat: altDestRouteLat,
        routeLng: altDestRouteLng,
        entrances: destination is CustomLocation
            ? (destination).entrances
            : null,
        walkingPath: destination is CustomLocation
            ? (destination).walkingPath
            : null,
      );

      final altRoute = _buildRouteResult(
        dijkstraResult,
        tempOrigin,
        tempDest,
        repo,
        fareService,
      );

      // Criteria for Saver Route:
      // 1. Lower fare than recommended route
      // 2. Must not be excessively slow (<= 15 minutes slower than regular)
      final isCheaper = altRoute.totalFareThb < regularRoute.totalFareThb;
      final isNotTooSlow =
          altRoute.totalMinutes <= regularRoute.totalMinutes + 15.0;

      if (isCheaper && isNotTooSlow) {
        final currentBest = bestSaverRoute;
        if (currentBest == null ||
            altRoute.totalFareThb < currentBest.totalFareThb ||
            (altRoute.totalFareThb == currentBest.totalFareThb &&
                altRoute.transferCount < currentBest.transferCount)) {
          bestSaverRoute = altRoute;
        }
      }
    }

    // 1. Alternative destination stations
    for (final altDest in candidateDestStations) {
      evaluateCandidate(
        startId: originStationId,
        endId: altDest.station.id,
        startWalkMin: origin.walkingMinutes ?? 0.0,
        endWalkMin: altDest.walkMinutes,
        altOriginRouteLat: origin.routeLat,
        altOriginRouteLng: origin.routeLng,
        altDestRouteLat: altDest.entrance.latitude,
        altDestRouteLng: altDest.entrance.longitude,
      );
    }

    // 2. Alternative origin stations
    for (final altOrigin in candidateOriginStations) {
      evaluateCandidate(
        startId: altOrigin.station.id,
        endId: destinationStationId,
        startWalkMin: altOrigin.walkMinutes,
        endWalkMin: destination.walkingMinutes ?? 0.0,
        altOriginRouteLat: altOrigin.entrance.latitude,
        altOriginRouteLng: altOrigin.entrance.longitude,
        altDestRouteLat: destination.routeLat,
        altDestRouteLng: destination.routeLng,
      );
    }

    // 3. Alternative both origin and destination stations
    for (final altOrigin in candidateOriginStations) {
      for (final altDest in candidateDestStations) {
        evaluateCandidate(
          startId: altOrigin.station.id,
          endId: altDest.station.id,
          startWalkMin: altOrigin.walkMinutes,
          endWalkMin: altDest.walkMinutes,
          altOriginRouteLat: altOrigin.entrance.latitude,
          altOriginRouteLng: altOrigin.entrance.longitude,
          altDestRouteLat: altDest.entrance.latitude,
          altDestRouteLng: altDest.entrance.longitude,
        );
      }
    }

    return bestSaverRoute;
  }

  RouteResult _buildRouteResult(
    DijkstraResult dijkstraResult,
    SearchableItem origin,
    SearchableItem destination,
    dynamic repo,
    FareService fareService,
  ) {
    final segments = <RouteSegment>[];
    final transfers = <TransferStep>[];
    final cardState = ref.read(userCardsProvider);
    final t = ref.read(translationsProvider);

    // ─── 1. If Origin requires walking, add initial Walk Segment ───
    if (origin.nearestStationId != null &&
        origin.id != origin.nearestStationId) {
      final nearestStation =
          repo.getStation(origin.nearestStationId!) as Station?;
      if (nearestStation != null) {
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkingMinutes = origin.walkingMinutes ?? 5.0;

        Landmark? originLandmark;
        if (origin is Landmark) {
          originLandmark = origin;
        } else {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == origin.id && l is Landmark) {
              originLandmark = l;
              break;
            }
          }
        }

        if (originLandmark != null) {
          if (nearestStation.id == originLandmark.nearestStationId &&
              originLandmark.walkingPath != null) {
            walkingPath = originLandmark.walkingPath;
            if (originLandmark.exitCode != null) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == originLandmark!.exitCode,
                orElse: () => nearestStation.findClosestExit(
                  repo.exits,
                  originLandmark!.routeLat,
                  originLandmark.routeLng,
                  targetNameTh: originLandmark.nameTh,
                  targetNameEn: originLandmark.nameEn,
                ),
              );
            }
          } else if (originLandmark.alternativeWalks != null &&
              originLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
            final walk = originLandmark.alternativeWalks![nearestStation.id]!;
            walkingPath = walk.walkingPath;
            walkingMinutes = walk.walkingMinutes;
            if (walk.exitCode.isNotEmpty) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == walk.exitCode,
                orElse: () => nearestStation.findClosestExit(
                  repo.exits,
                  originLandmark!.routeLat,
                  originLandmark.routeLng,
                  targetNameTh: originLandmark.nameTh,
                  targetNameEn: originLandmark.nameEn,
                ),
              );
            }
          }
        }

        if (origin is CustomLocation && origin.walkingPath != null) {
          walkingPath = origin.walkingPath;
        }

        exit ??= nearestStation.findClosestExit(
          repo.exits,
          origin.routeLat,
          origin.routeLng,
          targetNameTh: origin.nameTh,
          targetNameEn: origin.nameEn,
        );
        walkingPath ??= [
          LatLng(origin.routeLat, origin.routeLng),
          LatLng(exit.lat, exit.lng),
        ];

        String direction = t.routeResult.walkToStation;
        String? instructionsTh;
        String? instructionsEn;
        if (originLandmark != null &&
            originLandmark.alternativeWalks != null &&
            originLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
          final walk = originLandmark.alternativeWalks![nearestStation.id]!;
          instructionsTh = walk.instructionsTh;
          instructionsEn = walk.instructionsEn;
          if (instructionsTh != null) {
            direction = instructionsTh;
          }
        }

        segments.add(
          RouteSegment(
            lineId: 'WALK',
            lineName: 'Walk',
            direction: direction,
            boundIndex: 0,
            fromStation: origin,
            toStation: nearestStation,
            stationCount: 0,
            estimatedMinutes: walkingMinutes,
            fareThb: 0,
            standardFareThb: 0,
            walkingPath: walkingPath,
            exit: exit,
            instructionsTh: instructionsTh,
            instructionsEn: instructionsEn,
          ),
        );
      }
    }

    // Group path steps by line
    String currentLineId = '';
    Station? segmentStart;
    final segmentStations = <Station>[];

    for (int i = 0; i < dijkstraResult.path.length; i++) {
      final step = dijkstraResult.path[i];
      final station = repo.getStation(step.stationId) as Station?;
      if (station == null) continue;

      if (step.lineId == 'TRANSFER') {
        // End current segment
        if (segmentStart != null && segmentStations.length > 1) {
          final line = repo.getLine(currentLineId);
          final stationCount = segmentStations.length - 1;
          final bound =
              line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

          final standardFare = fareService.calculateFare(
            currentLineId,
            stationCount,
          );
          final discountedFare = fareService.calculateFare(
            currentLineId,
            stationCount,
            btsCardType: cardState.btsCardType,
            mrtCardType: cardState.mrtCardType,
            arlCardType: cardState.arlCardType,
          );

          segments.add(
            RouteSegment(
              lineId: currentLineId,
              lineName: line?.nameEn ?? currentLineId,
              direction: line?.getDirectionLabel(bound) ?? '',
              boundIndex: bound,
              fromStation: segmentStart,
              toStation: segmentStations.last,
              intermediateStations: segmentStations.length > 2
                  ? segmentStations.sublist(1, segmentStations.length - 1)
                  : [],
              stationCount: stationCount,
              estimatedMinutes:
                  stationCount * TransitConstants.avgTimeBetweenStations,
              fareThb: discountedFare,
              standardFareThb: standardFare,
            ),
          );
        }

        // Record transfer
        if (segmentStations.isNotEmpty) {
          final nextLineId = i + 1 < dijkstraResult.path.length
              ? dijkstraResult.path[i + 1].lineId
              : '';
          transfers.add(
            TransferStep(
              fromStation: segmentStations.last,
              toStation: station,
              fromLineId: currentLineId,
              toLineId: nextLineId,
            ),
          );
        }

        segmentStart = station;
        segmentStations.clear();
        segmentStations.add(station);
        currentLineId = i + 1 < dijkstraResult.path.length
            ? dijkstraResult.path[i + 1].lineId
            : '';
        continue;
      }

      if (step.lineId.isNotEmpty && step.lineId != currentLineId) {
        if (currentLineId.isEmpty) {
          currentLineId = step.lineId;
        } else {
          // Start of a new segment on a different line
          if (segmentStart != null && segmentStations.length > 1) {
            final line = repo.getLine(currentLineId);
            final stationCount = segmentStations.length - 1;
            final bound =
                line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

            final standardFare = fareService.calculateFare(
              currentLineId,
              stationCount,
            );
            final discountedFare = fareService.calculateFare(
              currentLineId,
              stationCount,
              btsCardType: cardState.btsCardType,
              mrtCardType: cardState.mrtCardType,
              arlCardType: cardState.arlCardType,
            );

            segments.add(
              RouteSegment(
                lineId: currentLineId,
                lineName: line?.nameEn ?? currentLineId,
                direction: line?.getDirectionLabel(bound) ?? '',
                boundIndex: bound,
                fromStation: segmentStart,
                toStation: segmentStations.last,
                intermediateStations: segmentStations.length > 2
                    ? segmentStations.sublist(1, segmentStations.length - 1)
                    : [],
                stationCount: stationCount,
                estimatedMinutes:
                    stationCount * TransitConstants.avgTimeBetweenStations,
                fareThb: discountedFare,
                standardFareThb: standardFare,
              ),
            );
          }
          currentLineId = step.lineId;
          segmentStart = station;
          segmentStations.clear();
        }
      }

      if (segmentStart == null) {
        segmentStart = station;
        currentLineId = step.lineId.isNotEmpty ? step.lineId : currentLineId;
      }
      segmentStations.add(station);
    }

    // Add last segment
    if (segmentStart != null && segmentStations.length > 1) {
      final line = repo.getLine(currentLineId);
      final stationCount = segmentStations.length - 1;
      final bound =
          line?.getBound(segmentStart.id, segmentStations.last.id) ?? 0;

      final standardFare = fareService.calculateFare(
        currentLineId,
        stationCount,
      );
      final discountedFare = fareService.calculateFare(
        currentLineId,
        stationCount,
        btsCardType: cardState.btsCardType,
        mrtCardType: cardState.mrtCardType,
        arlCardType: cardState.arlCardType,
      );

      segments.add(
        RouteSegment(
          lineId: currentLineId,
          lineName: line?.nameEn ?? currentLineId,
          direction: line?.getDirectionLabel(bound) ?? '',
          boundIndex: bound,
          fromStation: segmentStart,
          toStation: segmentStations.last,
          intermediateStations: segmentStations.length > 2
              ? segmentStations.sublist(1, segmentStations.length - 1)
              : [],
          stationCount: stationCount,
          estimatedMinutes:
              stationCount * TransitConstants.avgTimeBetweenStations,
          fareThb: discountedFare,
          standardFareThb: standardFare,
        ),
      );
    }

    // ─── 2. If Destination requires walking, add final Walk Segment ───
    if (destination.nearestStationId != null &&
        destination.id != destination.nearestStationId) {
      final nearestStation =
          repo.getStation(destination.nearestStationId!) as Station?;
      if (nearestStation != null) {
        StationExit? exit;
        List<LatLng>? walkingPath;
        double walkingMinutes = destination.walkingMinutes ?? 5.0;

        Landmark? destLandmark;
        if (destination is Landmark) {
          destLandmark = destination;
        } else {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == destination.id && l is Landmark) {
              destLandmark = l;
              break;
            }
          }
        }

        if (destLandmark != null) {
          if (nearestStation.id == destLandmark.nearestStationId &&
              destLandmark.walkingPath != null) {
            walkingPath = destLandmark.walkingPath;
            if (destLandmark.exitCode != null) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == destLandmark!.exitCode,
                orElse: () => nearestStation.findClosestExit(
                  repo.exits,
                  destLandmark!.routeLat,
                  destLandmark.routeLng,
                  targetNameTh: destLandmark.nameTh,
                  targetNameEn: destLandmark.nameEn,
                ),
              );
            }
          } else if (destLandmark.alternativeWalks != null &&
              destLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
            final walk = destLandmark.alternativeWalks![nearestStation.id]!;
            walkingPath = walk.walkingPath;
            walkingMinutes = walk.walkingMinutes;
            if (walk.exitCode.isNotEmpty) {
              final exits = repo.getExitsForStation(nearestStation.id);
              exit = exits.firstWhere(
                (e) => e.exitCode == walk.exitCode,
                orElse: () => nearestStation.findClosestExit(
                  repo.exits,
                  destLandmark!.routeLat,
                  destLandmark.routeLng,
                  targetNameTh: destLandmark.nameTh,
                  targetNameEn: destLandmark.nameEn,
                ),
              );
            }
          }
        }

        if (destination is CustomLocation && destination.walkingPath != null) {
          walkingPath = destination.walkingPath;
        }

        exit ??= nearestStation.findClosestExit(
          repo.exits,
          destination.routeLat,
          destination.routeLng,
          targetNameTh: destination.nameTh,
          targetNameEn: destination.nameEn,
        );
        walkingPath ??= [
          LatLng(exit.lat, exit.lng),
          LatLng(destination.routeLat, destination.routeLng),
        ];

        String direction = t.routeResult.walkToDestination;
        String? instructionsTh;
        String? instructionsEn;
        if (destLandmark != null &&
            destLandmark.alternativeWalks != null &&
            destLandmark.alternativeWalks!.containsKey(nearestStation.id)) {
          final walk = destLandmark.alternativeWalks![nearestStation.id]!;
          instructionsTh = walk.instructionsTh;
          instructionsEn = walk.instructionsEn;
          if (instructionsTh != null) {
            direction = instructionsTh;
          }
        }

        segments.add(
          RouteSegment(
            lineId: 'WALK',
            lineName: 'Walk',
            direction: direction,
            boundIndex: 0,
            fromStation: nearestStation,
            toStation: destination,
            stationCount: 0,
            estimatedMinutes: walkingMinutes,
            fareThb: 0,
            standardFareThb: 0,
            walkingPath: walkingPath,
            exit: exit,
            instructionsTh: instructionsTh,
            instructionsEn: instructionsEn,
          ),
        );
      }
    }

    final totalFare = segments.fold<int>(0, (sum, s) => sum + s.fareThb);
    final totalStandardFare = segments.fold<int>(
      0,
      (sum, s) => sum + s.standardFareThb,
    );

    double totalMinutes = dijkstraResult.totalWeight;
    if (origin.walkingMinutes != null) {
      totalMinutes += origin.walkingMinutes!;
    }
    if (destination.walkingMinutes != null) {
      totalMinutes += destination.walkingMinutes!;
    }

    final totalStations = dijkstraResult.path.length - 1;

    return RouteResult(
      origin: origin,
      destination: destination,
      segments: segments,
      transfers: transfers,
      totalMinutes: totalMinutes,
      totalFareThb: totalFare,
      totalStandardFareThb: totalStandardFare,
      totalStations: totalStations,
      calculatedAt: DateTime.now(),
    );
  }

  /// Hydrates all routes asynchronously in the background
  Future<void> _hydrateAllRoutes(
    RouteResult recommended,
    RouteResult? saver,
  ) async {
    final hydratedRecommended = await _hydrateRouteWalkingPaths(recommended);
    RouteResult? hydratedSaver;
    if (saver != null) {
      hydratedSaver = await _hydrateRouteWalkingPaths(saver);
    }

    if (_mounted) {
      state = state.copyWith(
        routeResult: state.activeRouteType == 'recommended'
            ? hydratedRecommended
            : (hydratedSaver ?? state.routeResult),
        regularRoute: hydratedRecommended,
        saverRoute: hydratedSaver,
      );
    }
  }

  /// Asynchronously hydrates a RouteResult's walking segments with realistic OSRM paths
  Future<RouteResult> _hydrateRouteWalkingPaths(RouteResult route) async {
    final repo = ref.read(transitRepositoryProvider);
    final hydratedSegments = <RouteSegment>[];
    bool modified = false;

    for (final segment in route.segments) {
      if (segment.lineId == 'WALK') {
        final from = segment.fromStation;
        final to = segment.toStation;

        // Skip if it's already a precalculated landmark path
        bool isPrecalculated = false;
        Landmark? lm;
        Station? st;
        if (from is Landmark) {
          lm = from;
          if (to is Station) st = to;
        } else if (to is Landmark) {
          lm = to;
          if (from is Station) st = from;
        }

        if (lm == null) {
          final List<dynamic> allLandmarks = repo.landmarks;
          for (final l in allLandmarks) {
            if (l.id == from.id && l is Landmark) {
              lm = l;
              if (to is Station) st = to;
              break;
            } else if (l.id == to.id && l is Landmark) {
              lm = l;
              if (from is Station) st = from;
              break;
            }
          }
        }

        if (lm != null && st != null) {
          if (st.id == lm.nearestStationId && lm.walkingPath != null) {
            isPrecalculated = true;
          } else if (lm.alternativeWalks != null &&
              lm.alternativeWalks!.containsKey(st.id)) {
            isPrecalculated = true;
          }
        }

        if (isPrecalculated) {
          hydratedSegments.add(segment);
          continue;
        }

        double fLat, fLng, tLat, tLng;
        final fromRouteLat = from.routeLat;
        final fromRouteLng = from.routeLng;
        final toRouteLat = to.routeLat;
        final toRouteLng = to.routeLng;

        if (segment.exit != null) {
          if (from is Station) {
            // Walk from station exit to destination
            fLat = segment.exit!.lat;
            fLng = segment.exit!.lng;
            tLat = toRouteLat;
            tLng = toRouteLng;
          } else {
            // Walk from origin to station exit
            fLat = fromRouteLat;
            fLng = fromRouteLng;
            tLat = segment.exit!.lat;
            tLng = segment.exit!.lng;
          }
        } else {
          // Direct walk
          fLat = fromRouteLat;
          fLng = fromRouteLng;
          tLat = toRouteLat;
          tLng = toRouteLng;
        }

        List<LatLng> path = await WalkingRouteService.getWalkingPath(
          fLat,
          fLng,
          tLat,
          tLng,
        );

        final straightDist = Geolocator.distanceBetween(fLat, fLng, tLat, tLng);
        if (straightDist < 150.0) {
          path = [LatLng(fLat, fLng), LatLng(tLat, tLng)];
        } else if (straightDist < 600.0 && path.isNotEmpty) {
          double pathDist = 0.0;
          for (int idx = 0; idx < path.length - 1; idx++) {
            pathDist += Geolocator.distanceBetween(
              path[idx].latitude,
              path[idx].longitude,
              path[idx + 1].latitude,
              path[idx + 1].longitude,
            );
          }
          if (pathDist > 2.0 * straightDist) {
            print(
              "OSRM massive detour detected (OSRM: ${pathDist.toStringAsFixed(1)}m, Straight: ${straightDist.toStringAsFixed(1)}m). Falling back to direct straight-line path.",
            );
            path = [LatLng(fLat, fLng), LatLng(tLat, tLng)];
          } else if (pathDist > 1.4 * straightDist) {
            print(
              "OSRM detour detected (OSRM: ${pathDist.toStringAsFixed(1)}m, Straight: ${straightDist.toStringAsFixed(1)}m). Falling back to smart L-shape path.",
            );
            path = WalkingRouteService.generateManhattanPath(
              fLat,
              fLng,
              tLat,
              tLng,
            );
          }
        }

        hydratedSegments.add(
          RouteSegment(
            lineId: segment.lineId,
            lineName: segment.lineName,
            direction: segment.direction,
            boundIndex: segment.boundIndex,
            fromStation: segment.fromStation,
            toStation: segment.toStation,
            intermediateStations: segment.intermediateStations,
            stationCount: segment.stationCount,
            estimatedMinutes: segment.estimatedMinutes,
            fareThb: segment.fareThb,
            standardFareThb: segment.standardFareThb,
            walkingPath: path,
            exit: segment.exit,
            instructionsTh: segment.instructionsTh,
            instructionsEn: segment.instructionsEn,
          ),
        );
        modified = true;
      } else {
        hydratedSegments.add(segment);
      }
    }

    if (modified) {
      return RouteResult(
        origin: route.origin,
        destination: route.destination,
        segments: hydratedSegments,
        transfers: route.transfers,
        totalMinutes: route.totalMinutes,
        totalFareThb: route.totalFareThb,
        totalStandardFareThb: route.totalStandardFareThb,
        totalStations: route.totalStations,
        calculatedAt: route.calculatedAt,
      );
    }
    return route;
  }
}
