import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../providers/route_tracker.dart';

class ActiveJourneyPanel extends ConsumerWidget {
  final RouteTrackerState tracker;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;

  const ActiveJourneyPanel({
    super.key,
    required this.tracker,
    required this.theme,
    required this.t,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = tracker.currentSegment;
    if (segment == null) return const SizedBox.shrink();

    final isWalk = segment.lineId == 'WALK';
    final lineColor = isWalk
        ? Colors.grey
        : TransitColors.getLineColor(segment.lineId);
    final stations = tracker.currentSegmentStations;

    if (tracker.hasArrived) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.journey.arrivedLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  ref.read(routeTrackerProvider.notifier).stopTracking();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(t.journey.endJourneyBtn),
              ),
            ],
          ),
        ),
      );
    }

    final currentStationName =
        tracker.currentStation?.displayName(isEnglish: localeCode == 'en') ??
        '';
    final nextStationName =
        tracker.nextStation?.displayName(isEnglish: localeCode == 'en') ?? '';

    // Calculate progress
    double progress = 1.0;
    if (stations.isNotEmpty) {
      progress = (tracker.currentStationIndex + 1) / stations.length;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Line Badge and Segment progress
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
                    isWalk ? t.journey.walkToLabel : segment.lineName,
                    style: TextStyle(
                      color: isWalk
                          ? Colors.white
                          : TransitColors.getLineTextColor(segment.lineId),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWalk
                        ? '~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}'
                        : '${stations.length} ${t.journey.stationsCount}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (tracker.isSimulation) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.amber.shade700,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.journey.simulationMode,
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: lineColor.withValues(alpha: 0.15),
              color: lineColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),

            // Current & Next station details
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.journey.currentStationLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentStationName.isNotEmpty
                            ? currentStationName
                            : (isWalk
                                  ? segment.fromStation.displayName(
                                      isEnglish: localeCode == 'en',
                                    )
                                  : ''),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.journey.nextStationLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextStationName.isNotEmpty
                            ? nextStationName
                            : (isWalk
                                  ? segment.toStation.displayName(
                                      isEnglish: localeCode == 'en',
                                    )
                                  : '-'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Buttons: Simulation Step & End Journey
            Row(
              children: [
                if (tracker.isSimulation) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(routeTrackerProvider.notifier)
                            .advanceSimulation();
                      },
                      icon: const Icon(Icons.skip_next_rounded, size: 20),
                      label: Text(t.journey.nextSimulationBtn),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(routeTrackerProvider.notifier).stopTracking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(t.journey.endJourneyBtn),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
