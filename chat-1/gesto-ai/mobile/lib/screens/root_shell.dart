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
              onOpenAbout: () => _select(3),
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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: kCard,
          border: Border(top: BorderSide(color: kLine)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            height: 66,
            backgroundColor: kCard,
            surfaceTintColor: Colors.transparent,
            indicatorColor: fade(kTeal, 0.14),
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded, color: kTealDeep),
                label: l.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.videocam_outlined),
                selectedIcon: const Icon(Icons.videocam_rounded, color: kTealDeep),
                label: l.demo,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_rounded),
                selectedIcon: const Icon(Icons.history_rounded, color: kTealDeep),
                label: l.history,
              ),
              NavigationDestination(
                icon: const Icon(Icons.info_outline_rounded),
                selectedIcon: const Icon(Icons.info_rounded, color: kTealDeep),
                label: l.about,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
