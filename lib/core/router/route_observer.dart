import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logTransition('PUSH', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logTransition('POP', previousRoute, route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logTransition('REPLACE', newRoute, oldRoute);
  }

  void _logTransition(String type, Route<dynamic>? to, Route<dynamic>? from) {
    if (!kDebugMode) return;

    final fromName = _getRouteDisplayName(from);
    final toName = _getRouteDisplayName(to);

    debugPrint('[$type] $fromName → $toName');
  }

  String _getRouteDisplayName(Route<dynamic>? route) {
    if (route == null) return 'none';

    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final typeStr = route.runtimeType.toString();
    if (typeStr.contains('ModalBottomSheetRoute')) {
      return 'BottomSheet';
    }
    if (typeStr.contains('DialogRoute')) {
      return 'Dialog';
    }

    return typeStr.replaceAll(RegExp(r'<[^>]*>'), '');
  }
}
