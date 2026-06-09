/// Transit line model
class TransitLine {
  final String id;           // e.g. "BTS_SUKHUMVIT"
  final String nameTh;       // e.g. "สายสุขุมวิท"
  final String nameEn;       // e.g. "Sukhumvit Line"
  final String operator;     // e.g. "BTS", "MRT", "ARL"
  final String colorHex;     // e.g. "#7DC242"
  final List<String> stationIds;  // Ordered station IDs along the line
  final String bound0Label;  // Direction label for bound 0 (e.g. "ไปหมอชิต")
  final String bound1Label;  // Direction label for bound 1 (e.g. "ไปเคหะฯ")
  final bool isLoop;         // True for MRT Blue Line (circular)
  final int peakIntervalMin;
  final int offPeakIntervalMin;

  const TransitLine({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.operator,
    required this.colorHex,
    required this.stationIds,
    required this.bound0Label,
    required this.bound1Label,
    this.isLoop = false,
    required this.peakIntervalMin,
    required this.offPeakIntervalMin,
  });

  factory TransitLine.fromJson(Map<String, dynamic> json) {
    return TransitLine(
      id: json['id'] as String,
      nameTh: json['name_th'] as String,
      nameEn: json['name_en'] as String,
      operator: json['operator'] as String,
      colorHex: json['color_hex'] as String,
      stationIds: (json['station_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      bound0Label: json['bound_0_label'] as String,
      bound1Label: json['bound_1_label'] as String,
      isLoop: json['is_loop'] as bool? ?? false,
      peakIntervalMin: json['peak_interval_min'] as int,
      offPeakIntervalMin: json['off_peak_interval_min'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_th': nameTh,
        'name_en': nameEn,
        'operator': operator,
        'color_hex': colorHex,
        'station_ids': stationIds,
        'bound_0_label': bound0Label,
        'bound_1_label': bound1Label,
        'is_loop': isLoop,
        'peak_interval_min': peakIntervalMin,
        'off_peak_interval_min': offPeakIntervalMin,
      };

  /// Get the direction label for a given bound index
  String getDirectionLabel(int bound) {
    return bound == 0 ? bound0Label : bound1Label;
  }

  /// Get station index in the line (-1 if not found)
  int stationIndex(String stationId) {
    return stationIds.indexOf(stationId);
  }

  /// Determine which bound (0 or 1) to take from origin to destination
  /// For non-loop lines: bound 0 = towards first station, bound 1 = towards last station
  int getBound(String fromStationId, String toStationId) {
    final fromIdx = stationIndex(fromStationId);
    final toIdx = stationIndex(toStationId);
    if (fromIdx < 0 || toIdx < 0) return 0;
    return toIdx > fromIdx ? 1 : 0;
  }

  String displayName({bool isEnglish = false}) {
    return isEnglish ? nameEn : nameTh;
  }

  @override
  String toString() => 'TransitLine($id: $nameEn)';
}
