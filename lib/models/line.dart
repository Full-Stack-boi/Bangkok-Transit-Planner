import 'package:freezed_annotation/freezed_annotation.dart';

part 'line.freezed.dart';
part 'line.g.dart';

/// Transit line model
@freezed
abstract class TransitLine with _$TransitLine {
  const TransitLine._(); // Allows custom methods/getters

  const factory TransitLine({
    required String id, // e.g. "BTS_SUKHUMVIT"
    @JsonKey(name: 'name_th') required String nameTh, // e.g. "สายสุขุมวิท"
    @JsonKey(name: 'name_en') required String nameEn, // e.g. "Sukhumvit Line"
    required String operator, // e.g. "BTS", "MRT", "ARL"
    @JsonKey(name: 'color_hex') required String colorHex, // e.g. "#7DC242"
    @JsonKey(name: 'station_ids')
    required List<String> stationIds, // Ordered station IDs along the line
    @JsonKey(name: 'bound_0_label')
    required String
    bound0Label, // Direction label for bound 0 (e.g. "ไปหมอชิต")
    @JsonKey(name: 'bound_1_label')
    required String bound1Label, // Direction label for bound 1 (e.g. "ไปเคหะฯ")
    @Default(false)
    @JsonKey(name: 'is_loop')
    bool isLoop, // True for MRT Blue Line (circular)
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
