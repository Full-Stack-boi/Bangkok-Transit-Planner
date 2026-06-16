import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/translation_helper.dart';
import '../../core/theme/transit_colors.dart';
import '../../providers/providers.dart';
import '../../services/transit_news_service.dart';

class UtilityScreen extends ConsumerWidget {
  const UtilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);

    final cardState = ref.watch(userCardsProvider);
    final newsService = ref.watch(transitNewsServiceProvider);
    final mockLocation = ref.watch(mockLocationProvider);

    final lineStatuses = newsService.getLineStatuses();
    final newsArticles = newsService.getNewsArticles();

    return Scaffold(
      appBar: AppBar(
        title: Text(t.common.appTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── PART 1: TRANSIT STATUS DASHBOARD ───
          _buildStatusDashboard(theme, t, lineStatuses),
          const SizedBox(height: 24),

          // ─── PART 2: NEWS & ANNOUNCEMENTS (NOW HIGHLY VISIBLE) ───
          _buildNewsSection(theme, t, newsArticles),
          const SizedBox(height: 24),

          // ─── PART 3: COMPACT TRANSIT CARDS & PASSES CONFIGURATION ───
          _buildCompactCardsRow(context, ref, cardState, theme, t),
          const SizedBox(height: 28),

          // ─── PART 4: MOCK LOCATION SETUP (DEBUG MODE ONLY) ───
          if (kDebugMode) ...[
            _buildDebugMockLocationCard(context, ref, mockLocation, theme, t),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDashboard(
    ThemeData theme,
    AppLocalizations t,
    List<TransitLineStatus> statuses,
  ) {
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
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: statuses.length,
            itemBuilder: (context, index) {
              final item = statuses[index];
              final lineColor = TransitColors.getLineColor(item.lineId);
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: lineColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.isTh ? item.lineNameTh : item.lineNameEn,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          item.isNormal
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: item.isNormal ? Colors.green : Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            t.isTh ? item.statusTh : item.statusEn,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: item.isNormal ? Colors.green : Colors.amber.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewsSection(
    ThemeData theme,
    AppLocalizations t,
    List<TransitNewsArticle> articles,
  ) {
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
        ...articles.map((item) {
          final lineColor = TransitColors.getLineColor(item.lineId);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.isTh ? item.titleTh : item.titleEn,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.isTh ? item.bodyTh : item.bodyEn,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompactCardsRow(
    BuildContext context,
    WidgetRef ref,
    UserCardsState cardState,
    ThemeData theme,
    AppLocalizations t,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Available width = screen width minus outer horizontal padding (16 * 2)
    // 0.44 allows 2 cards to fit fully with margins and the third card to poke out by ~15-20px
    final cardWidth = ((screenWidth - 32) * 0.44).clamp(130.0, 200.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.utility.cardsSectionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.utility.cardsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCompactCardPreview(
                context: context,
                ref: ref,
                theme: theme,
                t: t,
                networkId: 'BTS',
                cardName: t.utility.rabbitCardName,
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                activeType: cardState.btsCardType,
                options: [
                  _CardOption(
                    value: 'standard',
                    title: t.utility.optionStandardTitle,
                    subtitle: t.utility.optionStandardSubtitle,
                  ),
                  _CardOption(
                    value: 'student',
                    title: t.utility.optionStudentTitle,
                    subtitle: t.utility.optionStudentBtsSubtitle,
                  ),
                  _CardOption(
                    value: 'senior',
                    title: t.utility.optionSeniorTitle,
                    subtitle: t.utility.optionSeniorBtsSubtitle,
                  ),
                  _CardOption(
                    value: 'trip_package',
                    title: t.utility.optionTripPackageTitle,
                    subtitle: t.utility.optionTripPackageBtsSubtitle,
                  ),
                ],
                width: cardWidth,
              ),
              _buildCompactCardPreview(
                context: context,
                ref: ref,
                theme: theme,
                t: t,
                networkId: 'MRT',
                cardName: t.utility.mrtCardName,
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                activeType: cardState.mrtCardType,
                options: [
                  _CardOption(
                    value: 'standard',
                    title: t.utility.optionStandardTitle,
                    subtitle: t.utility.optionStandardSubtitle,
                  ),
                  _CardOption(
                    value: 'student',
                    title: t.utility.optionStudentTitle,
                    subtitle: t.utility.optionStudentMrtSubtitle,
                  ),
                  _CardOption(
                    value: 'senior',
                    title: t.utility.optionSeniorTitle,
                    subtitle: t.utility.optionSeniorMrtSubtitle,
                  ),
                ],
                width: cardWidth,
              ),
              _buildCompactCardPreview(
                context: context,
                ref: ref,
                theme: theme,
                t: t,
                networkId: 'ARL',
                cardName: t.utility.arlCardName,
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                activeType: cardState.arlCardType,
                options: [
                  _CardOption(
                    value: 'standard',
                    title: t.utility.optionStandardTitle,
                    subtitle: t.utility.optionStandardSubtitle,
                  ),
                  _CardOption(
                    value: 'student',
                    title: t.utility.optionStudentTitle,
                    subtitle: t.utility.optionStudentArlSubtitle,
                  ),
                  _CardOption(
                    value: 'senior',
                    title: t.utility.optionSeniorTitle,
                    subtitle: t.utility.optionSeniorArlSubtitle,
                  ),
                ],
                width: cardWidth,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCardPreview({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required AppLocalizations t,
    required String networkId,
    required String cardName,
    required Gradient gradient,
    required String activeType,
    required List<_CardOption> options,
    required double width,
  }) {
    final activeOption = options.firstWhere(
      (opt) => opt.value == activeType,
      orElse: () => options.first,
    );

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _showCardDetailsBottomSheet(
              context: context,
              ref: ref,
              theme: theme,
              networkId: networkId,
              cardName: cardName,
              gradient: gradient,
              activeType: activeType,
              options: options,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        cardName.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.credit_card_rounded, color: Colors.white70, size: 12),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeOption.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeOption.subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCardDetailsBottomSheet({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required String networkId,
    required String cardName,
    required Gradient gradient,
    required String activeType,
    required List<_CardOption> options,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _CardDetailBottomSheetContent(
          theme: theme,
          networkId: networkId,
          cardName: cardName,
          gradient: gradient,
          initialActiveType: activeType,
          options: options,
        );
      },
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
        side: BorderSide(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
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
        onTap: () => _showLocationSimulationDialog(context, ref, mockPos, theme, t),
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
                      decoration: const InputDecoration(
                        hintText: 'Search station...',
                        prefixIcon: Icon(Icons.search),
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
                        leading: const Icon(Icons.gps_off_rounded, color: Colors.red),
                        title: Text(t.utility.debugSimGpsDisableOption),
                        subtitle: Text(t.utility.debugSimGpsDisableSubtitle),
                        onTap: () {
                          ref.read(mockLocationProvider.notifier).clearMockLocation();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t.utility.debugSimGpsDisabledSnack)),
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
                          final isCurrent = mockPos != null &&
                              (mockPos.latitude - station.lat).abs() < 0.0001 &&
                              (mockPos.longitude - station.lng).abs() < 0.0001;

                          return ListTile(
                            leading: Icon(
                              Icons.directions_transit_rounded,
                              color: isCurrent ? theme.colorScheme.primary : null,
                            ),
                            title: Text(t.isTh ? station.nameTh : station.nameEn),
                            subtitle: Text('${station.id} \u2022 ${station.lat.toStringAsFixed(4)}, ${station.lng.toStringAsFixed(4)}'),
                            trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Colors.green) : null,
                            onTap: () {
                              ref.read(mockLocationProvider.notifier).setMockLocation(station.lat, station.lng);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t.utility.debugSimGpsEnabledSnack(
                                    t.isTh ? station.nameTh : station.nameEn,
                                  )),
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
}

class _CardDetailBottomSheetContent extends ConsumerStatefulWidget {
  final ThemeData theme;
  final String networkId;
  final String cardName;
  final Gradient gradient;
  final String initialActiveType;
  final List<_CardOption> options;

  const _CardDetailBottomSheetContent({
    required this.theme,
    required this.networkId,
    required this.cardName,
    required this.gradient,
    required this.initialActiveType,
    required this.options,
  });

  @override
  ConsumerState<_CardDetailBottomSheetContent> createState() =>
      _CardDetailBottomSheetContentState();
}

class _CardDetailBottomSheetContentState
    extends ConsumerState<_CardDetailBottomSheetContent> {
  late String _activeType;

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialActiveType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    Color networkColor = Colors.green.shade600;
    if (widget.networkId == 'MRT') networkColor = Colors.blue.shade700;
    if (widget.networkId == 'ARL') networkColor = Colors.red.shade700;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: RadioGroup<String>(
          groupValue: _activeType,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _activeType = val;
              });
              ref
                  .read(userCardsProvider.notifier)
                  .setCardType(widget.networkId, val);
              Future.delayed(const Duration(milliseconds: 150), () {
                if (context.mounted) {
                  Navigator.pop(context);
                }
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: networkColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.cardName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...widget.options.map((opt) {
                final isSelected = opt.value == _activeType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeType = opt.value;
                      });
                      ref
                          .read(userCardsProvider.notifier)
                          .setCardType(widget.networkId, opt.value);
                      // Short delay to show ripple animation before auto closing
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? networkColor.withValues(alpha: 0.08)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? networkColor
                              : theme.colorScheme.outline.withValues(alpha: 0.12),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? networkColor : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  opt.subtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isSelected
                                        ? networkColor.withValues(alpha: 0.8)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: opt.value,
                            activeColor: networkColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardOption {
  final String value;
  final String title;
  final String subtitle;

  const _CardOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}
