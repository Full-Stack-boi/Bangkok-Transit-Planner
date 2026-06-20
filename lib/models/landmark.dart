import 'package:latlong2/latlong.dart';
import 'searchable_item.dart';

/// Landmark model representing a popular attraction/place near transit stations
class Landmark extends SearchableItem {
  @override
  final String id;
  @override
  final String nameTh;
  @override
  final String nameEn;
  @override
  final String nearestStationId;
  @override
  final double walkingMinutes;
  @override
  final double lat;
  @override
  final double lng;
  
  final List<LatLng>? walkingPath;
  final String? exitCode;
  final Map<String, StationWalk>? alternativeWalks;
  final double? entranceLat;
  final double? entranceLng;

  @override
  double get routeLat => entranceLat ?? lat;
  @override
  double get routeLng => entranceLng ?? lng;

  const Landmark({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.nearestStationId,
    required this.walkingMinutes,
    required this.lat,
    required this.lng,
    this.walkingPath,
    this.exitCode,
    this.alternativeWalks,
    this.entranceLat,
    this.entranceLng,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    final rawAlternative = json['alternative_walks'] as Map<String, dynamic>?;
    Map<String, StationWalk>? alternativeWalks;
    if (rawAlternative != null) {
      alternativeWalks = rawAlternative.map(
        (key, value) => MapEntry(key, StationWalk.fromJson(value as Map<String, dynamic>)),
      );
    }

    return Landmark(
      id: json['id'] as String,
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      nearestStationId: json['nearest_station_id'] as String,
      walkingMinutes: (json['walking_minutes'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      walkingPath: (json['walking_path'] as List<dynamic>?)
          ?.map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList(),
      exitCode: json['exit_code'] as String?,
      alternativeWalks: alternativeWalks,
      entranceLat: json['entrance_lat'] != null ? (json['entrance_lat'] as num).toDouble() : null,
      entranceLng: json['entrance_lng'] != null ? (json['entrance_lng'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_th': nameTh,
        'name_en': nameEn,
        'nearest_station_id': nearestStationId,
        'walking_minutes': walkingMinutes,
        'lat': lat,
        'lng': lng,
        'walking_path': walkingPath?.map((p) => [p.latitude, p.longitude]).toList(),
        'exit_code': exitCode,
        'alternative_walks': alternativeWalks?.map((k, v) => MapEntry(k, v.toJson())),
        'entrance_lat': entranceLat,
        'entrance_lng': entranceLng,
      };
}

/// Model representing a walking route from a specific station to a landmark
class StationWalk {
  final List<LatLng> walkingPath;
  final String exitCode;
  final double walkingMinutes;
  final String? instructionsTh;
  final String? instructionsEn;

  const StationWalk({
    required this.walkingPath,
    required this.exitCode,
    required this.walkingMinutes,
    this.instructionsTh,
    this.instructionsEn,
  });

  factory StationWalk.fromJson(Map<String, dynamic> json) {
    return StationWalk(
      walkingPath: (json['walking_path'] as List<dynamic>)
          .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList(),
      exitCode: json['exit_code'] as String,
      walkingMinutes: (json['walking_minutes'] as num).toDouble(),
      instructionsTh: json['instructions_th'] as String? ?? json['instructions'] as String?,
      instructionsEn: json['instructions_en'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'walking_path': walkingPath.map((p) => [p.latitude, p.longitude]).toList(),
        'exit_code': exitCode,
        'walking_minutes': walkingMinutes,
        'instructions_th': instructionsTh,
        'instructions_en': instructionsEn,
      };
}


