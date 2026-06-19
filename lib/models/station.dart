import 'package:geolocator/geolocator.dart';
import 'searchable_item.dart';
import 'station_exit.dart';

/// Station model for a transit station
class Station extends SearchableItem {
  @override
  final String id;         // e.g. "BTS_N1", "MRT_BL01", "ARL_A1"
  final String code;       // e.g. "N1", "BL01", "A1"
  @override
  final String nameTh;     // Thai name
  @override
  final String nameEn;     // English name
  final String lineId;     // e.g. "BTS_SUKHUMVIT"
  @override
  final double lat;
  @override
  final double lng;
  final List<String> interchange;  // Other station IDs this connects to
  final Map<String, String> exitInfo;   // bound_0, bound_1 direction labels

  const Station({
    required this.id,
    required this.code,
    required this.nameTh,
    required this.nameEn,
    required this.lineId,
    required this.lat,
    required this.lng,
    this.interchange = const [],
    this.exitInfo = const {},
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      code: json['code'] as String,
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      lineId: json['line_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      interchange: (json['interchange'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      exitInfo: (json['exit_info'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name_th': nameTh,
        'name_en': nameEn,
        'line_id': lineId,
        'lat': lat,
        'lng': lng,
        'interchange': interchange,
        'exit_info': exitInfo,
      };

  /// Display name based on locale
  @override
  String displayName({bool isEnglish = false}) {
    return isEnglish ? nameEn : nameTh;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Station && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Station($id: $nameEn)';

  /// Find the exit of this station that is closest to the given target coordinates
  StationExit findClosestExit(List<StationExit> allExits, double targetLat, double targetLng) {
    final exits = allExits.where((e) => e.stationId == id).toList();
    if (exits.isEmpty) {
      // Fallback: generate a temporary exit at station coordinates
      return StationExit(
        id: '${id}_EX_FALLBACK',
        stationId: id,
        exitCode: '1',
        nameTh: 'ทางออก 1',
        nameEn: 'Exit 1',
        lat: lat,
        lng: lng,
      );
    }
    StationExit closest = exits.first;
    double minDistance = double.infinity;
    for (final exit in exits) {
      final dist = Geolocator.distanceBetween(targetLat, targetLng, exit.lat, exit.lng);
      if (dist < minDistance) {
        minDistance = dist;
        closest = exit;
      }
    }
    return closest;
  }
}
