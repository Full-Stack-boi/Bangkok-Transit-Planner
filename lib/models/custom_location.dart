import 'searchable_item.dart';

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

  const CustomLocation({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.nearestStationId,
    required this.walkingMinutes,
    required this.lat,
    required this.lng,
  });
}
