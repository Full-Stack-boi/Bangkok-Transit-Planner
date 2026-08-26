import 'package:freezed_annotation/freezed_annotation.dart';

part 'line.freezed.dart';
part 'line.g.dart';

@freezed
abstract class TransitLine with _$TransitLine {
  const TransitLine._();

  const factory TransitLine({
    required String id,
    @JsonKey(name: 'name_th') required String nameTh,
    @JsonKey(name: 'name_en') required String nameEn,
    required String operator,
    @JsonKey(name: 'color_hex') required String colorHex,
    @JsonKey(name: 'station_ids') required List<String> stationIds,
    @JsonKey(name: 'bound_0_label') required String bound0Label,
    @JsonKey(name: 'bound_1_label') required String bound1Label,
    @Default(false) @JsonKey(name: 'is_loop') bool isLoop,
    @JsonKey(name: 'peak_interval_min') required int peakIntervalMin,
    @JsonKey(name: 'off_peak_interval_min') required int offPeakIntervalMin,
  }) = _TransitLine;

  factory TransitLine.fromJson(Map<String, dynamic> json) =>
      _$TransitLineFromJson(json);

  /// Get the direction label for a given bound index
  String getDirectionLabel(int bound) {
    return bound == 0 ? bound0Label : bound1Label;
  }

  /// Get station index in the line (-1 if not found)
  int stationIndex(String stationId) {
    return stationIds.indexOf(stationId);
  }

  /// Determine which bound (0 or 1) to take from origin to destination
  /// For non-loop lines: bound 0 = towards first station, bound 1 = towards last station
  int getBound(String fromStationId, String toStationId) {
    final fromIdx = stationIndex(fromStationId);
    final toIdx = stationIndex(toStationId);
    if (fromIdx < 0 || toIdx < 0) return 0;
    return toIdx > fromIdx ? 1 : 0;
  }

  String displayName({bool isEnglish = false}) {
    return isEnglish ? nameEn : nameTh;
  }
}
