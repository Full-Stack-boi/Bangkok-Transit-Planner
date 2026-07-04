import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/translation_helper.dart';
import '../repositories/transit_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/crowd_repository.dart';
import '../services/fare_service.dart';
import '../services/schedule_service.dart';
import '../services/crowd_service.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'auth_providers.dart';

export 'auth_providers.dart';
export 'location_providers.dart';
export 'user_cards_provider.dart';

part 'providers.g.dart';

// ─── Repository Providers ───

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  return TransitRepository();
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return FavoritesRepository(supabase);
});

final crowdRepositoryProvider = Provider<CrowdRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CrowdRepository(supabase);
});

// ─── Service Providers ───

final fareServiceProvider = Provider<FareService>((ref) {
  return FareService();
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService();
});

final crowdServiceProvider = Provider<CrowdService>((ref) {
  return CrowdService();
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ─── Initialization Provider ───

final transitInitProvider = FutureProvider<void>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);
  await supabase.initialize();

  // Instantiate authProvider on startup so it listens to auth state events immediately
  ref.read(authProvider);

  final favorites = ref.read(favoritesRepositoryProvider);
  await favorites.initialize();

  // If user is already logged in on startup, proactively pull/push favorites & saved routes
  if (supabase.isInitialized && supabase.client?.auth.currentUser != null) {
    try {
      await favorites.syncOfflineDataWithSupabase();
    } catch (e) {
      print('Favorites startup sync failed: $e');
    }
  }

  final repo = ref.read(transitRepositoryProvider);
  await repo.initialize();
});


// ─── UI Providers ───

SharedPreferences? testSharedPreferencesInstance;

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  if (testSharedPreferencesInstance != null) {
    return testSharedPreferencesInstance!;
  }
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope overrides');
});

@riverpod
class HomeTabIndex extends _$HomeTabIndex {
  @override
  int build() => 1;

  void setTab(int index) {
    state = index;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeStr = prefs.getString('theme_mode');
    if (themeStr == 'light') return ThemeMode.light;
    if (themeStr == 'dark') return ThemeMode.dark;
    if (themeStr == 'system') return ThemeMode.system;
    return ThemeMode.dark; // Default theme
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString('language_code') ?? 'th';
  }

  Future<void> setLocale(String langCode) async {
    state = langCode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('language_code', langCode);
    } catch (_) {}
  }
}

final translationsProvider = Provider<AppLocalizations>((ref) {
  final lang = ref.watch(localeProvider);
  return AppLocalizations(lang);
});

class MapPrefetchProgress {
  final bool isPrefetching;
  final bool isPaused;
  final int totalTiles;
  final int currentTile;
  final int successCount;
  final int cachedCount;
  final int errorCount;

  const MapPrefetchProgress({
    this.isPrefetching = false,
    this.isPaused = false,
    this.totalTiles = 0,
    this.currentTile = 0,
    this.successCount = 0,
    this.cachedCount = 0,
    this.errorCount = 0,
  });

  double get progress => totalTiles > 0 ? currentTile / totalTiles : 0.0;

  MapPrefetchProgress copyWith({
    bool? isPrefetching,
    bool? isPaused,
    int? totalTiles,
    int? currentTile,
    int? successCount,
    int? cachedCount,
    int? errorCount,
  }) {
    return MapPrefetchProgress(
      isPrefetching: isPrefetching ?? this.isPrefetching,
      isPaused: isPaused ?? this.isPaused,
      totalTiles: totalTiles ?? this.totalTiles,
      currentTile: currentTile ?? this.currentTile,
      successCount: successCount ?? this.successCount,
      cachedCount: cachedCount ?? this.cachedCount,
      errorCount: errorCount ?? this.errorCount,
    );
  }
}

class MapPrefetchNotifier extends Notifier<MapPrefetchProgress> {
  @override
  MapPrefetchProgress build() {
    return const MapPrefetchProgress();
  }

  void startPrefetch(int total) {
    state = MapPrefetchProgress(
      isPrefetching: true,
      isPaused: false,
      totalTiles: total,
    );
  }

  void updateProgress({
    required int current,
    required int success,
    required int cached,
    required int error,
  }) {
    state = state.copyWith(
      currentTile: current,
      successCount: success,
      cachedCount: cached,
      errorCount: error,
    );
  }

  void pausePrefetch() {
    state = state.copyWith(isPaused: true);
  }

  void resumePrefetch() {
    state = state.copyWith(isPaused: false);
  }

  void finishPrefetch() {
    state = state.copyWith(isPrefetching: false, isPaused: false);
  }
}

final mapPrefetchProvider = NotifierProvider<MapPrefetchNotifier, MapPrefetchProgress>(() {
  return MapPrefetchNotifier();
});
