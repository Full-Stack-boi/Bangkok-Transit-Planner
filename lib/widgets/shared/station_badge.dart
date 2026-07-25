import 'package:flutter/material.dart';
import '../../core/theme/transit_colors.dart';

/// Reusable badge widget for rendering station codes and line badges
class StationBadge extends StatelessWidget {
  final String text;
  final String lineId;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final Color? textColor;

  const StationBadge({
    super.key,
    required this.text,
    required this.lineId,
    this.fontSize = 12.0,
    this.fontWeight = FontWeight.bold,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.backgroundColor,
    this.textColor,
  });

  /// Factory constructor for small interchange pill badges
  factory StationBadge.pill({
    Key? key,
    required String text,
    required String lineId,
  }) {
    return StationBadge(
      key: key,
      text: text,
      lineId: lineId,
      fontSize: 9.0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? TransitColors.getLineColor(lineId);
    final txtColor = textColor ?? TransitColors.getLineTextColor(lineId);

    return Container(
      padding: padding,
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Text(
        text,
        style: TextStyle(
          color: txtColor,
          fontWeight: fontWeight,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
