@Tags(["live_api"])
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';

void main() {
  test('Test resolve MBK with generic query', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();
    
    // Simulate user selecting a generic "MBK" from autocomplete
    final item = CustomLocation(
      id: 'photon_123',
      nameTh: 'มาบุญครอง (Bangkok)', // Example of what Photon might return
      nameEn: 'MBK', // Let's see what happens if nameEn is just MBK
      nearestStationId: '',
      walkingMinutes: 0,
      lat: 13.7444,
      lng: 100.5299,
    );
    
    // Mimic the _resolveItem logic
    final queryLower = item.nameTh.toLowerCase();
    bool matchedLocal = false;
    for (final l in repo.landmarks) {
      if (l.nameTh.toLowerCase() == queryLower || 
          l.nameEn.toLowerCase() == item.nameEn.toLowerCase() ||
          l.nameTh.toLowerCase().contains(queryLower)) {
        matchedLocal = true;
        print('Matched local landmark: ${l.nameEn}');
        break;
      }
    }
    
    if (!matchedLocal) {
      print('Did NOT match local landmark. Proceeding to resolveOnlinePlaceAsync...');
    }
  });
}
