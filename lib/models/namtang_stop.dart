import 'package:latlong2/latlong.dart';
import 'searchable_item.dart';

/// Model representing a stop or pier from the Namtang open dataset (Bus, Boat, BRT, Commuter Rail)
class NamtangStop extends SearchableItem {
  @override
  final String id;
  @override
  final String nameTh;
  @override
  final String nameEn;
  @override
  final double lat;
  @override
  final double lng;
  
  /// Stop classification: 'bus', 'boat', 'brt', 'commuter_train'
  final String type;

  /// Dynamic route fields
  @override
  final String? nearestStationId;
  @override
  final double? walkingMinutes;
  
  final List<LatLng>? walkingPath;

  const NamtangStop({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.lat,
    required this.lng,
    required this.type,
    this.nearestStationId,
    this.walkingMinutes,
    this.walkingPath,
  });

  factory NamtangStop.fromJson(Map<String, dynamic> json) {
    return NamtangStop(
      id: json['id'] as String,
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      type: json['type'] as String? ?? 'bus',
      nearestStationId: json['nearest_station_id'] as String?,
      walkingMinutes: json['walking_minutes'] != null ? (json['walking_minutes'] as num).toDouble() : null,
      walkingPath: (json['walking_path'] as List<dynamic>?)
          ?.map((c) => LatLng((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_th': nameTh,
        'name_en': nameEn,
        'lat': lat,
        'lng': lng,
        'type': type,
        if (nearestStationId != null) 'nearest_station_id': nearestStationId,
        if (walkingMinutes != null) 'walking_minutes': walkingMinutes,
        if (walkingPath != null) 'walking_path': walkingPath!.map((p) => [p.latitude, p.longitude]).toList(),
      };

  NamtangStop copyWith({
    String? id,
    String? nameTh,
    String? nameEn,
    double? lat,
    double? lng,
    String? type,
    String? nearestStationId,
    double? walkingMinutes,
    List<LatLng>? walkingPath,
  }) {
    return NamtangStop(
      id: id ?? this.id,
      nameTh: nameTh ?? this.nameTh,
      nameEn: nameEn ?? this.nameEn,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      type: type ?? this.type,
      nearestStationId: nearestStationId ?? this.nearestStationId,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      walkingPath: walkingPath ?? this.walkingPath,
    );
  }

  /// Get corresponding asset icon path for search results UI
  String get iconAssetPath {
    switch (type) {
      case 'bus':
        return 'assets/images/bus-stop.png';
      case 'boat':
        return 'assets/images/boat.png';
      case 'brt':
        return 'assets/images/brt.png';
      case 'commuter_train':
        return 'assets/images/train.png';
      default:
        return 'assets/images/bus-stop.png';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NamtangStop && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'NamtangStop($id: $nameEn, type: $type)';
}
