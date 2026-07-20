import 'package:geolocator/geolocator.dart';
import 'package:bkk_transit_planner/models/searchable_item.dart';
import 'package:bkk_transit_planner/models/custom_location.dart';
import 'package:bkk_transit_planner/repositories/transit_repository.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Resolves online place results (CustomLocation) to local landmarks
/// or deep-resolved entrances via Overpass + OSRM.
class PlaceResolver {
  final TransitRepository _repo;

  PlaceResolver(this._repo);

  /// Resolve a SearchableItem — match to local landmark if possible,
  /// otherwise deep-resolve via Overpass + OSRM.
  Future<SearchableItem> resolve(SearchableItem item) async {
    if (item is! CustomLocation) return item;

    try {
      // First, try matching with local landmarks by name
      final queryLower = item.nameTh.toLowerCase();
      if (queryLower.isNotEmpty) {
        for (final l in _repo.landmarks) {
          if (l.nameTh.toLowerCase() == queryLower ||
              l.nameEn.toLowerCase() == item.nameEn.toLowerCase() ||
              l.nameTh.toLowerCase().contains(queryLower)) {
            return l; // Return the perfectly curated local landmark instead
          }
        }
      }

      // Second, snap to a local landmark if the coordinates are extremely close (within 250m)
      for (final l in _repo.landmarks) {
        final dist = Geolocator.distanceBetween(
          item.lat,
          item.lng,
          l.lat,
          l.lng,
        );
        if (dist <= 250.0) {
          return l; // Snap to perfectly curated local landmark
        }
      }

      // Deep resolve via Overpass + OSRM
      final resolved = await _repo.resolveOnlinePlaceAsync(item);
      return resolved ?? item;
    } catch (e, stack) {
      AppLogger.error(
        'Error resolving item in PlaceResolver: $e\n$stack',
        error: e,
      );
      return item; // Safe fallback
    }
  }
}
