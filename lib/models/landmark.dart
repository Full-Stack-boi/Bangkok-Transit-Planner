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
      };
}

/// Model representing a walking route from a specific station to a landmark
class StationWalk {
  final List<LatLng> walkingPath;
  final String exitCode;
  final double walkingMinutes;

  const StationWalk({
    required this.walkingPath,
    required this.exitCode,
    required this.walkingMinutes,
  });

  factory StationWalk.fromJson(Map<String, dynamic> json) {
    return StationWalk(
      walkingPath: (json['walking_path'] as List<dynamic>)
          .map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList(),
      exitCode: json['exit_code'] as String,
      walkingMinutes: (json['walking_minutes'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'walking_path': walkingPath.map((p) => [p.latitude, p.longitude]).toList(),
        'exit_code': exitCode,
        'walking_minutes': walkingMinutes,
      };
}


