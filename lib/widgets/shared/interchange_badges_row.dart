import 'package:flutter/material.dart';
import '../../repositories/transit_repository.dart';
import 'station_badge.dart';

/// Reusable widget for displaying a row of interchange station badges
class InterchangeBadgesRow extends StatelessWidget {
  final List<String> interchangeStationIds;
  final TransitRepository transitRepo;
  final String? labelText;
  final TextStyle? labelStyle;
  final double spacing;

  const InterchangeBadgesRow({
    super.key,
    required this.interchangeStationIds,
    required this.transitRepo,
    this.labelText,
    this.labelStyle,
    this.spacing = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (interchangeStationIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultLabelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null && labelText!.isNotEmpty) ...[
          Text(labelText!, style: labelStyle ?? defaultLabelStyle),
          SizedBox(width: spacing),
        ],
        Wrap(
          spacing: spacing,
          children: interchangeStationIds.map((id) {
            final connStation = transitRepo.getStation(id);
            if (connStation == null) {
              return const SizedBox.shrink();
            }
            return StationBadge.pill(
              text: connStation.code,
              lineId: connStation.lineId,
            );
          }).toList(),
        ),
      ],
    );
  }
}
