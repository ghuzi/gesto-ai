import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Urdu speech output.
///
/// Android phones rarely ship an Urdu ("ur") voice, but many ship a Hindi
/// ("hi-IN") one. Urdu and Hindi share the same spoken language, so the caller
/// passes both an Urdu script and a Devanagari version of the sentence and we
/// pick whichever the device can actually pronounce.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool _hasUrduVoice = false;
  bool _hasHindiVoice = false;
  bool _hasAnyVoice = true;
  String _language = 'en-US';

  bool get hasVoice => _hasAnyVoice;
  bool get hasUrduVoice => _hasUrduVoice;
  bool get hasHindiVoice => _hasHindiVoice;
  String get language => _language;

  /// First non-English language the device can actually speak.
  String get voiceLabel {
    if (_hasUrduVoice) return 'Urdu (ur)';
    if (_hasHindiVoice) return 'Hindi (hi)';
    if (_hasAnyVoice) return 'English only';
    return 'No voice installed';
  }

  Future<void> ensureReady() async {
    if (_ready) return;
    _ready = true;

    try {
      await _tts.awaitSpeakCompletion(true);
    } on Object {
      // Not fatal on older engines.
    }

    // The TTS engine on Android needs a moment before listing voices.
    List<String> languages = <String>[];
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final dynamic raw = await _tts.getLanguages;
        if (raw is List) {
          for (final dynamic item in raw) {
            languages.add(item.toString().toLowerCase());
          }
        }
      } on Object {
        // Ignore — we fall back to English below.
      }
      if (languages.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    _hasUrduVoice = languages.any((String l) => l.startsWith('ur'));
    _hasHindiVoice = languages.any((String l) => l.startsWith('hi'));
    _hasAnyVoice = true;

    // Preferred pronunciation order: Urdu, then Hindi (same spoken language),
    // then plain English as a last resort.
    final List<String> candidates = <String>[
      if (_hasUrduVoice) ...<String>[
        languages.firstWhere(
          (String l) => l.startsWith('ur-PK'),
          orElse: () => languages.firstWhere((String l) => l.startsWith('ur')),
        ),
      ],
      if (_hasHindiVoice) ...<String>[
        languages.firstWhere(
          (String l) => l.startsWith('hi-IN'),
          orElse: () => languages.firstWhere((String l) => l.startsWith('hi')),
        ),
      ],
      // Engines that do not enumerate voices still often support these tags.
      'hi-IN',
      'ur-PK',
      'en-US',
    ];

    for (final String candidate in candidates) {
      try {
        final dynamic result = await _tts.setLanguage(candidate);
        if (result == 1 || result == true) {
          _language = candidate;
          if (candidate.startsWith('ur')) _hasUrduVoice = true;
          if (candidate.startsWith('hi')) _hasHindiVoice = true;
          break;
        }
      } on Object {
        // Try the next candidate.
      }
    }

    if (Platform.isIOS || Platform.isMacOS) {
      try {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } on Object {
        // iOS-only niceties; safe to ignore.
      }
    }
  }

  /// Speaks [urduText], or [hindiText] when the device has no Urdu voice.
  Future<void> speak({
    required String urduText,
    required String hindiText,
    required double rate,
  }) async {
    await ensureReady();
    if (!_hasAnyVoice) return;

    final String text = _language.startsWith('ur')
        ? urduText
        : (_language.startsWith('hi') ? hindiText : urduText);

    try {
      await _tts.stop();
      // Android maps 0.5 to "normal" speech rate; iOS maps 1.0 to normal.
      await _tts.setSpeechRate(Platform.isIOS ? (rate * 1.0) : rate);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
    } on Object catch (error) {
      debugPrint('[gesto-ai] TTS failed: $error');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Nothing is speaking.
    }
  }
}
