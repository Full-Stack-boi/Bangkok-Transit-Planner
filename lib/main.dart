import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/map/cached_tile_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    const ProviderScope(
      child: BkkTransitApp(),
    ),
  );
}
