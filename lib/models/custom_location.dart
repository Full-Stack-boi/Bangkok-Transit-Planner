import 'searchable_item.dart';
import 'package:latlong2/latlong.dart';

/// Represents a custom coordinate or place from the map pin, GPS, or online search
class CustomLocation extends SearchableItem {
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
  
  @override
  final double routeLat;

  @override
  final double routeLng;

  final List<LatLng>? walkingPath;
  final List<LatLng>? entrances;
  final bool hasAccuracyWarning;

  const CustomLocation({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.nearestStationId,
    required this.walkingMinutes,
    required this.lat,
    required this.lng,
    double? routeLat,
    double? routeLng,
    this.walkingPath,
    this.entrances,
    this.hasAccuracyWarning = false,
  }) : routeLat = routeLat ?? lat,
       routeLng = routeLng ?? lng;

  CustomLocation copyWith({
    String? id,
    String? nameTh,
    String? nameEn,
    String? nearestStationId,
    double? walkingMinutes,
    double? lat,
    double? lng,
    double? routeLat,
    double? routeLng,
    List<LatLng>? walkingPath,
    List<LatLng>? entrances,
    bool? hasAccuracyWarning,
    bool clearWalkingPath = false,
  }) {
    return CustomLocation(
      id: id ?? this.id,
      nameTh: nameTh ?? this.nameTh,
      nameEn: nameEn ?? this.nameEn,
      nearestStationId: nearestStationId ?? this.nearestStationId,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      routeLat: routeLat ?? this.routeLat,
      routeLng: routeLng ?? this.routeLng,
      walkingPath: clearWalkingPath ? null : (walkingPath ?? this.walkingPath),
      entrances: entrances ?? this.entrances,
      hasAccuracyWarning: hasAccuracyWarning ?? this.hasAccuracyWarning,
    );
  }
}
