import 'package:flutter/material.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../models/custom_location.dart';
import '../../../models/namtang_stop.dart';
import '../../../models/route_result.dart';
import '../../../models/station.dart';
import '../../../providers/providers.dart';
import '../../../providers/route_tracker.dart';
import '../../utility/route_calculating_overlay.dart';
import 'active_journey_panel.dart';
import 'custom_location_card.dart';
import 'map_prefetch_widget.dart';
import 'namtang_stop_card.dart';
import 'route_result_banner.dart';
import 'station_details_card.dart';

// Composes controls and detail cards displayed above the interactive map.

class MapOverlayStack extends StatelessWidget {
  final Widget mapLayer;
  final Widget searchCard;
  final MapPrefetchProgress prefetchState;
  final ThemeData theme;
  final AppLocalizations t;
  final String localeCode;
  final bool isPrefetchExpanded;
  final bool isLocating;
  final bool isOfflineMapInitializing;
  final bool isBottomCardVisible;
  final bool isCalculating;
  final bool isTrackingActive;
  final Station? selectedStation;
  final CustomLocation? selectedLocation;
  final NamtangStop? selectedNamtangStop;
  final RouteResult? routeResult;
  final RouteTrackerState? trackerState;
  final VoidCallback onTogglePrefetch;
  final VoidCallback onStartPrefetch;
  final VoidCallback onCenterOnUser;
  final VoidCallback onCloseStation;
  final ValueChanged<Station> onSelectHubStation;
  final ValueChanged<Station> onSetOrigin;
  final ValueChanged<Station> onSetDestination;
  final VoidCallback onCloseCustomLocation;
  final ValueChanged<bool> onOpenSearchOverlay;
  final VoidCallback onCloseNamtangStop;
  final VoidCallback onShowRouteDetail;

  const MapOverlayStack({
    super.key,
    required this.mapLayer,
    required this.searchCard,
    required this.prefetchState,
    required this.theme,
    required this.t,
    required this.localeCode,
    required this.isPrefetchExpanded,
    required this.isLocating,
    required this.isOfflineMapInitializing,
    required this.isBottomCardVisible,
    required this.isCalculating,
    required this.isTrackingActive,
    required this.selectedStation,
    required this.selectedLocation,
    required this.selectedNamtangStop,
    required this.routeResult,
    required this.trackerState,
    required this.onTogglePrefetch,
    required this.onStartPrefetch,
    required this.onCenterOnUser,
    required this.onCloseStation,
    required this.onSelectHubStation,
    required this.onSetOrigin,
    required this.onSetDestination,
    required this.onCloseCustomLocation,
    required this.onOpenSearchOverlay,
    required this.onCloseNamtangStop,
    required this.onShowRouteDetail,
  });

  @override
  Widget build(BuildContext context) {
    final canShowRouteResult =
        routeResult != null &&
        !isTrackingActive &&
        selectedStation == null &&
        selectedLocation == null &&
        selectedNamtangStop == null;
    final canShowJourneyPanel =
        isTrackingActive &&
        trackerState != null &&
        selectedStation == null &&
        selectedLocation == null &&
        selectedNamtangStop == null;

    return Stack(
      children: [
        mapLayer,
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                searchCard,
                if (prefetchState.isPrefetching) ...[
                  const SizedBox(height: 8),
                  MapPrefetchWidget(
                    prefetchState: prefetchState,
                    theme: theme,
                    t: t,
                    isExpanded: isPrefetchExpanded,
                    onToggleExpand: onTogglePrefetch,
                    onStartPrefetch: onStartPrefetch,
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: isBottomCardVisible ? 180 : 24,
          child: FloatingActionButton.small(
            heroTag: 'map_gps_fab',
            onPressed: onCenterOnUser,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            child: isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        Positioned(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
          left: 16,
          right: 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selectedStation != null ? 1.0 : 0.0,
            child: selectedStation == null
                ? const SizedBox.shrink()
                : StationDetailsCard(
                    station: selectedStation!,
                    localeCode: localeCode,
                    onClose: onCloseStation,
                    onSelectHubStation: onSelectHubStation,
                    onSetOrigin: onSetOrigin,
                    onSetDestination: onSetDestination,
                  ),
          ),
        ),
        if (selectedLocation != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: CustomLocationCard(
              location: selectedLocation!,
              theme: theme,
              t: t,
              localeCode: localeCode,
              onClose: onCloseCustomLocation,
              onOpenSearchOverlay: onOpenSearchOverlay,
            ),
          ),
        if (selectedNamtangStop != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: NamtangStopCard(
              stop: selectedNamtangStop!,
              theme: theme,
              t: t,
              localeCode: localeCode,
              onClose: onCloseNamtangStop,
              onOpenSearchOverlay: onOpenSearchOverlay,
            ),
          ),
        if (canShowRouteResult)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: RouteResultBanner(
              result: routeResult!,
              t: t,
              onTap: onShowRouteDetail,
            ),
          ),
        if (canShowJourneyPanel)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ActiveJourneyPanel(
              tracker: trackerState!,
              theme: theme,
              t: t,
              localeCode: localeCode,
            ),
          ),
        if (isCalculating) RouteCalculatingOverlay(theme: theme, t: t),
        if (isOfflineMapInitializing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          t.settings.offlineMapPreparing,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
