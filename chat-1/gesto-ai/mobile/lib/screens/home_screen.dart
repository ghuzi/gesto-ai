import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../data/urdu_words.dart';
import '../models/gesture_event.dart';
import '../services/tts_service.dart';
import '../widgets/brand_mark.dart';
import 'settings_screen.dart';

/// Deliberately sparse home screen: one clear action, the live server state
/// and just enough recent context. Everything else lives in the other tabs.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenDemo,
    required this.onOpenHistory,
  });

  final VoidCallback onOpenDemo;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final L10n l = L10n.of(context);
    final List<GestureEvent> recent = app.history.take(3).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _Header(app: app, l: l)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                const SizedBox(height: 18),
                _Headline(l: l),
                const SizedBox(height: 10),
                Text(
                  l.taglineShort,
                  style: GText.body.copyWith(fontSize: 14.5, height: 1.6),
                ),
                const SizedBox(height: 24),
                _PrimaryCta(l: l, onTap: onOpenDemo),
                if (!app.serverReachable && !app.healthLoading) ...<Widget>[
                  const SizedBox(height: 12),
                  _OfflineNote(app: app, l: l),
                ],
                const SizedBox(height: 30),
                _SectionRow(
                  title: l.recentGestures,
                  action: app.history.isEmpty ? null : l.seeAll,
                  onAction: onOpenHistory,
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  _EmptyRecent(l: l)
                else
                  ...recent.map(
                    (GestureEvent e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RecentRow(event: e, app: app),
                    ),
                  ),
                const SizedBox(height: 26),
                _SectionRow(title: l.signsYouCanUse),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: _GestureStrip(app: app)),
          const SliverToBoxAdapter(child: SizedBox(height: 34)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.app, required this.l});

  final AppState app;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(22, top + 14, 12, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFEAF7F4), kSurface],
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const BrandMark(size: 34),
              const SizedBox(width: 10),
              const BrandTitle(fontSize: 17),
              const Spacer(),
              _StatusPill(app: app, l: l),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l.settings,
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 21,
                  color: kInkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.app, required this.l});

  final AppState app;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final bool loading = app.healthLoading && app.health == null;
    final bool ready = app.modelReady;
    final bool online = app.serverReachable;

    final Color tint = loading
        ? kInkSoft
        : ready
            ? kTeal
            : online
                ? kAmber
                : kDanger;
    final String label = loading
        ? l.statusChecking
        : ready
            ? l.statusLive
            : online
                ? l.statusNoModel
                : l.statusOffline;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => app.refreshHealth(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: fade(tint, 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fade(tint, 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: fade(tint, 0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// hero
// ---------------------------------------------------------------------------

class _Headline extends StatelessWidget {
  const _Headline({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GText.display.copyWith(fontSize: 32, height: 1.18),
        children: <InlineSpan>[
          TextSpan(text: '${l.heroLine1}\n'),
          TextSpan(
            text: l.heroLine2,
            style: const TextStyle(color: kTealDeep),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.l, required this.onTap});

  final L10n l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(gradient: kHeroGradient),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: fade(Colors.white, 0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.startSigning,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.ctaSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: fade(Colors.white, 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: fade(Colors.white, 0.9),
                    size: 20,
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

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.app, required this.l});

  final AppState app;
  final L10n l;

  @override
  Widget build(BuildContext context) {
    final bool missing = app.backendMissing;
    final String text = missing ? l.backendMissingTitle : l.serverOffline;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: fade(kDanger, 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fade(kDanger, 0.16)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 17, color: kDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l.autoRetryHint,
                  style: GText.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => app.refreshHealth(),
            style: TextButton.styleFrom(
              foregroundColor: kTealDeep,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 11.5,
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

// ---------------------------------------------------------------------------
// recent + gestures
// ---------------------------------------------------------------------------

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: GText.h3.copyWith(fontSize: 15, letterSpacing: -0.2),
        ),
        const Spacer(),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: <Widget>[
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTealDeep,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: kTealDeep,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.history_rounded, size: 18, color: kInkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.noGesturesYet,
              style: GText.bodySmall.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.event, required this.app});

  final GestureEvent event;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => TtsService.instance.speak(
          urduText: event.sentence ?? urduSentenceFor(event.gesture),
          hindiText: spokenFor(event.gesture),
          rate: app.speechRate,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kLine),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: fade(kTeal, 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.sign_language_rounded,
                  size: 17,
                  color: kTealDeep,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayGesture(event.gesture),
                      style: GText.h3.copyWith(fontSize: 14),
                    ),
                    Text(
                      urduFor(event.gesture),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GText.bodySmall.copyWith(fontSize: 12, height: 1.7),
                    ),
                  ],
                ),
              ),
              Text(
                _clock(event.at),
                style: GText.mono.copyWith(fontSize: 10.5),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.volume_up_outlined,
                size: 15,
                color: kInkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clock(DateTime at) {
    final String h = at.hour.toString().padLeft(2, '0');
    final String m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _GestureStrip extends StatelessWidget {
  const _GestureStrip({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final List<String> gestures = app.gestureLabels;

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: gestures.length,
        separatorBuilder: (BuildContext context, int i) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String gesture = gestures[index];
          return Material(
            color: kCard,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => TtsService.instance.speak(
                urduText: urduSentenceFor(gesture),
                hindiText: spokenFor(gesture),
                rate: app.speechRate,
              ),
              child: Container(
                width: 96,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kLine),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      displayGesture(gesture),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      urduFor(gesture),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: kTealDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
