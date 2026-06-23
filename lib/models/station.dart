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
  StationExit findClosestExit(
    List<StationExit> allExits,
    double targetLat,
    double targetLng, {
    String? targetNameTh,
    String? targetNameEn,
  }) {
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

    // 1. Try to find exits that match the name of the destination
    if (targetNameTh != null || targetNameEn != null) {
      final nameTh = targetNameTh ?? '';
      final nameEn = targetNameEn ?? '';
      final matchingExits = exits.where((exit) => 
        _isNameMatch(nameTh, nameEn, exit.nameTh, exit.nameEn)
      ).toList();

      if (matchingExits.isNotEmpty) {
        StationExit closest = matchingExits.first;
        double minDistance = double.infinity;
        for (final exit in matchingExits) {
          final dist = Geolocator.distanceBetween(targetLat, targetLng, exit.lat, exit.lng);
          if (dist < minDistance) {
            minDistance = dist;
            closest = exit;
          }
        }
        return closest;
      }
    }

    // 2. Default fallback: closest by physical distance
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

  bool _isNameMatch(String nameTh1, String nameEn1, String nameTh2, String nameEn2) {
    String clean(String s) {
      return s.toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^a-z0-9ก-์]'), '');
    }

    final th1 = clean(nameTh1);
    final en1 = clean(nameEn1);
    final th2 = clean(nameTh2);
    final en2 = clean(nameEn2);

    if (th1.isEmpty || en1.isEmpty || th2.isEmpty || en2.isEmpty) return false;

    // Check for exact substring match
    if (th2.contains(th1) || th1.contains(th2) || en2.contains(en1) || en1.contains(en2)) {
      return true;
    }

    // Check cross-language match
    if (th2.contains(en1) || en2.contains(th1) || th1.contains(en2) || en1.contains(th2)) {
      return true;
    }

    final keywords = [
      'เซ็นทรัล', 'central',
      'ฟอร์จูน', 'fortune',
      'พารากอน', 'paragon',
      'เอ็มควอเทียร์', 'emquartier',
      'เอ็มโพเรียม', 'emporium',
      'มาบุญครอง', 'mbk',
      'ยูเนี่ยน', 'union',
      'เดอะมอลล์', 'themall',
      'โรบินสัน', 'robinson',
      'เทอร์มินอล', 'terminal',
      'ไอคอนสยาม', 'iconsiam'
    ];
    for (final kw in keywords) {
      final hasKw1 = th1.contains(kw) || en1.contains(kw);
      final hasKw2 = th2.contains(kw) || en2.contains(kw);
      if (hasKw1 && hasKw2) {
        return true;
      }
    }

    return false;
  }
}
