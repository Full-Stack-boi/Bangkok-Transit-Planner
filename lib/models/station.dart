/// Station model for a transit station
class Station {
  final String id;         // e.g. "BTS_N1", "MRT_BL01", "ARL_A1"
  final String code;       // e.g. "N1", "BL01", "A1"
  final String nameTh;     // Thai name
  final String nameEn;     // English name
  final String lineId;     // e.g. "BTS_SUKHUMVIT"
  final double lat;
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
}
