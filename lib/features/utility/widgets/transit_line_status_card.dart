import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../providers/providers.dart';
import '../../../services/transit_news_service.dart';
import 'disruption_detail_sheet.dart';

class TransitLineStatusCard extends ConsumerWidget {
  final ThemeData theme;
  final AppLocalizations t;
  final TransitLineStatus item;

  const TransitLineStatusCard({
    super.key,
    required this.theme,
    required this.t,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineColor = TransitColors.getLineColor(item.lineId);
    final disruptionState = ref.watch(disruptionProvider);
    final disruptions = disruptionState.getDisruptionsForLine(item.lineId);
    final activeDisruption = disruptions.isNotEmpty ? disruptions.first : null;

    Widget statusIcon;
    Color statusColor;
    String statusText;

    if (activeDisruption != null) {
      if (activeDisruption.isFullClosure || activeDisruption.isPartialClosure) {
        statusIcon = Icon(
          Icons.error_rounded,
          size: 14,
          color: Colors.red.shade700,
        );
        statusColor = Colors.red.shade700;
        statusText = t.isTh
            ? (activeDisruption.isFullClosure
                  ? 'ระงับบริการทั้งสาย'
                  : 'งดบริการบางช่วง')
            : (activeDisruption.isFullClosure
                  ? 'Full Closure'
                  : 'Partial Closure');
      } else {
        statusIcon = Icon(
          Icons.warning_rounded,
          size: 14,
          color: Colors.amber.shade800,
        );
        statusColor = Colors.amber.shade800;
        statusText = t.isTh ? 'ล่าช้าบางสถานี' : 'Minor Delay';
      }
    } else if (item.isNormal) {
      statusIcon = const Icon(
        Icons.check_circle_rounded,
        size: 14,
        color: Colors.green,
      );
      statusColor = Colors.green;
      statusText = t.isTh ? item.statusTh : item.statusEn;
    } else {
      statusIcon = Icon(
        Icons.error_rounded,
        size: 14,
        color: Colors.red.shade700,
      );
      statusColor = Colors.red.shade700;
      statusText = t.isTh ? item.statusTh : item.statusEn;
    }

    String getShortLineName(String id, bool isTh) {
      switch (id) {
        case 'BTS_SUKHUMVIT':
          return isTh ? 'สุขุมวิท' : 'Sukhumvit';
        case 'BTS_SILOM':
          return isTh ? 'สีลม' : 'Silom';
        case 'MRT_BLUE':
          return isTh ? 'สายสีน้ำเงิน' : 'Blue Line';
        case 'MRT_PURPLE':
          return isTh ? 'สายสีม่วง' : 'Purple Line';
        case 'MRT_YELLOW':
          return isTh ? 'สายสีเหลือง' : 'Yellow Line';
        case 'MRT_PINK':
          return isTh ? 'สายสีชมพู' : 'Pink Line';
        case 'ARL':
          return isTh ? 'แอร์พอร์ตลิงก์' : 'ARL';
        case 'SRT_RED_NORTH':
          return isTh ? 'สายสีแดง' : 'Red Line';
        default:
          return isTh ? item.lineNameTh : item.lineNameEn;
      }
    }

    final shortName = getShortLineName(item.lineId, t.isTh);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (activeDisruption != null) {
            DisruptionDetailSheet.show(context, activeDisruption);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: activeDisruption != null
                  ? (activeDisruption.isFullClosure ||
                            activeDisruption.isPartialClosure
                        ? Colors.red.shade900.withValues(alpha: 0.15)
                        : Colors.amber.shade900.withValues(alpha: 0.15))
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: activeDisruption != null
                    ? (activeDisruption.isFullClosure ||
                              activeDisruption.isPartialClosure
                          ? Colors.red.shade600.withValues(alpha: 0.4)
                          : Colors.amber.shade600.withValues(alpha: 0.4))
                    : theme.colorScheme.outline.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Clean solid line color bar on left
                Container(width: 5, height: 48, color: lineColor),
                const SizedBox(width: 8),
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shortName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status Dot or Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: statusIcon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
