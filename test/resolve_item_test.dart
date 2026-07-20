@Tags(["live_api"])
library;
import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';

void main() {
  test('Test resolveItem logic', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();
    
    print('Landmarks loaded: ${repo.landmarks.length}');
    final l = repo.landmarks.firstWhere((x) => x.id == 'LM_MBK');
    print('MBK local nameEn: ${l.nameEn}');
    
    final item = CustomLocation(
      id: 'photon_123',
      nameTh: 'MBK Center (Bangkok)',
      nameEn: 'MBK Center',
      nearestStationId: '',
      walkingMinutes: 10,
      lat: 13.7444,
      lng: 100.5299,
    );
    
    print('CustomLocation nameEn: ${item.nameEn}');
    
    final queryLower = item.nameTh.toLowerCase();
    bool matched = false;
    for (final lm in repo.landmarks) {
      if (lm.nameTh.toLowerCase() == queryLower || 
          lm.nameEn.toLowerCase() == item.nameEn.toLowerCase() ||
          lm.nameTh.toLowerCase().contains(queryLower)) {
        print('Matched! Returns: ${lm.id}');
        matched = true;
        break;
      }
    }
    expect(matched, true);
  });
}
