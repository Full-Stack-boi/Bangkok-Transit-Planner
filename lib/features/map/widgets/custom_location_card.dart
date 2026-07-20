import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../models/custom_location.dart';
import '../../../providers/providers.dart';
import '../../search/search_view_model.dart';

class CustomLocationCard extends ConsumerWidget {
  final CustomLocation location;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;
  final VoidCallback onClose;
  final Function(bool) onOpenSearchOverlay;

  const CustomLocationCard({
    super.key,
    required this.location,
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
    final nearest = transitRepo.getStation(location.nearestStationId ?? '');
    final nearestName =
        nearest?.displayName(isEnglish: localeCode == 'en') ?? '';
    final walkMin = location.walkingMinutes?.toInt() ?? 0;

    final stationName = localeCode == 'th' ? location.nameTh : location.nameEn;

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
                Icon(
                  Icons.place_rounded,
                  color: theme.colorScheme.error,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stationName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        t.proximity.nearStationWalk(
                          nearestName,
                          '${walkMin.toInt()}',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
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
                      searchVm.setOrigin(location);
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
                      searchVm.setDestination(location);
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
