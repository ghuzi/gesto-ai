import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Animated 0..1 confidence meter with a percentage label.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({
    super.key,
    required this.value,
    this.label,
    this.showPercent = true,
  });

  final double value;
  final String? label;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final double clamped = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    final int percent = (clamped * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label ?? '',
              style: GText.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (showPercent)
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTealDeep,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double animated, Widget? child) {
              return LinearProgressIndicator(
                value: animated,
                minHeight: 10,
                backgroundColor: kLine,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(kTeal, kBlue, animated) ?? kTeal,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
