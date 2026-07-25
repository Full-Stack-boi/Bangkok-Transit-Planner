import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../models/station.dart';
import '../../../models/crowd_report.dart';
import '../../../providers/providers.dart';
import '../../../widgets/shared/station_badge.dart';
import '../../favorites/favorites_view_model.dart';
import '../../utility/widgets/disruption_detail_sheet.dart';

class StationDetailsCard extends ConsumerWidget {
  final Station station;
  final String localeCode;
  final VoidCallback onClose;
  final ValueChanged<Station> onSelectHubStation;
  final ValueChanged<Station> onSetOrigin;
  final ValueChanged<Station> onSetDestination;

  const StationDetailsCard({
    super.key,
    required this.station,
    required this.localeCode,
    required this.onClose,
    required this.onSelectHubStation,
    required this.onSetOrigin,
    required this.onSetDestination,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final transitRepo = ref.watch(transitRepositoryProvider);
    final scheduleService = ref.watch(scheduleServiceProvider);
    final crowdService = ref.watch(crowdServiceProvider);
    final disruptionState = ref.watch(disruptionProvider);
    final activeDisruption = disruptionState.getDisruptionForStation(
      station.id,
    );

    final lineColor = TransitColors.getLineColor(station.lineId);
    final crowdInfo = crowdService.getCrowdInfo(station.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(
      station.lineId,
    );

    final stationName = station.localizedName(localeCode);
    final stationSubName = station.subName(localeCode);

    // Find all stations in the same interchange hub
    final hubStations = <Station>[station];
    for (final interchangeId in station.interchange) {
      final s = transitRepo.getStation(interchangeId);
      if (s != null && !hubStations.contains(s)) {
        hubStations.add(s);
      }
    }
    hubStations.sort((a, b) {
      int getPriority(String lineId) {
        if (lineId.startsWith('BTS')) return 1;
        if (lineId.startsWith('MRT')) return 2;
        if (lineId.startsWith('ARL')) return 3;
        if (lineId.startsWith('SRT')) return 4;
        return 5;
      }

      return getPriority(a.lineId).compareTo(getPriority(b.lineId));
    });

    final String trainStatusText;
    if (minutesUntilNext == null) {
      trainStatusText = t.routeResult.serviceEnded;
    } else if (minutesUntilNext == 0) {
      trainStatusText = t.routeResult.trainArriving;
    } else {
      trainStatusText =
          '${t.routeResult.nextTrain}: ~$minutesUntilNext ${t.common.minutesUnit}';
    }

    String getCrowdLevelText(CrowdLevel level) {
      switch (level) {
        case CrowdLevel.low:
          return t.routeResult.crowdLow;
        case CrowdLevel.medium:
          return t.routeResult.crowdMedium;
        case CrowdLevel.high:
          return t.routeResult.crowdHigh;
        case CrowdLevel.unknown:
          return t.routeResult.crowdUnknown;
      }
    }

    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Name + Close Button)
            Row(
              children: [
                StationBadge(
                  text: station.code,
                  lineId: station.lineId,
                  fontSize: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stationSubName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final favoritesState = ref.watch(
                      favoritesViewModelProvider,
                    );
                    final isFav = favoritesState.favoriteStations.any(
                      (s) => s.id == station.id,
                    );
                    return IconButton(
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        color: isFav ? Colors.red : null,
                      ),
                      onPressed: () async {
                        await ref
                            .read(favoritesViewModelProvider.notifier)
                            .toggleFavoriteStation(station.id);
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ],
            ),
            if (activeDisruption != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    DisruptionDetailSheet.show(context, activeDisruption),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.shade700.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber.shade800,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localeCode == 'th'
                              ? '⚠️ ${activeDisruption.titleTh}'
                              : '⚠️ ${activeDisruption.titleEn}',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        t.common.viewDetails,
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (hubStations.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: hubStations.map((hubStation) {
                    final hubLine = transitRepo.getLine(hubStation.lineId);
                    final hubLineColor = TransitColors.getLineColor(
                      hubStation.lineId,
                    );
                    final isSelected = hubStation.id == station.id;
                    final hubLineName = hubLine != null
                        ? hubLine.displayName(isEnglish: localeCode == 'en')
                        : hubStation.lineId;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          '${hubStation.code} - $hubLineName',
                          style: TextStyle(
                            color: isSelected ? Colors.white : hubLineColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: hubLineColor,
                        backgroundColor: theme.brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade100,
                        checkmarkColor: Colors.white,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: hubLineColor, width: 1.5),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            onSelectHubStation(hubStation);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const Divider(height: 16),

            // Next Train & Crowd Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Next Train
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 16,
                        color: Colors.amber.shade300,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trainStatusText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: minutesUntilNext == 0
                                ? Colors.amber.shade700
                                : Colors.amber.shade200,
                            fontWeight: minutesUntilNext == 0
                                ? FontWeight.bold
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Crowd Level
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 16,
                      color: crowdInfo.level == CrowdLevel.high
                          ? Colors.red
                          : (crowdInfo.level == CrowdLevel.medium
                                ? Colors.orange
                                : Colors.green),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${t.routeResult.crowdLevel}: ${getCrowdLevelText(crowdInfo.level)} (~${crowdInfo.presenceCount} ${t.common.peopleUnit})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: crowdInfo.level == CrowdLevel.high
                            ? Colors.red.shade400
                            : (crowdInfo.level == CrowdLevel.medium
                                  ? Colors.orange.shade400
                                  : Colors.green.shade400),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onSetOrigin(station);
                    },
                    icon: const Icon(
                      Icons.trip_origin_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: Text(t.favorites.setOriginBtn),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onSetDestination(station);
                    },
                    icon: const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(t.favorites.setDestBtn),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
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
