import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/station.dart';
import '../models/line.dart';
import '../models/landmark.dart';
import '../models/station_exit.dart';
import '../services/dijkstra_planner.dart';
import '../services/osrm_service.dart';
import '../services/overpass_service.dart';
import 'package:latlong2/latlong.dart';
import '../models/custom_location.dart';
import '../models/searchable_item.dart';
import '../models/namtang_stop.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Repository for loading and accessing static transit data
class TransitRepository {
  final OsrmService _osrmService = OsrmService();
  final OverpassService _overpassService = OverpassService();

  List<Station>? _stations;
  List<TransitLine>? _lines;
  List<Landmark>? _landmarks;
  List<NamtangStop>? _namtangStops;
  List<StationExit> _exits = [];
  TransitGraph? _graph;
  bool _initialized = false;

  final Map<String, Station> _stationCache = {};
  final Map<String, TransitLine> _lineCache = {};
  final Map<String, List<Station>> _lineStationsCache = {};

  bool get isInitialized => _initialized;
  List<Station> get stations => _stations ?? [];
  List<TransitLine> get lines => _lines ?? [];
  List<Landmark> get landmarks => _landmarks ?? [];
  List<NamtangStop> get namtangStops => _namtangStops ?? [];
  List<StationExit> get exits => _exits;
  TransitGraph get graph => _graph!;

  /// Initialize repository by loading core static data (Trains, Lines, Landmarks)
  Future<void> initialize() async {
    if (_initialized) return;

    await Future.wait([
      _loadStations(),
      _loadLines(),
      _loadLandmarks(),
      _loadExits(),
    ]);

    _buildGraph();
    _initialized = true;
  }

  Future<void> _loadExits() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/station_exits.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      var exitsList = jsonList.map((j) {
        final map = Map<String, dynamic>.from(j as Map);
        final exitCodeVal = map['exit_code'] as String? ?? '';
        map['name_th'] = map['name_th'] as String? ?? 'ทางออก $exitCodeVal';
        map['name_en'] = map['name_en'] as String? ?? 'Exit $exitCodeVal';
        return StationExit.fromJson(map);
      }).toList();
      if (!kDebugMode) {
        exitsList = exitsList.where((e) {
          final id = e.stationId;
          final isNew = id.startsWith('MRT_PK') || 
                        id.startsWith('MRT_MT') || 
                        id.startsWith('SRT_RN') || 
                        id.startsWith('SRT_RW');
          return !isNew;
        }).toList();
      }
      _exits = exitsList;
    } catch (e) {
      _exits = [];
      AppLogger.error('Failed to load station exits: $e', error: e);
    }
  }

  List<StationExit> getExitsForStation(String stationId) {
    return _exits.where((e) => e.stationId == stationId).toList();
  }

  Future<void> _loadStations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/stations.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      var stationsList = jsonList.map((j) => Station.fromJson(j as Map<String, dynamic>)).toList();
      if (!kDebugMode) {
        stationsList = stationsList.where((s) => 
          s.lineId != 'MRT_PINK' && 
          s.lineId != 'MRT_PINK_BRANCH' && 
          s.lineId != 'SRT_RED_NORTH' && 
          s.lineId != 'SRT_RED_WEST'
        ).toList();
      }
      _stations = stationsList;
      _stationCache.clear();
      for (final s in _stations!) {
        _stationCache[s.id] = s;
      }
    } catch (e) {
      // If JSON not available yet, use empty list
      _stations = [];
    }
  }

  Future<void> _loadLines() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/lines.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      var linesList = jsonList.map((j) => TransitLine.fromJson(j as Map<String, dynamic>)).toList();
      if (!kDebugMode) {
        linesList = linesList.where((l) => 
          l.id != 'MRT_PINK' && 
          l.id != 'MRT_PINK_BRANCH' && 
          l.id != 'SRT_RED_NORTH' && 
          l.id != 'SRT_RED_WEST'
        ).toList();
      }
      _lines = linesList;
      _lineCache.clear();
      for (final l in _lines!) {
        _lineCache[l.id] = l;
      }
    } catch (e) {
      _lines = [];
    }
  }

  Future<void> _loadLandmarks() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/landmarks.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _landmarks = jsonList.map((j) => Landmark.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _landmarks = [];
    }
  }

  bool _namtangLoading = false;
  Future<void> loadNamtangStops() async {
    if (_namtangStops != null || _namtangLoading) return;
    _namtangLoading = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/namtang_stops.json');
      
      // Use compute to parse and process the large 2MB JSON in a background isolate
      // to prevent blocking the main UI thread.
      final processedStops = await compute(_parseAndProcessStops, {
        'jsonStr': jsonStr,
        'stations': _stations,
      });
      
      _namtangStops = processedStops;
    } catch (e) {
      _namtangStops = [];
      AppLogger.error('Failed to load Namtang stops: $e', error: e);
    } finally {
      _namtangLoading = false;
    }
  }

  // Top-level or static function for compute
  static List<NamtangStop> _parseAndProcessStops(Map<String, dynamic> params) {
    final String jsonStr = params['jsonStr'];
    final List<Station>? stations = params['stations'];
    
    final List<dynamic> jsonList = json.decode(jsonStr);
    final rawStops = jsonList.map((j) => NamtangStop.fromJson(j as Map<String, dynamic>)).toList();
    
    if (stations == null || stations.isEmpty) return rawStops;

    // Calculate nearest stations for all stops
    return rawStops.map((stop) {
      Station? closest;
      double minDistSq = double.infinity;

      for (final station in stations) {
        final dLat = stop.lat - station.lat;
        final dLon = stop.lng - station.lng;
        final distSq = dLat * dLat + dLon * dLon;
        if (distSq < minDistSq) {
          minDistSq = distSq;
          closest = station;
        }
      }

      if (closest != null) {
        // Simple distance math (fast) instead of Geolocator.distanceBetween (slow/isolate-dependent)
        // 1 deg lat ~= 111km, 1 deg lon ~= 111km * cos(lat)
        // This is accurate enough for "nearest station" detection.
        final dLatM = (stop.lat - closest.lat) * 111320.0;
        final dLonM = (stop.lng - closest.lng) * 111320.0 * 0.97; // cos(13.7 deg) approx 0.97
        final dist = math.sqrt(dLatM * dLatM + dLonM * dLonM);
        
        final walkMin = (dist / 80.0).clamp(1.0, 30.0);
        return stop.copyWith(
          nearestStationId: closest.id,
          walkingMinutes: walkMin,
        );
      }
      return stop;
    }).toList();
  }


  void _buildGraph() {
    _graph = TransitGraph();

    // Add all stations to graph
    for (final station in _stations!) {
      _graph!.addStation(station);
    }

    // Add edges between consecutive stations on each line
    for (final line in _lines!) {
      for (int i = 0; i < line.stationIds.length - 1; i++) {
        final s1 = getStation(line.stationIds[i]);
        final s2 = getStation(line.stationIds[i + 1]);
        if (s1 != null && s2 != null) {
          final dist = Geolocator.distanceBetween(s1.lat, s1.lng, s2.lat, s2.lng);
          // Average transit speed ~35 km/h -> ~583 m/min. Add 0.5 min for dwell time.
          final weight = (dist / 583.0) + 0.5;
          _graph!.addEdge(
            line.stationIds[i],
            line.stationIds[i + 1],
            line.id,
            weight: weight,
          );
        }
      }

      // For loop lines (MRT Blue), connect last to first
      if (line.isLoop && line.stationIds.length > 2) {
        final s1 = getStation(line.stationIds.last);
        final s2 = getStation(line.stationIds.first);
        if (s1 != null && s2 != null) {
          final dist = Geolocator.distanceBetween(s1.lat, s1.lng, s2.lat, s2.lng);
          final weight = (dist / 583.0) + 0.5;
          _graph!.addEdge(
            line.stationIds.last,
            line.stationIds.first,
            line.id,
            weight: weight,
          );
        }
      }
    }

    // Add transfer edges for interchange stations
    for (final station in _stations!) {
      for (final interchangeId in station.interchange) {
        final target = getStation(interchangeId);
        if (target != null) {
          final dist = Geolocator.distanceBetween(station.lat, station.lng, target.lat, target.lng);
          // Base wait time of 2.0 mins + walking time (80 meters/min)
          // If distance is 0 (e.g. cross-platform transfer like Siam), walking time is 0.
          // Minimum transfer time is clamped to 1.0 minute for realism.
          double walkMin = (dist / 80.0) + 2.0;
          
          // Special case: Exact same coordinates (cross-platform transfer)
          if (dist < 10) {
            walkMin = 1.0; 
          }
          
          _graph!.addTransferEdge(
            station.id,
            interchangeId,
            walkingMinutes: walkMin,
          );
        }
      }
    }
  }

  /// Search stations by query (Thai/English name or code)
  List<Station> searchStations(String query) {
    if (_graph == null) return [];
    return _graph!.searchStations(query);
  }

  /// Get a station by ID
  Station? getStation(String id) {
    return _stationCache[id] ?? _graph?.getStation(id);
  }

  /// Get a line by ID
  TransitLine? getLine(String lineId) {
    if (_lineCache.containsKey(lineId)) return _lineCache[lineId];
    return _lines?.firstWhere(
      (l) => l.id == lineId,
      orElse: () => throw StateError('Line not found: $lineId'),
    );
  }

  /// Get all stations on a line
  List<Station> getStationsOnLine(String lineId) {
    if (_lineStationsCache.containsKey(lineId)) {
      return _lineStationsCache[lineId]!;
    }
    final line = getLine(lineId);
    if (line == null) return [];
    final list = line.stationIds
        .map((id) => getStation(id))
        .whereType<Station>()
        .toList();
    _lineStationsCache[lineId] = list;
    return list;
  }

  /// Find shortest path between two stations
  DijkstraResult? findRoute(String fromId, String toId) {
    return _graph?.findShortestPath(fromId, toId);
  }

  /// Search stations and local landmarks by query
  List<SearchableItem> searchLocalPlaces(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    final matchingStations = searchStations(query);

    final matchingLandmarks = (_landmarks ?? []).where((l) {
      final normalizedTh = l.nameTh.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final normalizedEn = l.nameEn.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return normalizedTh.contains(q) ||
             normalizedEn.contains(q);
    }).toList();

    final matchingNamtangStops = (_namtangStops ?? []).where((s) {
      final normalizedTh = s.nameTh.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final normalizedEn = s.nameEn.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      return normalizedTh.contains(q) ||
             normalizedEn.contains(q);
    }).take(20).toList();

    return [...matchingStations, ...matchingLandmarks, ...matchingNamtangStops];
  }

  /// Search places online via Photon API (Elasticsearch-based autocomplete), bounded to Bangkok
  Future<List<CustomLocation>> searchOnlinePlaces(String query) async {
    if (query.trim().length < 3) return [];

    try {
      // Query Photon API with Bangkok location bias (lat=13.7563, lon=100.5018)
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5&lat=13.7563&lon=100.5018&lang=en'
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'com.bkktransit.bkk_transit_planner'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        final results = <CustomLocation>[];

        for (final item in features) {
          final geometry = item['geometry'] as Map<String, dynamic>?;
          final properties = item['properties'] as Map<String, dynamic>?;
          if (geometry == null || properties == null) continue;

          final coords = geometry['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;

          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          if (lat == 0.0 || lon == 0.0) continue;

          final name = properties['name'] as String? ?? '';
          if (name.isEmpty) continue;

          final city = properties['city'] as String? ?? '';
          final state = properties['state'] as String? ?? '';

          // Explicitly exclude Phetchaburi Province to prevent it from being selectable
          final lowerName = name.toLowerCase();
          final lowerCity = city.toLowerCase();
          final lowerState = state.toLowerCase();
          if (lowerName.contains('จังหวัดเพชรบุรี') ||
              lowerCity.contains('จังหวัดเพชรบุรี') ||
              lowerState.contains('จังหวัดเพชรบุรี') ||
              lowerName.contains('phetchaburi') ||
              lowerCity.contains('phetchaburi') ||
              lowerState.contains('phetchaburi')) {
            continue;
          }

          // Find nearest station
          final nearest = findNearestStation(lat, lon);
          if (nearest != null) {
            final dist = Geolocator.distanceBetween(lat, lon, nearest.lat, nearest.lng);
            // Limit results to locations within 12 km of a transit station to filter out far-away provinces
            if (dist <= 12000.0) {
              // Walking minutes based on 80 meters/minute, capped between 1 and 30 mins
              final walkMin = (dist / 80.0).clamp(1.0, 30.0);

              final osmType = properties['osm_type'] as String? ?? 'N';
              final osmId = properties['osm_id'] ?? DateTime.now().millisecondsSinceEpoch;
              results.add(CustomLocation(
                id: 'OSM_${osmType}_${osmId}_${lat.toStringAsFixed(6)}_${lon.toStringAsFixed(6)}',
                nameTh: name,
                nameEn: name,
                nearestStationId: nearest.id,
                walkingMinutes: walkMin,
                lat: lat,
                lng: lon,
              ));
            }
          }
        }
        return results;
      }
    } catch (e) {
      AppLogger.error('Online place search failed: $e', error: e);
    }
    return [];
  }

  /// Resolves the best entrance for a CustomLocation using Overpass and OSRM
  Future<CustomLocation?> resolveOnlinePlaceAsync(CustomLocation place) async {
    // 1. Fetch entrances around the centroid (or use existing if provided)
    List<LatLng> entrances;
    bool hasWarning = false;
    if (place.entrances != null && place.entrances!.isNotEmpty) {
      entrances = List<LatLng>.from(place.entrances!);
    } else {
      String? osmType;
      int? osmId;
      if (place.id.startsWith('OSM_')) {
        final parts = place.id.split('_');
        if (parts.length >= 3) {
          osmType = parts[1];
          osmId = int.tryParse(parts[2]);
        }
      }
      try {
        entrances = await _overpassService.findEntrances(
          place.lat,
          place.lng,
          radius: 800.0,
          osmType: osmType,
          osmId: osmId,
        );
      } catch (e) {
        AppLogger.error('Overpass resolution failed after retries: $e', error: e);
        entrances = [];
        hasWarning = true;
      }
    }
    
    if (entrances.isEmpty) {
      // Fallback: use the centroid itself if no entrances found
      final result = await findTrueNearestStationAsync(place.lat, place.lng);
      if (result != null) {
        return place.copyWith(
          nearestStationId: result.station.id,
          walkingMinutes: result.osrmResult?.durationSeconds != null ? (result.osrmResult!.durationSeconds / 60.0).clamp(1.0, 30.0) : place.walkingMinutes,
          walkingPath: result.osrmResult?.coordinates,
          hasAccuracyWarning: hasWarning,
        );
      }
      return place.copyWith(hasAccuracyWarning: hasWarning);
    }

    // 2. We have entrances. Find the one that gives the shortest OSRM path to its nearest station.
    // Sort by distance to the nearest transit station (not the POI centroid) so that for large
    // complex POIs like airports, we prefer entrances on the station-facing side rather than
    // far-away perimeter gates that would require routing around the entire building.
    final anchorStation = findNearestStation(place.lat, place.lng);
    final anchorLat = anchorStation?.lat ?? place.lat;
    final anchorLng = anchorStation?.lng ?? place.lng;
    entrances.sort((a, b) =>
      Geolocator.distanceBetween(anchorLat, anchorLng, a.latitude, a.longitude)
      .compareTo(Geolocator.distanceBetween(anchorLat, anchorLng, b.latitude, b.longitude))
    );
    final topEntrances = entrances.take(5).toList();

    ({Station station, OsrmRouteResult? osrmResult, LatLng entrance})? bestMatch;
    double shortestDuration = double.infinity;

    // Fetch OSRM walking paths for all 5 entrances in parallel
    final List<Future<({Station station, OsrmRouteResult? osrmResult, LatLng entrance})?>> futures = [];

    for (final entrance in topEntrances) {
      final nearest = findNearestStation(entrance.latitude, entrance.longitude);
      if (nearest != null) {
        futures.add(() async {
          final res = await _osrmService.getWalkingRoute(
            entrance.latitude,
            entrance.longitude,
            nearest.lat,
            nearest.lng,
            fetchGeometry: true,
          );
          return (station: nearest, osrmResult: res, entrance: entrance);
        }());
      }
    }

    final results = await Future.wait(futures);

    for (final r in results) {
      if (r != null && r.osrmResult != null) {
        final duration = r.osrmResult!.durationSeconds.toDouble();
        if (duration < shortestDuration) {
          shortestDuration = duration;
          bestMatch = r;
        }
      }
    }

    if (bestMatch != null) {
      // We found a valid route via an entrance!
      // Use routeLat/routeLng (not lat/lng) so the map display pin stays at the
      // original centroid while only the routing/walking coordinate moves to the entrance.
      return place.copyWith(
        customRouteLat: bestMatch.entrance.latitude,
        customRouteLng: bestMatch.entrance.longitude,
        nearestStationId: bestMatch.station.id,
        walkingMinutes: (bestMatch.osrmResult!.durationSeconds / 60.0).clamp(1.0, 30.0),
        walkingPath: bestMatch.osrmResult!.coordinates,
        entrances: entrances,
      );
    }

    return place;
  }

  Station? findNearestStation(double lat, double lon) {
    if (_stations == null || _stations!.isEmpty) return null;

    Station? closest;
    double minDist = double.infinity;

    for (final station in _stations!) {
      final dist = Geolocator.distanceBetween(lat, lon, station.lat, station.lng);
      if (dist < minDist) {
        minDist = dist;
        closest = station;
      }
    }
    return closest;
  }

  /// Finds the truly nearest station using OSRM walking paths for the top candidate stations.
  Future<({Station station, OsrmRouteResult? osrmResult})?> findTrueNearestStationAsync(double lat, double lon) async {
    if (_stations == null || _stations!.isEmpty) return null;

    // 1. Find top 3 nearest stations by straight-line distance
    final List<MapEntry<Station, double>> candidates = _stations!.map((station) {
      final dist = Geolocator.distanceBetween(lat, lon, station.lat, station.lng);
      return MapEntry(station, dist);
    }).toList();

    // Sort by straight line distance
    candidates.sort((a, b) => a.value.compareTo(b.value));
    
    // Take top 3 closest by straight line
    final topCandidates = candidates.take(3).map((e) => e.key).toList();

    Station? bestStation;
    OsrmRouteResult? bestOsrmResult;
    double minWalkDuration = double.infinity;

    // 2. Query OSRM for true walking duration in parallel
    final results = await Future.wait(
      topCandidates.map((station) async {
        final res = await _osrmService.getWalkingRoute(lat, lon, station.lat, station.lng, fetchGeometry: true);
        return (station: station, osrmResult: res);
      })
    );

    for (final r in results) {
      if (r.osrmResult != null) {
        if (r.osrmResult!.durationSeconds < minWalkDuration) {
          minWalkDuration = r.osrmResult!.durationSeconds;
          bestStation = r.station;
          bestOsrmResult = r.osrmResult;
        }
      }
    }

    // Fallback to straight-line if OSRM fails for all
    if (bestStation == null) {
      return (station: topCandidates.first, osrmResult: null);
    }

    return (station: bestStation, osrmResult: bestOsrmResult);
  }
}
