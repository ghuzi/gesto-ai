import 'package:flutter/material.dart';

/// Gesto AI design tokens — mirrors the web frontend palette so the
/// mobile app and the deployed site feel like one product.

const Color kInk = Color(0xFF0B2E33);
const Color kInkSoft = Color(0xFF456B70);
const Color kTeal = Color(0xFF0D9488);
const Color kTealDeep = Color(0xFF0F766E);
const Color kTealDark = Color(0xFF0B4F4A);
const Color kBlue = Color(0xFF2563EB);
const Color kAqua = Color(0xFF99F6E4);
const Color kSurface = Color(0xFFF4FAF9);
const Color kCard = Color(0xFFFFFFFF);
const Color kLine = Color(0xFFDCEBE9);
const Color kDanger = Color(0xFFE11D48);
const Color kAmber = Color(0xFFD97706);

/// Cross-version safe alpha application (avoids the deprecated `withOpacity`).
Color fade(Color color, double alpha) => color.withAlpha((alpha * 255).round());

const LinearGradient kHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kTeal, kTealDeep, kTealDark],
  stops: <double>[0.0, 0.55, 1.0],
);

const LinearGradient kAquaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFCCFBF1), Color(0xFFEFF6FF)],
);

const List<BoxShadow> kSoftShadow = <BoxShadow>[
  BoxShadow(color: Color(0x140B2E33), blurRadius: 24, offset: Offset(0, 10)),
];

const List<BoxShadow> kTealGlow = <BoxShadow>[
  BoxShadow(color: Color(0x330D9488), blurRadius: 28, offset: Offset(0, 12)),
];

class GText {
  const GText._();

  static const TextStyle display = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.4,
    height: 1.05,
    color: kInk,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.12,
    color: kInk,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: kInk,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    color: kInk,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    height: 1.6,
    color: kInkSoft,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: kInkSoft,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.3,
    color: kTealDeep,
  );
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontFamily: 'monospace',
    color: kInkSoft,
  );
}

ThemeData buildGestoTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: kTeal).copyWith(
    primary: kTeal,
    onPrimary: Colors.white,
    secondary: kBlue,
    onSecondary: Colors.white,
    surface: kCard,
    onSurface: kInk,
    error: kDanger,
    outline: kLine,
  );

  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kSurface,
  );

  return base.copyWith(
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kInk,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: kInk, displayColor: kInk),
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kTeal),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: kTeal,
      inactiveTrackColor: kLine,
      thumbColor: kTeal,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: kInkSoft, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kTeal, width: 1.6),
      ),
    ),
  );
}
