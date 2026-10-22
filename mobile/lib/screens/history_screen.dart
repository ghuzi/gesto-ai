import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../data/urdu_words.dart';
import '../models/gesture_event.dart';
import '../services/tts_service.dart';
import '../widgets/brand_mark.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _filter;

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}';

  String _dayLabel(L10n l, DateTime at) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(at.year, at.month, at.day);
    final int diff = today.difference(day).inDays;
    if (diff == 0) return l.today;
    if (diff == 1) return l.yesterday;
    return '${_two(at.day)}/${_two(at.month)}/${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final L10n l = L10n.of(context);
    final List<GestureEvent> all = app.history;
    final List<String> filters = <String>{
      for (final GestureEvent event in all) event.gesture,
    }.toList()
      ..sort();

    final List<GestureEvent> items = _filter == null
        ? all
        : all.where((GestureEvent e) => e.gesture == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Text(l.history),
          ],
        ),
        actions: <Widget>[
          if (all.isNotEmpty)
            IconButton(
              tooltip: l.clearAll,
              onPressed: () => _confirmClear(l, app),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: all.isEmpty
          ? _EmptyHistory(l: l)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '${all.length} ${l.savedGestures}',
                      style: GText.bodySmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      l.filter,
                      style: GText.bodySmall.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      _FilterChip(
                        label: l.all,
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final String gesture in filters)
                        _FilterChip(
                          label: displayGesture(gesture),
                          selected: _filter == gesture,
                          onTap: () => setState(
                            () => _filter = _filter == gesture ? null : gesture,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ..._buildGroups(l, app, items),
              ],
            ),
    );
  }

  List<Widget> _buildGroups(
    L10n l,
    AppState app,
    List<GestureEvent> items,
  ) {
    final List<Widget> widgets = <Widget>[];
    String? currentDay;

    for (final GestureEvent event in items) {
      final String day = _dayLabel(l, event.at);
      if (day != currentDay) {
        currentDay = day;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10, left: 4),
            child: Text(
              day,
              style: GText.label.copyWith(color: kInkSoft, letterSpacing: 1.1),
            ),
          ),
        );
      }
      widgets.add(_HistoryRow(event: event, time: _time(event.at), l: l, app: app));
    }
    return widgets;
  }

  Future<void> _confirmClear(L10n l, AppState app) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.clearAll),
        content: Text(l.clearAllConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.clearHistory();
      if (mounted) setState(() => _filter = null);
    }
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.event,
    required this.time,
    required this.l,
    required this.app,
  });

  final GestureEvent event;
  final String time;
  final L10n l;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: kAquaGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.sign_language_rounded,
              color: kTealDeep,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        displayGesture(event.gesture),
                        style: GText.h3.copyWith(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(event.confidence * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: kTealDeep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  event.sentence?.trim().isNotEmpty == true
                      ? event.sentence!.trim()
                      : urduFor(event.gesture),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GText.bodySmall.copyWith(fontSize: 12.5, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: GText.mono.copyWith(fontSize: 11),
          ),
          IconButton(
            tooltip: l.speak,
            visualDensity: VisualDensity.compact,
            onPressed: () => unawaited(
              TtsService.instance.speak(
                urduText: event.sentence ?? urduSentenceFor(event.gesture),
                hindiText: spokenFor(event.gesture),
                rate: app.speechRate,
              ),
            ),
            icon: const Icon(
              Icons.play_circle_outline_rounded,
              color: kTealDeep,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? kTealDeep : kCard,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? kTealDeep : kLine),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : kInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.l});

  final L10n l;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kAquaGradient,
                border: Border.all(color: fade(kTeal, 0.16)),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 42,
                color: kTealDeep,
              ),
            ),
            const SizedBox(height: 20),
            Text(l.historyTitle, style: GText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              l.historyEmpty,
              textAlign: TextAlign.center,
              style: GText.body,
            ),
          ],
        ),
      ),
    );
  }
}
