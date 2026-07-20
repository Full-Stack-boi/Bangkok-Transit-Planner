import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'features/map/cached_tile_provider.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set default moderate limits for image cache (safe for most devices)
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      150 * 1024 * 1024; // 150 MB
  PaintingBinding.instance.imageCache.maximumSize = 1000; // 1000 images

  // Listen to OS memory pressure signals to clear and downgrade caches automatically
  WidgetsBinding.instance.addObserver(MemoryPressureObserver());

  // Disable runtime font fetching — rely on cached fonts only (offline safety)
  GoogleFonts.config.allowRuntimeFetching = false;

  // Pre-initialize SharedPreferences to avoid theme/locale flickering
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // Pre-initialize map tile cache path so it is synchronously available to TileProvider from frame 1
  try {
    await CachedTileProvider.getCachePath();
  } catch (e) {
    debugPrint('Failed to initialize map cache path or copy bundle: $e');
  }

  // Handle global asynchronous errors (e.g., Supabase offline token refresh warnings)
  // to prevent them from bubbling up as unhandled exceptions in the console/logs.
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    if (errorStr.contains('AuthRetryableFetchException') ||
        errorStr.contains('SocketException') ||
        errorStr.contains('ClientException') ||
        errorStr.contains('Failed host lookup')) {
      debugPrint('Background network exception handled gracefully: $error');
      return true; // Prevents crash reporting or unhandled logging
    }
    return false; // Let other critical exceptions bubble up
  };

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BkkTransitApp(),
    ),
  );
}

/// Listens to OS memory pressure warnings to release RAM and shrink cache bounds dynamically
class MemoryPressureObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    debugPrint(
      'LOW MEMORY WARNING: OS memory pressure detected. Downgrading caches.',
    );

    // Clear all caches in RAM
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    MapBundleManager.instance.clearCache();

    // Dynamically downgrade cache limits to save the app from being killed
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        40 * 1024 * 1024; // 40 MB
    PaintingBinding.instance.imageCache.maximumSize = 300; // 300 images
    MapBundleManager.instance.setMaxCacheLimit(16); // 16 tiles
  }
}
