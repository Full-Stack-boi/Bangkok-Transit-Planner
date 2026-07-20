import 'package:freezed_annotation/freezed_annotation.dart';

part 'station_exit.freezed.dart';
part 'station_exit.g.dart';

/// Represents a physical entrance/exit of a transit station
@freezed
abstract class StationExit with _$StationExit {
  const factory StationExit({
    required String id,
    @JsonKey(name: 'station_id') required String stationId,
    @JsonKey(name: 'exit_code') required String exitCode,
    @JsonKey(name: 'name_th') required String nameTh,
    @JsonKey(name: 'name_en') required String nameEn,
    required double lat,
    required double lng,
  }) = _StationExit;

  factory StationExit.fromJson(Map<String, dynamic> json) =>
      _$StationExitFromJson(json);
}
