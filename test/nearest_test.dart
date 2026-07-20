@Tags(["live_api"])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';

void main() {
  test('Find nearest station to MBK centroid', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();

    final nearest = repo.findNearestStation(13.7444, 100.5299);
    print(
      'Nearest station to 13.7444, 100.5299 is: ${nearest?.id} (${nearest?.nameEn})',
    );
  });
}
