import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Supabase Database Trigger Integration Tests', () {
    const supabaseUrl = 'https://REDACTED_SUPABASE_PROJECT_ID.supabase.co';
    const supabaseAnonKey = 'REDACTED_SUPABASE_ANON_KEY';

    setUpAll(() async {
      // Mock shared_preferences since Supabase initialization uses it for storing session info
      SharedPreferences.setMockInitialValues({});
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
      } catch (e) {
        print('Supabase was already initialized: $e');
      }
    });

    test('Verify cleanup_old_presence trigger purges records older than 1 minute', () async {
      final client = Supabase.instance.client;
      final testUserId = 'integration_test_user_${DateTime.now().millisecondsSinceEpoch}';

      print('\n--- E2E Database Integration Test Start ---');

      // 1. Clean up any leftovers
      print('[E2E] Step 1: Cleaning up any old test records...');
      await client.from('crowd_presence').delete().eq('user_id', testUserId);

      // 2. Insert an outdated presence ping (1 hour ago to ensure it is older than 1 minute despite clock drift)
      print('[E2E] Step 2: Inserting an OUTDATED record (1 hour old)...');
      final oneHourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
      await client.from('crowd_presence').insert({
        'station_id': 'ARL_A4',
        'user_id': testUserId,
        'detected_at': oneHourAgo,
        'accuracy_meters': 10.0,
      });

      // 3. Query database - the trigger should have INSTANTLY deleted it since it's > 1 minute old
      print('[E2E] Step 3: Querying database - should be 0 because trigger instantly purged it...');
      var rows = await client.from('crowd_presence').select().eq('user_id', testUserId);
      print('[E2E] Current rows count: ${rows.length}');
      if (rows.isNotEmpty) {
        print('[E2E] Leftover row details:');
        for (final r in rows) {
          print('  - ID: ${r['id']}, detected_at: ${r['detected_at']}, user_id: ${r['user_id']}');
        }
      }
      expect(rows.length, equals(0)); // Instantly deleted by TTL trigger!

      // 4. Insert a fresh presence ping (now)
      print('[E2E] Step 4: Inserting a FRESH record (current time)...');
      final now = DateTime.now().toUtc().toIso8601String();
      await client.from('crowd_presence').insert({
        'station_id': 'ARL_A4',
        'user_id': testUserId,
        'detected_at': now,
        'accuracy_meters': 10.0,
      });

      // 5. Query database again - the fresh record should persist because it's < 1 minute old
      print('[E2E] Step 5: Querying database again. Fresh record should still exist.');
      rows = await client.from('crowd_presence').select().eq('user_id', testUserId);
      print('[E2E] Current rows count after inserting fresh record: ${rows.length}');
      expect(rows.length, equals(1));
      print('[E2E] Remaining row in DB: ID: ${rows.first['id']}, Detected At: ${rows.first['detected_at']}');

      // 6. Clean up test records
      print('[E2E] Step 6: Cleaning up test records from DB...');
      await client.from('crowd_presence').delete().eq('user_id', testUserId);

      print('--- E2E Database Integration Test Success! ---\n');
    });
  });
}
