import 'dart:async';
import 'package:flutter/material.dart';

/// In-app notification banner component.
class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration displayDuration;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 8),
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    // Start entrance animation
    _controller.forward();

    // Auto dismiss timer
    _dismissTimer = Timer(widget.displayDuration, _dismiss);
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _offsetAnimation,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B).withValues(
                        alpha: 0.9,
                      ) // slate-800
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF6366F1).withValues(
                          alpha: 0.4,
                        ) // Indigo glow
                      : const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF4F46E5))
                            .withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () {
                    _dismissTimer?.cancel();
                    widget.onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Left brand indicator bar
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Glowing transit icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF4F46E5))
                                    .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.train_rounded,
                            color: isDark
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF4F46E5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Notification text details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Dismiss button
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            size: 20,
                          ),
                          onPressed: () {
                            _dismissTimer?.cancel();
                            _dismiss();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
