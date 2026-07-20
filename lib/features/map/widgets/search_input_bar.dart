import 'package:flutter/material.dart';

class SearchInputBar extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destController;
  final FocusNode originFocusNode;
  final FocusNode destFocusNode;
  final bool isSelectingOrigin;
  final String originHint;
  final String destHint;
  final VoidCallback onOriginTap;
  final VoidCallback onDestTap;
  final ValueChanged<String> onOriginChanged;
  final ValueChanged<String> onDestChanged;
  final VoidCallback onOriginClear;
  final VoidCallback onDestClear;
  final VoidCallback? onSwap;

  const SearchInputBar({
    super.key,
    required this.originController,
    required this.destController,
    required this.originFocusNode,
    required this.destFocusNode,
    required this.isSelectingOrigin,
    required this.originHint,
    required this.destHint,
    required this.onOriginTap,
    required this.onDestTap,
    required this.onOriginChanged,
    required this.onDestChanged,
    required this.onOriginClear,
    required this.onDestClear,
    this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Hero(
      tag: 'search_bar_card',
      flightShuttleBuilder:
          (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            final theme = Theme.of(flightContext);
            final isDark = theme.brightness == Brightness.dark;
            final shimmerColor = isDark
                ? Colors.white12
                : Colors.black.withValues(alpha: 0.06);

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
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(width: 2, height: 24, color: shimmerColor),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
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
                            Container(
                              width: double.infinity,
                              height: 1,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                            ),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.trip_origin_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(
                      width: 2,
                      height: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.white24),
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: originController,
                        focusNode: originFocusNode,
                        onTap: onOriginTap,
                        onChanged: onOriginChanged,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          hintText: originHint,
                          border: InputBorder.none,
                          hintStyle: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          suffixIcon:
                              isSelectingOrigin &&
                                  originController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: onOriginClear,
                                )
                              : null,
                        ),
                      ),
                      Divider(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.15,
                        ),
                        height: 1,
                      ),
                      TextField(
                        controller: destController,
                        focusNode: destFocusNode,
                        onTap: onDestTap,
                        onChanged: onDestChanged,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          hintText: destHint,
                          border: InputBorder.none,
                          hintStyle: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          suffixIcon:
                              !isSelectingOrigin &&
                                  destController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: onDestClear,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSwap,
                  icon: Icon(
                    Icons.swap_vert_rounded,
                    size: 26,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.08,
                    ),
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
    );
  }
}
