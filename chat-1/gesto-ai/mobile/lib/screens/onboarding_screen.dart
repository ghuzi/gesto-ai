import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../widgets/brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.sign_language_rounded,
      titleIndex: 0,
      bodyIndex: 0,
      accent: kTeal,
    ),
    _Slide(
      icon: Icons.auto_awesome_rounded,
      titleIndex: 1,
      bodyIndex: 1,
      accent: kBlue,
    ),
    _Slide(
      icon: Icons.videocam_rounded,
      titleIndex: 2,
      bodyIndex: 2,
      accent: kTealDeep,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _title(L10n l, int index) {
    switch (index) {
      case 0:
        return l.onboardTitle1;
      case 1:
        return l.onboardTitle2;
      default:
        return l.onboardTitle3;
    }
  }

  String _body(L10n l, int index) {
    switch (index) {
      case 0:
        return l.onboardBody1;
      case 1:
        return l.onboardBody2;
      default:
        return l.onboardBody3;
    }
  }

  Future<void> _finish() => AppScope.read(context).completeOnboarding();

  void _next() {
    if (_page >= _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);
    final bool isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: <Widget>[
                  const BrandMark(size: 38),
                  const SizedBox(width: 10),
                  const BrandTitle(fontSize: 18),
                  const Spacer(),
                  _LanguagePill(l: l),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (int index) => setState(() => _page = index),
                itemBuilder: (BuildContext context, int index) {
                  final _Slide slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                fade(slide.accent, 0.16),
                                fade(slide.accent, 0.04),
                              ],
                            ),
                            border: Border.all(color: fade(slide.accent, 0.2)),
                          ),
                          child: Icon(slide.icon, size: 60, color: slide.accent),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          _title(l, slide.titleIndex),
                          textAlign: TextAlign.center,
                          style: GText.h1,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _body(l, slide.bodyIndex),
                          textAlign: TextAlign.center,
                          style: GText.body.copyWith(fontSize: 15, height: 1.65),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(_slides.length, (int i) {
                      final bool selected = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? kTeal : fade(kTeal, 0.22),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: kTealDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(
                        isLast
                            ? l.getStarted
                            : (_page == 0 ? l.continueLabel : l.next),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: isLast
                        ? null
                        : TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: kInkSoft,
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(l.skip),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopupMenuButton<AppLanguage>(
      initialValue: app.language,
      onSelected: app.setLanguage,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppLanguage>>[
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.english,
          child: Text(AppLanguage.english.label),
        ),
        PopupMenuItem<AppLanguage>(
          value: AppLanguage.urdu,
          child: Text(AppLanguage.urdu.label),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.language_rounded, size: 16, color: kTealDeep),
            const SizedBox(width: 6),
            Text(
              app.language.label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.titleIndex,
    required this.bodyIndex,
    required this.accent,
  });

  final IconData icon;
  final int titleIndex;
  final int bodyIndex;
  final Color accent;
}
