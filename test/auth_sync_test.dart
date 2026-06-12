import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bkk_transit_planner/repositories/favorites_repository.dart';
import 'package:bkk_transit_planner/services/supabase_service.dart';

class MockSupabaseService extends SupabaseService {
  @override
  bool get isInitialized => false; // Mock offline state
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('FavoritesRepository offline favorite toggle test', () async {
    final supabase = MockSupabaseService();
    final repo = FavoritesRepository(supabase);
    await repo.initialize();

    // Verify initially empty
    expect(repo.getFavoriteStationIds(), isEmpty);

    // Toggle favorite on BTS_01
    final isFav = await repo.toggleFavoriteStation('BTS_01');
    expect(isFav, isTrue);
    expect(repo.getFavoriteStationIds(), contains('BTS_01'));

    // Toggle again to remove
    final isFav2 = await repo.toggleFavoriteStation('BTS_01');
    expect(isFav2, isFalse);
    expect(repo.getFavoriteStationIds(), isEmpty);
  });
}
