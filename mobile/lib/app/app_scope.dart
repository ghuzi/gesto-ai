import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Provides the single [AppState] instance to the whole widget tree and
/// rebuilds dependents whenever it notifies.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Subscribes the calling widget to state changes.
  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found above this widget.');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing (safe in callbacks / initState).
  static AppState read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found above this widget.');
    return scope!.notifier!;
  }
}
