import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'features/home/home_screen.dart';

class BkkTransitApp extends ConsumerWidget {
  const BkkTransitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize transit data
    ref.watch(transitInitProvider);

    final themeMode = ref.watch(themeModeProvider);
    final localeCode = ref.watch(localeProvider);

    return MaterialApp(
      title: 'BKK Transit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: Locale(localeCode),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th'),
        Locale('en'),
      ],
      // Use a ValueKey based on the locale code to force a clean redraw
      // of the entire main UI tree when the language changes. 
      // This is the most robust way to ensure that all state and 
      // event listeners (especially on Web) are correctly updated.
      home: HomeScreen(key: ValueKey('home_root_$localeCode')),
    );
  }
}
