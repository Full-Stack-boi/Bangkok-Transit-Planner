/// Abstract base class for any location or place that can be searched
/// and used as a route origin or destination.
abstract class SearchableItem {
  String get id;
  String get nameTh;
  String get nameEn;
  double get lat;
  double get lng;

  /// The latitude to use when routing to/from this item. Defaults to [lat].
  double get routeLat => lat;

  /// The longitude to use when routing to/from this item. Defaults to [lng].
  double get routeLng => lng;

  const SearchableItem();

  /// Display name based on selected language
  String displayName({bool isEnglish = false}) {
    return isEnglish ? nameEn : nameTh;
  }

  /// Convenience getter for localized primary name using localeCode ('th' or 'en')
  String localizedName(String localeCode) =>
      displayName(isEnglish: localeCode == 'en');

  /// Convenience getter for secondary sub-name in alternative language
  String subName(String localeCode) => localeCode == 'en' ? nameTh : nameEn;

  /// The nearest transit station ID if this is a walkable place (landmark, custom location)
  String? get nearestStationId => null;

  /// Estimated walking minutes to the nearest station
  double? get walkingMinutes => null;
}
