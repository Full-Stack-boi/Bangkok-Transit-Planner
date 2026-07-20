import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'searchable_item.dart';

part 'custom_location.freezed.dart';
part 'custom_location.g.dart';

/// Represents a custom coordinate or place from the map pin, GPS, or online search
@freezed
abstract class CustomLocation extends SearchableItem with _$CustomLocation {
  const CustomLocation._(); // Allows custom methods/getters

  const factory CustomLocation({
    required String id,
    required String nameTh,
    required String nameEn,
    String? nearestStationId,
    double? walkingMinutes,
    required double lat,
    required double lng,
    double? customRouteLat,
    double? customRouteLng,
    List<LatLng>? walkingPath,
    List<LatLng>? entrances,
    @Default(false) bool hasAccuracyWarning,
  }) = _CustomLocation;

  @override
  double get routeLat => customRouteLat ?? lat;

  @override
  double get routeLng => customRouteLng ?? lng;

  /// Custom copy helper to resolve naming conflicts between non-nullable overridden getters and nullable parameters
  CustomLocation updateRoute({
    double? routeLat,
    double? routeLng,
    String? nearestStationId,
    double? walkingMinutes,
    bool clearWalkingPath = false,
  }) {
    return copyWith(
      customRouteLat: routeLat ?? customRouteLat,
      customRouteLng: routeLng ?? customRouteLng,
      nearestStationId: nearestStationId ?? this.nearestStationId,
      walkingMinutes: walkingMinutes ?? this.walkingMinutes,
      walkingPath: clearWalkingPath ? null : walkingPath,
    );
  }

  factory CustomLocation.fromJson(Map<String, dynamic> json) =>
      _$CustomLocationFromJson(json);
}
