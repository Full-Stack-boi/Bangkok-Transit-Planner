import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../providers/providers.dart';
import '../../../models/station.dart';

class ManualReportCard extends ConsumerWidget {
  final ThemeData theme;
  final AppLocalizations t;

  const ManualReportCard({super.key, required this.theme, required this.t});

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
                      return s.lineId == 'MRT_PINK' ||
                          s.lineId == 'MRT_PINK_BRANCH';
                    } else if (selectedLineId == 'ARL') {
                      return s.lineId == 'ARL';
                    } else if (selectedLineId == 'SRT_RED_NORTH') {
                      return s.lineId == 'SRT_RED_NORTH' ||
                          s.lineId == 'SRT_RED_WEST';
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Station>(
                          value: selectedStation,
                          hint: Text(
                            selectedLineId == null
                                ? t.utility.selectLineFirstHint
                                : t.utility.selectStationHint,
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
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                              color: isSelected
                                  ? levelColor
                                  : theme.colorScheme.surfaceContainer,
                              border: Border.all(
                                color: isSelected
                                    ? levelColor
                                    : theme.colorScheme.outline.withValues(
                                        alpha: 0.2,
                                      ),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '$lvl',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
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
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          t.utility.severeDelayLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: selectedStation == null
                          ? null
                          : () async {
                              Navigator.pop(context);
                              final crowdRepo = ref.read(
                                crowdRepositoryProvider,
                              );
                              await crowdRepo.submitCrowdReport(
                                stationId: selectedStation!.id,
                                level: selectedLevel,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(t.utility.reportSuccessSnack),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      t.utility.reportDelayDesc,
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
}
