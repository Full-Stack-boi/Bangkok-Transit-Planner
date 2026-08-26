library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String kAppName = 'BKK Transit Planner';
  static const String kAppVersion = '1.0.0';

  // SharedPreferences Keys
  static const String kMapPrefetchKey = 'map_prefetch_completed_v6_greater';

  // Map / Layout
  static const int kMapTileCount = 6914;
  static const double kMaxGridWidth = 800.0;

  // Navigation
  static const int kMapTabIndex = 1;
  static const double kWideLayoutBreakpoint = 900.0;
  static const double kNavBarHeight = 66.0;
  static const Duration kNavAnimationDuration = Duration(milliseconds: 300);

  // GPS / Proximity
  static const String kGpsCurrentId = 'GPS_CURRENT';
  static const double kKmThresholdMeters = 1000.0;
  static const double kCoordEpsilon = 0.0001;
  static const int kProactiveReportNotifId = 999;
  static const String kNotifPayloadReportPrefix = 'prompt_report:';
  static const Duration kCardSelectionDelay = Duration(milliseconds: 150);

  // Favorites / Routes
  static const String kDefaultRouteName = 'เส้นทางไม่มีชื่อ';

  // Bottom Sheet
  static const double kSheetInitialSize = 0.7;
  static const double kSheetMinSize = 0.4;
  static const double kSheetMaxSize = 0.95;
  static const double kSheetHandleWidth = 40.0;
  static const double kSheetHandleHeight = 4.0;
  static const double kSheetCornerRadius = 20.0;
}

class MapConstants {
  MapConstants._();

  static const double zoomChangeThreshold = 0.15;
  static const double namtangMinZoom = 15.0;
  static const double markerScaleBase = 0.75;
  static const double markerScaleStep = 0.16;
}
