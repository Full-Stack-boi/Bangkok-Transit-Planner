import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/map/map_screen.dart';
import '../../features/map/widgets/map_search_overlay.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/utility/utility_screen.dart';
import 'route_constants.dart';

List<StatefulShellBranch> get shellBranches => [
  StatefulShellBranch(
    routes: [
      GoRoute(
        name: 'utility',
        path: AppRoute.utility,
        pageBuilder: (_, state) =>
            const NoTransitionPage(child: UtilityScreen()),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        name: 'map',
        path: AppRoute.map,
        pageBuilder: (_, state) => const NoTransitionPage(child: MapScreen()),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        name: 'favorites',
        path: AppRoute.favorites,
        pageBuilder: (_, state) =>
            const NoTransitionPage(child: FavoritesScreen()),
      ),
    ],
  ),
  StatefulShellBranch(
    routes: [
      GoRoute(
        name: 'settings',
        path: AppRoute.settings,
        pageBuilder: (_, state) =>
            const NoTransitionPage(child: SettingsScreen()),
      ),
    ],
  ),
];

/// Top-level routes (outside the shell — full-screen push).
List<RouteBase> get topLevelRoutes => [
  // ── Auth ──
  GoRoute(
    name: 'login',
    path: AppRoute.login,
    builder: (_, _) => const LoginScreen(),
  ),
  GoRoute(
    name: 'register',
    path: AppRoute.register,
    builder: (_, _) => const RegisterScreen(),
  ),

  // ── Map Search Overlay (custom fade transition) ──
  GoRoute(
    name: 'mapSearch',
    path: AppRoute.mapSearch,
    pageBuilder: (context, state) => CustomTransitionPage(
      key: state.pageKey,
      child: MapSearchOverlay(
        focusDestination:
            state.uri.queryParameters[AppRoute.qFocusDest] == 'true',
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  ),
];
