import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/transit_colors.dart';
import '../../models/station.dart';
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
  final _searchController = TextEditingController();
  bool _isSelectingOrigin = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                _searchController.clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Origin / Destination Selector ───
          _buildStationSelector(context, state, vm, theme, t, localeCode),

          // ─── Search Bar ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (query) => vm.search(query),
              decoration: InputDecoration(
                hintText: _isSelectingOrigin
                    ? t.get('origin_hint')
                    : t.get('dest_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          vm.search('');
                        },
                      )
                    : null,
              ),
            ),
          ),

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
            child: state.searchResults.isEmpty && state.query.isEmpty
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
        ? (localeCode == 'th' ? state.origin!.nameTh : state.origin!.nameEn)
        : t.get('origin_hint');

    final destLabel = state.destination != null
        ? (localeCode == 'th' ? state.destination!.nameTh : state.destination!.nameEn)
        : t.get('dest_hint');

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
            label: originLabel,
            sublabel: state.origin != null
                ? (localeCode == 'th' ? state.origin!.nameEn : state.origin!.nameTh)
                : null,
            isSelected: _isSelectingOrigin,
            onTap: () => setState(() => _isSelectingOrigin = true),
            lineColor: state.origin != null
                ? TransitColors.getLineColor(state.origin!.lineId)
                : null,
          ),

          // Swap stations action row
          Row(
            children: [
              const Expanded(child: Divider()),
              IconButton(
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
                onPressed: state.origin != null || state.destination != null
                    ? () => vm.swapStations()
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
            label: destLabel,
            sublabel: state.destination != null
                ? (localeCode == 'th' ? state.destination!.nameEn : state.destination!.nameTh)
                : null,
            isSelected: !_isSelectingOrigin,
            onTap: () => setState(() => _isSelectingOrigin = false),
            lineColor: state.destination != null
                ? TransitColors.getLineColor(state.destination!.lineId)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? sublabel,
    required bool isSelected,
    required VoidCallback onTap,
    Color? lineColor,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
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
            if (lineColor != null)
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
        final station = state.searchResults[index];
        return _StationListTile(
          station: station,
          localeCode: localeCode,
          onTap: () {
            if (_isSelectingOrigin) {
              vm.setOrigin(station);
              setState(() => _isSelectingOrigin = false);
            } else {
              vm.setDestination(station);
            }
            _searchController.clear();
            vm.search('');
          },
        );
      },
    );
  }

  Widget _buildQuickActions(BuildContext context, AppLocalizations t) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.train_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            t.get('search_title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            t.get('search_desc'),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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

class _StationListTile extends StatelessWidget {
  final Station station;
  final String localeCode;
  final VoidCallback onTap;

  const _StationListTile({
    required this.station,
    required this.localeCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = TransitColors.getLineColor(station.lineId);
    final theme = Theme.of(context);

    final title = localeCode == 'th' ? station.nameTh : station.nameEn;
    final subtitle = localeCode == 'th' ? station.nameEn : station.nameTh;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: lineColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              station.code,
              style: TextStyle(
                color: lineColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
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
            color: lineColor,
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
