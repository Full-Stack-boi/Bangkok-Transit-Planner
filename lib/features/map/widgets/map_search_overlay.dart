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

/// Fullscreen search overlay for origin and destination station selection
class MapSearchOverlay extends ConsumerStatefulWidget {
  final bool focusDestination;

  const MapSearchOverlay({
    super.key,
    this.focusDestination = false,
  });

  @override
  ConsumerState<MapSearchOverlay> createState() => _MapSearchOverlayState();
}

class _MapSearchOverlayState extends ConsumerState<MapSearchOverlay> {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destFocusNode = FocusNode();

  bool _isSelectingOrigin = true;
  bool _isFirstLoad = true;
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _isSelectingOrigin = !widget.focusDestination;
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _originFocusNode.dispose();
    _destFocusNode.dispose();
    super.dispose();
  }

  void _initFields(SearchState state, String localeCode) {
    if (!_isFirstLoad) return;
    _isFirstLoad = false;

    _originController.text = state.origin != null
        ? state.origin!.displayName(isEnglish: localeCode == 'en')
        : '';
    _destController.text = state.destination != null
        ? state.destination!.displayName(isEnglish: localeCode == 'en')
        : '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      void requestInitialFocus() {
        if (!mounted) return;
        if (widget.focusDestination) {
          _startEditingDest(state);
        } else if (state.origin == null) {
          _startEditingOrigin(state);
        } else {
          _startEditingDest(state);
        }
      }

      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        if (route.animation!.isCompleted) {
          requestInitialFocus();
        } else {
          void listener(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              route.animation!.removeStatusListener(listener);
              requestInitialFocus();
            }
          }
          route.animation!.addStatusListener(listener);
        }
      } else {
        requestInitialFocus();
      }
    });
  }

  void _startEditingOrigin(SearchState state) {
    setState(() {
      _isSelectingOrigin = true;
    });
    _originController.text = state.origin != null
        ? state.origin!.displayName(
            isEnglish: ref.read(localeProvider) == 'en',
          )
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_originFocusNode.canRequestFocus && mounted) {
        _originFocusNode.requestFocus();
      }
    });
    _originController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _originController.text.length,
    );
    ref.read(searchViewModelProvider.notifier).search(_originController.text);
  }

  void _startEditingDest(SearchState state) {
    setState(() {
      _isSelectingOrigin = false;
    });
    _destController.text = state.destination != null
        ? state.destination!.displayName(
            isEnglish: ref.read(localeProvider) == 'en',
          )
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_destFocusNode.canRequestFocus && mounted) {
        _destFocusNode.requestFocus();
      }
    });
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

    _initFields(state, localeCode);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(t.navigation.searchTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (state.origin != null || state.destination != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: t.search.clearAll,
              onPressed: () {
                vm.clear();
                _originController.clear();
                _destController.clear();
                _startEditingOrigin(ref.read(searchViewModelProvider));
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Input Card (Origin & Destination Fields) ───
            Hero(
              tag: 'search_bar_card',
              flightShuttleBuilder: (
                BuildContext flightContext,
                Animation<double> animation,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                final theme = Theme.of(flightContext);
                final isDark = theme.brightness == Brightness.dark;
                final shimmerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);
                
                return Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          // Left track indicator placeholder
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: shimmerColor, shape: BoxShape.circle)),
                              Container(width: 2, height: 24, color: shimmerColor),
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: shimmerColor, shape: BoxShape.circle)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Input fields placeholders
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: shimmerColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(width: double.infinity, height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                                const SizedBox(height: 12),
                                Container(
                                  width: 140,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: shimmerColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Swap button placeholder
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        // Left track connecting indicator
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trip_origin_rounded, color: Colors.green, size: 20),
                            SizedBox(
                              width: 2,
                              height: 36,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Input Fields
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                // Origin Field
                                TextField(
                                  controller: _originController,
                                  focusNode: _originFocusNode,
                                  onTap: () => _startEditingOrigin(state),
                                  onChanged: (query) => vm.search(query),
                                  style: theme.textTheme.titleMedium,
                                  decoration: InputDecoration(
                                    hintText: t.search.originHint,
                                    border: InputBorder.none,
                                    hintStyle: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    suffixIcon: _isSelectingOrigin && _originController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _originController.clear();
                                              vm.search('');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                                Divider(color: theme.colorScheme.outline.withValues(alpha: 0.15), height: 1),
                                // Destination Field
                                TextField(
                                  controller: _destController,
                                  focusNode: _destFocusNode,
                                  onTap: () => _startEditingDest(state),
                                  onChanged: (query) => vm.search(query),
                                  style: theme.textTheme.titleMedium,
                                  decoration: InputDecoration(
                                    hintText: t.search.destHint,
                                    border: InputBorder.none,
                                    hintStyle: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    suffixIcon: !_isSelectingOrigin && _destController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              _destController.clear();
                                              vm.search('');
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                        ),
                        const SizedBox(width: 8),
                        // Swap Button
                        IconButton(
                          onPressed: state.origin != null || state.destination != null
                              ? () {
                                  vm.swapStations();
                                  final nextState = ref.read(searchViewModelProvider);
                                  _originController.text = nextState.origin != null
                                      ? nextState.origin!.displayName(isEnglish: localeCode == 'en')
                                      : '';
                                  _destController.text = nextState.destination != null
                                      ? nextState.destination!.displayName(isEnglish: localeCode == 'en')
                                      : '';
                                  if (_isSelectingOrigin) {
                                    _startEditingOrigin(nextState);
                                  } else {
                                    _startEditingDest(nextState);
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.swap_vert_rounded,
                            size: 26,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                            foregroundColor: theme.colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error))),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading Indicator
            if (state.isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // ─── Search Results or Quick Actions ───
            Expanded(
              child: state.searchResults.isEmpty && state.query.isEmpty
                  ? _buildQuickActions(context, t)
                  : _buildSearchResults(state, vm, t, localeCode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    SearchState state,
    SearchViewModel vm,
    AppLocalizations t,
    String localeCode,
  ) {
    final results = state.searchResults;
    if (results.isEmpty && !state.isSearching) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              t.search.noResultsFound,
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
            t.search.groupStations,
            Icons.train_rounded,
            stations,
            vm,
            localeCode,
          ),
        if (landmarks.isNotEmpty)
          _buildGroup(
            t.search.groupLandmarks,
            Icons.domain_rounded,
            landmarks,
            vm,
            localeCode,
          ),
        if (transitStops.isNotEmpty)
          _buildGroup(
            t.search.groupOtherTransit,
            Icons.directions_bus_rounded,
            transitStops,
            vm,
            localeCode,
          ),
        if (onlinePlaces.isNotEmpty)
          _buildGroup(
            t.search.groupPlaces,
            Icons.place_rounded,
            onlinePlaces,
            vm,
            localeCode,
          ),
        if (results.isEmpty && state.isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildGroup(
    String title,
    IconData icon,
    List<SearchableItem> items,
    SearchViewModel vm,
    String localeCode,
  ) {
    final theme = Theme.of(context);
    final isExpanded = _expandedCategories.contains(title);
    final displayItems = isExpanded ? items : items.take(2).toList();
    final hasMore = items.length > 2 && !isExpanded;
    final t = ref.watch(translationsProvider);

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
                return _StationListTile(
                  station: item,
                  localeCode: localeCode,
                  onTap: () {
                    if (_isSelectingOrigin) {
                      vm.setOrigin(item);
                      final nextState = ref.read(searchViewModelProvider);
                      _originController.text = item.displayName(isEnglish: localeCode == 'en');
                      if (nextState.destination == null) {
                        _startEditingDest(nextState);
                      } else {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop(true);
                      }
                    } else {
                      vm.setDestination(item);
                      final nextState = ref.read(searchViewModelProvider);
                      _destController.text = item.displayName(isEnglish: localeCode == 'en');
                      if (nextState.origin == null) {
                        _startEditingOrigin(nextState);
                      } else {
                        FocusScope.of(context).unfocus();
                        Navigator.of(context).pop(true);
                      }
                    }
                    vm.search('');
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
                      t.search.showMore(items.length - 2),
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

  Widget _buildQuickActions(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Use Current Location Button
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
                          t.search.useCurrentLocation,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.search.useCurrentLocationDesc,
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
            t.navigation.searchTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            t.search.searchDesc,
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
    final t = ref.read(translationsProvider);
    final localeCode = ref.read(localeProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final locationService = ref.read(locationServiceProvider);

      // Check if simulation is active (bypass permission checks in debug)
      final hasMock = kDebugMode && ref.read(mockLocationProvider) != null;
      if (!hasMock) {
        // Request permission
        final status = await locationService.requestLocationPermission();
        if (status != LocationPermissionStatus.granted) {
          if (mounted) Navigator.pop(context); // Dismiss loading
          if (status == LocationPermissionStatus.permanentlyDenied) {
            await locationService.openSettings();
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  t.search.locationDeniedSnack,
                ),
              ),
            );
          }
          return;
        }
      }

      final pos = await locationService.getCurrentPosition();
      if (mounted) Navigator.pop(context); // Dismiss loading

      if (pos == null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              t.search.locationFailedSnack,
            ),
          ),
        );
        return;
      }

      final transitRepo = ref.read(transitRepositoryProvider);
      Station? nearest;
      double minDist = double.infinity;
      for (final s in transitRepo.stations) {
        final dist = locationService.calculateDistance(
          pos.latitude,
          pos.longitude,
          s.lat,
          s.lng,
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
          nameTh: t.search.currentLocationNameTh,
          nameEn: t.search.currentLocationNameEn,
          nearestStationId: nearest.id,
          walkingMinutes: walkMin,
          lat: pos.latitude,
          lng: pos.longitude,
        );

        final vm = ref.read(searchViewModelProvider.notifier);
        final searchState = ref.read(searchViewModelProvider);
        if (_isSelectingOrigin) {
          vm.setOrigin(currentLoc);
          _originController.text = currentLoc.displayName(isEnglish: localeCode == 'en');
          if (searchState.destination == null) {
            _startEditingDest(searchState);
          } else {
            if (mounted) {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(true);
            }
          }
        } else {
          vm.setDestination(currentLoc);
          _destController.text = currentLoc.displayName(isEnglish: localeCode == 'en');
          if (searchState.origin == null) {
            _startEditingOrigin(searchState);
          } else {
            if (mounted) {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop(true);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('${t.common.errorOccurred} $e')));
    }
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
      final nearestName =
          nearestStation?.displayName(isEnglish: localeCode == 'en') ?? '';
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
          leadingIcon = Icons.business_rounded; // Building icon for named places/landmarks
          itemColor = theme.appColors.landmarkColor ?? const Color(0xFFF97316);
        }
      } else if (station is Landmark) {
        leadingIcon = Icons.business_rounded; // Building icon for Landmarks
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
