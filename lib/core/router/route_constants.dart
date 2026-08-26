abstract final class AppRoute {
  // ── Shell tabs ──
  static const utility = '/utility';
  static const map = '/'; // default tab (index 1)
  static const favorites = '/favorites';
  static const settings = '/settings';

  // ── Auth ──
  static const login = '/login';
  static const register = '/register';

  // ── Map sub-routes ──
  static const mapSearch = '/map/search';

  // ── Query parameter keys ──
  static const qFocusDest = 'focusDest';
}
