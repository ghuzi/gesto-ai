import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The Gesto AI logo mark: a gradient tile with a signing-hand glyph.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.glow = false});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kHeroGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: glow ? kTealGlow : null,
      ),
      child: Icon(
        Icons.sign_language,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}

/// "Gesto AI" word mark used in the app bar and hero.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.fontSize = 20, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
          color: onDark ? Colors.white : kInk,
        ),
        children: <InlineSpan>[
          const TextSpan(text: 'Gesto '),
          TextSpan(
            text: 'AI',
            style: TextStyle(
              color: onDark ? kAqua : kTeal,
            ),
          ),
        ],
      ),
    );
  }
}
