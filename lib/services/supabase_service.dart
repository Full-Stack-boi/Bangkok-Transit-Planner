import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';
import 'secure_local_storage.dart';

class SupabaseService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const envUrl = String.fromEnvironment('SUPABASE_URL');
      const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

      final supabaseUrl = envUrl.isNotEmpty
          ? envUrl
          : 'https://REDACTED_SUPABASE_PROJECT_ID.supabase.co';
      final supabaseAnonKey = envKey.isNotEmpty
          ? envKey
          : 'REDACTED_SUPABASE_ANON_KEY';

      if (supabaseUrl.isNotEmpty &&
          supabaseAnonKey.isNotEmpty &&
          !supabaseUrl.contains('PLACEHOLDER')) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
          authOptions: FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
            localStorage: kIsWeb ? null : SecureLocalStorage(),
          ),
        );
        _isInitialized = true;
        AppLogger.success('Supabase initialized successfully.');
      }
    } catch (e) {
      _isInitialized = false;
      AppLogger.error(
        'Supabase initialization failed: $e. Running in offline/fallback mode.',
        error: e,
      );
    }
  }

  /// Get active Supabase client if initialized, otherwise null
  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }
}
