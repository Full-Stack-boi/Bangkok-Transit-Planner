/// App constants
library;

/// General app-level constants
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // App Info
  static const String kAppName = 'BKK Transit Planner';
  static const String kAppVersion = '1.0.0';

  // SharedPreferences Keys
  /// Key used to track if offline map prefetch has been completed
  static const String kMapPrefetchKey = 'map_prefetch_completed_v6_greater';

  // Map / Prefetch
  /// Total number of tiles for Bangkok offline map package
  static const int kMapTileCount = 6914;

  /// Maximum content width for utility/settings layout on wide screens
  static const double kMaxGridWidth = 800.0;

  // Navigation
  /// Tab index for the Map screen in the bottom navigation bar
  static const int kMapTabIndex = 1;

  /// Breakpoint (px) above which the navigation rail is shown instead of bottom bar
  static const double kWideLayoutBreakpoint = 900.0;

  /// Height of the bottom NavigationBar widget
  static const double kNavBarHeight = 66.0;

  /// Animation duration used consistently across nav rail / nav bar transitions
  static const Duration kNavAnimationDuration = Duration(milliseconds: 300);

  // GPS / Proximity
  /// Synthetic station ID used for the user's current GPS location
  static const String kGpsCurrentId = 'GPS_CURRENT';

  /// Threshold in metres above which distance is shown as km
  static const double kKmThresholdMeters = 1000.0;

  /// Epsilon for floating-point coordinate comparison
  static const double kCoordEpsilon = 0.0001;

  /// Notification ID used for proactive crowd-report prompt
  static const int kProactiveReportNotifId = 999;

  /// Prefix for notification payload that triggers a crowd report screen
  static const String kNotifPayloadReportPrefix = 'prompt_report:';

  /// Short delay after card selection before navigation (for visual feedback)
  static const Duration kCardSelectionDelay = Duration(milliseconds: 150);

  // Favorites / Routes
  /// Default route name used when saving a route without a custom name
  static const String kDefaultRouteName =
      '\u0e40\u0e2a\u0e49\u0e19\u0e17\u0e32\u0e07\u0e44\u0e21\u0e48\u0e21\u0e35\u0e0a\u0e37\u0e48\u0e2d'; // 'เส้นทางไม่มีชื่อ'

  // Bottom Sheet
  static const double kSheetInitialSize = 0.7;
  static const double kSheetMinSize = 0.4;
  static const double kSheetMaxSize = 0.95;
  static const double kSheetHandleWidth = 40.0;
  static const double kSheetHandleHeight = 4.0;
  static const double kSheetCornerRadius = 20.0;
}

/// Map constants
class MapConstants {
  MapConstants._();

  /// Minimum change in zoom level that triggers a marker rebuild
  static const double zoomChangeThreshold = 0.15;

  /// Minimum zoom level at which Namtang stops (bus/boat) markers appear
  static const double namtangMinZoom = 15.0;

  /// Base scale factor for station markers at default zoom
  static const double markerScaleBase = 0.75;

  /// Per-zoom-level scale increment for station markers
  static const double markerScaleStep = 0.16;
}
