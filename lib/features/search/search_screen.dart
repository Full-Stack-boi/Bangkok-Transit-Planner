import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
import '../../models/searchable_item.dart';
import '../../models/landmark.dart';
import '../../models/custom_location.dart';
import 'search_view_model.dart';
import '../route_result/route_result_sheet.dart';
import '../../providers/providers.dart';
import '../../core/constants/translation_helper.dart';

/// Search screen — main screen for route planning
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destFocusNode = FocusNode();

  bool _isEditingOrigin = false;
  bool _isEditingDest = false;
  bool _isSelectingOrigin = true;

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _originFocusNode.dispose();
    _destFocusNode.dispose();
    super.dispose();
  }

  void _startEditingOrigin(SearchState state) {
    setState(() {
      _isEditingOrigin = true;
      _isEditingDest = false;
      _isSelectingOrigin = true;
      _originController.text = state.origin != null 
          ? state.origin!.displayName(isEnglish: ref.read(localeProvider) == 'en') 
          : '';
    });
    _originFocusNode.requestFocus();
    _originController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _originController.text.length,
    );
    ref.read(searchViewModelProvider.notifier).search(_originController.text);
  }

  void _startEditingDest(SearchState state) {
    setState(() {
      _isEditingOrigin = false;
      _isEditingDest = true;
      _isSelectingOrigin = false;
      _destController.text = state.destination != null 
          ? state.destination!.displayName(isEnglish: ref.read(localeProvider) == 'en') 
          : '';
    });
    _destFocusNode.requestFocus();
    _destController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _destController.text.length,
    );
    ref.read(searchViewModelProvider.notifier).search(_destController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchViewModelProvider);
    final vm = ref.read(searchViewModelProvider.notifier);
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider);
    final localeCode = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.get('app_title')),
        actions: [
          if (state.origin != null || state.destination != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                vm.clear();
                _originController.clear();
                _destController.clear();
                setState(() {
                  _isEditingOrigin = false;
                  _isEditingDest = false;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Origin / Destination Selector with Inline Fields ───
          _buildStationSelector(context, state, vm, theme, t, localeCode),

          // ─── Route Calculation Progress Banner ───
          if (state.isCalculating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.error!)),
                    ],
                  ),
                ),
              ),
            ),

          // ─── Route Result Summary Banner ───
          if (state.routeResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _RouteResultBanner(
                result: state.routeResult!,
                t: t,
                onTap: () => _showRouteDetail(context),
              ),
            ),

          // ─── Search Results or Quick Actions ───
          Expanded(
            child: (state.searchResults.isEmpty && state.query.isEmpty) || (!_isEditingOrigin && !_isEditingDest)
                ? _buildQuickActions(context, t)
                : _buildSearchResults(state, vm, t, localeCode),
          ),
        ],
      ),
    );
  }

  Widget _buildStationSelector(
    BuildContext context,
    SearchState state,
    SearchViewModel vm,
    ThemeData theme,
    AppLocalizations t,
    String localeCode,
  ) {
    final originLabel = state.origin != null
        ? state.origin!.displayName(isEnglish: localeCode == 'en')
        : t.get('origin_hint');

    final destLabel = state.destination != null
        ? state.destination!.displayName(isEnglish: localeCode == 'en')
        : t.get('dest_hint');

    String? originSublabel;
    if (state.origin != null) {
      if (state.origin is Station) {
        originSublabel = localeCode == 'th' ? state.origin!.nameEn : state.origin!.nameTh;
      } else if (state.origin is Landmark) {
        originSublabel = localeCode == 'th' ? 'สถานที่ยอดนิยม' : 'Popular Landmark';
      } else {
        originSublabel = localeCode == 'th' ? 'ตำแหน่งที่กำหนดเอง' : 'Custom Location';
      }
    }

    String? destSublabel;
    if (state.destination != null) {
      if (state.destination is Station) {
        destSublabel = localeCode == 'th' ? state.destination!.nameEn : state.destination!.nameTh;
      } else if (state.destination is Landmark) {
        destSublabel = localeCode == 'th' ? 'สถานที่ยอดนิยม' : 'Popular Landmark';
      } else {
        destSublabel = localeCode == 'th' ? 'ตำแหน่งที่กำหนดเอง' : 'Custom Location';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Origin Selection Row
          _buildStationRow(
            icon: Icons.trip_origin,
            iconColor: Colors.green,
            isEditing: _isEditingOrigin,
            controller: _originController,
            focusNode: _originFocusNode,
            label: originLabel,
            sublabel: originSublabel,
            onTap: () => _startEditingOrigin(state),
            onChanged: (query) => vm.search(query),
            onClear: () {
              _originController.clear();
              vm.search('');
            },
            lineColor: state.origin != null
                ? (state.origin is Station
                    ? TransitColors.getLineColor((state.origin as Station).lineId)
                    : theme.colorScheme.secondary)
                : null,
          ),

          // Swap stations action row
          Row(
            children: [
              const Expanded(child: Divider()),
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                onPressed: state.origin != null || state.destination != null
                    ? () {
                        setState(() {
                          _isEditingOrigin = false;
                          _isEditingDest = false;
                        });
                        vm.swapStations();
                      }
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          // Destination Selection Row
          _buildStationRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            isEditing: _isEditingDest,
            controller: _destController,
            focusNode: _destFocusNode,
            label: destLabel,
            sublabel: destSublabel,
            onTap: () => _startEditingDest(state),
            onChanged: (query) => vm.search(query),
            onClear: () {
              _destController.clear();
              vm.search('');
            },
            lineColor: state.destination != null
                ? (state.destination is Station
                    ? TransitColors.getLineColor((state.destination as Station).lineId)
                    : theme.colorScheme.secondary)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStationRow({
    required IconData icon,
    required Color iconColor,
    required bool isEditing,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    String? sublabel,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    Color? lineColor,
  }) {
    final theme = Theme.of(context);
    final localeCode = ref.read(localeProvider);
    final searchHint = localeCode == 'en' ? 'Search station or place...' : 'ค้นหาสถานีหรือสถานที่...';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isEditing
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    style: theme.textTheme.titleMedium,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                    },
                    decoration: InputDecoration(
                      hintText: searchHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  )
                : InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: sublabel != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (sublabel != null)
                                  Text(
                                    sublabel,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      fontSize: 12,
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
          if (isEditing && controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onClear,
            ),
          if (!isEditing && lineColor != null)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: lineColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    SearchState state,
    SearchViewModel vm,
    AppLocalizations t,
    String localeCode,
  ) {
    if (state.searchResults.isEmpty && state.query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              '${t.get('no_station_found')} "${state.query}"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.searchResults.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final item = state.searchResults[index];
        return _StationListTile(
          station: item,
          localeCode: localeCode,
          onTap: () {
            if (_isSelectingOrigin) {
              vm.setOrigin(item);
              setState(() {
                _isEditingOrigin = false;
                final nextState = ref.read(searchViewModelProvider);
                if (nextState.destination == null) {
                  _startEditingDest(nextState);
                } else {
                  FocusScope.of(context).unfocus();
                }
              });
            } else {
              vm.setDestination(item);
              setState(() {
                _isEditingDest = false;
                final nextState = ref.read(searchViewModelProvider);
                if (nextState.origin == null) {
                  _startEditingOrigin(nextState);
                } else {
                  FocusScope.of(context).unfocus();
                }
              });
            }
            vm.search('');
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ─── Use Current Location Button ───
        Card(
          margin: const EdgeInsets.only(bottom: 24),
          child: InkWell(
            onTap: _useCurrentLocation,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.localeCode == 'en' ? 'Use Current Location' : 'ใช้ตำแหน่งปัจจุบันของคุณ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.localeCode == 'en'
                              ? 'Find routes starting from where you are'
                              : 'ค้นหาเส้นทางโดยเริ่มจากตำแหน่งที่คุณอยู่',
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

        const SizedBox(height: 16),
        Center(
          child: Icon(
            Icons.train_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            t.get('search_title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            t.get('search_desc'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _useCurrentLocation() async {
    final t = ref.read(translationsProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final locationService = ref.read(locationServiceProvider);

      // Request permission
      final hasPermission = await locationService.requestLocationPermission();
      if (!hasPermission) {
        if (mounted) Navigator.pop(context); // Dismiss loading
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(t.localeCode == 'en' ? 'Location permission denied' : 'ปฏิเสธการเข้าถึงตำแหน่งที่ตั้ง')),
        );
        return;
      }

      final pos = await locationService.getCurrentPosition();
      if (mounted) Navigator.pop(context); // Dismiss loading

      if (pos == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(t.localeCode == 'en' ? 'Unable to retrieve location' : 'ไม่สามารถดึงข้อมูลตำแหน่งที่ตั้งได้')),
        );
        return;
      }

      final transitRepo = ref.read(transitRepositoryProvider);
      Station? nearest;
      double minDist = double.infinity;
      for (final s in transitRepo.stations) {
        final dist = locationService.calculateDistance(
          pos.latitude, pos.longitude, s.lat, s.lng
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
          nameTh: 'ตำแหน่งปัจจุบันของคุณ',
          nameEn: 'Your Current Location',
          nearestStationId: nearest.id,
          walkingMinutes: walkMin,
          lat: pos.latitude,
          lng: pos.longitude,
        );

        final vm = ref.read(searchViewModelProvider.notifier);
        final searchState = ref.read(searchViewModelProvider);
        if (_isSelectingOrigin) {
          vm.setOrigin(currentLoc);
          setState(() {
            _isSelectingOrigin = false;
            _isEditingOrigin = false;
            if (searchState.destination == null) {
              _startEditingDest(searchState);
            }
          });
        } else {
          vm.setDestination(currentLoc);
          setState(() {
            _isEditingDest = false;
            if (searchState.origin == null) {
              _startEditingOrigin(searchState);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showRouteDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const RouteResultSheet(),
    );
  }
}

class _StationListTile extends ConsumerWidget {
  final SearchableItem station;
  final String localeCode;
  final VoidCallback onTap;

  const _StationListTile({
    required this.station,
    required this.localeCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isStation = station is Station;

    final title = station.displayName(isEnglish: localeCode == 'en');
    String subtitle = '';
    Color itemColor = theme.colorScheme.primary;
    Widget leadingWidget;

    if (isStation) {
      final s = station as Station;
      itemColor = TransitColors.getLineColor(s.lineId);
      subtitle = localeCode == 'th' ? s.nameEn : s.nameTh;

      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            s.code,
            style: TextStyle(
              color: itemColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      );
    } else {
      // Landmark or CustomLocation
      final repo = ref.read(transitRepositoryProvider);
      final nearestStation = station.nearestStationId != null
          ? repo.getStation(station.nearestStationId!)
          : null;
      final nearestName = nearestStation?.displayName(isEnglish: localeCode == 'en') ?? '';
      final walkTime = station.walkingMinutes?.toInt() ?? 5;

      itemColor = theme.colorScheme.secondary;

      subtitle = localeCode == 'en'
          ? 'Near $nearestName station · ~$walkTime min walk'
          : 'ใกล้สถานี$nearestName · เดิน ~$walkTime นาที';

      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            Icons.place_rounded,
            color: itemColor,
            size: 20,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: leadingWidget,
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: itemColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _RouteResultBanner extends StatelessWidget {
  final dynamic result;
  final AppLocalizations t;
  final VoidCallback onTap;

  const _RouteResultBanner({
    required this.result,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.route_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '~${result.totalMinutes.toInt()} ${t.get('minutes_unit')} · ${result.totalFareThb} ${t.get('currency_unit')}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${result.segments.length} ${t.get('lines_count')} · ${result.transferCount} ${t.get('transfers_count')} · ${result.totalStations} ${t.get('stations_count')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
