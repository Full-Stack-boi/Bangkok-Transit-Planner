import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/transit_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/station.dart';
import '../../../models/searchable_item.dart';
import '../../../models/custom_location.dart';
import '../../../models/namtang_stop.dart';
import '../../../models/landmark.dart';
import '../../search/search_view_model.dart';
import '../../../providers/providers.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../models/location_permission_status.dart';

class SearchResultsList extends ConsumerStatefulWidget {
  final SearchState state;
  final SearchViewModel vm;
  final String localeCode;
  final AppLocalizations t;
  final bool isSelectingOrigin;
  final Function(SearchableItem) onOriginSelected;
  final Function(SearchableItem) onDestSelected;

  const SearchResultsList({
    super.key,
    required this.state,
    required this.vm,
    required this.localeCode,
    required this.t,
    required this.isSelectingOrigin,
    required this.onOriginSelected,
    required this.onDestSelected,
  });

  @override
  ConsumerState<SearchResultsList> createState() => _SearchResultsListState();
}

class _SearchResultsListState extends ConsumerState<SearchResultsList> {
  final Set<String> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    final results = widget.state.searchResults;
    
    if (results.isEmpty && !widget.state.isSearching && widget.state.query.isEmpty) {
      return _buildQuickActions(context);
    }
    
    if (results.isEmpty && !widget.state.isSearching) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              widget.t.search.noResultsFound,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final stations = results.whereType<Station>().toList();
    final landmarks = results.whereType<Landmark>().toList();
    final transitStops = results.whereType<NamtangStop>().toList();
    final onlinePlaces = results.where((item) => item is CustomLocation && item.id != 'GPS_CURRENT').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (stations.isNotEmpty)
          _buildGroup(
            widget.t.search.groupStations,
            Icons.train_rounded,
            stations,
          ),
        if (landmarks.isNotEmpty)
          _buildGroup(
            widget.t.search.groupLandmarks,
            Icons.domain_rounded,
            landmarks,
          ),
        if (transitStops.isNotEmpty)
          _buildGroup(
            widget.t.search.groupOtherTransit,
            Icons.directions_bus_rounded,
            transitStops,
          ),
        if (onlinePlaces.isNotEmpty)
          _buildGroup(
            widget.t.search.groupPlaces,
            Icons.place_rounded,
            onlinePlaces,
          ),
        if (results.isEmpty && widget.state.isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildGroup(String title, IconData icon, List<SearchableItem> items) {
    final theme = Theme.of(context);
    final isExpanded = _expandedCategories.contains(title);
    final displayItems = isExpanded ? items : items.take(2).toList();
    final hasMore = items.length > 2 && !isExpanded;

    Color categoryColor = theme.colorScheme.primary;
    if (icon == Icons.train_rounded) {
      categoryColor = theme.colorScheme.primary;
    } else if (icon == Icons.domain_rounded) {
      categoryColor = theme.appColors.landmarkColor ?? const Color(0xFFF97316);
    } else if (icon == Icons.directions_bus_rounded) {
      categoryColor = Colors.green;
    } else if (icon == Icons.place_rounded) {
      categoryColor = theme.appColors.landmarkColor ?? const Color(0xFFF97316);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: categoryColor, size: 18),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            children: [
              ...displayItems.map((item) {
                return StationListTile(
                  station: item,
                  localeCode: widget.localeCode,
                  onTap: () {
                    if (widget.isSelectingOrigin) {
                      widget.onOriginSelected(item);
                    } else {
                      widget.onDestSelected(item);
                    }
                  },
                );
              }),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _expandedCategories.add(title);
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.t.search.showMore(items.length - 2),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: _useCurrentLocation,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.t.search.useCurrentLocation,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.t.search.useCurrentLocationDesc,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 40),
        Center(
          child: Icon(
            Icons.train_rounded,
            size: 72,
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            widget.t.navigation.searchTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            widget.t.search.searchDesc,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _useCurrentLocation() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locationService = ref.read(locationServiceProvider);

      final hasMock = kDebugMode && ref.read(mockLocationProvider) != null;
      if (!hasMock) {
        final status = await locationService.requestLocationPermission();
        if (status != LocationPermissionStatus.granted) {
          if (mounted) Navigator.pop(context);
          if (status == LocationPermissionStatus.permanentlyDenied) {
            await locationService.openSettings();
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(content: Text(widget.t.search.locationDeniedSnack)),
            );
          }
          return;
        }
      }

      final pos = await locationService.getCurrentPosition();
      if (mounted) Navigator.pop(context);

      if (pos == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(widget.t.search.locationFailedSnack)),
        );
        return;
      }

      final transitRepo = ref.read(transitRepositoryProvider);
      Station? nearest;
      double minDist = double.infinity;
      for (final s in transitRepo.stations) {
        final dist = locationService.calculateDistance(
          pos.latitude, pos.longitude, s.lat, s.lng,
        );
        if (dist < minDist) {
          minDist = dist;
          nearest = s;
        }
      }

      if (nearest != null) {
        final walkMin = (minDist / 80.0).clamp(1.0, 30.0);
        final currentLoc = CustomLocation(
          id: 'GPS_CURRENT',
          nameTh: widget.t.search.currentLocationNameTh,
          nameEn: widget.t.search.currentLocationNameEn,
          nearestStationId: nearest.id,
          walkingMinutes: walkMin,
          lat: pos.latitude,
          lng: pos.longitude,
        );

        if (widget.isSelectingOrigin) {
          widget.onOriginSelected(currentLoc);
        } else {
          widget.onDestSelected(currentLoc);
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('${widget.t.common.errorOccurred} $e')));
    }
  }
}

class StationListTile extends ConsumerWidget {
  final SearchableItem station;
  final String localeCode;
  final VoidCallback onTap;

  const StationListTile({
    super.key,
    required this.station,
    required this.localeCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final isStation = station is Station;

    final title = station.displayName(isEnglish: localeCode == 'en');
    String subtitle = '';
    Color itemColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    Widget leadingWidget;

    if (isStation) {
      final s = station as Station;
      itemColor = TransitColors.getLineColor(s.lineId);
      subtitle = localeCode == 'th' ? s.nameEn : s.nameTh;

      leadingWidget = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            s.code,
            style: TextStyle(
              color: itemColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else {
      final repo = ref.read(transitRepositoryProvider);
      final nearestStation = station.nearestStationId != null
          ? repo.getStation(station.nearestStationId!)
          : null;
      final nearestName = nearestStation?.displayName(isEnglish: localeCode == 'en') ?? '';
      final walkTime = station.walkingMinutes?.toInt() ?? 5;

      itemColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
      subtitle = t.proximity.nearStationWalk(nearestName, '$walkTime');

      IconData leadingIcon = Icons.place_rounded;
      if (station is NamtangStop) {
        final ns = station as NamtangStop;
        if (ns.type == 'bus' || ns.type == 'brt') {
          leadingIcon = Icons.directions_bus_rounded;
          itemColor = Colors.green;
        } else if (ns.type == 'boat') {
          leadingIcon = Icons.directions_boat_rounded;
          itemColor = Colors.blue.shade700;
        } else if (ns.type == 'commuter_train') {
          leadingIcon = Icons.train_rounded;
          itemColor = Colors.red.shade700;
        }
      } else if (station is CustomLocation) {
        final cl = station as CustomLocation;
        if (cl.id.startsWith('coord_') ||
            cl.nameEn.toLowerCase().contains('pin') ||
            cl.nameEn.toLowerCase().contains('current') ||
            cl.nameEn.toLowerCase().contains('location')) {
          leadingIcon = Icons.my_location_rounded;
          itemColor = theme.appColors.gpsPinColor ?? const Color(0xFF2DD4BF);
        } else {
          leadingIcon = Icons.business_rounded;
          itemColor = theme.appColors.landmarkColor ?? const Color(0xFFF97316);
        }
      } else if (station is Landmark) {
        leadingIcon = Icons.business_rounded;
        itemColor = theme.appColors.landmarkColor ?? const Color(0xFFF97316);
      }

      leadingWidget = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(leadingIcon, color: itemColor, size: 22),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: leadingWidget,
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }
}
