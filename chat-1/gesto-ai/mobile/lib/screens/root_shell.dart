import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import 'about_screen.dart';
import 'demo_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Bottom-navigation shell. All four tabs stay mounted so the camera demo
/// keeps its state while the user peeks at history or settings.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.read(context);
      if (app.health == null && !app.healthLoading) {
        app.refreshHealth();
      }
    });
  }

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final L10n l = L10n.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          TickerMode(
            enabled: _index == 0,
            child: HomeScreen(
              onOpenDemo: () => _select(1),
              onOpenHistory: () => _select(2),
            ),
          ),
          TickerMode(
            enabled: _index == 1,
            child: DemoScreen(active: _index == 1),
          ),
          TickerMode(enabled: _index == 2, child: const HistoryScreen()),
          TickerMode(enabled: _index == 3, child: const AboutScreen()),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        onSelect: _select,
        items: <_BarItem>[
          _BarItem(Icons.home_outlined, Icons.home_rounded, l.home),
          _BarItem(Icons.videocam_outlined, Icons.videocam_rounded, l.demo),
          _BarItem(Icons.history_rounded, Icons.history_rounded, l.history),
          _BarItem(Icons.info_outline_rounded, Icons.info_rounded, l.about),
        ],
      ),
    );
  }
}

class _BarItem {
  const _BarItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Minimal bottom bar: icon + label, teal when selected, no Material pill.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<_BarItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _BarButton(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? kTealDeep : fade(kInkSoft, 0.78);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? fade(kTeal, 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              selected ? item.activeIcon : item.icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
