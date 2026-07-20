@Tags(["live_api"])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/services/photon_search_service.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:flutter/widgets.dart';

/// Helper function to search and resolve a place by text query
Future<void> debugOnlinePlaceResolution(
  TransitRepository repo,
  PhotonSearchService photon,
  String query, {
  List<String>? expectedNearestStations,
}) async {
  print('\n======================================================');
  print('RESOLVING QUERY: $query');
  print('======================================================');
  
  final results = await photon.searchOnlinePlaces(query);
  if (results.isEmpty) {
    print('No results found for "$query".');
    return;
  }

  final place = results.first;
  print('Found: ${place.nameTh} / ${place.nameEn} (lat=${place.lat}, lng=${place.lng})');
  print('Resolving deep entrances...');
  
  final resolved = await repo.resolveOnlinePlaceAsync(place);
  expect(resolved, isNotNull);
  
  if (resolved != null) {
    print('Display pin (lat/lng): ${resolved.lat}, ${resolved.lng}');
    print('Routing coord (routeLat/routeLng): ${resolved.routeLat}, ${resolved.routeLng}');
    
    if (place.lat == resolved.routeLat && place.lng == resolved.routeLng) {
      print('Warning: Routing coord UNCHANGED (still pointing to centroid/back alley or no entrance found)');
    } else {
      print('Success: Routing coord UPDATED to an entrance!');
    }

    print('Nearest Station ID: ${resolved.nearestStationId}');
    print('Walking path length: ${resolved.walkingPath?.length}');
    
    if (expectedNearestStations != null && expectedNearestStations.isNotEmpty) {
      expect(
        expectedNearestStations.contains(resolved.nearestStationId),
        isTrue,
        reason: 'Nearest station ${resolved.nearestStationId} is not in expected list $expectedNearestStations',
      );
    }
  }
}

/// Helper function to resolve a specific CustomLocation (e.g., passing a specific OSM ID)
Future<void> debugCustomLocationResolution(
  TransitRepository repo,
  CustomLocation location, {
  List<String>? expectedNearestStations,
}) async {
  print('\n======================================================');
  print('RESOLVING CUSTOM LOCATION: ${location.nameEn}');
  print('======================================================');
  
  final resolved = await repo.resolveOnlinePlaceAsync(location);
  expect(resolved, isNotNull);
  
  if (resolved != null) {
    print('Original Centroid (lat/lng): ${location.lat}, ${location.lng}');
    print('Display pin (lat/lng): ${resolved.lat}, ${resolved.lng}');
    print('Routing coord (routeLat/routeLng): ${resolved.routeLat}, ${resolved.routeLng}');
    print('Nearest Station ID: ${resolved.nearestStationId}');
    print('Walking Minutes: ${resolved.walkingMinutes}');
    print('Walking Path Length: ${resolved.walkingPath?.length}');

    expect(resolved.lat, equals(location.lat), reason: 'lat (display pin) must stay at centroid after resolution');
    expect(resolved.lng, equals(location.lng), reason: 'lng (display pin) must stay at centroid after resolution');

    if (resolved.routeLat != location.lat || resolved.routeLng != location.lng) {
      print('Success: Routing coord UPDATED to entrance at (${resolved.routeLat}, ${resolved.routeLng})');
    } else {
      print('Info: No entrance found (possible Overpass timeout) — using centroid as routing point');
    }

    if (expectedNearestStations != null && expectedNearestStations.isNotEmpty) {
      expect(
        expectedNearestStations.contains(resolved.nearestStationId),
        isTrue,
        reason: 'Nearest station ${resolved.nearestStationId} is not in expected list $expectedNearestStations',
      );
    }
  }
}

void main() {
  test('Debug Generic Place Resolution', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize(); // Requires init for loading landmarks
    final photonService = PhotonSearchService(repo);

    // ---------------------------------------------------------
    // Scenario 1: MBK Center (Search by string)
    // ---------------------------------------------------------
    await debugOnlinePlaceResolution(
      repo, 
      photonService, 
      'MBK Center',
      expectedNearestStations: ['BTS_W1', 'BTS_CEN'],
    );

    // ---------------------------------------------------------
    // Scenario 2: Lumphini Park (Search by CustomLocation / OSM Relation)
    // ---------------------------------------------------------
    final lumpini = CustomLocation(
      id: 'OSM_R_2619873',
      nameTh: 'สวนลุมพินี',
      nameEn: 'Lumphini Park',
      nearestStationId: '',
      walkingMinutes: 0.0,
      lat: 13.7313,
      lng: 100.5414,
    );
    await debugCustomLocationResolution(
      repo, 
      lumpini,
      expectedNearestStations: ['MRT_BL26', 'BTS_S2'],
    );
    
    // ---------------------------------------------------------
    // Add more scenarios below as needed:
    // await debugOnlinePlaceResolution(repo, photonService, 'Siam Paragon');
    // ---------------------------------------------------------
  });
}
