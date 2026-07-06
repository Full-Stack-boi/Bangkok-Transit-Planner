import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'searchable_item.dart';

part 'landmark.freezed.dart';
part 'landmark.g.dart';

class NullableLatLngListConverter implements JsonConverter<List<LatLng>?, List<dynamic>?> {
  const NullableLatLngListConverter();

  @override
  List<LatLng>? fromJson(List<dynamic>? json) {
    if (json == null) return null;
    return json
        .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();
  }

  @override
  List<dynamic>? toJson(List<LatLng>? object) {
    if (object == null) return null;
    return object.map((p) => [p.latitude, p.longitude]).toList();
  }
}

class LatLngListConverter implements JsonConverter<List<LatLng>, List<dynamic>> {
  const LatLngListConverter();

  @override
  List<LatLng> fromJson(List<dynamic> json) {
    return json
        .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
        .toList();
  }

  @override
  List<dynamic> toJson(List<LatLng> object) {
    return object.map((p) => [p.latitude, p.longitude]).toList();
  }
}

class AlternativeWalksConverter implements JsonConverter<Map<String, StationWalk>?, Map<String, dynamic>?> {
  const AlternativeWalksConverter();

  @override
  Map<String, StationWalk>? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return json.map((k, v) {
      final valMap = Map<String, dynamic>.from(v as Map);
      valMap['instructions_th'] = valMap['instructions_th'] ?? valMap['instructions'];
      return MapEntry(k, StationWalk.fromJson(valMap));
    });
  }

  @override
  Map<String, dynamic>? toJson(Map<String, StationWalk>? object) {
    if (object == null) return null;
    return object.map((k, v) => MapEntry(k, v.toJson()));
  }
}

/// Landmark model representing a popular attraction/place near transit stations
@freezed
abstract class Landmark extends SearchableItem with _$Landmark {
  const Landmark._(); // Allows custom methods/getters

  const factory Landmark({
    required String id,
    @JsonKey(name: 'name_th') required String nameTh,
    @JsonKey(name: 'name_en') required String nameEn,
    @JsonKey(name: 'nearest_station_id') String? nearestStationId,
    @JsonKey(name: 'walking_minutes') double? walkingMinutes,
    required double lat,
    required double lng,
    @NullableLatLngListConverter() @JsonKey(name: 'walking_path') List<LatLng>? walkingPath,
    @JsonKey(name: 'exit_code') String? exitCode,
    @AlternativeWalksConverter() @JsonKey(name: 'alternative_walks') Map<String, StationWalk>? alternativeWalks,
    @JsonKey(name: 'entrance_lat') double? entranceLat,
    @JsonKey(name: 'entrance_lng') double? entranceLng,
  }) = _Landmark;

  @override
  double get routeLat => entranceLat ?? lat;
  @override
  double get routeLng => entranceLng ?? lng;

  factory Landmark.fromJson(Map<String, dynamic> json) => _$LandmarkFromJson(json);
}

/// Model representing a walking route from a specific station to a landmark
@freezed
abstract class StationWalk with _$StationWalk {
  const factory StationWalk({
    @LatLngListConverter() @JsonKey(name: 'walking_path') required List<LatLng> walkingPath,
    @JsonKey(name: 'exit_code') required String exitCode,
    @JsonKey(name: 'walking_minutes') required double walkingMinutes,
    @JsonKey(name: 'instructions_th') String? instructionsTh,
    @JsonKey(name: 'instructions_en') String? instructionsEn,
  }) = _StationWalk;

  factory StationWalk.fromJson(Map<String, dynamic> json) => _$StationWalkFromJson(json);
}
