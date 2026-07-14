import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/route_result.dart';
import '../../models/station.dart';
import '../../models/searchable_item.dart';
import '../../models/custom_location.dart';

import '../../models/crowd_report.dart';
import '../../providers/providers.dart';
import '../search/search_view_model.dart';
import '../favorites/favorites_view_model.dart';
import '../../core/constants/translation_helper.dart';
import '../../providers/route_tracker.dart';

/// Bottom sheet showing detailed route result with dynamic localization
class RouteResultSheet extends ConsumerWidget {
  const RouteResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(searchViewModelProvider.select((s) => s.routeResult));
    final saverRoute = ref.watch(searchViewModelProvider.select((s) => s.saverRoute));
    final regularRoute = ref.watch(searchViewModelProvider.select((s) => s.regularRoute));
    final activeRouteType = ref.watch(searchViewModelProvider.select((s) => s.activeRouteType));
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);
    final crowdService = ref.watch(crowdServiceProvider);
    final scheduleService = ref.watch(scheduleServiceProvider);

    if (result == null) {
      return SizedBox(
        height: 200,
        child: Center(child: Text(t.routeResult.noRouteData)),
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

              // Route Type Selector (Recommended vs Saver)
              if (saverRoute != null) ...[
                const SizedBox(height: 16),
                _buildRouteTypeSelector(context, ref, activeRouteType, regularRoute, saverRoute, theme, t),
              ],

              // Accuracy Warning if overpass failed
              if (result.origin is CustomLocation && (result.origin as CustomLocation).hasAccuracyWarning ||
                  result.destination is CustomLocation && (result.destination as CustomLocation).hasAccuracyWarning) ...[
                const SizedBox(height: 12),
                _buildAccuracyWarningWidget(context, theme, localeCode, t),
              ],

              const SizedBox(height: 24),

              // Route Timeline Segments
              Builder(
                builder: (context) {
                  final transferMap = <String, TransferStep>{};
                  for (final tr in result.transfers) {
                    transferMap['${tr.fromStation.id}-${tr.toStation.id}-${tr.fromLineId}-${tr.toLineId}'] = tr;
                  }
                  return RepaintBoundary(
                    child: Column(
                      children: result.segments.asMap().entries.map((entry) {
                        final i = entry.key;
                        final segment = entry.value;
                        return Column(
                          children: [
                            _buildSegmentCard(context, ref, segment, theme, t, localeCode, crowdService, scheduleService),
                            if (i < result.segments.length - 1)
                              Builder(
                                builder: (context) {
                                  final nextSegment = result.segments[i + 1];
                                  final key = '${segment.toStation.id}-${nextSegment.fromStation.id}-${segment.lineId}-${nextSegment.lineId}';
                                  final matchingTransfer = transferMap[key];
                                  if (matchingTransfer != null) {
                                    return _buildTransferIndicator(
                                      context,
                                      matchingTransfer,
                                      segment,
                                      nextSegment,
                                      theme,
                                      t,
                                      localeCode,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),

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
                label: '~${result.totalMinutes.toInt()} ${t.common.minutesUnit}',
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
                label: '${result.transferCount} ${t.routeResult.transfersCount}',
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
            _buildBookmarkButton(context, ref, result, theme, t, localeCode),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                ref.read(routeTrackerProvider.notifier).startTracking(result, simulation: false);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.navigation_rounded),
              label: Text(t.journey.startJourneyBtn),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(routeTrackerProvider.notifier).startTracking(result, simulation: true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.videogame_asset_outlined),
                label: Text(t.journey.simulateJourneyBtn),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
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
        color: isSaved ? theme.appColors.favoriteColor : null,
      ),
      onPressed: () async {
        if (isSaved) {
          await favoritesRepo.deleteRoute(result.origin.id, result.destination.id);
          ref.read(favoritesViewModelProvider.notifier).refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.routeResult.routeDeletedSuccess)),
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
    
    TextEditingController? controller;

    return showDialog<void>(
      context: context,
      builder: (context) {
        controller ??= TextEditingController(text: '$originName - $destName');
        return AlertDialog(
          title: Text(t.routeResult.saveRouteBtn),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: t.routeResult.routeNameLabel,
              hintText: t.routeResult.routeNameHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.common.cancelBtn),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller!.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(favoritesViewModelProvider.notifier).saveRoute(
                    originId: result.origin.id,
                    destinationId: result.destination.id,
                    originName: result.origin.nameTh,
                    destinationName: result.destination.nameTh,
                    routeName: name,
                    originLat: result.origin.lat,
                    originLng: result.origin.lng,
                    destinationLat: result.destination.lat,
                    destinationLng: result.destination.lng,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.routeResult.routeSavedSuccess)),
                    );
                  }
                }
              },
              child: Text(t.common.saveBtn),
            ),
          ],
        );
      },
    ).whenComplete(() => controller?.dispose());
  }

  Widget _buildRouteTypeSelector(
    BuildContext context,
    WidgetRef ref,
    String activeType,
    RouteResult? recommended,
    RouteResult? saver,
    ThemeData theme,
    AppLocalizations t,
  ) {
    if (recommended == null || saver == null) return const SizedBox.shrink();

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
                      )
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
                    color: theme.colorScheme.onSurface.withValues(alpha: isSelected ? 0.8 : 0.5),
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
          subtitle: recommended.totalDiscountThb > 0
              ? '~${recommended.totalMinutes.toInt()} ${t.common.minutesUnit} · ${recommended.totalFareThb} ${t.common.currencyUnit} (-${recommended.totalDiscountThb} ฿)'
              : '~${recommended.totalMinutes.toInt()} ${t.common.minutesUnit} · ${recommended.totalFareThb} ${t.common.currencyUnit}',
          icon: Icons.star_rounded,
        ),
        const SizedBox(width: 12),
        buildTabButton(
          type: 'saver',
          title: t.routeResult.routeSaver,
          subtitle: saver.totalDiscountThb > 0
              ? '~${saver.totalMinutes.toInt()} ${t.common.minutesUnit} · ${saver.totalFareThb} ${t.common.currencyUnit} (-${saver.totalDiscountThb} ฿)'
              : '~${saver.totalMinutes.toInt()} ${t.common.minutesUnit} · ${saver.totalFareThb} ${t.common.currencyUnit}',
          icon: Icons.savings_rounded,
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
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
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

  Widget _buildSegmentCard(
    BuildContext context,
    WidgetRef ref,
    RouteSegment segment,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
    dynamic crowdService,
    dynamic scheduleService,
  ) {
    if (segment.lineId == 'WALK') {
      return _buildWalkSegmentCard(context, ref, segment, theme, t, localeCode);
    }

    final lineColor = TransitColors.getLineColor(segment.lineId);

    final crowdInfo = crowdService.getCrowdInfo(segment.fromStation.id);
    final minutesUntilNext = scheduleService.getMinutesUntilNextTrain(segment.lineId);

    // Format localized line name and direction label
    final String displayLineName = segment.lineName;
    
    // Parse simulated direction name
    final displayDirection = t.directions.getDirectionLabel(
      segment.lineId,
      segment.boundIndex,
      segment.direction,
    );

    final String trainStatusText;
    if (minutesUntilNext == null) {
      trainStatusText = t.routeResult.serviceEnded;
    } else if (minutesUntilNext == 0) {
      trainStatusText = t.routeResult.trainArriving;
    } else {
      trainStatusText = '${t.routeResult.nextTrain}: ~$minutesUntilNext ${t.common.minutesUnit}';
    }

    String getCrowdLevelText(CrowdLevel level) {
      switch (level) {
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
                    style: TextStyle(
                      color: TransitColors.getLineTextColor(segment.lineId),
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
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
                        color: theme.appColors.timeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trainStatusText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: minutesUntilNext == 0
                              ? Colors.amber.shade700
                              : theme.appColors.timeColor,
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
                        '${t.routeResult.crowdLevel}: ${getCrowdLevelText(crowdInfo.level)} (~${crowdInfo.presenceCount} ${t.common.peopleUnit})',
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
                    '${segment.stationCount} ${t.routeResult.stationsCount} · ~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}',
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

  Widget _buildStationBadge(Station station, String localeCode, ThemeData theme) {
    final lineColor = TransitColors.getLineColor(station.lineId);
    final isEng = localeCode == 'en';
    final name = station.displayName(isEnglish: isEng);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$name (${station.code})',
        style: TextStyle(
          color: TransitColors.getLineTextColor(station.lineId),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildWalkSegmentCard(
    BuildContext context,
    WidgetRef ref,
    RouteSegment segment,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final fromStation = segment.fromStation;
    final toStation = segment.toStation;
    final timeStr = '~${segment.estimatedMinutes.toInt()} ${t.common.minutesUnit}';
    final customInstruction = localeCode == 'en'
        ? (segment.instructionsEn ?? segment.instructionsTh)
        : (segment.instructionsTh ?? segment.instructionsEn);
    
    Widget buildLocationSpan(SearchableItem item) {
      if (item is Station) {
        return _buildStationBadge(item, localeCode, theme);
      } else {
        return Text(
          item.displayName(isEnglish: localeCode == 'en'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        );
      }
    }

    Widget buildSubtitleLocationSpan(SearchableItem item) {
      if (item is Station) {
        return _buildStationBadge(item, localeCode, theme);
      } else {
        return Text(
          item.displayName(isEnglish: localeCode == 'en'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        );
      }
    }

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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        t.routeResult.walkTo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      buildLocationSpan(toStation),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        t.routeResult.fromLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      buildSubtitleLocationSpan(fromStation),
                      if (fromStation is Station && segment.exit != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t.routeResult.exitLabel(segment.exit!.exitCode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        '· $timeStr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  if (customInstruction != null && customInstruction.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              customInstruction,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      return toUpper ? t.transfers.transferThaphraUp : t.transfers.transferThaphraDown;
    }

    // ─── Case 2: Siam (BTS Sukhumvit <-> Silom) ───
    if ((fromId == 'BTS_CEN' && toId == 'BTS_CEN_SILOM') || (fromId == 'BTS_CEN_SILOM' && toId == 'BTS_CEN')) {
      int arrivalFloor = 3;
      if (prevSegment.lineId == 'BTS_SUKHUMVIT' || prevSegment.lineId == 'BTS_SILOM') {
        arrivalFloor = prevSegment.boundIndex == 1 ? 4 : 3;
      }

      int departureFloor = 3;
      if (nextSegment.lineId == 'BTS_SUKHUMVIT' || nextSegment.lineId == 'BTS_SILOM') {
        departureFloor = nextSegment.boundIndex == 1 ? 4 : 3;
      }

      if (arrivalFloor == departureFloor) {
        return t.transfers.transferSiamSameLevel(arrivalFloor);
      } else {
        return departureFloor == 3 ? t.transfers.transferSiamUp : t.transfers.transferSiamDown;
      }
    }

    // ─── Case 3: Other Same-Name Interchanges ───
    final stationId = transfer.fromStation.id;
    final toLine = transfer.toLineId;

    final targetStationName = localeCode == 'th' ? transfer.toStation.nameTh : transfer.toStation.nameEn;

    // Sukhumvit (MRT_BL22) <-> Asok (BTS_E4)
    if ((stationId == 'MRT_BL22' && toId == 'BTS_E4') || (stationId == 'BTS_E4' && toId == 'MRT_BL22')) {
      return t.transfers.transferAsokSukhumvit(targetStationName);
    }

    // Si Lom (MRT_BL26) <-> Sala Daeng (BTS_S2)
    if ((stationId == 'MRT_BL26' && toId == 'BTS_S2') || (stationId == 'BTS_S2' && toId == 'MRT_BL26')) {
      final exitNum = stationId == 'MRT_BL26' ? '2' : '4';
      return t.transfers.transferSilomSaladaeng(targetStationName, exitNum);
    }

    // Chatuchak Park (MRT_BL13) <-> Mo Chit (BTS_N8)
    if ((stationId == 'MRT_BL13' && toId == 'BTS_N8') || (stationId == 'BTS_N8' && toId == 'MRT_BL13')) {
      final exits = stationId == 'MRT_BL13'
          ? (localeCode == 'th' ? '1 หรือ 2' : '1 or 2')
          : (localeCode == 'th' ? '1 หรือ 3' : '1 or 3');
      return t.transfers.transferMoChitChatuchak(targetStationName, exits);
    }

    // Lat Phrao (Blue <-> Yellow)
    if (stationId == 'MRT_BL15' || stationId == 'MRT_YL01') {
      return toLine == 'MRT_YELLOW' ? t.transfers.transferLatphraoYellow : t.transfers.transferLatphraoBlue;
    }

    // Phaya Thai (BTS <-> ARL)
    if (stationId == 'BTS_N2' || stationId == 'ARL_A8') {
      return t.transfers.transferPhayathai;
    }

    // Samrong (BTS <-> Yellow)
    if (stationId == 'BTS_E15' || stationId == 'MRT_YL23') {
      return t.transfers.transferSamrong;
    }

    // Hua Mak (ARL <-> Yellow)
    if (stationId == 'ARL_A4' || stationId == 'MRT_YL11') {
      return t.transfers.transferHuamak;
    }

    // ─── Case 4: Default Walk ───
    return t.transfers.interchangeWalk(transfer.walkingMinutes.toInt());
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    Text(
                      '${s.fareThb} ${t.common.currencyUnit}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: hasSegmentDiscount ? Colors.green.shade600 : null,
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

  Widget _buildAccuracyWarningWidget(
    BuildContext context,
    ThemeData theme,
    String localeCode,
    AppLocalizations t,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.routeResult.accuracyWarning,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.routeResult.accuracyBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showReportDialog(context, localeCode, theme, t),
                  child: Text(
                    t.routeResult.reportIssueLink,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(
    BuildContext context,
    String localeCode,
    ThemeData theme,
    AppLocalizations t,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t.routeResult.reportDialogTitle,
        ),
        content: Text(
          t.routeResult.reportDialogBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.cancelBtn),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    t.routeResult.reportSuccess,
                  ),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            child: Text(t.utility.submitReportBtn),
          ),
        ],
      ),
    );
  }
}
