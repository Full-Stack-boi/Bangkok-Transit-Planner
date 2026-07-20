import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'station.dart';
import 'searchable_item.dart';
import 'station_exit.dart';

part 'route_result.freezed.dart';

/// A single segment of a route (travel on one line)
@freezed
abstract class RouteSegment with _$RouteSegment {
  const RouteSegment._(); // Allows custom methods/getters

  const factory RouteSegment({
    required String lineId,
    required String lineName,
    required String direction, // e.g. "ไปสุวรรณภูมิ"
    required int boundIndex, // 0 or 1
    required SearchableItem fromStation,
    required SearchableItem toStation,
    @Default([]) List<Station> intermediateStations,
    required int stationCount,
    required double estimatedMinutes,
    required int fareThb,
    required int standardFareThb, // Standard fare (without discount)
    List<LatLng>? walkingPath,
    StationExit? exit,
    String? instructionsTh,
    String? instructionsEn,
  }) = _RouteSegment;

  /// Total stations including origin and destination
  int get totalStops => stationCount + 1;
}

/// A transfer between two lines
@freezed
abstract class TransferStep with _$TransferStep {
  const factory TransferStep({
    required Station fromStation,
    required Station toStation,
    required String fromLineId,
    required String toLineId,
    @Default(5.0) double walkingMinutes,
  }) = _TransferStep;
}

/// Complete route result from origin to destination
@freezed
abstract class RouteResult with _$RouteResult {
  const RouteResult._(); // Allows custom methods/getters

  const factory RouteResult({
    required SearchableItem origin,
    required SearchableItem destination,
    required List<RouteSegment> segments,
    required List<TransferStep> transfers,
    required double totalMinutes,
    required int totalFareThb,
    required int totalStandardFareThb, // Standard fare (without discount)
    required int totalStations,
    required DateTime calculatedAt,
  }) = _RouteResult;

  /// Number of line transfers
  int get transferCount => transfers.length;

  /// All unique line IDs used in this route
  List<String> get lineIds => segments.map((s) => s.lineId).toSet().toList();

  /// Is this a direct route (no transfers)?
  bool get isDirect => transfers.isEmpty;

  /// Total discount in THB
  int get totalDiscountThb => totalStandardFareThb - totalFareThb;
}
