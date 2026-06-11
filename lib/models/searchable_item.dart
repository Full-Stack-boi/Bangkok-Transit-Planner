/// Abstract base class for any location or place that can be searched
/// and used as a route origin or destination.
abstract class SearchableItem {
  String get id;
  String get nameTh;
  String get nameEn;
  double get lat;
  double get lng;

  const SearchableItem();

  /// Display name based on selected language
  String displayName({bool isEnglish = false}) {
    return isEnglish ? nameEn : nameTh;
  }

  /// The nearest transit station ID if this is a walkable place (landmark, custom location)
  String? get nearestStationId => null;

  /// Estimated walking minutes to the nearest station
  double? get walkingMinutes => null;
}
