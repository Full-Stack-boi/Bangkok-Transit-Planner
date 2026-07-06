import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/translation_helper.dart';
import '../../core/theme/transit_colors.dart';
import '../../providers/providers.dart';
import '../../services/transit_news_service.dart';
import '../../models/station.dart';
import 'route_calculating_overlay.dart';

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
      appBar: AppBar(
        title: Text(t.common.appTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── PART 1: TRANSIT STATUS DASHBOARD (GRID) ───
          statusesAsync.when(
            data: (statuses) => _buildStatusDashboard(theme, t, statuses),
            loading: () => _buildStatusShimmer(theme, t),
            error: (err, stack) => _buildErrorCard(ref, t, theme),
          ),
          const SizedBox(height: 24),

          // ─── PART 2: COMPACT TRANSIT CARDS & PASSES (GRID) ───
          _buildCompactCardsRow(context, ref, cardState, theme, t),
          const SizedBox(height: 24),

          // ─── PART 2.5: MANUAL REPORT ACTION ───
          _buildManualReportActionCard(context, ref, theme, t),
          const SizedBox(height: 28),

          // ─── PART 3: NEWS & ANNOUNCEMENTS (NOW HIGHLY VISIBLE & ASYNC) ───
          newsAsync.when(
            data: (articles) => _buildNewsSection(context, theme, t, articles),
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
                            ShimmerPlaceholder(width: 60, height: 10, borderRadius: 99),
                            SizedBox(height: 4),
                            ShimmerPlaceholder(width: 40, height: 8, borderRadius: 99),
                          ],
                        ),
                      ),
                      // Status Circle Icon placeholder on the right
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: ShimmerPlaceholder(width: 14, height: 14, borderRadius: 7),
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
        ...List.generate(2, (index) => Card(
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
                      ShimmerPlaceholder(width: 150, height: 12, borderRadius: 99),
                      SizedBox(height: 6),
                      ShimmerPlaceholder(width: 220, height: 8, borderRadius: 99),
                      SizedBox(height: 4),
                      ShimmerPlaceholder(width: 120, height: 8, borderRadius: 99),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
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
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final item = statuses[index];
                final lineColor = TransitColors.getLineColor(item.lineId);

                Widget statusIcon;
                Color statusColor;

                if (item.isNormal) {
                  statusIcon = const Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Colors.green,
                  );
                  statusColor = Colors.green;
                } else if (item.statusTh.contains('รอยืนยัน') || item.statusEn.contains('Pending')) {
                  statusIcon = Icon(
                    Icons.warning_rounded,
                    size: 14,
                    color: Colors.amber.shade700,
                  );
                  statusColor = Colors.amber.shade800;
                } else {
                  statusIcon = Icon(
                    Icons.error_rounded,
                    size: 14,
                    color: Colors.red.shade700,
                  );
                  statusColor = Colors.red.shade700;
                }

                String getShortLineName(String id, bool isTh) {
                  switch (id) {
                    case 'BTS_SUKHUMVIT':
                      return isTh ? 'สุขุมวิท' : 'Sukhumvit';
                    case 'BTS_SILOM':
                      return isTh ? 'สีลม' : 'Silom';
                    case 'MRT_BLUE':
                      return isTh ? 'สายสีน้ำเงิน' : 'Blue Line';
                    case 'MRT_PURPLE':
                      return isTh ? 'สายสีม่วง' : 'Purple Line';
                    case 'MRT_YELLOW':
                      return isTh ? 'สายสีเหลือง' : 'Yellow Line';
                    case 'MRT_PINK':
                      return isTh ? 'สายสีชมพู' : 'Pink Line';
                    case 'ARL':
                      return isTh ? 'แอร์พอร์ตลิงก์' : 'ARL';
                    case 'SRT_RED_NORTH':
                      return isTh ? 'สายสีแดง' : 'Red Line';
                    default:
                      return isTh ? item.lineNameTh : item.lineNameEn;
                  }
                }

                final shortName = getShortLineName(item.lineId, t.isTh);

                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Vertical line indicator on the left (4px)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              shortName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.isTh ? item.statusTh : item.statusEn,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Status Dot or Icon
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: statusIcon,
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

  void _showNewsDetailsBottomSheet(
    BuildContext context,
    ThemeData theme,
    AppLocalizations t,
    TransitNewsArticle article,
  ) {
    final lineColor = TransitColors.getLineColor(article.lineId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.utility.officialAnnouncementTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                t.isTh ? article.titleTh : (article.titleEn.isNotEmpty ? article.titleEn : article.titleTh),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                article.date.toLocal().toString().split('.')[0],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 24),
              Text(
                t.isTh ? article.bodyTh : (article.bodyEn.isNotEmpty ? article.bodyEn : article.bodyTh),
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewsSection(
    BuildContext context,
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
        if (articles.isEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.utility.noNewsAnnouncements,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...articles.map((item) {
          final lineColor = TransitColors.getLineColor(item.lineId);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showNewsDetailsBottomSheet(context, theme, t, item),
              borderRadius: BorderRadius.circular(12),
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
                            t.isTh ? item.titleTh : (item.titleEn.isNotEmpty ? item.titleEn : item.titleTh),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.isTh ? item.bodyTh : (item.bodyEn.isNotEmpty ? item.bodyEn : item.bodyTh),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
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
                ),
                _buildCompactCardPreview(
                  context: context,
                  ref: ref,
                  theme: theme,
                  t: t,
                  networkId: 'SRT',
                  cardName: t.utility.srtCardName,
                  gradient: LinearGradient(
                    colors: [Colors.red.shade800, Colors.red.shade900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  activeType: cardState.srtCardType,
                  options: [
                    _CardOption(
                      value: 'standard',
                      title: t.utility.optionStandardTitle,
                      subtitle: t.utility.optionStandardSubtitle,
                    ),
                    _CardOption(
                      value: 'student',
                      title: t.utility.optionStudentTitle,
                      subtitle: t.utility.optionStudentSrtSubtitle,
                    ),
                    _CardOption(
                      value: 'senior',
                      title: t.utility.optionSeniorTitle,
                      subtitle: t.utility.optionSeniorSrtSubtitle,
                    ),
                  ],
                ),
              ],
            ),
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
  }) {
    final activeOption = options.firstWhere(
      (opt) => opt.value == activeType,
      orElse: () => options.first,
    );

    return Card(
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

  Widget _buildManualReportActionCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations t,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () {
          _showManualReportBottomSheet(context, ref, theme, t);
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.utility.reportDelayTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.isTh 
                          ? 'ร่วมแจ้งความหนาแน่นและสถานะชานชาลารถไฟเพื่อแชร์แก่เพื่อนผู้โดยสาร' 
                          : 'Share delay and platform crowding info with other commuters.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualReportBottomSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AppLocalizations t,
  ) {
    final transitRepo = ref.read(transitRepositoryProvider);
    final stations = transitRepo.stations;
    
    String? selectedLineId;
    Station? selectedStation;
    int selectedLevel = 3;
    
    final lines = [
      {'id': 'BTS_SUKHUMVIT', 'name': t.utility.lineBtsSukhumvit},
      {'id': 'BTS_SILOM', 'name': t.utility.lineBtsSilom},
      {'id': 'MRT_BLUE', 'name': t.utility.lineMrtBlue},
      {'id': 'MRT_PURPLE', 'name': t.utility.lineMrtPurple},
      {'id': 'MRT_YELLOW', 'name': t.utility.lineMrtYellow},
      {'id': 'MRT_PINK', 'name': t.utility.lineMrtPink},
      {'id': 'ARL', 'name': t.utility.lineArl},
      {'id': 'SRT_RED_NORTH', 'name': t.utility.lineSrtRed},
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredStations = selectedLineId == null
                ? <Station>[]
                : stations.where((s) {
                    if (selectedLineId == 'BTS_SUKHUMVIT') {
                      return s.lineId == 'BTS_SUKHUMVIT';
                    } else if (selectedLineId == 'BTS_SILOM') {
                      return s.lineId == 'BTS_SILOM';
                    } else if (selectedLineId == 'MRT_BLUE') {
                      return s.lineId == 'MRT_BLUE';
                    } else if (selectedLineId == 'MRT_PURPLE') {
                      return s.lineId == 'MRT_PURPLE';
                    } else if (selectedLineId == 'MRT_YELLOW') {
                      return s.lineId == 'MRT_YELLOW';
                    } else if (selectedLineId == 'MRT_PINK') {
                      return s.lineId == 'MRT_PINK' || s.lineId == 'MRT_PINK_BRANCH';
                    } else if (selectedLineId == 'ARL') {
                      return s.lineId == 'ARL';
                    } else if (selectedLineId == 'SRT_RED_NORTH') {
                      return s.lineId == 'SRT_RED_NORTH' || s.lineId == 'SRT_RED_WEST';
                    }
                    return false;
                  }).toList();
            
            filteredStations.sort((a, b) {
              final nameA = t.isTh ? a.nameTh : a.nameEn;
              final nameB = t.isTh ? b.nameTh : b.nameEn;
              return nameA.compareTo(nameB);
            });

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                    Text(
                      t.utility.submitReportTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      t.utility.selectLineLabel,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLineId,
                          hint: Text(t.utility.selectLineHint),
                          isExpanded: true,
                          items: lines.map((l) {
                            return DropdownMenuItem<String>(
                              value: l['id'],
                              child: Text(l['name']!),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedLineId = val;
                              selectedStation = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      t.utility.selectStationLabel,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Station>(
                          value: selectedStation,
                          hint: Text(
                            selectedLineId == null
                                ? t.utility.selectLineFirstHint
                                : t.utility.selectStationHint
                          ),
                          isExpanded: true,
                          items: filteredStations.map((s) {
                            return DropdownMenuItem<Station>(
                              value: s,
                              child: Text(t.isTh ? s.nameTh : s.nameEn),
                            );
                          }).toList(),
                          onChanged: selectedLineId == null
                              ? null
                              : (val) {
                                  setState(() {
                                    selectedStation = val;
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    
                    Text(
                      t.utility.delayIntensityLabel,
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (index) {
                        final lvl = index + 1;
                        final isSelected = selectedLevel == lvl;
                        
                        Color levelColor = Colors.green;
                        if (lvl >= 4) {
                          levelColor = Colors.red;
                        } else if (lvl >= 3) {
                          levelColor = Colors.amber.shade700;
                        }
                        
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedLevel = lvl;
                            });
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? levelColor : theme.colorScheme.surfaceContainer,
                              border: Border.all(
                                color: isSelected 
                                    ? levelColor 
                                    : theme.colorScheme.outline.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '$lvl',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.utility.normalSmoothLabel,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          t.utility.severeDelayLabel,
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    
                    ElevatedButton(
                      onPressed: selectedStation == null ? null : () async {
                        Navigator.pop(context);
                        final crowdRepo = ref.read(crowdRepositoryProvider);
                        await crowdRepo.submitCrowdReport(
                          stationId: selectedStation!.id,
                          level: selectedLevel,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                t.utility.reportSuccessSnack,
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        ref.invalidate(transitLineStatusProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        t.utility.submitReportBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
    if (widget.networkId == 'SRT') networkColor = Colors.red.shade800;

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
