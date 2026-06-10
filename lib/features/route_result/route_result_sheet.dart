import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/route_result.dart';
import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import '../favorites/favorites_view_model.dart';

/// Bottom sheet showing detailed route result
class RouteResultSheet extends ConsumerWidget {
  const RouteResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchViewModelProvider);
    final result = state.routeResult;

    if (result == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('ไม่มีข้อมูลเส้นทาง')),
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
              // ─── Handle ───
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

              // ─── Header ───
              _buildHeader(context, ref, result, theme),
              const SizedBox(height: 24),

              // ─── Route Timeline ───
              ...result.segments.asMap().entries.map((entry) {
                final i = entry.key;
                final segment = entry.value;
                return Column(
                  children: [
                    _buildSegmentCard(context, ref, segment, theme),
                    if (i < result.segments.length - 1 &&
                        i < result.transfers.length)
                      _buildTransferIndicator(
                        context,
                        result.transfers[i],
                        theme,
                      ),
                  ],
                );
              }),

              const SizedBox(height: 16),

              // ─── Fare Breakdown ───
              _buildFareBreakdown(context, result, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, RouteResult result, ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildInfoChip(
              icon: Icons.timer_outlined,
              label: '~${result.totalMinutes.toInt()} นาที',
              theme: theme,
            ),
            _buildInfoChip(
              icon: Icons.payments_outlined,
              label: '${result.totalFareThb} บาท',
              theme: theme,
            ),
            _buildInfoChip(
              icon: Icons.swap_horiz_rounded,
              label: '${result.transferCount} ต่อรถ',
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 48), // Balanced spacing for bookmark button
            Expanded(
              child: Text(
                '${result.origin.nameTh} → ${result.destination.nameTh}',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            _buildBookmarkButton(context, ref, result, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildBookmarkButton(
    BuildContext context,
    WidgetRef ref,
    RouteResult result,
    ThemeData theme,
  ) {
    final favoritesRepo = ref.watch(favoritesRepositoryProvider);
    final isSaved = favoritesRepo.isRouteSaved(result.origin.id, result.destination.id);

    return IconButton(
      icon: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: isSaved ? theme.colorScheme.primary : null,
      ),
      onPressed: () async {
        if (isSaved) {
          await favoritesRepo.deleteRoute(result.origin.id, result.destination.id);
          ref.read(favoritesViewModelProvider.notifier).refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบเส้นทางที่บันทึกแล้ว')),
            );
          }
        } else {
          _showSaveRouteDialog(context, ref, result);
        }
      },
    );
  }

  Future<void> _showSaveRouteDialog(BuildContext context, WidgetRef ref, RouteResult result) async {
    final controller = TextEditingController(text: '${result.origin.nameTh} - ${result.destination.nameTh}');

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('บันทึกเส้นทาง'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ชื่อเส้นทาง',
              hintText: 'เช่น ไปทำงาน, กลับบ้าน',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final favoritesRepo = ref.read(favoritesRepositoryProvider);
                  await favoritesRepo.saveRoute(
                    originId: result.origin.id,
                    destinationId: result.destination.id,
                    originName: result.origin.nameTh,
                    destinationName: result.destination.nameTh,
                    routeName: name,
                  );
                  ref.read(favoritesViewModelProvider.notifier).refresh();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกเส้นทางเรียบร้อยแล้ว')),
                    );
                  }
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
    BuildContext context,
    WidgetRef ref,
    RouteSegment segment,
    ThemeData theme,
  ) {
    final lineColor = TransitColors.getLineColor(segment.lineId);
    final crowdService = ref.watch(crowdServiceProvider);
    final scheduleService = ref.watch(scheduleServiceProvider);

    final crowdInfo = crowdService.getCrowdInfo(segment.fromStation.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(segment.lineId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line badge + direction
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    segment.lineName,
                    style: const TextStyle(
                      color: Colors.white,
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
                    segment.direction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: lineColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // From station
            _buildStationDot(
              station: segment.fromStation,
              color: lineColor,
              isFirst: true,
              theme: theme,
            ),

            // Next Train & Crowd Info
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  // Next Train
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        minutesUntilNext == null
                            ? 'หมดระยะบริการ'
                            : (minutesUntilNext == 0 ? 'รถกำลังเข้าสถานี' : 'ขบวนถัดไป: ~$minutesUntilNext นาที'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: minutesUntilNext == 0
                              ? Colors.amber.shade700
                              : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: minutesUntilNext == 0 ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                  // Crowd Level
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: crowdInfo.level == CrowdLevel.high
                            ? Colors.red
                            : (crowdInfo.level == CrowdLevel.medium ? Colors.orange : Colors.green),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'คนรอ: ${crowdInfo.levelTextTh} (~${crowdInfo.presenceCount} คน)',
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
            ),

            // Intermediate stations (collapsed)
            if (segment.stationCount > 1)
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: lineColor, width: 2),
                    ),
                  ),
                  child: Text(
                    '${segment.stationCount} สถานี · ~${segment.estimatedMinutes.toInt()} นาที',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),

            // To station
            _buildStationDot(
              station: segment.toStation,
              color: lineColor,
              isFirst: false,
              theme: theme,
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
    required ThemeData theme,
  }) {
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.nameTh,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${station.nameEn} (${station.code})',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferIndicator(
    BuildContext context,
    TransferStep transfer,
    ThemeData theme,
  ) {
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
              'เปลี่ยนสาย · เดิน ~${transfer.walkingMinutes.toInt()} นาที',
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

  Widget _buildFareBreakdown(
    BuildContext context,
    RouteResult result,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ค่าโดยสาร', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.segments.map((s) {
              final lineColor = TransitColors.getLineColor(s.lineId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.lineName)),
                    Text('${s.fareThb} บาท', style: theme.textTheme.labelLarge),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('รวม', style: theme.textTheme.titleMedium),
                Text(
                  '${result.totalFareThb} บาท',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
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
