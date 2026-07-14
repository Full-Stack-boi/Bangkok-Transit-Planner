import 'package:flutter/material.dart';
import '../../models/crowd_report.dart';
import '../../core/constants/translation_helper.dart';

extension CrowdLevelLabel on CrowdLevel {
  String getLabel(AppLocalizations t) {
    switch (this) {
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

  Color getColor() {
    switch (this) {
      case CrowdLevel.high:
        return Colors.red;
      case CrowdLevel.medium:
        return Colors.orange;
      case CrowdLevel.low:
      case CrowdLevel.unknown:
        return Colors.green;
    }
  }

  Color getTextColor() {
    switch (this) {
      case CrowdLevel.high:
        return Colors.red.shade400;
      case CrowdLevel.medium:
        return Colors.orange.shade400;
      case CrowdLevel.low:
      case CrowdLevel.unknown:
        return Colors.green.shade400;
    }
  }
}

class CrowdLevelBadge extends StatelessWidget {
  final StationCrowdInfo crowdInfo;
  final ThemeData theme;
  final AppLocalizations t;

  const CrowdLevelBadge({
    super.key,
    required this.crowdInfo,
    required this.theme,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final level = crowdInfo.level;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.people_outline_rounded, size: 14, color: level.getColor()),
        const SizedBox(width: 4),
        Text(
          '${t.routeResult.crowdLevel}: ${level.getLabel(t)} (~${crowdInfo.presenceCount} ${t.common.peopleUnit})',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: level.getTextColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
