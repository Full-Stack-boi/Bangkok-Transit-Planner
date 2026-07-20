import 'package:flutter/material.dart';

class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (i) => AnimationController(
        vsync: this,
        duration: widget.duration,
        value: i == widget.index ? 1.0 : 0.0,
      ),
    );
    _animations = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOutCubic))
        .toList();
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controllers[oldWidget.index].reverse();
      _controllers[widget.index].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        final isSelected = i == widget.index;

        final Animation<double> opacityAnimation = _animations[i];
        final Animation<double> scaleAnimation =
            Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: _controllers[i],
                curve: Curves.easeOutCubic,
              ),
            );

        return FadeTransition(
          opacity: opacityAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: IgnorePointer(
              ignoring: !isSelected,
              child: TickerMode(enabled: isSelected, child: widget.children[i]),
            ),
          ),
        );
      }),
    );
  }
}
