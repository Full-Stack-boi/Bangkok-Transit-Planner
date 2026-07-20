import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/providers.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/app_theme.dart';

class AppBottomNavigationBar extends ConsumerWidget {
  const AppBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations(locale);
    final theme = Theme.of(context);

    final activeColors = [
      theme.colorScheme.primary,
      theme.appColors.routeColor ?? const Color(0xFF818CF8),
      theme.appColors.favoriteColor ?? const Color(0xFFF472B6),
      theme.appColors.timeColor ?? const Color(0xFFF59E0B),
    ];
    final activeColor = activeColors[currentIndex];

    return Theme(
      data: theme.copyWith(
        navigationBarTheme: theme.navigationBarTheme.copyWith(
          indicatorColor: activeColor.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.outfit(
                color: activeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }
            return GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
      ),
      child: NavigationBar(
        height: 66.0,
        key: ValueKey('nav_bar_$locale'),
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(homeTabIndexProvider.notifier).setTab(index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(
              Icons.dashboard_customize,
              color: activeColors[0],
            ),
            label: t.navigation.utilityTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: activeColors[1]),
            label: t.navigation.mapTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded, color: activeColors[2]),
            label: t.navigation.favoritesTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: activeColors[3]),
            label: t.navigation.settingsTitle,
          ),
        ],
      ),
    );
  }
}
