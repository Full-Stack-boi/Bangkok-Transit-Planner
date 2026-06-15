import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/translation_helper.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../providers/providers.dart';
import '../../providers/user_cards_provider.dart';
import '../../services/transit_news_service.dart';

class UtilityScreen extends ConsumerWidget {
  const UtilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isTh = ref.watch(localeProvider) == 'th';
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
          _buildStatusDashboard(theme, isTh, lineStatuses),
          const SizedBox(height: 24),

          // ─── PART 2: TRANSIT CARDS & PASSES CONFIGURATION ───
          Text(
            isTh ? 'บัตรโดยสารและสิทธิ์ของฉัน' : 'My Transit Cards & Passes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTh
                ? 'เลือกสิทธิ์ส่วนลดของคุณเพื่อการแสดงผลราคาในระบบเดินทางอย่างถูกต้อง'
                : 'Configure your active cards to display customized fares across the map.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // BTS Rabbit Card Section
          _buildNetworkCardSection(
            context: context,
            ref: ref,
            theme: theme,
            isTh: isTh,
            networkColor: Colors.green.shade600,
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            cardLabel: isTh ? 'บัตรแรบบิท (Rabbit Card)' : 'Rabbit Card',
            activeType: cardState.btsCardType,
            options: [
              _CardOption(
                value: 'standard',
                title: isTh ? 'บุคคลทั่วไป' : 'Standard',
                subtitle: isTh ? 'ราคาปกติ' : 'Regular',
              ),
              _CardOption(
                value: 'student',
                title: isTh ? 'นักเรียน/นักศึกษา' : 'Student',
                subtitle: isTh ? 'ลด 10%' : '10% off',
              ),
              _CardOption(
                value: 'senior',
                title: isTh ? 'ผู้สูงอายุ' : 'Senior',
                subtitle: isTh ? 'ลด 50%' : '50% off',
              ),
              _CardOption(
                value: 'trip_package',
                title: isTh ? 'เหมาเที่ยว (BTS)' : 'Trip Package',
                subtitle: isTh ? '30 บาท/เที่ยว' : 'Flat 30 ฿',
              ),
            ],
            onSelect: (type) {
              ref.read(userCardsProvider.notifier).setCardType('BTS', type);
            },
          ),
          const SizedBox(height: 24),

          // MRT Card Section
          _buildNetworkCardSection(
            context: context,
            ref: ref,
            theme: theme,
            isTh: isTh,
            networkColor: Colors.blue.shade700,
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            cardLabel: isTh ? 'บัตรเอ็มอาร์ที (MRT Card)' : 'MRT Card',
            activeType: cardState.mrtCardType,
            options: [
              _CardOption(
                value: 'standard',
                title: isTh ? 'บุคคลทั่วไป' : 'Standard',
                subtitle: isTh ? 'ราคาปกติ' : 'Regular',
              ),
              _CardOption(
                value: 'student',
                title: isTh ? 'นักเรียน/นักศึกษา' : 'Student',
                subtitle: isTh ? 'ลด 10%' : '10% off',
              ),
              _CardOption(
                value: 'senior',
                title: isTh ? 'ผู้สูงอายุ' : 'Senior',
                subtitle: isTh ? 'ลด 50%' : '50% off',
              ),
            ],
            onSelect: (type) {
              ref.read(userCardsProvider.notifier).setCardType('MRT', type);
            },
          ),
          const SizedBox(height: 24),

          // ARL Smart Pass Section
          _buildNetworkCardSection(
            context: context,
            ref: ref,
            theme: theme,
            isTh: isTh,
            networkColor: Colors.red.shade700,
            gradient: LinearGradient(
              colors: [Colors.red.shade400, Colors.red.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            cardLabel: isTh ? 'บัตรสมาร์ทพาส (Smart Pass)' : 'ARL Smart Pass',
            activeType: cardState.arlCardType,
            options: [
              _CardOption(
                value: 'standard',
                title: isTh ? 'บุคคลทั่วไป' : 'Standard',
                subtitle: isTh ? 'ราคาปกติ' : 'Regular',
              ),
              _CardOption(
                value: 'student',
                title: isTh ? 'นักเรียน/นักศึกษา' : 'Student',
                subtitle: isTh ? 'ลด 20%' : '20% off',
              ),
              _CardOption(
                value: 'senior',
                title: isTh ? 'ผู้สูงอายุ' : 'Senior',
                subtitle: isTh ? 'ลด 50%' : '50% off',
              ),
            ],
            onSelect: (type) {
              ref.read(userCardsProvider.notifier).setCardType('ARL', type);
            },
          ),
          const SizedBox(height: 28),

          // ─── PART 3: NEWS & ANNOUNCEMENTS ───
          _buildNewsSection(theme, isTh, newsArticles),
          const SizedBox(height: 24),

          // ─── PART 4: MOCK LOCATION SETUP (DEBUG MODE ONLY) ───
          if (kDebugMode) ...[
            _buildDebugMockLocationCard(context, ref, mockLocation, theme, isTh),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDashboard(
    ThemeData theme,
    bool isTh,
    List<TransitLineStatus> statuses,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTh ? 'สถานะการเดินรถไฟฟ้า' : 'Transit Service Status',
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
                            isTh ? item.lineNameTh : item.lineNameEn,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                            isTh ? item.statusTh : item.statusEn,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: item.isNormal ? Colors.green : Colors.amber.shade800,
                              fontWeight: FontWeight.w600,
                            ),
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

  Widget _buildNetworkCardSection({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required bool isTh,
    required Color networkColor,
    required Gradient gradient,
    required String cardLabel,
    required String activeType,
    required List<_CardOption> options,
    required ValueChanged<String> onSelect,
  }) {
    String activeSubtype = 'STANDARD';
    if (activeType == 'student') activeSubtype = 'STUDENT';
    if (activeType == 'senior') activeSubtype = 'SENIOR';
    if (activeType == 'trip_package') activeSubtype = 'TRIP PACKAGE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Credit Card Mock Widget
        Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: networkColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cardLabel.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Icon(Icons.wifi_tethering_rounded, color: Colors.white70, size: 18),
                ],
              ),
              Text(
                activeSubtype,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '••••  ••••  ••••  2026',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  ),
                  Icon(Icons.contactless_outlined, color: Colors.white70, size: 18),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Grid selection cards
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((opt) {
                final isSelected = opt.value == activeType;
                return SizedBox(
                  width: width,
                  child: InkWell(
                    onTap: () => onSelect(opt.value),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? networkColor.withValues(alpha: 0.08)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? networkColor
                              : theme.colorScheme.outline.withValues(alpha: 0.15),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? networkColor : null,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: networkColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            opt.subtitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? networkColor.withValues(alpha: 0.8)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNewsSection(
    ThemeData theme,
    bool isTh,
    List<TransitNewsArticle> articles,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isTh ? 'ข่าวสารและประกาศ' : 'Transit News & Alerts',
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
                          isTh ? item.titleTh : item.titleEn,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isTh ? item.bodyTh : item.bodyEn,
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

  Widget _buildDebugMockLocationCard(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    bool isTh,
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
        title: Text(isTh ? 'จำลองตำแหน่งพิกัด GPS' : 'Simulate GPS Location'),
        subtitle: Text(
          mockPos != null
              ? 'Simulating at: ${mockPos.latitude.toStringAsFixed(4)}, ${mockPos.longitude.toStringAsFixed(4)}\n(Debug Mode Only)'
              : 'Disabled (Using Real GPS)\n(Debug Mode Only)',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showLocationSimulationDialog(context, ref, mockPos, theme, isTh ? 'th' : 'en'),
      ),
    );
  }

  void _showLocationSimulationDialog(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    String localeCode,
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
              title: const Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Simulate Location'),
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
                        title: const Text('Disable Simulation'),
                        subtitle: const Text('Use real hardware/emulator GPS'),
                        onTap: () {
                          ref.read(mockLocationProvider.notifier).clearMockLocation();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mock location disabled')),
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
                            title: Text(localeCode == 'th' ? station.nameTh : station.nameEn),
                            subtitle: Text('${station.id} • ${station.lat.toStringAsFixed(4)}, ${station.lng.toStringAsFixed(4)}'),
                            trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Colors.green) : null,
                            onTap: () {
                              ref.read(mockLocationProvider.notifier).setMockLocation(station.lat, station.lng);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Simulating at ${localeCode == 'th' ? station.nameTh : station.nameEn}'),
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
