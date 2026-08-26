import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';

class BkkTransitApp extends ConsumerWidget {
  const BkkTransitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize transit data
    ref.watch(transitInitProvider);

    final themeMode = ref.watch(themeModeProvider);
    final localeCode = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      key: ValueKey('app_$localeCode'),
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
      supportedLocales: const [Locale('th'), Locale('en')],
      routerConfig: router,
    );
  }
}
