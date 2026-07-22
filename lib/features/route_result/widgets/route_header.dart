import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/route_result.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/route_tracker.dart';
import 'bookmark_button.dart';

class RouteHeader extends ConsumerWidget {
  final RouteResult result;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;

  const RouteHeader({
    super.key,
    required this.result,
    required this.theme,
    required this.t,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originName = localeCode == 'th'
        ? result.origin.nameTh
        : result.origin.nameEn;
    final destName = localeCode == 'th'
        ? result.destination.nameTh
        : result.destination.nameEn;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Flexible(
              child: _buildInfoChip(
                icon: Icons.timer_outlined,
                label: Formatters.formatDuration(
                  result.totalMinutes,
                  localeCode,
                ),
                theme: theme,
                iconColor: theme.appColors.timeColor,
              ),
            ),
            Flexible(
              child: _buildInfoChip(
                icon: Icons.payments_outlined,
                label: result.totalDiscountThb > 0
                    ? '${result.totalFareThb} ${t.common.currencyUnit} (-${result.totalDiscountThb} ฿)'
                    : '${result.totalFareThb} ${t.common.currencyUnit}',
                theme: theme,
                iconColor: theme.appColors.moneyColor,
              ),
            ),
            Flexible(
              child: _buildInfoChip(
                icon: Icons.swap_horiz_rounded,
                label:
                    '${result.transferCount} ${t.routeResult.transfersCount}',
                theme: theme,
                iconColor: theme.appColors.routeColor,
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
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  children: [
                    TextSpan(text: originName),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    TextSpan(text: destName),
                  ],
                ),
              ),
            ),
            BookmarkButton(
              result: result,
              theme: theme,
              t: t,
              localeCode: localeCode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(routeTrackerProvider.notifier)
                    .startTracking(result, simulation: false);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(t.journey.startJourneyBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref
                      .read(routeTrackerProvider.notifier)
                      .startTracking(result, simulation: true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.videogame_asset_outlined),
                label: Text(t.journey.simulateJourneyBtn),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? theme.colorScheme.primary),
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
}
