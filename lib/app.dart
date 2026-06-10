import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'features/home/home_screen.dart';

class BkkTransitApp extends ConsumerWidget {
  const BkkTransitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize transit data
    ref.watch(transitInitProvider);

    return MaterialApp(
      title: 'BKK Transit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to dark mode
      home: const HomeScreen(),
    );
  }
}
