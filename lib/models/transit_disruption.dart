import 'package:flutter/foundation.dart';

enum DisruptionSeverity { minorDelay, partialClosure, fullClosure }

@immutable
class TransitDisruption {
  final String id;
  final String lineId;
  final DisruptionSeverity severity;
  final List<String> affectedStationIds;
  final List<String> affectedSegmentIds;
  final String titleTh;
  final String titleEn;
  final String descriptionTh;
  final String descriptionEn;
  final int? estimatedDelayMinutes;
  final String? alternativeAdviceTh;
  final String? alternativeAdviceEn;
  final DateTime reportedAt;

  const TransitDisruption({
    required this.id,
    required this.lineId,
    required this.severity,
    required this.affectedStationIds,
    required this.affectedSegmentIds,
    required this.titleTh,
    required this.titleEn,
    required this.descriptionTh,
    required this.descriptionEn,
    this.estimatedDelayMinutes,
    this.alternativeAdviceTh,
    this.alternativeAdviceEn,
    required this.reportedAt,
  });

  bool get isFullClosure => severity == DisruptionSeverity.fullClosure;
  bool get isPartialClosure => severity == DisruptionSeverity.partialClosure;
  bool get isMinorDelay => severity == DisruptionSeverity.minorDelay;
}
