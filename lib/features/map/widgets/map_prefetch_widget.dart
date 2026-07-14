import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/translation_helper.dart';
import '../../../providers/providers.dart';
import '../cached_tile_provider.dart';
import '../painters/progress_painter.dart';

class MapPrefetchWidget extends ConsumerWidget {
  final MapPrefetchProgress prefetchState;
  final ThemeData theme;
  final AppLocalizations t;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onStartPrefetch;

  const MapPrefetchWidget({
    super.key,
    required this.prefetchState,
    required this.theme,
    required this.t,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onStartPrefetch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percentage = (prefetchState.progress * 100).toInt();
    final showDetails = isExpanded && !prefetchState.isPaused;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          foregroundPainter: RoundedRectangleProgressPainter(
            progress: prefetchState.progress,
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            strokeWidth: 3.0,
            borderRadius: 8.0,
          ),
          child: GestureDetector(
            onTap: () {
              if (prefetchState.isPaused) {
                CachedTileProvider.isPaused = false;
                ref.read(mapPrefetchProvider.notifier).resumePrefetch();
                if (!isExpanded) onToggleExpand();
                onStartPrefetch();
              } else {
                if (!isExpanded) {
                  onToggleExpand();
                } else {
                  CachedTileProvider.isPaused = true;
                  ref.read(mapPrefetchProvider.notifier).pausePrefetch();
                  onToggleExpand();
                }
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  prefetchState.isPaused ? Icons.play_arrow : Icons.pause,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: showDetails ? 288 : 0,
          height: showDetails ? 104 : 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 288,
              maxWidth: 288,
              minHeight: 104,
              maxHeight: 104,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 280,
                  height: 104,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.settings.offlineMapDownloading,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: onToggleExpand,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: prefetchState.progress,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.settings.offlineMapDownloaded(prefetchState.currentTile, prefetchState.totalTiles),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.settings.offlineMapCachedAndNew(prefetchState.cachedCount, prefetchState.successCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
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
