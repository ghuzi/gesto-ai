import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/urdu_words.dart';
import '../models/backend_health.dart';
import '../models/gesture_event.dart';
import '../services/backend_service.dart';
import 'config.dart';
import 'l10n.dart';

/// Single source of truth for settings, server health and gesture history.
///
/// Persisted in SharedPreferences so the app reopens exactly where the user
/// left it (language, server address, speech preferences, history).
class AppState extends ChangeNotifier {
  AppState();

  static const String _kLanguage = 'gesto.language';
  static const String _kOnboarded = 'gesto.onboarded';
  static const String _kBaseUrl = 'gesto.baseUrl';
  static const String _kSpeechEnabled = 'gesto.speechEnabled';
  static const String _kSpeechRate = 'gesto.speechRate';
  static const String _kHistory = 'gesto.history';
  static const int _maxHistory = 120;

  SharedPreferences? _prefs;

  final BackendService backend = BackendService();

  AppLanguage _language = AppLanguage.english;
  bool _onboarded = false;
  bool _speechEnabled = true;
  double _speechRate = 0.5;
  final List<GestureEvent> _history = <GestureEvent>[];

  BackendHealth? _health;
  bool _healthLoading = false;
  String? _healthError;
  BackendFailure? _healthFailure;
  DateTime? _healthCheckedAt;
  Timer? _healthRetryTimer;
  int _healthRetrySeconds = 0;
  bool _disposed = false;

  // ------------------------------------------------------------- getters
  AppLanguage get language => _language;
  bool get onboarded => _onboarded;
  bool get speechEnabled => _speechEnabled;
  double get speechRate => _speechRate;
  List<GestureEvent> get history => List<GestureEvent>.unmodifiable(_history);
  BackendHealth? get health => _health;
  bool get healthLoading => _healthLoading;
  String? get healthError => _healthError;
  BackendFailure? get healthFailure => _healthFailure;
  DateTime? get healthCheckedAt => _healthCheckedAt;
  bool get healthAutoRetrying => _healthRetryTimer?.isActive ?? false;
  String get baseUrl => backend.baseUrl;

  /// True when the address answered but no Gesto backend lives there —
  /// the user has to point the app at a deployed server.
  bool get backendMissing => _healthFailure == BackendFailure.notDeployed;

  List<String> get gestureLabels {
    final List<String>? live = _health?.gestureLabels;
    if (live != null && live.isNotEmpty) return live;
    return kDefaultGestures;
  }

  bool get modelReady => _health?.modelLoaded ?? false;
  bool get serverReachable => _health != null && _healthError == null;

  // ---------------------------------------------------------------- load
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final String? langCode = prefs.getString(_kLanguage);
    _language = AppLanguage.values.firstWhere(
      (AppLanguage l) => l.code == langCode,
      orElse: () => AppLanguage.english,
    );
    _onboarded = prefs.getBool(_kOnboarded) ?? false;
    _speechEnabled = prefs.getBool(_kSpeechEnabled) ?? true;
    _speechRate = prefs.getDouble(_kSpeechRate) ?? 0.5;
    backend.baseUrl = prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl;

    final String? rawHistory = prefs.getString(_kHistory);
    if (rawHistory != null && rawHistory.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(rawHistory);
        if (decoded is List) {
          for (final Object? item in decoded) {
            if (item is Map<String, dynamic>) {
              _history.add(GestureEvent.fromJson(item));
            }
          }
        }
      } on Object {
        // Corrupt history is not worth crashing over — start empty.
        _history.clear();
      }
    }
    _notify();
  }

  // ------------------------------------------------------------ settings
  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    _notify();
    await _prefs?.setString(_kLanguage, value.code);
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    _notify();
    await _prefs?.setBool(_kOnboarded, true);
  }

  Future<void> setSpeechEnabled(bool value) async {
    _speechEnabled = value;
    _notify();
    await _prefs?.setBool(_kSpeechEnabled, value);
  }

  Future<void> setSpeechRate(double value) async {
    _speechRate = value.clamp(0.25, 0.9);
    _notify();
    await _prefs?.setDouble(_kSpeechRate, _speechRate);
  }

  Future<void> setBaseUrl(String value) async {
    backend.baseUrl = value;
    _health = null;
    _healthError = null;
    _healthFailure = null;
    _healthRetrySeconds = 0;
    _healthRetryTimer?.cancel();
    _notify();
    await _prefs?.setString(_kBaseUrl, backend.baseUrl);
    unawaited(refreshHealth());
  }

  Future<void> resetBaseUrl() => setBaseUrl(AppConfig.defaultBaseUrl);

  // -------------------------------------------------------------- health
  /// Probes `/health`. While the server stays unreachable it re-tries on its
  /// own (15s → 30s → 60s), so a sleeping free-tier instance heals itself
  /// without the user tapping anything.
  Future<void> refreshHealth({bool silent = false}) async {
    if (_healthLoading || _disposed) return;
    _healthRetryTimer?.cancel();
    _healthLoading = true;
    if (!silent) _healthError = null;
    _notify();
    try {
      final BackendHealth result = await backend.fetchHealth();
      _health = result;
      _healthError = null;
      _healthFailure = null;
      _healthRetrySeconds = 0;
    } on BackendException catch (error) {
      _health = null;
      _healthError = error.message;
      _healthFailure = error.failure;
      _scheduleHealthRetry();
    } on Object catch (error) {
      _health = null;
      _healthError = error.toString();
      _healthFailure = BackendFailure.unreachable;
      _scheduleHealthRetry();
    } finally {
      _healthLoading = false;
      _healthCheckedAt = DateTime.now();
      _notify();
    }
  }

  void _scheduleHealthRetry() {
    if (_disposed) return;
    _healthRetryTimer?.cancel();
    _healthRetrySeconds = _healthRetrySeconds == 0
        ? 15
        : (_healthRetrySeconds >= 60 ? 60 : _healthRetrySeconds * 2);
    _healthRetryTimer = Timer(
      Duration(seconds: _healthRetrySeconds),
      () {
        if (!_disposed) unawaited(refreshHealth(silent: true));
      },
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _healthRetryTimer?.cancel();
    super.dispose();
  }


  /// Quick connectivity probe used by Settings → "Test connection".
  Future<BackendHealth> probe(String url) async {
    final BackendService probeClient = BackendService(baseUrl: url);
    return probeClient.fetchHealth(timeout: const Duration(seconds: 20));
  }

  // ------------------------------------------------------------- history
  void addGesture(GestureEvent event) {
    final bool continuous = _history.isNotEmpty &&
        _history.first.gesture == event.gesture &&
        event.at.difference(_history.first.at).inSeconds <= 15;

    if (continuous) {
      // Same sign still being held: refresh confidence/time, do not duplicate.
      _history[0] = _history[0].copyWith(
        confidence: event.confidence,
        at: event.at,
        sentence: event.sentence,
      );
    } else {
      _history.insert(0, event);
      if (_history.length > _maxHistory) {
        _history.removeRange(_maxHistory, _history.length);
      }
    }
    _notify();
    unawaited(_persistHistory());
  }

  Future<void> clearHistory() async {
    _history.clear();
    _notify();
    await _prefs?.remove(_kHistory);
  }

  Future<void> _persistHistory() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    try {
      final String encoded = jsonEncode(
        _history.map((GestureEvent e) => e.toJson()).toList(),
      );
      await prefs.setString(_kHistory, encoded);
    } on Object {
      // Storage full / serialization issue — history stays in memory.
    }
  }
}
