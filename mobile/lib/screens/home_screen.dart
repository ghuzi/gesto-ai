import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/section_card.dart';
import '../widgets/step_card.dart';
import '../widgets/wave_painter.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenDemo,
    required this.onOpenAbout,
  });

  final VoidCallback onOpenDemo;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final L10n l = L10n.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Hero(l: l, onOpenDemo: onOpenDemo, onOpenAbout: onOpenAbout),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StatsRow(l: l),
                  const SizedBox(height: 14),
                  _ServerStatusCard(app: app, l: l),
                  const SizedBox(height: 30),
                  SectionHeader(
                    eyebrow: l.howItWorks,
                    title: l.signItSayIt,
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
                    child: Column(
                      children: <Widget>[
                        StepCard(
                          index: 1,
                          title: l.stepCameraTitle,
                          body: l.stepCameraBody,
                          icon: Icons.videocam_rounded,
                        ),
                        const _StepDivider(),
                        StepCard(
                          index: 2,
                          title: l.stepModelTitle,
                          body: l.stepModelBody,
                          icon: Icons.auto_awesome_rounded,
                        ),
                        const _StepDivider(),
                        StepCard(
                          index: 3,
                          title: l.stepSpeechTitle,
                          body: l.stepSpeechBody,
                          icon: Icons.volume_up_rounded,
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _DemoCta(l: l, onTap: onOpenDemo),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      l.footerNote,
                      textAlign: TextAlign.center,
                      style: GText.bodySmall.copyWith(fontSize: 12),
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

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Divider(color: kLine, height: 1),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.l,
    required this.onOpenDemo,
    required this.onOpenAbout,
  });

  final L10n l;
  final VoidCallback onOpenDemo;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: kHeroGradient),
            ),
          ),
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: fade(Colors.white, 0.09), width: 26),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -60,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fade(kAqua, 0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 58),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const BrandMark(size: 40, glow: true),
                    const SizedBox(width: 10),
                    const BrandTitle(fontSize: 19, onDark: true),
                    const Spacer(),
                    _HeroIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: l.settings,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Eyebrow(l.heroEyebrow, onDark: true),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: GText.display.copyWith(fontSize: 46, color: Colors.white),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Gesto '),
                      TextSpan(text: 'AI', style: TextStyle(color: kAqua)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Text(
                    l.heroTagline,
                    style: GText.body.copyWith(
                      color: fade(Colors.white, 0.86),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenDemo,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kTealDark,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        icon: const Icon(Icons.videocam_rounded, size: 20),
                        label: Text(l.tryLiveDemo),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _HeroGhostButton(label: l.whyItMatters, onTap: onOpenAbout),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            child: WavePainter(color: kSurface, height: 34),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fade(Colors.white, 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _HeroGhostButton extends StatelessWidget {
  const _HeroGhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: fade(Colors.white, 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _Stat(value: l.statsPeople, label: l.statsPeopleLabel)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: l.statsGestures, label: l.statsGesturesLabel)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(value: l.statsRealtime, label: l.statsRealtimeLabel)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: kTealDeep,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GText.bodySmall.copyWith(fontSize: 11.5, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({required this.app, required this.l});

  final AppState app;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final bool ready = app.modelReady;
    final bool loading = app.healthLoading;
    final bool online = app.serverReachable;
    final Color tint = ready ? kTeal : (online ? kAmber : kDanger);
    final String text = loading
        ? l.checking
        : ready
            ? '${l.modelReady} · ${l.gesturesAvailable(app.gestureLabels.length)}'
            : online
                ? l.modelNotReady
                : l.serverOffline;

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fade(tint, 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(tint),
                    ),
                  )
                : Icon(
                    ready
                        ? Icons.cloud_done_rounded
                        : (online
                            ? Icons.warning_amber_rounded
                            : Icons.cloud_off_rounded),
                    color: tint,
                    size: 21,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.serverStatus,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: kInkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GText.h3.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: loading ? null : () => app.refreshHealth(),
            style: TextButton.styleFrom(
              foregroundColor: kTealDeep,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(l.checkAgain),
          ),
        ],
      ),
    );
  }
}

class _DemoCta extends StatelessWidget {
  const _DemoCta({required this.l, required this.onTap});

  final L10n l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(gradient: kHeroGradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.signItSayIt,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.startDemo,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: fade(Colors.white, 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: fade(Colors.white, 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
