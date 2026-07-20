import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/providers.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/app_theme.dart';

const double _kRailWidth = 100.0;
const double _kRailHeight = 350.0;
const double _kRailRadius = 28.0;
const double _kRailOpacity = 0.75;
const double _kRailIconSize = 28.0;
const double _kRailFontSize = 13.0;
const double _kRailPadding = 16.0;

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final locale = ref.watch(localeProvider);
    final t = AppLocalizations(locale);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double verticalMargin = (screenHeight - _kRailHeight) / 2;

    final activeColors = [
      theme.colorScheme.primary,
      theme.appColors.routeColor ?? const Color(0xFF818CF8),
      theme.appColors.favoriteColor ?? const Color(0xFFF472B6),
      theme.appColors.timeColor ?? const Color(0xFFF59E0B),
    ];
    final activeColor = activeColors[currentIndex];
    final isFloating = currentIndex == 1;

    final BorderRadius borderRadius = isFloating
        ? BorderRadius.circular(_kRailRadius)
        : BorderRadius.zero;

    final BoxBorder border = Border.all(
      color: isFloating
          ? theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08)
          : Colors.transparent,
    );

    final List<BoxShadow>? boxShadow = isFloating
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(4, 4),
            ),
          ]
        : null;

    final EdgeInsets margin = isFloating
        ? EdgeInsets.fromLTRB(
            _kRailPadding,
            verticalMargin > 0 ? verticalMargin : 0.0,
            0,
            verticalMargin > 0 ? verticalMargin : 0.0,
          )
        : EdgeInsets.zero;

    return Theme(
      data: theme.copyWith(
        navigationRailTheme: theme.navigationRailTheme.copyWith(
          backgroundColor: Colors.transparent,
          indicatorColor: activeColor.withValues(alpha: 0.15),
          selectedIconTheme: IconThemeData(
            color: activeColor,
            size: _kRailIconSize,
          ),
          selectedLabelTextStyle: GoogleFonts.outfit(
            color: activeColor,
            fontSize: _kRailFontSize,
            fontWeight: FontWeight.w600,
          ),
          unselectedIconTheme: const IconThemeData(
            color: Color(0xFF64748B),
            size: _kRailIconSize,
          ),
          unselectedLabelTextStyle: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: _kRailFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: SizedBox(
        width: _kRailWidth + _kRailPadding + 8.0,
        height: screenHeight,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: _kRailWidth,
              height: isFloating ? _kRailHeight : screenHeight,
              margin: margin,
              decoration: BoxDecoration(
                color: isFloating
                    ? theme.colorScheme.surface.withValues(alpha: _kRailOpacity)
                    : theme.colorScheme.surface,
                borderRadius: borderRadius,
                border: border,
                boxShadow: boxShadow,
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left: isFloating ? _kRailPadding : 0.0,
              top: isFloating ? verticalMargin : 0.0,
              width: _kRailWidth,
              height: isFloating ? _kRailHeight : screenHeight,
              child: NavigationRail(
                groupAlignment: 0.0,
                backgroundColor: Colors.transparent,
                selectedIndex: currentIndex,
                onDestinationSelected: (index) {
                  ref.read(homeTabIndexProvider.notifier).setTab(index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    selectedIcon: Icon(
                      Icons.dashboard_customize,
                      color: activeColors[0],
                    ),
                    label: Text(t.navigation.utilityTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: Icon(
                      Icons.map_rounded,
                      color: activeColors[1],
                    ),
                    label: Text(t.navigation.mapTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.favorite_outline_rounded),
                    selectedIcon: Icon(
                      Icons.favorite_rounded,
                      color: activeColors[2],
                    ),
                    label: Text(t.navigation.favoritesTitle),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: Icon(
                      Icons.settings_rounded,
                      color: activeColors[3],
                    ),
                    label: Text(t.navigation.settingsTitle),
                  ),
                ],
              ),
            ),
            Positioned(
              left: _kRailWidth - 1.0,
              top: 0,
              bottom: 0,
              width: 1.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isFloating ? 0.0 : 1.0,
                child: ColoredBox(
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
