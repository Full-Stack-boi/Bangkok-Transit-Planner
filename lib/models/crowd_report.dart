/// Crowd report from a user (active report)
class CrowdReport {
  final String id;
  final String stationId;
  final String userId;
  final int level;         // 1-5
  final DateTime reportedAt;
  final String? direction;

  const CrowdReport({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.level,
    required this.reportedAt,
    this.direction,
  });

  factory CrowdReport.fromJson(Map<String, dynamic> json) {
    return CrowdReport(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      userId: json['user_id'] as String,
      level: json['level'] as int,
      reportedAt: DateTime.parse(json['reported_at'] as String),
      direction: json['direction'] as String?,
    );
  }
}

/// Passive GPS presence detection
class CrowdPresence {
  final String id;
  final String stationId;
  final String userId;
  final DateTime detectedAt;
  final double? accuracyMeters;

  const CrowdPresence({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.detectedAt,
    this.accuracyMeters,
  });

  factory CrowdPresence.fromJson(Map<String, dynamic> json) {
    return CrowdPresence(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      userId: json['user_id'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
    );
  }
}

/// Aggregated crowd level for a station
enum CrowdLevel {
  low,      // 🟢 โล่ง
  medium,   // 🟡 ปานกลาง
  high,     // 🔴 แน่นมาก
  unknown,  // ไม่มีข้อมูล
}

class StationCrowdInfo {
  final String stationId;
  final CrowdLevel level;
  final int presenceCount;      // number of users detected nearby
  final int activeReportCount;  // number of manual reports
  final double? averageReportLevel;
  final DateTime updatedAt;

  const StationCrowdInfo({
    required this.stationId,
    required this.level,
    this.presenceCount = 0,
    this.activeReportCount = 0,
    this.averageReportLevel,
    required this.updatedAt,
  });

  String get levelEmoji {
    switch (level) {
      case CrowdLevel.low:
        return '🟢';
      case CrowdLevel.medium:
        return '🟡';
      case CrowdLevel.high:
        return '🔴';
      case CrowdLevel.unknown:
        return '⚪';
    }
  }

  String get levelTextTh {
    switch (level) {
      case CrowdLevel.low:
        return 'โล่ง';
      case CrowdLevel.medium:
        return 'ปานกลาง';
      case CrowdLevel.high:
        return 'แน่นมาก';
      case CrowdLevel.unknown:
        return 'ไม่มีข้อมูล';
    }
  }

  String get levelTextEn {
    switch (level) {
      case CrowdLevel.low:
        return 'Not Crowded';
      case CrowdLevel.medium:
        return 'Moderate';
      case CrowdLevel.high:
        return 'Very Crowded';
      case CrowdLevel.unknown:
        return 'No Data';
    }
  }
}
