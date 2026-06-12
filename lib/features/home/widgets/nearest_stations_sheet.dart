import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../models/station.dart';
import '../../../providers/providers.dart';
import '../../search/search_view_model.dart';

/// Bottom sheet displaying nearest stations with distances, line badges,
/// and interchange options, allowing the user to select their departure point.
class NearestStationsSheet extends ConsumerWidget {
  final List<MapEntry<Station, double>> nearestEntries;
  final double accuracy;

  const NearestStationsSheet({
    super.key,
    required this.nearestEntries,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);
    final transitRepo = ref.watch(transitRepositoryProvider);
    final crowdRepo = ref.watch(crowdRepositoryProvider);
    final searchVm = ref.read(searchViewModelProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          Text(
            t.search.selectStationTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.search.selectStationSubtitle,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // List of Stations
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: nearestEntries.length,
              itemBuilder: (context, index) {
                final entry = nearestEntries[index];
                final station = entry.key;
                final distanceM = entry.value;

                final lineColor = TransitColors.getLineColor(station.lineId);
                final stationName = localeCode == 'th'
                    ? station.nameTh
                    : station.nameEn;
                final stationSubName = localeCode == 'th'
                    ? station.nameEn
                    : station.nameTh;

                // Format distance
                final String distanceText;
                if (distanceM >= 1000.0) {
                  final km = (distanceM / 1000.0).toStringAsFixed(1);
                  distanceText = '$km ${t.common.kmUnit}';
                } else {
                  final m = distanceM.round();
                  distanceText = '$m ${t.common.metersUnit}';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    onTap: () async {
                      // 1. Passive check-in
                      await crowdRepo.reportPresence(
                        stationId: station.id,
                        accuracy: accuracy,
                      );

                      // 2. Set as origin in Search
                      searchVm.setOrigin(station);

                      // 3. Switch to Search tab (index 0)
                      ref.read(homeTabIndexProvider.notifier).state = 0;

                      if (context.mounted) {
                        Navigator.pop(context); // Close bottom sheet

                        // 4. Show success banner
                        final msg = t.proximity.checkinSuccess(stationName);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: theme.colorScheme.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: lineColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          station.code,
                          style: TextStyle(
                            color: lineColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stationName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          distanceText,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stationSubName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        if (station.interchange.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                t.proximity.interconnectText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Wrap(
                                spacing: 4,
                                children: station.interchange.map((id) {
                                  final connStation = transitRepo.getStation(
                                    id,
                                  );
                                  if (connStation == null)
                                    return const SizedBox();
                                  final connColor = TransitColors.getLineColor(
                                    connStation.lineId,
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: connColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      connStation.code,
                                      style: TextStyle(
                                        color: TransitColors.getLineTextColor(connStation.lineId),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
