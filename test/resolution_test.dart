import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('Debug MBK Center Resolution', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize(); // Requires init for loading landmarks

    print('Searching for MBK Center...');
    final results = await repo.searchOnlinePlaces('MBK Center');
    if (results.isEmpty) {
      print('No results found.');
      return;
    }

    final mbk = results.first;
    print('Found: ${mbk.nameTh} (${mbk.lat}, ${mbk.lng})');

    print('Resolving deep entrances...');
    final resolved = await repo.resolveOnlinePlaceAsync(mbk);
    if (resolved != null) {
      print('Resolved coordinates: ${resolved.lat}, ${resolved.lng}');
      if (mbk.lat == resolved.lat && mbk.lng == resolved.lng) {
        print(
          'Warning: Location UNCHANGED (still pointing to centroid/back alley)',
        );
      } else {
        print('Success: Location UPDATED to an entrance!');
      }

      print('Nearest Station ID: ${resolved.nearestStationId}');
      print('Walking path length: ${resolved.walkingPath?.length}');
    }
  });

  test('Debug Lumphini Park Resolution', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();

    // Centroid of Lumphini Park
    final lumpini = CustomLocation(
      id: 'OSM_LUMPINI_CENTROID',
      nameTh: 'สวนลุมพินี',
      nameEn: 'Lumphini Park',
      nearestStationId: '',
      walkingMinutes: 0.0,
      lat: 13.7313,
      lng: 100.5414,
    );

    print('Resolving Lumphini Park entrances from centroid (13.7313, 100.5414)...');
    final resolved = await repo.resolveOnlinePlaceAsync(lumpini);
    
    expect(resolved, isNotNull);
    if (resolved != null) {
      print('Original Centroid: ${lumpini.lat}, ${lumpini.lng}');
      print('Resolved coordinates: ${resolved.lat}, ${resolved.lng}');
      print('Nearest Station ID: ${resolved.nearestStationId}');
      print('Walking Minutes: ${resolved.walkingMinutes}');
      print('Walking Path Length: ${resolved.walkingPath?.length}');

      // The resolved location should be updated to a gate (e.g. Gate 4 at ~13.7300, 100.5382)
      // and NOT remain at the centroid (13.7313, 100.5414)
      expect(resolved.lat, isNot(equals(lumpini.lat)));
      expect(resolved.lng, isNot(equals(lumpini.lng)));
      
      // Nearest station should be MRT Si Lom (MRT_BL26) or BTS Sala Daeng (BTS_S2)
      expect(resolved.nearestStationId, anyOf(equals('MRT_BL26'), equals('BTS_S2')));
    }
  });
}
