import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../providers/providers.dart';
import '../../../models/namtang_stop.dart';
import '../../../models/station.dart';
import '../../../models/custom_location.dart';

class NamtangStopsLayer extends ConsumerStatefulWidget {
  final MapController mapController;
  final ValueNotifier<double> currentZoom;
  final bool isRouteActive;
  final Brightness themeBrightness;
  final Function(NamtangStop) onStopSelected;

  const NamtangStopsLayer({
    super.key,
    required this.mapController,
    required this.currentZoom,
    required this.isRouteActive,
    required this.themeBrightness,
    required this.onStopSelected,
  });

  @override
  ConsumerState<NamtangStopsLayer> createState() => _NamtangStopsLayerState();
}

class _NamtangStopsLayerState extends ConsumerState<NamtangStopsLayer> {
  List<Marker> _cachedMarkers = [];
  LatLngBounds? _lastBounds;

  @override
  void initState() {
    super.initState();
    widget.currentZoom.addListener(_onZoomChanged);
    _updateMarkers();
  }

  @override
  void didUpdateWidget(covariant NamtangStopsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRouteActive != widget.isRouteActive ||
        oldWidget.themeBrightness != widget.themeBrightness) {
      _updateMarkers();
    }
  }

  @override
  void dispose() {
    widget.currentZoom.removeListener(_onZoomChanged);
    super.dispose();
  }

  void _onZoomChanged() {
    // Only update if zoom crosses the 15.0 threshold, or if bounds changed significantly
    if (widget.currentZoom.value < 15.0 && _cachedMarkers.isNotEmpty) {
      setState(() {
        _cachedMarkers = [];
      });
    } else if (widget.currentZoom.value >= 15.0) {
      _checkBoundsAndUpdate();
    }
  }

  void _checkBoundsAndUpdate() {
    try {
      final bounds = widget.mapController.camera.visibleBounds;
      if (_lastBounds == null || !_isBoundsSimilar(_lastBounds!, bounds)) {
        _lastBounds = bounds;
        _updateMarkers();
      }
    } catch (e) {
      // Map camera might not be ready
    }
  }

  bool _isBoundsSimilar(LatLngBounds a, LatLngBounds b) {
    // Simple heuristic: if centers are close and zoom is similar
    return a.containsBounds(b); // Requires strict containment for cache hit
  }

  void _updateMarkers() {
    if (widget.currentZoom.value < 15.0 || widget.isRouteActive) {
      if (_cachedMarkers.isNotEmpty) {
        setState(() => _cachedMarkers = []);
      }
      return;
    }

    final transitRepo = ref.read(transitRepositoryProvider);
    final bounds = widget.mapController.camera.visibleBounds;
    final newMarkers = <Marker>[];

    for (final stop in transitRepo.namtangStops) {
      final stopPoint = LatLng(stop.lat, stop.lng);
      if (bounds.contains(stopPoint)) {
        newMarkers.add(
          Marker(
            point: stopPoint,
            width: 24,
            height: 24,
            alignment: Alignment.center,
            child: RepaintBoundary(
              child: GestureDetector(
                onTap: () => widget.onStopSelected(stop),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.themeBrightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: stop.type == 'boat'
                          ? Colors.blue.shade700
                          : (stop.type == 'commuter_train'
                              ? Colors.red.shade700
                              : Colors.green.shade700),
                      width: 2.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      stop.type == 'boat'
                          ? Icons.directions_boat_rounded
                          : (stop.type == 'commuter_train'
                              ? Icons.train_rounded
                              : Icons.directions_bus_rounded),
                      size: 12,
                      color: stop.type == 'boat'
                          ? Colors.blue.shade700
                          : (stop.type == 'commuter_train'
                              ? Colors.red.shade700
                              : Colors.green.shade700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    setState(() {
      _cachedMarkers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(markers: _cachedMarkers);
  }
}
