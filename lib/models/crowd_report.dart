import 'package:freezed_annotation/freezed_annotation.dart';

part 'crowd_report.freezed.dart';
part 'crowd_report.g.dart';

/// Crowd report from a user (active report)
@freezed
abstract class CrowdReport with _$CrowdReport {
  const factory CrowdReport({
    required String id,
    @JsonKey(name: 'station_id') required String stationId,
    @JsonKey(name: 'user_id') required String userId,
    required int level,         // 1-5
    @JsonKey(name: 'reported_at') required DateTime reportedAt,
    String? direction,
  }) = _CrowdReport;

  factory CrowdReport.fromJson(Map<String, dynamic> json) => _$CrowdReportFromJson(json);
}

/// Passive GPS presence detection
@freezed
abstract class CrowdPresence with _$CrowdPresence {
  const factory CrowdPresence({
    required String id,
    @JsonKey(name: 'station_id') required String stationId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'detected_at') required DateTime detectedAt,
    @JsonKey(name: 'accuracy_meters') double? accuracyMeters,
  }) = _CrowdPresence;

  factory CrowdPresence.fromJson(Map<String, dynamic> json) => _$CrowdPresenceFromJson(json);
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
