import '../services/supabase_service.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Repository for handling crowd reports and presence signals
class CrowdRepository {
  final SupabaseService _supabaseService;

  CrowdRepository(this._supabaseService);

  /// Report passive GPS presence at a station
  Future<void> reportPresence({
    required String stationId,
    required double accuracy,
    String? userId,
  }) async {
    final now = DateTime.now().toIso8601String();
    AppLogger.info(
      'Passive GPS check-in reported locally: Station: $stationId, Accuracy: $accuracy meters, Time: $now',
    );

    if (_supabaseService.isInitialized) {
      try {
        final client = _supabaseService.client;
        final actualUserId =
            userId ?? client?.auth.currentUser?.id ?? 'anonymous_user';

        await client?.from('crowd_presence').insert({
          'station_id': stationId,
          'user_id': actualUserId,
          'detected_at': DateTime.now().toUtc().toIso8601String(),
          'accuracy_meters': accuracy,
        });
      } catch (e) {
        AppLogger.error('Supabase passive check-in sync failed: $e', error: e);
      }
    }
  }

  /// Submit manual active crowd report
  Future<void> submitCrowdReport({
    required String stationId,
    required int level, // 1-5
    String? direction,
    String? userId,
  }) async {
    final now = DateTime.now().toIso8601String();
    AppLogger.info(
      'Active crowd report submitted locally: Station: $stationId, Level: $level, Direction: $direction, Time: $now',
    );

    if (_supabaseService.isInitialized) {
      try {
        final client = _supabaseService.client;
        final actualUserId =
            userId ?? client?.auth.currentUser?.id ?? 'anonymous_user';

        await client?.from('crowd_reports').insert({
          'station_id': stationId,
          'user_id': actualUserId,
          'level': level,
          'reported_at': DateTime.now().toUtc().toIso8601String(),
          'direction': direction,
        });
      } catch (e) {
        AppLogger.error(
          'Supabase active crowd report sync failed: $e',
          error: e,
        );
      }
    }
  }
}
