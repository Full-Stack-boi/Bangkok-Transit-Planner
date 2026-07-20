@Tags(["live_api"])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/services/photon_search_service.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('Debug MBK Center Resolution', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize(); // Requires init for loading landmarks

    final photonService = PhotonSearchService(repo);

    print('Searching for MBK Center...');
    final results = await photonService.searchOnlinePlaces('MBK Center');
    if (results.isEmpty) {
      print('No results found.');
      return;
    }

    final mbk = results.first;
    print('Found: ${mbk.nameTh} (lat=${mbk.lat}, lng=${mbk.lng})');

    print('Resolving deep entrances...');
    final resolved = await repo.resolveOnlinePlaceAsync(mbk);
    if (resolved != null) {
      // After BUG 2 fix: lat/lng stays at centroid, routeLat/routeLng moves to entrance
      print('Display pin (lat/lng): ${resolved.lat}, ${resolved.lng}');
      print(
        'Routing coord (routeLat/routeLng): ${resolved.routeLat}, ${resolved.routeLng}',
      );
      if (mbk.lat == resolved.routeLat && mbk.lng == resolved.routeLng) {
        print(
          'Warning: Routing coord UNCHANGED (still pointing to centroid/back alley)',
        );
      } else {
        print('Success: Routing coord UPDATED to an entrance!');
      }

      print('Nearest Station ID: ${resolved.nearestStationId}');
      print('Walking path length: ${resolved.walkingPath?.length}');
    }
  });

  test('Debug Lumphini Park Resolution', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();

    // Centroid of Lumphini Park.
    // Use the real OSM Relation id (R2619873) so the OSM-aware Overpass query
    // runs against the actual park relation (not a radius fallback).
    final lumpini = CustomLocation(
      id: 'OSM_R_2619873',
      nameTh: 'สวนลุมพินี',
      nameEn: 'Lumphini Park',
      nearestStationId: '',
      walkingMinutes: 0.0,
      lat: 13.7313,
      lng: 100.5414,
    );

    print(
      'Resolving Lumphini Park entrances from centroid (13.7313, 100.5414)...',
    );
    final resolved = await repo.resolveOnlinePlaceAsync(lumpini);

    expect(resolved, isNotNull);
    if (resolved != null) {
      print('Original Centroid (lat/lng): ${lumpini.lat}, ${lumpini.lng}');
      // After BUG 2 fix: lat/lng = centroid (display pin), routeLat/routeLng = entrance (routing)
      print('Display pin (lat/lng): ${resolved.lat}, ${resolved.lng}');
      print(
        'Routing coord (routeLat/routeLng): ${resolved.routeLat}, ${resolved.routeLng}',
      );
      print('Nearest Station ID: ${resolved.nearestStationId}');
      print('Walking Minutes: ${resolved.walkingMinutes}');
      print('Walking Path Length: ${resolved.walkingPath?.length}');

      // BUG 2 fix: display pin (lat/lng) must remain at centroid — must NOT be updated
      expect(
        resolved.lat,
        equals(lumpini.lat),
        reason: 'lat (display pin) must stay at centroid after resolution',
      );
      expect(
        resolved.lng,
        equals(lumpini.lng),
        reason: 'lng (display pin) must stay at centroid after resolution',
      );

      // The routing coordinate (routeLat/routeLng) should move to a gate entrance.
      // If no entrance was found (e.g. Overpass timeout), fallback to centroid is acceptable.
      if (resolved.routeLat != lumpini.lat ||
          resolved.routeLng != lumpini.lng) {
        print(
          'Success: Routing coord UPDATED to entrance at (${resolved.routeLat}, ${resolved.routeLng})',
        );
      } else {
        print(
          'Info: No entrance found (possible Overpass timeout) — using centroid as routing point',
        );
      }

      // Nearest station should be MRT Si Lom (MRT_BL26) or BTS Sala Daeng (BTS_S2)
      expect(
        resolved.nearestStationId,
        anyOf(equals('MRT_BL26'), equals('BTS_S2')),
      );
    }
  });
}
