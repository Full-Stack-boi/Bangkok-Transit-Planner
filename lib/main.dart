import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
