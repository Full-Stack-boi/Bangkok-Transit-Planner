/// Domain enums for transit card types, networks, and route preferences
library;

/// Supported user transit card concession types
enum TransitCardType {
  standard,
  student,
  senior,
  tripPackage;

  /// Serializes the enum to a stable string for SharedPreferences and Supabase
  String toJson() {
    switch (this) {
      case TransitCardType.standard:
        return 'standard';
      case TransitCardType.student:
        return 'student';
      case TransitCardType.senior:
        return 'senior';
      case TransitCardType.tripPackage:
        return 'trip_package';
    }
  }

  /// Parses string representations, including legacy 'trip_package'
  static TransitCardType fromJson(String? value) {
    if (value == null) return TransitCardType.standard;
    switch (value.toLowerCase().trim()) {
      case 'student':
        return TransitCardType.student;
      case 'senior':
        return TransitCardType.senior;
      case 'trip_package':
      case 'trippackage':
        return TransitCardType.tripPackage;
      case 'standard':
      default:
        return TransitCardType.standard;
    }
  }
}

/// Transit network operator groups for card management
enum TransitNetwork {
  bts('BTS'),
  mrt('MRT'),
  arl('ARL'),
  srt('SRT');

  final String key;
  const TransitNetwork(this.key);

  /// Parse from network key string ('BTS', 'MRT', 'ARL', 'SRT')
  static TransitNetwork? fromKey(String? key) {
    if (key == null) return null;
    final upper = key.toUpperCase().trim();
    for (final network in TransitNetwork.values) {
      if (network.key == upper) return network;
    }
    return null;
  }

  /// Maps a specific line ID to its responsible ticketing/card network
  static TransitNetwork? fromLineId(String lineId) {
    // BTS Sukhumvit, Silom, Gold Line, and EBM/NBM Monorails (Yellow & Pink) use Rabbit Card
    if (lineId.startsWith('BTS') ||
        lineId == 'MRT_YELLOW' ||
        lineId == 'MRT_PINK' ||
        lineId == 'MRT_PINK_BRANCH') {
      return TransitNetwork.bts;
    }
    // BEM Heavy Rail lines (Blue & Purple) use MRT Card
    if (lineId == 'MRT_BLUE' || lineId == 'MRT_PURPLE') {
      return TransitNetwork.mrt;
    }
    // Airport Rail Link uses ARL Card
    if (lineId == 'ARL') {
      return TransitNetwork.arl;
    }
    // SRT Dark and Light Red Lines use SRT Card
    if (lineId.startsWith('SRT')) {
      return TransitNetwork.srt;
    }
    return null;
  }
}

/// Routing algorithm preference
enum RoutePreference {
  fastest,
  cheapest;

  String toJson() => name;
  static RoutePreference fromJson(String? value) {
    if (value == 'cheapest') return RoutePreference.cheapest;
    return RoutePreference.fastest;
  }
}
