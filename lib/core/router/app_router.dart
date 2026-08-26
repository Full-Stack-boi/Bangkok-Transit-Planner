import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/home/home_shell.dart';
import 'error_screen.dart';
import 'route_constants.dart';
import 'route_observer.dart';
import 'route_registry.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoute.map,
    debugLogDiagnostics: kDebugMode,
    observers: [AppRouteObserver()],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShell(navigationShell: navigationShell);
        },
        branches: shellBranches,
      ),
      ...topLevelRoutes,
    ],
  );
}
