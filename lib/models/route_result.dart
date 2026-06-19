import 'package:latlong2/latlong.dart';
import 'station.dart';
import 'searchable_item.dart';
import 'station_exit.dart';

/// A single segment of a route (travel on one line)
class RouteSegment {
  final String lineId;
  final String lineName;
  final String direction;    // e.g. "ไปสุวรรณภูมิ"
  final int boundIndex;      // 0 or 1
  final SearchableItem fromStation;
  final SearchableItem toStation;
  final List<Station> intermediateStations;
  final int stationCount;
  final double estimatedMinutes;
  final int fareThb;
  final int standardFareThb; // Standard fare (without discount)
  final List<LatLng>? walkingPath;
  final StationExit? exit;

  const RouteSegment({
    required this.lineId,
    required this.lineName,
    required this.direction,
    required this.boundIndex,
    required this.fromStation,
    required this.toStation,
    this.intermediateStations = const [],
    required this.stationCount,
    required this.estimatedMinutes,
    required this.fareThb,
    required this.standardFareThb,
    this.walkingPath,
    this.exit,
  });

  /// Total stations including origin and destination
  int get totalStops => stationCount + 1;
}

/// A transfer between two lines
class TransferStep {
  final Station fromStation;
  final Station toStation;
  final String fromLineId;
  final String toLineId;
  final double walkingMinutes;

  const TransferStep({
    required this.fromStation,
    required this.toStation,
    required this.fromLineId,
    required this.toLineId,
    this.walkingMinutes = 5.0,
  });
}

/// Complete route result from origin to destination
class RouteResult {
  final SearchableItem origin;
  final SearchableItem destination;
  final List<RouteSegment> segments;
  final List<TransferStep> transfers;
  final double totalMinutes;
  final int totalFareThb;
  final int totalStandardFareThb; // Standard fare (without discount)
  final int totalStations;
  final DateTime calculatedAt;

  const RouteResult({
    required this.origin,
    required this.destination,
    required this.segments,
    required this.transfers,
    required this.totalMinutes,
    required this.totalFareThb,
    required this.totalStandardFareThb,
    required this.totalStations,
    required this.calculatedAt,
  });

  /// Number of line transfers
  int get transferCount => transfers.length;

  /// All unique line IDs used in this route
  List<String> get lineIds =>
      segments.map((s) => s.lineId).toSet().toList();

  /// Is this a direct route (no transfers)?
  bool get isDirect => transfers.isEmpty;

  /// Total discount in THB
  int get totalDiscountThb => totalStandardFareThb - totalFareThb;
}
