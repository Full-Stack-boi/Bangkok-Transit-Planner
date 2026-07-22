import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../models/station.dart';
import '../../../providers/providers.dart';

class DisruptionDetailSheet extends ConsumerWidget {
  final TransitDisruption disruption;
  final ValueChanged<Station>? onSelectStation;

  const DisruptionDetailSheet({
    super.key,
    required this.disruption,
    this.onSelectStation,
  });

  static void show(
    BuildContext context,
    TransitDisruption disruption, {
    ValueChanged<Station>? onSelectStation,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DisruptionDetailSheet(
        disruption: disruption,
        onSelectStation: onSelectStation,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localeCode = ref.watch(localeProvider);
    final transitRepo = ref.read(transitRepositoryProvider);

    final lineColor = TransitColors.getLineColor(disruption.lineId);
    final isDark = theme.brightness == Brightness.dark;

    final String title = localeCode == 'th'
        ? disruption.titleTh
        : disruption.titleEn;
    final String desc = localeCode == 'th'
        ? disruption.descriptionTh
        : disruption.descriptionEn;
    final String? advice = localeCode == 'th'
        ? disruption.alternativeAdviceTh
        : disruption.alternativeAdviceEn;

    final List<Station> affectedStations = disruption.affectedStationIds
        .map((id) => transitRepo.getStation(id))
        .whereType<Station>()
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Badge & Line Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  disruption.lineId
                      .replaceAll('BTS_', '')
                      .replaceAll('MRT_', ''),
                  style: TextStyle(
                    color: TransitColors.getLineTextColor(disruption.lineId),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: disruption.isFullClosure || disruption.isPartialClosure
                      ? Colors.red.shade700.withValues(alpha: 0.15)
                      : Colors.amber.shade700.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        disruption.isFullClosure || disruption.isPartialClosure
                        ? Colors.red.shade700
                        : Colors.amber.shade700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 14,
                      color:
                          disruption.isFullClosure ||
                              disruption.isPartialClosure
                          ? Colors.red.shade700
                          : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      disruption.isFullClosure
                          ? (localeCode == 'th'
                                ? 'ระงับบริการทั้งสาย'
                                : 'Full Suspension')
                          : (disruption.isPartialClosure
                                ? (localeCode == 'th'
                                      ? 'ปิดบริการบางช่วง'
                                      : 'Partial Suspension')
                                : (localeCode == 'th'
                                      ? 'ล่าช้าบางสถานี'
                                      : 'Minor Delay')),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            disruption.isFullClosure ||
                                disruption.isPartialClosure
                            ? Colors.red.shade700
                            : Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            desc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Estimated Delay Banner
          if (disruption.estimatedDelayMinutes != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.shade900.withValues(alpha: 0.2)
                    : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.shade400.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: Colors.amber.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      localeCode == 'th'
                          ? 'คาดว่ามีความล่าช้าบวกเพิ่ม ~${disruption.estimatedDelayMinutes} นาที'
                          : 'Estimated additional delay: ~${disruption.estimatedDelayMinutes} mins',
                      style: TextStyle(
                        color: isDark
                            ? Colors.amber.shade200
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Affected Stations List
          if (affectedStations.isNotEmpty) ...[
            Text(
              localeCode == 'th'
                  ? 'สถานีที่ได้รับผลกระทบ:'
                  : 'Affected Stations:',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: affectedStations.map((station) {
                final sName = localeCode == 'th'
                    ? station.nameTh
                    : station.nameEn;
                final chipLineColor = TransitColors.getLineColor(
                  station.lineId,
                );

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onSelectStation?.call(station);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.shade700.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: chipLineColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              station.code,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: TransitColors.getLineTextColor(
                                  station.lineId,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Alternative Advice
          if (advice != null && advice.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.directions_outlined,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      advice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
