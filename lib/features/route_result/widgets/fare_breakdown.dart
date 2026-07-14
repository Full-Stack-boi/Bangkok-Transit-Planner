import 'package:flutter/material.dart';
import '../../../models/route_result.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../core/constants/translation_helper.dart';

class FareBreakdown extends StatelessWidget {
  final RouteResult result;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;

  const FareBreakdown({
    super.key,
    required this.result,
    required this.theme,
    required this.t,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.routeResult.fareTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.segments.map((s) {
              final lineColor = TransitColors.getLineColor(s.lineId);
              final hasSegmentDiscount = s.standardFareThb > s.fareThb;
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
                    if (hasSegmentDiscount) ...[
                      Text(
                        '${s.standardFareThb} ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    Text(
                      '${s.fareThb} ${t.common.currencyUnit}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: hasSegmentDiscount
                            ? Colors.green.shade600
                            : null,
                        fontWeight: hasSegmentDiscount ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (result.totalDiscountThb > 0) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.routeResult.cardDiscount,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '-${result.totalDiscountThb} ${t.common.currencyUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.common.total, style: theme.textTheme.titleMedium),
                Text(
                  '${result.totalFareThb} ${t.common.currencyUnit}',
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
