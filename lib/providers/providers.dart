import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants/translation_helper.dart';
import '../core/network/http_client_factory.dart';
import '../repositories/transit_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/crowd_repository.dart';
import '../services/fare_service.dart';
import '../services/schedule_service.dart';
import '../services/crowd_service.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/transit_news_service.dart';
import '../services/photon_search_service.dart';
import 'auth_providers.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

export 'auth_providers.dart';
export 'location_providers.dart';
export 'user_cards_provider.dart';
export 'disruption_provider.dart';
export '../models/transit_disruption.dart';

part 'providers.g.dart';

// Network Providers

@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = createHttpClient();
  ref.onDispose(() => client.close());
  return client;
}

// Repository Providers

@Riverpod(keepAlive: true)
TransitRepository transitRepository(Ref ref) {
  final client = ref.watch(httpClientProvider);
  return TransitRepository(client);
}

@Riverpod(keepAlive: true)
PhotonSearchService photonSearchService(Ref ref) {
  final client = ref.watch(httpClientProvider);
  final repo = ref.watch(transitRepositoryProvider);
  return PhotonSearchService(repo, client);
}

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return FavoritesRepository(supabase);
}

@Riverpod(keepAlive: true)
CrowdRepository crowdRepository(Ref ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return CrowdRepository(supabase);
}

// Service Providers

@Riverpod(keepAlive: true)
FareService fareService(Ref ref) {
  return FareService();
}

@Riverpod(keepAlive: true)
ScheduleService scheduleService(Ref ref) {
  return ScheduleService();
}

@Riverpod(keepAlive: true)
CrowdService crowdService(Ref ref) {
  return CrowdService();
}

@Riverpod(keepAlive: true)
SupabaseService supabaseService(Ref ref) {
  return SupabaseService();
}

@Riverpod(keepAlive: true)
LocationService locationService(Ref ref) {
  return LocationService(ref);
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService();
}

// Initialization Provider

@riverpod
Future<void> transitInit(Ref ref) async {
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
      // ignore: avoid_print
      AppLogger.error('Favorites startup sync failed: $e', error: e);
    }
  }

  final repo = ref.read(transitRepositoryProvider);
  await repo.initialize();
}

// UI Providers

SharedPreferences? testSharedPreferencesInstance;

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  if (testSharedPreferencesInstance != null) {
    return testSharedPreferencesInstance!;
  }
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope overrides',
  );
}

@riverpod
class HomeTabIndex extends _$HomeTabIndex {
  @override
  int build() => 1;

  void setTab(int index) {
    state = index;
  }
}

@riverpod
class AppThemeMode extends _$AppThemeMode {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeStr = prefs.getString('theme_mode');
    if (themeStr == 'light') return ThemeMode.light;
    if (themeStr == 'dark') return ThemeMode.dark;
    if (themeStr == 'system') return ThemeMode.system;
    return ThemeMode.system; // Default theme
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }
}

/// Backwards compatibility alias for themeModeProvider
final themeModeProvider = appThemeModeProvider;

@riverpod
class AppLocale extends _$AppLocale {
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

/// Backwards compatibility alias for localeProvider
final localeProvider = appLocaleProvider;

@riverpod
AppLocalizations translations(Ref ref) {
  final lang = ref.watch(localeProvider);
  return AppLocalizations(lang);
}

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

@riverpod
class MapPrefetch extends _$MapPrefetch {
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

// Utility Screen Future Providers

@riverpod
class ActiveNotificationPayload extends _$ActiveNotificationPayload {
  @override
  String? build() => null;

  void setPayload(String? val) {
    state = val;
  }
}

@riverpod
Future<List<TransitNewsArticle>> drtNews(Ref ref) async {
  final newsService = ref.watch(transitNewsServiceProvider);
  return newsService.fetchDrtNews();
}

@riverpod
Future<List<TransitLineStatus>> transitLineStatus(Ref ref) async {
  // 1. Fetch official announcements from DRT to see if any contain delay alerts
  final List<TransitNewsArticle> disruptions = [];
  try {
    final drtArticles = await ref.watch(drtNewsProvider.future);
    for (final art in drtArticles) {
      final text = '${art.titleTh} ${art.bodyTh}'.toLowerCase();
      if (text.contains('ขัดข้อง') ||
          text.contains('ล่าช้า') ||
          text.contains('ปิดสถานี') ||
          text.contains('ปรับปรุง')) {
        disruptions.add(art);
      }
    }
  } catch (e) {
    // ignore: avoid_print
    AppLogger.error('Failed to read DRT news for line status: $e', error: e);
  }

  // 2. Fetch active crowd reports from Supabase if initialized
  final supabase = ref.watch(supabaseServiceProvider);
  Map<String, double> stationCrowdReports = {};

  if (supabase.isInitialized) {
    try {
      final client = supabase.client;
      // Get reports from the last 30 minutes
      final cutOffTime = DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 30))
          .toIso8601String();
      final response = await client
          ?.from('crowd_reports')
          .select('station_id, level')
          .gt('reported_at', cutOffTime);

      if (response != null) {
        final reportsList = response as List<dynamic>;
        // Group by station and get the average level
        final Map<String, List<int>> stationLevels = {};
        for (final report in reportsList) {
          final sId = report['station_id'] as String;
          final level = report['level'] as int;
          stationLevels.putIfAbsent(sId, () => []).add(level);
        }

        stationLevels.forEach((sId, levels) {
          final avg = levels.reduce((a, b) => a + b) / levels.length;
          stationCrowdReports[sId] = avg;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      AppLogger.error(
        'Failed to load real-time crowd reports for line status: $e',
        error: e,
      );
    }
  }

  // 3. Define the list of standard transit lines to track
  final defaultLines = [
    {
      'id': 'BTS_SUKHUMVIT',
      'nameTh': 'สายสุขุมวิท',
      'nameEn': 'Sukhumvit Line',
    },
    {'id': 'BTS_SILOM', 'nameTh': 'สายสีลม', 'nameEn': 'Silom Line'},
    {'id': 'MRT_BLUE', 'nameTh': 'สายสีน้ำเงิน', 'nameEn': 'Blue Line'},
    {'id': 'MRT_PURPLE', 'nameTh': 'สายสีม่วง', 'nameEn': 'Purple Line'},
    {'id': 'MRT_YELLOW', 'nameTh': 'สายสีเหลือง', 'nameEn': 'Yellow Line'},
    {'id': 'MRT_PINK', 'nameTh': 'สายสีชมพู', 'nameEn': 'Pink Line'},
    {'id': 'ARL', 'nameTh': 'แอร์พอร์ตลิงก์', 'nameEn': 'Airport Rail Link'},
    {'id': 'SRT_RED_NORTH', 'nameTh': 'สายสีแดงเข้ม', 'nameEn': 'SRT Red Line'},
  ];

  final List<TransitLineStatus> statuses = [];

  for (final line in defaultLines) {
    final lineId = line['id']!;
    final nameTh = line['nameTh']!;
    final nameEn = line['nameEn']!;

    // Check if there is an official news alert about this line
    final matchingAlert = disruptions.firstWhere(
      (art) => art.lineId == lineId,
      orElse: () => TransitNewsArticle(
        id: '',
        titleTh: '',
        titleEn: '',
        bodyTh: '',
        bodyEn: '',
        date: DateTime.fromMillisecondsSinceEpoch(0),
        lineId: '',
      ),
    );

    if (matchingAlert.id.isNotEmpty) {
      // Official disruption confirmed
      statuses.add(
        TransitLineStatus(
          lineId: lineId,
          lineNameTh: nameTh,
          lineNameEn: nameEn,
          statusTh: 'ประกาศเหตุขัดข้องทางการ',
          statusEn: 'Official Disruption Alert',
          isNormal: false,
        ),
      );
      continue;
    }

    // Check if there are active user crowd reports for this line's stations
    bool hasHighCrowdReport = false;
    stationCrowdReports.forEach((sId, avgLevel) {
      final isBtsSukhumvit =
          lineId == 'BTS_SUKHUMVIT' &&
          sId.startsWith('BTS_') &&
          !sId.contains('SILOM') &&
          sId != 'BTS_CEN';
      final isBtsSilom =
          lineId == 'BTS_SILOM' &&
          (sId.startsWith('BTS_') && sId.contains('SILOM') || sId == 'BTS_CEN');
      final isMrtBlue = lineId == 'MRT_BLUE' && sId.startsWith('MRT_BL');
      final isMrtPurple = lineId == 'MRT_PURPLE' && sId.startsWith('MRT_PP');
      final isMrtYellow = lineId == 'MRT_YELLOW' && sId.startsWith('MRT_YL');
      final isMrtPink = lineId == 'MRT_PINK' && sId.startsWith('MRT_PK');
      final isArl = lineId == 'ARL' && sId.startsWith('ARL');
      final isSrt = lineId == 'SRT_RED_NORTH' && sId.startsWith('SRT');

      if ((isBtsSukhumvit ||
              isBtsSilom ||
              isMrtBlue ||
              isMrtPurple ||
              isMrtYellow ||
              isMrtPink ||
              isArl ||
              isSrt) &&
          avgLevel >= 4.0) {
        hasHighCrowdReport = true;
      }
    });

    if (hasHighCrowdReport) {
      // Community reported alert
      statuses.add(
        TransitLineStatus(
          lineId: lineId,
          lineNameTh: nameTh,
          lineNameEn: nameEn,
          statusTh: 'มีรายงานล่าช้าจากผู้ใช้ (รอยืนยัน)',
          statusEn: 'Commuter Reported Delay (Pending)',
          isNormal: false,
        ),
      );
    } else {
      // Normal operating status
      statuses.add(
        TransitLineStatus(
          lineId: lineId,
          lineNameTh: nameTh,
          lineNameEn: nameEn,
          statusTh: 'ปกติ',
          statusEn: 'Normal',
          isNormal: true,
        ),
      );
    }
  }

  return statuses;
}
