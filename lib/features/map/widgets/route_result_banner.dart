import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';

class RouteResultBanner extends StatelessWidget {
  final dynamic result;
  final AppLocalizations t;
  final VoidCallback onTap;

  const RouteResultBanner({
    super.key,
    required this.result,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.route_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.totalDiscountThb > 0
                          ? '~${result.totalMinutes.toInt()} ${t.common.minutesUnit} · ${result.totalFareThb} ${t.common.currencyUnit} (-${result.totalDiscountThb} ฿)'
                          : '~${result.totalMinutes.toInt()} ${t.common.minutesUnit} · ${result.totalFareThb} ${t.common.currencyUnit}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${result.segments.length} ${t.routeResult.linesCount} · ${result.transferCount} ${t.routeResult.transfersCount} · ${result.totalStations} ${t.routeResult.stationsCount}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
