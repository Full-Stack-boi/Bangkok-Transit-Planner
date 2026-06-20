import 'package:flutter_test/flutter_test.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/models/landmark.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('Check alternativeWalks parsing', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final repo = TransitRepository();
    await repo.initialize();
    
    final mbk = repo.landmarks.firstWhere((l) => l.nameEn == 'MBK Center') as Landmark;
    print('Alternative Walks keys: ${mbk.alternativeWalks?.keys.toList()}');
    print('BTS_CEN walk path length: ${mbk.alternativeWalks?['BTS_CEN']?.walkingPath.length}');
  });
}
