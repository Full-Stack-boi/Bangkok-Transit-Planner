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

  const Landmark({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.nearestStationId,
    required this.walkingMinutes,
    required this.lat,
    required this.lng,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'] as String,
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      nearestStationId: json['nearest_station_id'] as String,
      walkingMinutes: (json['walking_minutes'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
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
      };
}
