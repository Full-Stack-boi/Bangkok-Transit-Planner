/// Represents a physical entrance/exit of a transit station
class StationExit {
  final String id;
  final String stationId;
  final String exitCode;
  final String nameTh;
  final String nameEn;
  final double lat;
  final double lng;

  const StationExit({
    required this.id,
    required this.stationId,
    required this.exitCode,
    required this.nameTh,
    required this.nameEn,
    required this.lat,
    required this.lng,
  });

  factory StationExit.fromJson(Map<String, dynamic> json) {
    return StationExit(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      exitCode: json['exit_code'] as String,
      nameTh: json['name_th'] as String? ?? 'ทางออก ${json['exit_code']}',
      nameEn: json['name_en'] as String? ?? 'Exit ${json['exit_code']}',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'station_id': stationId,
        'exit_code': exitCode,
        'name_th': nameTh,
        'name_en': nameEn,
        'lat': lat,
        'lng': lng,
      };

  @override
  String toString() => 'StationExit($id: Exit $exitCode)';
}
