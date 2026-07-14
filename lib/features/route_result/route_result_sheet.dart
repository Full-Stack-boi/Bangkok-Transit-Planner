import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/route_result.dart';
import '../../models/custom_location.dart';

import '../../providers/providers.dart';
import '../search/search_view_model.dart';
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

    if (result == null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(t.routeResult.noRouteData)),
      );
    }

    final theme = Theme.of(context);

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
                    transferMap['${tr.fromStation.id}-${tr.toStation.id}-${tr.fromLineId}-${tr.toLineId}'] =
                        tr;
                  }
                  return RepaintBoundary(
                    child: Column(
                      children: result.segments.asMap().entries.map((entry) {
                        final i = entry.key;
                        final segment = entry.value;
                        return Column(
                          children: [
                            SegmentCard(
                              segment: segment,
                              theme: theme,
                              t: t,
                              localeCode: localeCode,
                            ),
                            if (i < result.segments.length - 1)
                              Builder(
                                builder: (context) {
                                  final nextSegment = result.segments[i + 1];
                                  final key =
                                      '${segment.toStation.id}-${nextSegment.fromStation.id}-${segment.lineId}-${nextSegment.lineId}';
                                  final matchingTransfer = transferMap[key];
                                  if (matchingTransfer != null) {
                                    return _buildTransferIndicator(
                                      context,
                                      matchingTransfer,
                                      segment,
                                      nextSegment,
                                      theme,
                                      t,
                                      localeCode,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
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

  Widget _buildTransferIndicator(
    BuildContext context,
    TransferStep transfer,
    RouteSegment prevSegment,
    RouteSegment nextSegment,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final text = _getTransferInstruction(
      transfer: transfer,
      prevSegment: prevSegment,
      nextSegment: nextSegment,
      localeCode: localeCode,
      t: t,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk_rounded,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w500,
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
    required RouteSegment nextSegment,
    required String localeCode,
    required AppLocalizations t,
  }) {
    final fromId = transfer.fromStation.id;
    final toId = transfer.toStation.id;

    // ─── Case 1: Tha Phra (MRT Blue Line Self-Interchange) ───
    if ((fromId == 'MRT_BL01' && toId == 'MRT_BL33') ||
        (fromId == 'MRT_BL33' && toId == 'MRT_BL01')) {
      final toUpper = toId == 'MRT_BL01';
      return toUpper
          ? t.transfers.transferThaphraUp
          : t.transfers.transferThaphraDown;
    }

    // ─── Case 2: Siam (BTS Sukhumvit <-> Silom) ───
    if ((fromId == 'BTS_CEN' && toId == 'BTS_CEN_SILOM') ||
        (fromId == 'BTS_CEN_SILOM' && toId == 'BTS_CEN')) {
      int arrivalFloor = 3;
      if (prevSegment.lineId == 'BTS_SUKHUMVIT' ||
          prevSegment.lineId == 'BTS_SILOM') {
        arrivalFloor = prevSegment.boundIndex == 1 ? 4 : 3;
      }

      int departureFloor = 3;
      if (nextSegment.lineId == 'BTS_SUKHUMVIT' ||
          nextSegment.lineId == 'BTS_SILOM') {
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

    // ─── Case 3: Other Same-Name Interchanges ───
    final stationId = transfer.fromStation.id;
    final toLine = transfer.toLineId;

    final targetStationName = localeCode == 'th'
        ? transfer.toStation.nameTh
        : transfer.toStation.nameEn;

    // Sukhumvit (MRT_BL22) <-> Asok (BTS_E4)
    if ((stationId == 'MRT_BL22' && toId == 'BTS_E4') ||
        (stationId == 'BTS_E4' && toId == 'MRT_BL22')) {
      return t.transfers.transferAsokSukhumvit(targetStationName);
    }

    // Si Lom (MRT_BL26) <-> Sala Daeng (BTS_S2)
    if ((stationId == 'MRT_BL26' && toId == 'BTS_S2') ||
        (stationId == 'BTS_S2' && toId == 'MRT_BL26')) {
      final exitNum = stationId == 'MRT_BL26' ? '2' : '4';
      return t.transfers.transferSilomSaladaeng(targetStationName, exitNum);
    }

    // Chatuchak Park (MRT_BL13) <-> Mo Chit (BTS_N8)
    if ((stationId == 'MRT_BL13' && toId == 'BTS_N8') ||
        (stationId == 'BTS_N8' && toId == 'MRT_BL13')) {
      final exits = stationId == 'MRT_BL13'
          ? (localeCode == 'th' ? '1 หรือ 2' : '1 or 2')
          : (localeCode == 'th' ? '1 หรือ 3' : '1 or 3');
      return t.transfers.transferMoChitChatuchak(targetStationName, exits);
    }

    // Lat Phrao (Blue <-> Yellow)
    if (stationId == 'MRT_BL15' || stationId == 'MRT_YL01') {
      return toLine == 'MRT_YELLOW'
          ? t.transfers.transferLatphraoYellow
          : t.transfers.transferLatphraoBlue;
    }

    // Phaya Thai (BTS <-> ARL)
    if (stationId == 'BTS_N2' || stationId == 'ARL_A8') {
      return t.transfers.transferPhayathai;
    }

    // Samrong (BTS <-> Yellow)
    if (stationId == 'BTS_E15' || stationId == 'MRT_YL23') {
      return t.transfers.transferSamrong;
    }

    // Hua Mak (ARL <-> Yellow)
    if (stationId == 'ARL_A4' || stationId == 'MRT_YL11') {
      return t.transfers.transferHuamak;
    }

    // ─── Case 4: Default Walk ───
    return t.transfers.interchangeWalk(transfer.walkingMinutes.toInt());
  }
}
