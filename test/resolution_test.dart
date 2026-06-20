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
    
    final mbk = results.first as CustomLocation;
    print('Found: ${mbk.nameTh} (${mbk.lat}, ${mbk.lng})');
    
    print('Resolving deep entrances...');
    final resolved = await repo.resolveOnlinePlaceAsync(mbk);
    if (resolved != null) {
      print('Resolved coordinates: ${resolved.lat}, ${resolved.lng}');
      if (mbk.lat == resolved.lat && mbk.lng == resolved.lng) {
        print('Warning: Location UNCHANGED (still pointing to centroid/back alley)');
      } else {
        print('Success: Location UPDATED to an entrance!');
      }
      
      print('Nearest Station ID: ${resolved.nearestStationId}');
      print('Walking path length: ${resolved.walkingPath?.length}');
    }
  });
}
