import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/custom_location.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class RouteResultBanner extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localeCode = ref.watch(localeProvider);
    final hasWarning =
        (result.origin is CustomLocation &&
            (result.origin as CustomLocation).hasAccuracyWarning) ||
        (result.destination is CustomLocation &&
            (result.destination as CustomLocation).hasAccuracyWarning);

    final durationText = Formatters.formatDuration(
      (result.totalMinutes as num).toDouble(),
      localeCode,
    );

    return Card(
      color: hasWarning
          ? Colors.amber.withValues(alpha: 0.1)
          : (theme.appColors.routeColor ?? const Color(0xFF818CF8)).withValues(
              alpha: 0.1,
            ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                hasWarning ? Icons.warning_amber_rounded : Icons.route_rounded,
                color: hasWarning
                    ? Colors.amber[800]
                    : (theme.appColors.routeColor ?? const Color(0xFF818CF8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.totalDiscountThb > 0
                          ? '$durationText · ${result.totalFareThb} ${t.common.currencyUnit} (-${result.totalDiscountThb} ฿)'
                          : '$durationText · ${result.totalFareThb} ${t.common.currencyUnit}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
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
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
