import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'location_providers.dart';

export 'auth_providers.dart';
export 'location_providers.dart';

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

  // Instantiate authNotifierProvider on startup so it listens to auth state events immediately
  ref.read(authNotifierProvider);

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

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('theme_mode');
      if (themeStr == 'light') {
        state = ThemeMode.light;
      } else if (themeStr == 'dark') {
        state = ThemeMode.dark;
      } else if (themeStr == 'system') {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('th') {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('language_code') ?? 'th';
      state = lang;
    } catch (_) {}
  }

  Future<void> setLocale(String langCode) async {
    state = langCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', langCode);
    } catch (_) {}
  }
}

final translationsProvider = Provider<AppLocalizations>((ref) {
  final lang = ref.watch(localeProvider);
  return AppLocalizations(lang);
});
