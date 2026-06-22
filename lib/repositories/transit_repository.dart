import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

  /// Initialize repository by loading all static data
  Future<void> initialize() async {
    if (_initialized) return;

    await Future.wait([
      _loadStations(),
      _loadLines(),
      _loadLandmarks(),
      _loadExits(),
    ]);

    await _loadNamtangStops();

    _buildGraph();
    _initialized = true;
  }

  Future<void> _loadExits() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/station_exits.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _exits = jsonList.map((j) => StationExit.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      _exits = [];
      print('Failed to load station exits: $e');
    }
  }

  List<StationExit> getExitsForStation(String stationId) {
    return _exits.where((e) => e.stationId == stationId).toList();
  }

  Future<void> _loadStations() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/stations.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _stations = jsonList.map((j) => Station.fromJson(j as Map<String, dynamic>)).toList();
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
      _lines = jsonList.map((j) => TransitLine.fromJson(j as Map<String, dynamic>)).toList();
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

  Future<void> _loadNamtangStops() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/namtang_stops.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      final rawStops = jsonList.map((j) => NamtangStop.fromJson(j as Map<String, dynamic>)).toList();
      
      // Calculate nearest stations for all stops
      _namtangStops = rawStops.map((stop) {
        final nearest = _findNearestStationFast(stop.lat, stop.lng);
        if (nearest != null) {
          final dist = Geolocator.distanceBetween(stop.lat, stop.lng, nearest.lat, nearest.lng);
          final walkMin = (dist / 80.0).clamp(1.0, 30.0);
          return stop.copyWith(
            nearestStationId: nearest.id,
            walkingMinutes: walkMin,
          );
        }
        return stop;
      }).toList();
    } catch (e) {
      _namtangStops = [];
      print('Failed to load Namtang stops: $e');
    }
  }

  Station? _findNearestStationFast(double lat, double lon) {
    if (_stations == null || _stations!.isEmpty) return null;

    Station? closest;
    double minDistSq = double.infinity;

    for (final station in _stations!) {
      final dLat = lat - station.lat;
      final dLon = lon - station.lng;
      final distSq = dLat * dLat + dLon * dLon;
      if (distSq < minDistSq) {
        minDistSq = distSq;
        closest = station;
      }
    }
    return closest;
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

    final client = HttpClient();
    client.userAgent = 'com.bkktransit.bkk_transit_planner';

    try {
      // Query Photon API with Bangkok location bias (lat=13.7563, lon=100.5018)
      final uri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=5&lat=13.7563&lon=100.5018&lang=en'
      );

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(body);
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
                id: 'OSM_${osmType}_$osmId',
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
      print('Online place search failed: $e');
    } finally {
      client.close();
    }
    return [];
  }

  /// Resolves the best entrance for a CustomLocation using Overpass and OSRM
  Future<CustomLocation?> resolveOnlinePlaceAsync(CustomLocation place) async {
    // 1. Fetch entrances around the centroid (or use existing if provided)
    final List<LatLng> entrances;
    if (place.entrances != null && place.entrances!.isNotEmpty) {
      entrances = List<LatLng>.from(place.entrances!);
    } else {
      String? osmType;
      int? osmId;
      if (place.id.startsWith('OSM_')) {
        final parts = place.id.split('_');
        if (parts.length == 3) {
          osmType = parts[1];
          osmId = int.tryParse(parts[2]);
        }
      }
      entrances = await _overpassService.findEntrances(
        place.lat,
        place.lng,
        radius: 800.0,
        osmType: osmType,
        osmId: osmId,
      );
    }
    
    if (entrances.isEmpty) {
      // Fallback: use the centroid itself if no entrances found
      final result = await findTrueNearestStationAsync(place.lat, place.lng);
      if (result != null) {
        return place.copyWith(
          nearestStationId: result.station.id,
          walkingMinutes: result.osrmResult?.durationSeconds != null ? (result.osrmResult!.durationSeconds / 60.0).clamp(1.0, 30.0) : place.walkingMinutes,
          walkingPath: result.osrmResult?.coordinates,
        );
      }
      return place;
    }

    // 2. We have entrances. Find the one that gives the shortest OSRM path to any station.
    // To avoid too many calls, limit to top 10 entrances closest to the centroid by straight line.
    entrances.sort((a, b) => 
      Geolocator.distanceBetween(place.lat, place.lng, a.latitude, a.longitude)
      .compareTo(Geolocator.distanceBetween(place.lat, place.lng, b.latitude, b.longitude))
    );
    final topEntrances = entrances.take(10).toList();

    ({Station station, OsrmRouteResult? osrmResult})? bestMatch;
    double shortestDuration = double.infinity;
    LatLng? bestEntrance;

    for (final entrance in topEntrances) {
      final result = await findTrueNearestStationAsync(entrance.latitude, entrance.longitude);
      if (result?.osrmResult != null) {
        final duration = result!.osrmResult!.durationSeconds.toDouble();
        if (duration < shortestDuration) {
          shortestDuration = duration;
          bestMatch = result;
          bestEntrance = entrance;
        }
      }
    }

    if (bestMatch != null && bestEntrance != null) {
      // We found a valid route via an entrance!
      // Use routeLat/routeLng (not lat/lng) so the map display pin stays at the
      // original centroid while only the routing/walking coordinate moves to the entrance.
      return place.copyWith(
        routeLat: bestEntrance.latitude,
        routeLng: bestEntrance.longitude,
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

    // 2. Query OSRM for true walking duration
    for (final station in topCandidates) {
      final osrmResult = await _osrmService.getWalkingRoute(lat, lon, station.lat, station.lng, fetchGeometry: true);
      
      if (osrmResult != null) {
        if (osrmResult.durationSeconds < minWalkDuration) {
          minWalkDuration = osrmResult.durationSeconds;
          bestStation = station;
          bestOsrmResult = osrmResult;
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
