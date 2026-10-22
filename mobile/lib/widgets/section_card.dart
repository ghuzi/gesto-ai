import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The rounded white panel used everywhere in the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = kCard,
    this.borderColor,
    this.onTap,
    this.radius = 22,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: shadow ? kSoftShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase label with a leading accent bar.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.onDark = false});

  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color color = onDark ? kAqua : kTealDeep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Section heading + optional subtitle, used on every scroll page.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.onDark = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Eyebrow(eyebrow, onDark: onDark),
        const SizedBox(height: 10),
        Text(
          title,
          style: GText.h2.copyWith(color: onDark ? Colors.white : kInk),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: GText.body.copyWith(
              color: onDark ? fade(Colors.white, 0.8) : kInkSoft,
            ),
          ),
        ],
      ],
    );
  }
}
