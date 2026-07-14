import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../models/namtang_stop.dart';
import '../../../providers/providers.dart';
import '../../search/search_view_model.dart';

class NamtangStopCard extends ConsumerWidget {
  final NamtangStop stop;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;
  final VoidCallback onClose;
  final Function(bool) onOpenSearchOverlay;

  const NamtangStopCard({
    super.key,
    required this.stop,
    required this.theme,
    required this.t,
    required this.localeCode,
    required this.onClose,
    required this.onOpenSearchOverlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchVm = ref.read(searchViewModelProvider.notifier);
    final transitRepo = ref.read(transitRepositoryProvider);
    final nearest = stop.nearestStationId != null
        ? transitRepo.getStation(stop.nearestStationId!)
        : null;
    final nearestName =
        nearest?.displayName(isEnglish: localeCode == 'en') ?? '';
    final walkMin = stop.walkingMinutes?.toInt() ?? 5;

    final stopName = localeCode == 'th' ? stop.nameTh : stop.nameEn;

    IconData leadingIcon = Icons.directions_bus_rounded;
    Color leadingColor = Colors.green;
    if (stop.type == 'boat') {
      leadingIcon = Icons.directions_boat_rounded;
      leadingColor = Colors.blue.shade700;
    } else if (stop.type == 'commuter_train') {
      leadingIcon = Icons.train_rounded;
      leadingColor = Colors.red.shade700;
    }

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(leadingIcon, color: leadingColor, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (nearestName.isNotEmpty)
                        Text(
                          t.proximity.nearStationWalk(nearestName, '$walkMin'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setOrigin(stop);
                      onClose();
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.destination == null) {
                        onOpenSearchOverlay(true);
                      }
                    },
                    icon: const Icon(
                      Icons.trip_origin_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: Text(t.favorites.setOriginBtn),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      searchVm.setDestination(stop);
                      onClose();
                      final currentState = ref.read(searchViewModelProvider);
                      if (currentState.origin == null) {
                        onOpenSearchOverlay(false);
                      }
                    },
                    icon: const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(t.favorites.setDestBtn),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
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
