import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Supabase integration and offline fallback
class SupabaseService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize Supabase with try-catch wrapper to avoid crashes if offline or credentials are wrong
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // In production, these would be loaded from environment config
      const supabaseUrl = 'https://REDACTED_SUPABASE_PROJECT_ID.supabase.co';
      const supabaseAnonKey = 'REDACTED_SUPABASE_ANON_KEY';

      // Simple validation to ensure non-empty strings before initializing
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && !supabaseUrl.contains('PLACEHOLDER')) {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        _isInitialized = true;
        print('Supabase initialized successfully.');
      }
    } catch (e) {
      _isInitialized = false;
      print('Supabase initialization failed: $e. Running in offline/fallback mode.');
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
