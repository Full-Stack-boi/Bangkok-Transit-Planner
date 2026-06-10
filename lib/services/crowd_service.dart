import '../models/crowd_report.dart';

/// Service for calculating station crowd levels and passenger counts
class CrowdService {
  /// Check if a station is a major interchange hub
  bool _isInterchangeHub(String stationId) {
    final majorHubs = {
      'BTS_CEN',       // Siam (Sukhumvit)
      'BTS_CEN_SILOM', // Siam (Silom)
      'BTS_E4',        // Asok
      'MRT_BL22',      // Sukhumvit
      'MRT_BL10',      // Tao Poon
      'MRT_PP16',      // Tao Poon
      'MRT_BL01',      // Tha Phra
      'MRT_BL33',      // Tha Phra
      'BTS_N2',        // Phaya Thai
      'ARL_A8',        // Phaya Thai
    };
    return majorHubs.contains(stationId);
  }

  /// Get crowd information for a station based on the current time and station characteristics
  StationCrowdInfo getCrowdInfo(String stationId, {DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final hour = now.hour;
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    CrowdLevel level;
    int presenceCount;
    int activeReportCount;
    double averageReportLevel;

    // Determine if it is peak hour (07:00 - 09:00, 17:00 - 19:00 on weekdays)
    final isPeakHour = !isWeekend && ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19));

    // Semi-deterministic random variation based on stationId and current hour
    final hash = (stationId.hashCode + hour) % 10;

    if (isPeakHour) {
      level = CrowdLevel.high;
      presenceCount = _isInterchangeHub(stationId) ? 80 + hash * 5 : 45 + hash * 3;
      activeReportCount = 3 + (hash % 4);
      averageReportLevel = 4.0 + (hash % 10) / 10.0; // 4.0 - 4.9
    } else {
      if (isWeekend) {
        // Weekends have lower crowd levels overall, except for shopping hubs
        final isShoppingHub = stationId == 'BTS_CEN' || stationId == 'BTS_CEN_SILOM' || stationId == 'BTS_E4' || stationId == 'MRT_BL22';
        if (isShoppingHub && hour >= 11 && hour <= 20) {
          level = CrowdLevel.medium;
          presenceCount = 30 + hash * 2;
          activeReportCount = 1 + (hash % 3);
          averageReportLevel = 3.0 + (hash % 5) / 10.0;
        } else {
          level = hash < 3 ? CrowdLevel.medium : CrowdLevel.low;
          presenceCount = level == CrowdLevel.medium ? 12 + hash : 2 + (hash % 4);
          activeReportCount = level == CrowdLevel.medium ? 1 : 0;
          averageReportLevel = level == CrowdLevel.medium ? 2.5 : 1.5;
        }
      } else {
        // Weekdays non-peak
        if (_isInterchangeHub(stationId)) {
          level = CrowdLevel.medium;
          presenceCount = 25 + hash * 3;
          activeReportCount = 1 + (hash % 2);
          averageReportLevel = 3.0 + (hash % 5) / 10.0;
        } else {
          // Normal station off-peak
          if (hour >= 22 || hour < 6) {
            level = CrowdLevel.low;
            presenceCount = hash % 3;
            activeReportCount = 0;
            averageReportLevel = 1.0;
          } else {
            // General daytime
            level = hash < 4 ? CrowdLevel.medium : CrowdLevel.low;
            presenceCount = level == CrowdLevel.medium ? 10 + hash : 2 + (hash % 5);
            activeReportCount = level == CrowdLevel.medium ? 1 : 0;
            averageReportLevel = level == CrowdLevel.medium ? 2.8 : 1.8;
          }
        }
      }
    }

    return StationCrowdInfo(
      stationId: stationId,
      level: level,
      presenceCount: presenceCount,
      activeReportCount: activeReportCount,
      averageReportLevel: activeReportCount > 0 ? averageReportLevel : null,
      updatedAt: now,
    );
  }
}
