import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/route_result.dart';
import '../../models/custom_location.dart';
import '../../core/constants/transit_constants.dart';

import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import '../utility/widgets/disruption_detail_sheet.dart';
import '../../core/constants/translation_helper.dart';
import 'widgets/route_header.dart';
import 'widgets/route_type_selector.dart';
import 'widgets/accuracy_warning_card.dart';
import 'widgets/segment_card.dart';
import 'widgets/fare_breakdown.dart';

/// Bottom sheet showing detailed route result with dynamic localization
class RouteResultSheet extends ConsumerWidget {
  const RouteResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(
      searchViewModelProvider.select((s) => s.routeResult),
    );
    final saverRoute = ref.watch(
      searchViewModelProvider.select((s) => s.saverRoute),
    );
    final regularRoute = ref.watch(
      searchViewModelProvider.select((s) => s.regularRoute),
    );
    final activeType = ref.watch(
      searchViewModelProvider.select((s) => s.activeRouteType),
    );
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);
    final disruptionState = ref.watch(disruptionProvider);

    if (result == null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(t.routeResult.noRouteData)),
      );
    }

    final theme = Theme.of(context);

    // Check if route contains disrupted stations
    final routeStationIds = <String>{};
    for (final seg in result.segments) {
      routeStationIds.add(seg.fromStation.id);
      routeStationIds.add(seg.toStation.id);
      for (final s in seg.intermediateStations) {
        routeStationIds.add(s.id);
      }
    }

    final activeDisruptions = disruptionState.disruptions.where((d) {
      return d.affectedStationIds.any((id) => routeStationIds.contains(id));
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              RouteHeader(
                result: result,
                theme: theme,
                t: t,
                localeCode: localeCode,
              ),

              // Disruption Warning Banner
              if (activeDisruptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => DisruptionDetailSheet.show(
                    context,
                    activeDisruptions.first,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade700.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            localeCode == 'th'
                                ? '⚠️ เส้นทางนี้ผ่านสถานีที่มีปัญหา: ${activeDisruptions.first.titleTh}'
                                : '⚠️ This route passes through disrupted station: ${activeDisruptions.first.titleEn}',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],

              // Route Type Selector (Recommended vs Saver)
              if (saverRoute != null) ...[
                const SizedBox(height: 16),
                RouteTypeSelector(
                  activeType: activeType,
                  recommended: regularRoute,
                  saver: saverRoute,
                  theme: theme,
                  t: t,
                ),
              ],

              // Accuracy Warning if overpass failed
              if (result.origin is CustomLocation &&
                      (result.origin as CustomLocation).hasAccuracyWarning ||
                  result.destination is CustomLocation &&
                      (result.destination as CustomLocation)
                          .hasAccuracyWarning) ...[
                const SizedBox(height: 12),
                AccuracyWarningCard(theme: theme, localeCode: localeCode, t: t),
              ],

              const SizedBox(height: 24),

              // Route Timeline Segments
              Builder(
                builder: (context) {
                  final transferMap = <String, TransferStep>{};
                  for (final tr in result.transfers) {
                    transferMap[tr.fromStation.id] = tr;
                  }

                  final children = <Widget>[];

                  // Check for initial transfer before first segment
                  if (result.segments.isNotEmpty &&
                      result.transfers.isNotEmpty) {
                    final firstSeg = result.segments.first;
                    for (final tr in result.transfers) {
                      if (tr.toStation.id == firstSeg.fromStation.id) {
                        children.add(
                          _buildTransferIndicator(
                            context,
                            tr,
                            firstSeg,
                            firstSeg,
                            theme,
                            t,
                            localeCode,
                          ),
                        );
                        break;
                      }
                    }
                  }

                  for (int i = 0; i < result.segments.length; i++) {
                    final segment = result.segments[i];
                    final nextSegment = i < result.segments.length - 1
                        ? result.segments[i + 1]
                        : null;

                    children.add(
                      SegmentCard(
                        segment: segment,
                        theme: theme,
                        t: t,
                        localeCode: localeCode,
                      ),
                    );

                    final matchingTransfer = transferMap[segment.toStation.id];
                    if (matchingTransfer != null) {
                      children.add(
                        _buildTransferIndicator(
                          context,
                          matchingTransfer,
                          segment,
                          nextSegment,
                          theme,
                          t,
                          localeCode,
                        ),
                      );
                    }
                  }

                  return RepaintBoundary(child: Column(children: children));
                },
              ),

              const SizedBox(height: 16),

              // Fare Breakdown Card
              FareBreakdown(
                result: result,
                theme: theme,
                t: t,
                localeCode: localeCode,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransferInstructionCard({
    required BuildContext context,
    required TransferStep transfer,
    required RouteSegment prevSegment,
    RouteSegment? nextSegment,
    required String localeCode,
    required AppLocalizations t,
    required ThemeData theme,
  }) {
    final instruction = _getTransferInstruction(
      transfer: transfer,
      prevSegment: prevSegment,
      nextSegment: nextSegment,
      localeCode: localeCode,
      t: t,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              instruction,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTransferInstruction({
    required TransferStep transfer,
    required RouteSegment prevSegment,
    RouteSegment? nextSegment,
    required String localeCode,
    required AppLocalizations t,
  }) {
    final fromId = transfer.fromStation.id;
    final toId = transfer.toStation.id;
    final isEnglish = localeCode == 'en';

    // Case 1: Tha Phra (MRT Blue Line Self-Interchange)
    if ((fromId == TransitConstants.kStationMrtThaphraBl01 &&
            toId == TransitConstants.kStationMrtThaphraUpperBl33) ||
        (fromId == TransitConstants.kStationMrtThaphraUpperBl33 &&
            toId == TransitConstants.kStationMrtThaphraBl01)) {
      final toUpper = toId == TransitConstants.kStationMrtThaphraBl01;
      return toUpper
          ? t.transfers.transferThaphraUp
          : t.transfers.transferThaphraDown;
    }

    // Case 2: Siam (BTS Sukhumvit <-> Silom)
    if ((fromId == TransitConstants.kStationBtsSiamCen &&
            toId == TransitConstants.kStationBtsSiamSilom) ||
        (fromId == TransitConstants.kStationBtsSiamSilom &&
            toId == TransitConstants.kStationBtsSiamCen)) {
      int arrivalFloor = 3;
      if (prevSegment.lineId == TransitConstants.kBtsSukhumvit ||
          prevSegment.lineId == TransitConstants.kBtsSilom) {
        arrivalFloor = prevSegment.boundIndex == 1 ? 4 : 3;
      }

      int departureFloor = 3;
      if (nextSegment != null &&
          (nextSegment.lineId == TransitConstants.kBtsSukhumvit ||
              nextSegment.lineId == TransitConstants.kBtsSilom)) {
        departureFloor = nextSegment.boundIndex == 1 ? 4 : 3;
      }

      if (arrivalFloor == departureFloor) {
        return t.transfers.transferSiamSameLevel(arrivalFloor);
      } else {
        return departureFloor == 3
            ? t.transfers.transferSiamUp
            : t.transfers.transferSiamDown;
      }
    }

    // Case 3: Data-driven lookup via InterchangeRegistry
    final targetStationName = transfer.toStation.displayName(
      isEnglish: isEnglish,
    );
    final record = InterchangeRegistry.lookup(fromId, toId);

    if (record != null) {
      switch (record.type) {
        case TransferType.skywalk:
          return t.transfers.transferSkywalk(
            targetStationName,
            record.defaultWalkMinutes,
          );
        case TransferType.exit:
          final exitInfo = record.getExitInfo(fromId, isEnglish);
          return t.transfers.transferExit(
            targetStationName,
            exitInfo,
            record.defaultWalkMinutes,
          );
        case TransferType.platformLevel:
          final levelInfo = record.getLevelInfo(isEnglish);
          return t.transfers.transferPlatformLevel(
            levelInfo,
            record.defaultWalkMinutes,
          );
        case TransferType.walk:
          return t.transfers.transferGenericWalk(
            targetStationName,
            record.defaultWalkMinutes,
          );
      }
    }

    // Case 4: Default Walk Fallback
    return t.transfers.interchangeWalk(transfer.walkingMinutes.toInt());
  }
}
