import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../providers/providers.dart';

class DeveloperTestSheet extends ConsumerStatefulWidget {
  const DeveloperTestSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DeveloperTestSheet(),
    );
  }

  @override
  ConsumerState<DeveloperTestSheet> createState() => _DeveloperTestSheetState();
}

class _DeveloperTestSheetState extends ConsumerState<DeveloperTestSheet> {
  String _selectedLineId = 'BTS_SUKHUMVIT';
  DisruptionSeverity _selectedSeverity = DisruptionSeverity.minorDelay;
  Set<String> _selectedStationIds = {'BTS_CEN'};
  int _selectedDelayMinutes = 15;
  bool _isCustomBuilderExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final disruptionState = ref.watch(disruptionProvider);
    final mockLocation = ref.watch(mockLocationProvider);
    final localeCode = ref.watch(localeProvider);
    final transitRepo = ref.watch(transitRepositoryProvider);

    final lineStations = transitRepo.stations
        .where((s) => s.lineId == _selectedLineId)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developer & Testing Suite',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Custom Disruption Builder & GPS Simulation',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 1: Quick Presets
            Text(
              '🚨 Quick Disruption Presets',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('🟢 Normal (Clear)'),
                  selected: !disruptionState.isMockActive,
                  onSelected: (_) {
                    ref.read(disruptionProvider.notifier).clearDisruptions();
                  },
                ),
                ChoiceChip(
                  label: const Text('🟡 Siam Delay (+15m)'),
                  selected: disruptionState.disruptions.any(
                    (d) => d.id == 'mock_siam_delay',
                  ),
                  selectedColor: Colors.amber.shade800.withValues(alpha: 0.2),
                  onSelected: (_) {
                    ref
                        .read(disruptionProvider.notifier)
                        .applySiamDelayPreset();
                  },
                ),
                ChoiceChip(
                  label: const Text('🟠 Mo Chit ➔ Ha Yaek (Closed)'),
                  selected: disruptionState.disruptions.any(
                    (d) => d.id == 'mock_mochit_closure',
                  ),
                  selectedColor: Colors.orange.shade800.withValues(alpha: 0.2),
                  onSelected: (_) {
                    ref
                        .read(disruptionProvider.notifier)
                        .applyMoChitClosurePreset();
                  },
                ),
                ChoiceChip(
                  label: const Text('🔴 MRT Purple Line (Closed)'),
                  selected: disruptionState.disruptions.any(
                    (d) => d.id == 'mock_purple_closure',
                  ),
                  selectedColor: Colors.red.shade800.withValues(alpha: 0.2),
                  onSelected: (_) {
                    ref
                        .read(disruptionProvider.notifier)
                        .applyPurpleLineClosurePreset();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Custom Disruption Builder Toggle
            InkWell(
              onTap: () {
                setState(() {
                  _isCustomBuilderExpanded = !_isCustomBuilderExpanded;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🛠️ Custom Disruption Creator (Select Line & Stations)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      _isCustomBuilderExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            if (_isCustomBuilderExpanded) ...[
              const SizedBox(height: 14),
              // Line Selector
              Text(
                '1. Select Transit Line:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      [
                        'BTS_SUKHUMVIT',
                        'BTS_SILOM',
                        'MRT_BLUE',
                        'MRT_PURPLE',
                        'MRT_YELLOW',
                        'ARL',
                      ].map((lineId) {
                        final line = transitRepo.getLine(lineId);
                        final isSel = _selectedLineId == lineId;
                        final lineLabel = line != null
                            ? (localeCode == 'th' ? line.nameTh : line.nameEn)
                            : lineId;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(lineLabel),
                            selected: isSel,
                            onSelected: (_) {
                              setState(() {
                                _selectedLineId = lineId;
                                final newStations = transitRepo.stations
                                    .where((s) => s.lineId == lineId)
                                    .toList();
                                if (newStations.isNotEmpty) {
                                  _selectedStationIds = {newStations.first.id};
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Severity Selector
              Text(
                '2. Select Severity Level:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('🟡 Minor Delay'),
                    selected:
                        _selectedSeverity == DisruptionSeverity.minorDelay,
                    onSelected: (_) {
                      setState(() {
                        _selectedSeverity = DisruptionSeverity.minorDelay;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('🟠 Partial Closure'),
                    selected:
                        _selectedSeverity == DisruptionSeverity.partialClosure,
                    onSelected: (_) {
                      setState(() {
                        _selectedSeverity = DisruptionSeverity.partialClosure;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('🔴 Full Closure'),
                    selected:
                        _selectedSeverity == DisruptionSeverity.fullClosure,
                    onSelected: (_) {
                      setState(() {
                        _selectedSeverity = DisruptionSeverity.fullClosure;
                        _selectedStationIds = lineStations
                            .map((s) => s.id)
                            .toSet();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Station Picker
              Text(
                '3. Select Affected Stations (${_selectedStationIds.length} stations):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: lineStations.map((station) {
                      final isSel = _selectedStationIds.contains(station.id);
                      final sName = localeCode == 'th'
                          ? station.nameTh
                          : station.nameEn;

                      return FilterChip(
                        label: Text('${station.code} $sName'),
                        selected: isSel,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStationIds.add(station.id);
                            } else {
                              if (_selectedStationIds.length > 1) {
                                _selectedStationIds.remove(station.id);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Delay Minutes Picker
              Text(
                '4. Estimated Delay (Minutes):',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [5, 10, 15, 30, 60].map((mins) {
                  return ChoiceChip(
                    label: Text('+$mins mins'),
                    selected: _selectedDelayMinutes == mins,
                    onSelected: (_) {
                      setState(() {
                        _selectedDelayMinutes = mins;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Apply Custom Disruption Button
              ElevatedButton.icon(
                onPressed: () {
                  final line = transitRepo.getLine(_selectedLineId);
                  final lineNameTh = line?.nameTh ?? _selectedLineId;
                  final lineNameEn = line?.nameEn ?? _selectedLineId;

                  final disruption = TransitDisruption(
                    id: 'custom_${_selectedLineId}_${DateTime.now().millisecondsSinceEpoch}',
                    lineId: _selectedLineId,
                    severity: _selectedSeverity,
                    affectedStationIds: _selectedStationIds.toList(),
                    affectedSegmentIds: [],
                    titleTh: _selectedSeverity == DisruptionSeverity.fullClosure
                        ? 'ระงับให้บริการสาย $lineNameTh ชั่วคราวทั้งสาย'
                        : (_selectedSeverity ==
                                  DisruptionSeverity.partialClosure
                              ? 'งดให้บริการบางช่วงที่สาย $lineNameTh'
                              : 'ขบวนรถไฟฟ้าล่าช้าที่สาย $lineNameTh'),
                    titleEn: _selectedSeverity == DisruptionSeverity.fullClosure
                        ? 'Full Suspension on $lineNameEn'
                        : (_selectedSeverity ==
                                  DisruptionSeverity.partialClosure
                              ? 'Partial Closure on $lineNameEn'
                              : 'Service Delay on $lineNameEn'),
                    descriptionTh:
                        'ส่งผลกระทบ ${_selectedStationIds.length} สถานี (ประมาณการล่าช้า $_selectedDelayMinutes นาที)',
                    descriptionEn:
                        'Affects ${_selectedStationIds.length} station(s) (~$_selectedDelayMinutes mins delay).',
                    estimatedDelayMinutes: _selectedDelayMinutes,
                    alternativeAdviceTh:
                        'แนะนำให้เผื่อเวลาเดินทาง หรือใช้ระบบขนส่งทางเลือก',
                    alternativeAdviceEn:
                        'Please allow extra travel time or use alternative transit.',
                    reportedAt: DateTime.now(),
                  );

                  ref
                      .read(disruptionProvider.notifier)
                      .setCustomDisruption(disruption);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Applied custom disruption for $lineNameEn successfully!',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('⚡ Apply Custom Disruption Mock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Section 2: Location Mocks
            Text(
              '📍 GPS Location Simulation (1-Tap Toggles)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('📡 Real GPS Location'),
                  selected: mockLocation == null,
                  onSelected: (_) {
                    ref.read(mockLocationProvider.notifier).clearMockLocation();
                  },
                ),
                ChoiceChip(
                  label: const Text('📍 Siam Station'),
                  selected:
                      mockLocation != null &&
                      (mockLocation.latitude - 13.7456).abs() < 0.001,
                  onSelected: (_) {
                    ref
                        .read(mockLocationProvider.notifier)
                        .setMockLocation(13.7456, 100.5342);
                  },
                ),
                ChoiceChip(
                  label: const Text('📍 Mo Chit Station'),
                  selected:
                      mockLocation != null &&
                      (mockLocation.latitude - 13.8026).abs() < 0.001,
                  onSelected: (_) {
                    ref
                        .read(mockLocationProvider.notifier)
                        .setMockLocation(13.8026, 100.5538);
                  },
                ),
                ChoiceChip(
                  label: const Text('📍 Asok Station'),
                  selected:
                      mockLocation != null &&
                      (mockLocation.latitude - 13.7375).abs() < 0.001,
                  onSelected: (_) {
                    ref
                        .read(mockLocationProvider.notifier)
                        .setMockLocation(13.7375, 100.5606);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.search, size: 16),
                  label: const Text('Search Station...'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showStationSearchDialog(
                      context,
                      ref,
                      mockLocation,
                      theme,
                      localeCode,
                      t,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Footer Action
            OutlinedButton.icon(
              onPressed: () {
                ref.read(disruptionProvider.notifier).clearDisruptions();
                ref.read(mockLocationProvider.notifier).clearMockLocation();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All mocks reset to normal!')),
                );
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
              label: const Text('Reset All Mocks to Normal'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStationSearchDialog(
    BuildContext context,
    WidgetRef ref,
    Position? mockPos,
    ThemeData theme,
    String localeCode,
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
              title: const Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Simulate GPS Station'),
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
                              localeCode == 'th'
                                  ? station.nameTh
                                  : station.nameEn,
                            ),
                            subtitle: Text(
                              '${station.id} • ${station.lat.toStringAsFixed(4)}, ${station.lng.toStringAsFixed(4)}',
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
