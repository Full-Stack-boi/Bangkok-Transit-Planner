import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/route_result.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/providers.dart';
import '../../search/search_view_model.dart';

class RouteTypeSelector extends ConsumerWidget {
  final String activeType;
  final RouteResult? recommended;
  final RouteResult? saver;
  final ThemeData theme;
  final AppLocalizations t;

  const RouteTypeSelector({
    super.key,
    required this.activeType,
    required this.recommended,
    required this.saver,
    required this.theme,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recommended == null || saver == null) return const SizedBox.shrink();

    final localeCode = ref.watch(localeProvider);

    final recDuration = Formatters.formatDuration(
      recommended!.totalMinutes,
      localeCode,
    );
    final saverDuration = Formatters.formatDuration(
      saver!.totalMinutes,
      localeCode,
    );

    Widget buildTabButton({
      required String type,
      required String title,
      required String subtitle,
      required IconData icon,
    }) {
      final isSelected = activeType == type;
      return Expanded(
        child: InkWell(
          onTap: () {
            ref.read(searchViewModelProvider.notifier).selectRouteType(type);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isSelected ? 0.8 : 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTabButton(
          type: 'recommended',
          title: t.routeResult.routeRecommended,
          subtitle: recommended!.totalDiscountThb > 0
              ? '$recDuration · ${recommended!.totalFareThb} ${t.common.currencyUnit} (-${recommended!.totalDiscountThb} ฿)'
              : '$recDuration · ${recommended!.totalFareThb} ${t.common.currencyUnit}',
          icon: Icons.star_rounded,
        ),
        const SizedBox(width: 12),
        buildTabButton(
          type: 'saver',
          title: t.routeResult.routeSaver,
          subtitle: saver!.totalDiscountThb > 0
              ? '$saverDuration · ${saver!.totalFareThb} ${t.common.currencyUnit} (-${saver!.totalDiscountThb} ฿)'
              : '$saverDuration · ${saver!.totalFareThb} ${t.common.currencyUnit}',
          icon: Icons.savings_rounded,
        ),
      ],
    );
  }
}
