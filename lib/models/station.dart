import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'searchable_item.dart';
import 'station_exit.dart';

part 'station.freezed.dart';
part 'station.g.dart';

/// Station model for a transit station
@freezed
abstract class Station extends SearchableItem with _$Station {
  const Station._(); // Allows custom methods/getters

  const factory Station({
    required String id,         // e.g. "BTS_N1", "MRT_BL01", "ARL_A1"
    required String code,       // e.g. "N1", "BL01", "A1"
    @JsonKey(name: 'name_th') required String nameTh,     // Thai name
    @JsonKey(name: 'name_en') required String nameEn,     // English name
    @JsonKey(name: 'line_id') required String lineId,     // e.g. "BTS_SUKHUMVIT"
    required double lat,
    required double lng,
    @Default([]) List<String> interchange,  // Other station IDs this connects to
    @Default({}) @JsonKey(name: 'exit_info') Map<String, String> exitInfo,   // bound_0, bound_1 direction labels
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

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
