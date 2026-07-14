import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/translation_helper.dart';
import '../../providers/providers.dart';
import 'route_calculating_overlay.dart';
import 'widgets/status_dashboard.dart';
import 'widgets/news_section.dart';
import 'widgets/transit_card_row.dart';
import 'widgets/manual_report_card.dart';

class UtilityScreen extends ConsumerWidget {
  const UtilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);

    final cardState = ref.watch(userCardsProvider);
    final mockLocation = ref.watch(mockLocationProvider);

    final statusesAsync = ref.watch(transitLineStatusProvider);
    final newsAsync = ref.watch(drtNewsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.common.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── PART 1: TRANSIT STATUS DASHBOARD (GRID) ───
          statusesAsync.when(
            data: (statuses) =>
                StatusDashboard(theme: theme, t: t, statuses: statuses),
            loading: () => _buildStatusShimmer(theme, t),
            error: (err, stack) => _buildErrorCard(ref, t, theme),
          ),
          const SizedBox(height: 24),

          // ─── PART 2: COMPACT TRANSIT CARDS & PASSES (GRID) ───
          TransitCardRow(theme: theme, t: t, cardState: cardState),
          const SizedBox(height: 24),

          // ─── PART 2.5: MANUAL REPORT ACTION ───
          ManualReportCard(theme: theme, t: t),
          const SizedBox(height: 28),

          // ─── PART 3: NEWS & ANNOUNCEMENTS (NOW HIGHLY VISIBLE & ASYNC) ───
          newsAsync.when(
            data: (articles) =>
                NewsSection(theme: theme, t: t, articles: articles),
            loading: () => _buildNewsShimmer(theme, t),
            error: (err, stack) => _buildErrorCard(ref, t, theme),
          ),
          const SizedBox(height: 24),

          // ─── PART 4: MOCK LOCATION SETUP (DEBUG MODE ONLY) ───
          if (kDebugMode) ...[
            _buildDebugMockLocationCard(context, ref, mockLocation, theme, t),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusShimmer(ThemeData theme, AppLocalizations t) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.utility.statusSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
                mainAxisExtent: 52,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Left vertical line indicator skeleton (static translucent line)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text info skeletons
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            ShimmerPlaceholder(
                              width: 60,
                              height: 10,
                              borderRadius: 99,
                            ),
                            SizedBox(height: 4),
                            ShimmerPlaceholder(
                              width: 40,
                              height: 8,
                              borderRadius: 99,
                            ),
                          ],
                        ),
                      ),
                      // Status Circle Icon placeholder on the right
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: ShimmerPlaceholder(
                          width: 14,
                          height: 14,
                          borderRadius: 7,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsShimmer(ThemeData theme, AppLocalizations t) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.utility.newsSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          2,
          (index) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left indicator skeleton line
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerPlaceholder(
                          width: 150,
                          height: 12,
                          borderRadius: 99,
                        ),
                        SizedBox(height: 6),
                        ShimmerPlaceholder(
                          width: 220,
                          height: 8,
                          borderRadius: 99,
                        ),
                        SizedBox(height: 4),
                        ShimmerPlaceholder(
                          width: 120,
                          height: 8,
                          borderRadius: 99,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugMockLocationCard(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    AppLocalizations t,
  ) {
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: const Icon(Icons.bug_report_outlined, color: Colors.orange),
        title: Text(t.utility.debugSimGpsTitle),
        subtitle: Text(
          mockPos != null
              ? t.utility.debugSimGpsActive(
                  mockPos.latitude.toStringAsFixed(4),
                  mockPos.longitude.toStringAsFixed(4),
                )
              : t.utility.debugSimGpsDisabled,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            _showLocationSimulationDialog(context, ref, mockPos, theme, t),
      ),
    );
  }

  void _showLocationSimulationDialog(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    AppLocalizations t,
  ) {
    final transitRepo = ref.read(transitRepositoryProvider);
    final stations = transitRepo.stations;

    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = stations.where((s) {
              final query = searchQuery.toLowerCase();
              return s.nameEn.toLowerCase().contains(query) ||
                  s.nameTh.contains(query) ||
                  s.id.toLowerCase().contains(query);
            }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.bug_report_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(t.utility.debugSimGpsDialogTitle),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: t.search.searchPlaceholder,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (mockPos != null)
                      ListTile(
                        leading: const Icon(
                          Icons.gps_off_rounded,
                          color: Colors.red,
                        ),
                        title: Text(t.utility.debugSimGpsDisableOption),
                        subtitle: Text(t.utility.debugSimGpsDisableSubtitle),
                        onTap: () {
                          ref
                              .read(mockLocationProvider.notifier)
                              .clearMockLocation();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.utility.debugSimGpsDisabledSnack),
                            ),
                          );
                        },
                      ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final station = filtered[index];
                          final isCurrent =
                              mockPos != null &&
                              (mockPos.latitude - station.lat).abs() < 0.0001 &&
                              (mockPos.longitude - station.lng).abs() < 0.0001;

                          return ListTile(
                            leading: Icon(
                              Icons.directions_transit_rounded,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: Text(
                              t.isTh ? station.nameTh : station.nameEn,
                            ),
                            subtitle: Text(
                              '${station.id} \u2022 ${station.lat.toStringAsFixed(4)}, ${station.lng.toStringAsFixed(4)}',
                            ),
                            trailing: isCurrent
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                  )
                                : null,
                            onTap: () {
                              ref
                                  .read(mockLocationProvider.notifier)
                                  .setMockLocation(station.lat, station.lng);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    t.utility.debugSimGpsEnabledSnack(
                                      t.isTh ? station.nameTh : station.nameEn,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorCard(WidgetRef ref, AppLocalizations t, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.utility.errorLoadingStatus,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
