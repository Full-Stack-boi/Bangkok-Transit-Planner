import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/route_result.dart';

import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import '../favorites/favorites_view_model.dart';
import '../../core/constants/translation_helper.dart';

/// Bottom sheet showing detailed route result with dynamic localization
class RouteResultSheet extends ConsumerWidget {
  const RouteResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchViewModelProvider);
    final result = state.routeResult;
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);

    if (result == null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(t.get('no_route_data'))),
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
              _buildHeader(context, ref, result, theme, t, localeCode),
              const SizedBox(height: 24),

              // Route Timeline Segments
              ...result.segments.asMap().entries.map((entry) {
                final i = entry.key;
                final segment = entry.value;
                return Column(
                  children: [
                    _buildSegmentCard(context, ref, segment, theme, t, localeCode),
                    if (i < result.segments.length - 1 && i < result.transfers.length)
                      _buildTransferIndicator(
                        context,
                        result.transfers[i],
                        segment,
                        result.segments[i + 1],
                        theme,
                        t,
                        localeCode,
                      ),
                  ],
                );
              }),

              const SizedBox(height: 16),

              // Fare Breakdown Card
              _buildFareBreakdown(context, result, theme, t, localeCode),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    RouteResult result,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final originName = localeCode == 'th' ? result.origin.nameTh : result.origin.nameEn;
    final destName = localeCode == 'th' ? result.destination.nameTh : result.destination.nameEn;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: _buildInfoChip(
                icon: Icons.timer_outlined,
                label: '~${result.totalMinutes.toInt()} ${t.get('minutes_unit')}',
                theme: theme,
              ),
            ),
            Flexible(
              child: _buildInfoChip(
                icon: Icons.payments_outlined,
                label: '${result.totalFareThb} ${t.get('currency_unit')}',
                theme: theme,
              ),
            ),
            Flexible(
              child: _buildInfoChip(
                icon: Icons.swap_horiz_rounded,
                label: '${result.transferCount} ${t.get('transfers_count')}',
                theme: theme,
              ),
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
                '$originName → $destName',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _buildBookmarkButton(context, ref, result, theme, t, localeCode),
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
    AppLocalizations t,
    String localeCode,
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
              SnackBar(content: Text(t.get('route_deleted_success'))),
            );
          }
        } else {
          _showSaveRouteDialog(context, ref, result, t, localeCode);
        }
      },
    );
  }

  Future<void> _showSaveRouteDialog(
    BuildContext context,
    WidgetRef ref,
    RouteResult result,
    AppLocalizations t,
    String localeCode,
  ) async {
    final originName = localeCode == 'th' ? result.origin.nameTh : result.origin.nameEn;
    final destName = localeCode == 'th' ? result.destination.nameTh : result.destination.nameEn;
    
    final controller = TextEditingController(text: '$originName - $destName');

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.get('save_route_btn')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: t.get('route_name_label'),
              hintText: t.get('route_name_hint'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.get('cancel_btn')),
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
                      SnackBar(content: Text(t.get('route_saved_success'))),
                    );
                  }
                }
              },
              child: Text(t.get('save_btn')),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
    BuildContext context,
    WidgetRef ref,
    RouteSegment segment,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    if (segment.lineId == 'WALK') {
      return _buildWalkSegmentCard(context, segment, theme, t, localeCode);
    }

    final lineColor = TransitColors.getLineColor(segment.lineId);
    final crowdService = ref.watch(crowdServiceProvider);
    final scheduleService = ref.watch(scheduleServiceProvider);

    final crowdInfo = crowdService.getCrowdInfo(segment.fromStation.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(segment.lineId);

    // Format localized line name and direction label
    final String displayLineName = segment.lineName;
    
    // Parse simulated direction name
    String displayDirection = segment.direction;
    if (localeCode == 'en') {
      if (segment.direction.contains('ไปคูคต')) {
        displayDirection = 'to Khu Khot';
      } else if (segment.direction.contains('ไปเคหะฯ')) {
        displayDirection = 'to Kheha';
      } else if (segment.direction.contains('ไปสนามกีฬาแห่งชาติ')) {
        displayDirection = 'to National Stadium';
      } else if (segment.direction.contains('ไปบางหว้า')) {
        displayDirection = 'to Bang Wa';
      } else if (segment.direction.contains('ไปกรุงธนบุรี')) {
        displayDirection = 'to Krung Thon Buri';
      } else if (segment.direction.contains('ไปคลองสาน')) {
        displayDirection = 'to Khlong San';
      } else if (segment.direction.contains('วงกลม (ตามเข็ม)')) {
        displayDirection = 'Circle Loop (Clockwise)';
      } else if (segment.direction.contains('วงกลม (ทวนเข็ม)')) {
        displayDirection = 'Circle Loop (Counter-Clockwise)';
      } else if (segment.direction.contains('ไปคลาดบางไผ่') || segment.direction.contains('ไปคลองบางไผ่')) {
        displayDirection = 'to Khlong Bang Phai';
      } else if (segment.direction.contains('ไปเตาปูน')) {
        displayDirection = 'to Tao Poon';
      } else if (segment.direction.contains('ไปลาดพร้าว')) {
        displayDirection = 'to Lat Phrao';
      } else if (segment.direction.contains('ไปสำโรง')) {
        displayDirection = 'to Samrong';
      } else if (segment.direction.contains('ไปสุวรรณภูมิ')) {
        displayDirection = 'to Suvarnabhumi';
      } else if (segment.direction.contains('ไปพญาไท')) {
        displayDirection = 'to Phaya Thai';
      }
    }

    final String trainStatusText;
    if (minutesUntilNext == null) {
      trainStatusText = t.get('service_ended');
    } else if (minutesUntilNext == 0) {
      trainStatusText = t.get('train_arriving');
    } else {
      trainStatusText = '${t.get('next_train')}: ~$minutesUntilNext ${t.get('minutes_unit')}';
    }

    String getCrowdLevelText(CrowdLevel level) {
      switch (level) {
        case CrowdLevel.low:
          return t.get('crowd_low');
        case CrowdLevel.medium:
          return t.get('crowd_medium');
        case CrowdLevel.high:
          return t.get('crowd_high');
        case CrowdLevel.unknown:
          return t.get('crowd_unknown');
      }
    }

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
                    displayLineName,
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
                    displayDirection,
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
              localeCode: localeCode,
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
                        trainStatusText,
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
                        '${t.get('crowd_level')}: ${getCrowdLevelText(crowdInfo.level)} (~${crowdInfo.presenceCount} ${localeCode == 'th' ? 'คน' : 'pax'})',
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
                    '${segment.stationCount} ${t.get('stations_count')} · ~${segment.estimatedMinutes.toInt()} ${t.get('minutes_unit')}',
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
              localeCode: localeCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkSegmentCard(
    BuildContext context,
    RouteSegment segment,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final fromName = segment.fromStation.displayName(isEnglish: localeCode == 'en');
    final toName = segment.toStation.displayName(isEnglish: localeCode == 'en');
    final timeStr = '~${segment.estimatedMinutes.toInt()} ${t.get('minutes_unit')}';
    
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
                  Text(
                    localeCode == 'en' ? 'Walk to $toName' : 'เดินเท้าไปยัง $toName',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localeCode == 'en'
                        ? 'From $fromName · $timeStr'
                        : 'จาก $fromName · $timeStr',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
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
    required ThemeData theme,
    required String localeCode,
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
    if ((fromId == 'MRT_BL01' && toId == 'MRT_BL33') || (fromId == 'MRT_BL33' && toId == 'MRT_BL01')) {
      final toUpper = toId == 'MRT_BL01';
      if (localeCode == 'th') {
        return toUpper
            ? 'ขึ้นบันไดเลื่อนไปชานชาลาชั้น 4 (สายวงกลม ไปทางจรัญฯ/เตาปูน) · เดิน ~1 นาที'
            : 'ลงบันไดเลื่อนไปชานชาลาชั้น 3 (สายกิ่ง ไปทางบางหว้า/หลักสอง) · เดิน ~1 นาที';
      } else {
        return toUpper
            ? 'Go up to Level 4 platform (Circle Line towards Charan / Tao Poon) · Walk ~1 min'
            : 'Go down to Level 3 platform (Branch Line towards Bang Wa / Lak Song) · Walk ~1 min';
      }
    }

    // ─── Case 2: Siam (BTS Sukhumvit <-> Silom) ───
    if ((fromId == 'BTS_CEN' && toId == 'BTS_CEN_SILOM') || (fromId == 'BTS_CEN_SILOM' && toId == 'BTS_CEN')) {
      int arrivalFloor = 3;
      final prevDir = prevSegment.direction;
      if (prevSegment.lineId == 'BTS_SUKHUMVIT') {
        if (prevDir.contains('เคหะ') || prevDir.contains('Kheha')) {
          arrivalFloor = 4;
        } else {
          arrivalFloor = 3;
        }
      } else if (prevSegment.lineId == 'BTS_SILOM') {
        if (prevDir.contains('บางหว้า') || prevDir.contains('Bang Wa')) {
          arrivalFloor = 4;
        } else {
          arrivalFloor = 3;
        }
      }

      int departureFloor = 3;
      final nextDir = nextSegment.direction;
      if (nextSegment.lineId == 'BTS_SUKHUMVIT') {
        if (nextDir.contains('เคหะ') || nextDir.contains('Kheha')) {
          departureFloor = 4;
        } else {
          departureFloor = 3;
        }
      } else if (nextSegment.lineId == 'BTS_SILOM') {
        if (nextDir.contains('บางหว้า') || nextDir.contains('Bang Wa')) {
          departureFloor = 4;
        } else {
          departureFloor = 3;
        }
      }

      if (arrivalFloor == departureFloor) {
        if (localeCode == 'th') {
          return 'เดินสลับฝั่งชานชาลาที่ชั้นเดียวกัน (ชั้น $arrivalFloor) · เดิน ~1 นาที';
        } else {
          return 'Cross-platform transfer on the same level (Level $arrivalFloor) · Walk ~1 min';
        }
      } else {
        if (departureFloor == 3) {
          if (localeCode == 'th') {
            return 'ขึ้นบันไดเลื่อนขึ้นไปชานชาลาชั้น 3 · เดิน ~1 นาที';
          } else {
            return 'Go up to Level 3 platform · Walk ~1 min';
          }
        } else {
          if (localeCode == 'th') {
            return 'ลงบันไดเลื่อนลงไปชานชาลาชั้น 4 · เดิน ~1 นาที';
          } else {
            return 'Go down to Level 4 platform · Walk ~1 min';
          }
        }
      }
    }

    // ─── Case 3: Other Same-Name Interchanges ───
    if (transfer.fromStation.nameEn == transfer.toStation.nameEn) {
      final toLine = transfer.toLineId;

      // Lat Phrao (Blue <-> Yellow)
      if (transfer.fromStation.nameEn.contains('Lat Phrao')) {
        if (toLine == 'MRT_YELLOW') {
          if (localeCode == 'th') {
            return 'ขึ้นบันไดเลื่อนขึ้นไปชานชาลารถไฟฟ้ายกระดับสายสีเหลือง · เดิน ~2 นาที';
          } else {
            return 'Go up to the elevated Yellow Line platform · Walk ~2 min';
          }
        } else {
          if (localeCode == 'th') {
            return 'ลงบันไดเลื่อนลงไปสถานีรถไฟฟ้าใต้ดินสายสีน้ำเงิน · เดิน ~2 นาที';
          } else {
            return 'Go down to the underground Blue Line platform · Walk ~2 min';
          }
        }
      }

      // Phaya Thai (BTS <-> ARL)
      if (transfer.fromStation.nameEn.contains('Phaya Thai')) {
        if (localeCode == 'th') {
          return 'เดินผ่านทางเชื่อมเพื่อเปลี่ยนชานชาลาต่างระดับ · เดิน ~2 นาที';
        } else {
          return 'Walk via connection link to the other station level · Walk ~2 min';
        }
      }

      // Samrong (BTS <-> Yellow)
      if (transfer.fromStation.nameEn.contains('Samrong')) {
        if (localeCode == 'th') {
          return 'เดินผ่านทางเชื่อมสกายวอล์คเปลี่ยนชานชาลายกระดับ · เดิน ~2 นาที';
        } else {
          return 'Walk via skywalk connection link to the other line · Walk ~2 min';
        }
      }

      // Hua Mak (ARL <-> Yellow)
      if (transfer.fromStation.nameEn.contains('Hua Mak')) {
        if (localeCode == 'th') {
          return 'เดินผ่านทางเชื่อมสกายวอล์คเพื่อเปลี่ยนสาย · เดิน ~2 นาที';
        } else {
          return 'Walk via skywalk transfer bridge to the other line · Walk ~2 min';
        }
      }
    }

    // ─── Case 4: Default Walk ───
    return t.get('interchange_walk').replaceAll('{time}', '${transfer.walkingMinutes.toInt()}');
  }

  Widget _buildFareBreakdown(
    BuildContext context,
    RouteResult result,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.get('fare_title'), style: theme.textTheme.titleMedium),
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
                    Text('${s.fareThb} ${t.get('currency_unit')}', style: theme.textTheme.labelLarge),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.get('total'), style: theme.textTheme.titleMedium),
                Text(
                  '${result.totalFareThb} ${t.get('currency_unit')}',
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
