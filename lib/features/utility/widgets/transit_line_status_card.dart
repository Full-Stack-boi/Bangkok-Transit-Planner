import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../services/transit_news_service.dart';

class TransitLineStatusCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final lineColor = TransitColors.getLineColor(item.lineId);

    Widget statusIcon;
    Color statusColor;

    if (item.isNormal) {
      statusIcon = const Icon(
        Icons.check_circle_rounded,
        size: 14,
        color: Colors.green,
      );
      statusColor = Colors.green;
    } else if (item.statusTh.contains('รอยืนยัน') || item.statusEn.contains('Pending')) {
      statusIcon = Icon(
        Icons.warning_rounded,
        size: 14,
        color: Colors.amber.shade700,
      );
      statusColor = Colors.amber.shade800;
    } else {
      statusIcon = Icon(
        Icons.error_rounded,
        size: 14,
        color: Colors.red.shade700,
      );
      statusColor = Colors.red.shade700;
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

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Vertical line indicator on the left (4px)
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
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
                  t.isTh ? item.statusTh : item.statusEn,
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
            padding: const EdgeInsets.only(right: 8.0),
            child: statusIcon,
          ),
        ],
      ),
    );
  }
}
