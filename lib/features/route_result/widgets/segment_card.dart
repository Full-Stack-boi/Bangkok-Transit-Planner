import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../models/route_result.dart';
import '../../../models/station.dart';
import '../../../models/searchable_item.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/crowd_level_badge.dart';

class SegmentCard extends ConsumerWidget {
  final RouteSegment segment;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;

  const SegmentCard({
    super.key,
    required this.segment,
    required this.theme,
    required this.t,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (segment.lineId == 'WALK') {
      return _buildWalkSegmentCard(context, ref);
    }

    final crowdService = ref.watch(crowdServiceProvider);
    final scheduleService = ref.watch(scheduleServiceProvider);

    final lineColor = TransitColors.getLineColor(segment.lineId);
    final crowdInfo = crowdService.getCrowdInfo(segment.fromStation.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(
      segment.lineId,
    );

    final String displayLineName = segment.lineName;
    final displayDirection = t.directions.getDirectionLabel(
      segment.lineId,
      segment.boundIndex,
      segment.direction,
    );

    final String trainStatusText;
    if (minutesUntilNext == null) {
      trainStatusText = t.routeResult.serviceEnded;
    } else if (minutesUntilNext == 0) {
      trainStatusText = t.routeResult.trainArriving;
    } else {
      trainStatusText =
          '${t.routeResult.nextTrain}: ~$minutesUntilNext ${t.common.minutesUnit}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayLineName,
                    style: TextStyle(
                      color: TransitColors.getLineTextColor(segment.lineId),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16, color: lineColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayDirection,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStationDot(
              station: segment.fromStation,
              color: lineColor,
              isFirst: true,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.appColors.timeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trainStatusText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: minutesUntilNext == 0
                              ? Colors.amber.shade700
                              : theme.appColors.timeColor,
                          fontWeight: minutesUntilNext == 0
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ],
                  ),
                  CrowdLevelBadge(crowdInfo: crowdInfo, theme: theme, t: t),
                ],
              ),
            ),
            if (segment.stationCount > 1)
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: lineColor, width: 2),
                    ),
                  ),
                  child: Text(
                    '${segment.stationCount} ${t.routeResult.stationsCount} · ~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            _buildStationDot(
              station: segment.toStation,
              color: lineColor,
              isFirst: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationBadge(Station station) {
    final lineColor = TransitColors.getLineColor(station.lineId);
    final isEng = localeCode == 'en';
    final name = station.displayName(isEnglish: isEng);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$name (${station.code})',
        style: TextStyle(
          color: TransitColors.getLineTextColor(station.lineId),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildWalkSegmentCard(BuildContext context, WidgetRef ref) {
    final fromStation = segment.fromStation;
    final toStation = segment.toStation;
    final timeStr =
        '~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}';
    final customInstruction = localeCode == 'en'
        ? (segment.instructionsEn ?? segment.instructionsTh)
        : (segment.instructionsTh ?? segment.instructionsEn);

    Widget buildLocationSpan(SearchableItem item) {
      if (item is Station) {
        return _buildStationBadge(item);
      } else {
        return Text(
          item.displayName(isEnglish: localeCode == 'en'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }

    Widget buildSubtitleLocationSpan(SearchableItem item) {
      if (item is Station) {
        return _buildStationBadge(item);
      } else {
        return Text(
          item.displayName(isEnglish: localeCode == 'en'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_walk_rounded,
                color: theme.colorScheme.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        t.routeResult.walkTo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      buildLocationSpan(toStation),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        t.routeResult.fromLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      buildSubtitleLocationSpan(fromStation),
                      if (fromStation is Station && segment.exit != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.routeResult.exitLabel(segment.exit!.exitCode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        '· $timeStr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (customInstruction != null &&
                      customInstruction.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customInstruction,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.9,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationDot({
    required dynamic station,
    required Color color,
    required bool isFirst,
  }) {
    final name = localeCode == 'th' ? station.nameTh : station.nameEn;
    final subName = localeCode == 'th' ? station.nameEn : station.nameTh;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$subName (${station.code})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
