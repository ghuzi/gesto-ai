import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../app/config.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../models/backend_health.dart';
import '../services/backend_service.dart';
import '../services/tts_service.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;

  bool _testing = false;
  bool _testOk = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppScope.read(context).baseUrl);
    unawaited(
      TtsService.instance.ensureReady().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveUrl(AppState app, L10n l) async {
    FocusScope.of(context).unfocus();
    await app.setBaseUrl(_urlController.text);
    if (!mounted) return;
    setState(() {
      _urlController.text = app.baseUrl;
      _testMessage = null;
    });
    _snack(l.saved);
  }

  Future<void> _resetUrl(AppState app) async {
    await app.resetBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = app.baseUrl;
      _testMessage = null;
    });
  }

  Future<void> _test(L10n l) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final BackendHealth health = await AppScope.read(context).probe(
        _urlController.text,
      );
      if (!mounted) return;
      setState(() {
        _testOk = health.modelLoaded;
        _testMessage = health.modelLoaded
            ? '${l.connectionOk} · ${l.modelReady} · ${l.gesturesAvailable(health.gestureLabels.length)}'
            : '${l.connectionOk} · ${l.modelNotReady}';
      });
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = '${l.connectionFailed} · ${error.message}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = '${l.connectionFailed} · $error';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _confirmClear(AppState app, L10n l) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.clearHistory),
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
      if (mounted) _snack(l.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final L10n l = L10n.of(context);
    final TtsService tts = TtsService.instance;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          // ------------------------------------------------------ language
          _SectionTitle(l.languageSetting),
          SectionCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: <Widget>[
                _LanguageTile(
                  label: 'English',
                  selected: app.language == AppLanguage.english,
                  onTap: () => app.setLanguage(AppLanguage.english),
                ),
                _LanguageTile(
                  label: 'اردو',
                  selected: app.language == AppLanguage.urdu,
                  onTap: () => app.setLanguage(AppLanguage.urdu),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Text(
                    l.languageHelp,
                    style: GText.bodySmall.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ------------------------------------------------------- backend
          _SectionTitle(l.backend),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveUrl(app, l),
                  decoration: InputDecoration(
                    hintText: AppConfig.defaultBaseUrl,
                    prefixIcon: const Icon(Icons.dns_outlined, size: 19),
                  ),
                  style: const TextStyle(fontSize: 13.5, color: kInk),
                ),
                const SizedBox(height: 8),
                Text(l.backendHelp, style: GText.bodySmall.copyWith(fontSize: 11.5)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: _testing ? null : () => _saveUrl(app, l),
                        style: FilledButton.styleFrom(
                          backgroundColor: kTealDeep,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(l.save),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : () => _test(l),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTealDeep,
                          side: const BorderSide(color: kLine),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(_testing ? l.testing : l.testConnection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _testing ? null : () => _resetUrl(app),
                    style: TextButton.styleFrom(
                      foregroundColor: kInkSoft,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(l.resetDefault),
                  ),
                ),
                if (_testMessage != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: fade(_testOk ? kTeal : kDanger, 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fade(_testOk ? kTeal : kDanger, 0.22),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          _testOk
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          size: 17,
                          color: _testOk ? kTealDeep : kDanger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testMessage!,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: _testOk ? kTealDeep : kDanger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ---------------------------------------------------------- voice
          _SectionTitle(l.voice),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l.voice, style: GText.h3),
                          const SizedBox(height: 2),
                          Text(
                            l.voiceHelp,
                            style: GText.bodySmall.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: app.speechEnabled,
                      onChanged: (bool value) {
                        app.setSpeechEnabled(value);
                        if (!value) unawaited(tts.stop());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(l.speechRate, style: GText.bodySmall),
                    const Spacer(),
                    Text(
                      app.speechRate <= 0.42
                          ? l.slow
                          : (app.speechRate >= 0.62 ? l.fast : l.normal),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: kTealDeep,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: app.speechRate,
                  min: 0.3,
                  max: 0.8,
                  divisions: 10,
                  onChanged: app.setSpeechRate,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${l.voice}: ${tts.voiceLabel}',
                        style: GText.bodySmall.copyWith(fontSize: 11.5),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: app.speechEnabled
                          ? () => unawaited(
                                tts.speak(
                                  urduText: 'شکریہ',
                                  hindiText: 'शुक्रिया',
                                  rate: app.speechRate,
                                ),
                              )
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: kTealDeep,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(l.testVoice),
                    ),
                  ],
                ),
                if (!tts.hasVoice)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.noVoiceWarning,
                      style: GText.bodySmall.copyWith(
                        fontSize: 11.5,
                        color: kAmber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ----------------------------------------------------------- data
          _SectionTitle(l.data),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: kDanger,
                    size: 21,
                  ),
                  title: Text(l.clearHistory, style: GText.h3.copyWith(fontSize: 14)),
                  subtitle: Text(
                    '${app.history.length} ${l.savedGestures}',
                    style: GText.bodySmall.copyWith(fontSize: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: app.history.isEmpty ? null : () => _confirmClear(app, l),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ------------------------------------------------------ app info
          _SectionTitle(l.about),
          SectionCard(
            child: Column(
              children: <Widget>[
                _InfoRow(label: l.version, value: '${AppConfig.version}+${AppConfig.buildNumber}'),
                const Divider(height: 18),
                _InfoRow(
                  label: l.modelStatus,
                  value: app.healthLoading
                      ? l.checking
                      : (app.modelReady ? l.modelReady : l.modelNotReady),
                  valueColor: app.modelReady ? kTealDeep : kAmber,
                ),
                const Divider(height: 18),
                _InfoRow(
                  label: l.gesturesLoaded,
                  value: '${app.gestureLabels.length}',
                ),
                const Divider(height: 18),
                _InfoRow(
                  label: l.backend,
                  value: app.baseUrl,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 9, top: 4),
      child: Text(text.toUpperCase(), style: GText.label),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? kTeal : kInkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GText.h3.copyWith(
                  fontSize: 14.5,
                  color: selected ? kTealDeep : kInk,
                ),
              ),
            ),
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fade(kTeal, 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.check_rounded, size: 13, color: kTealDeep),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.small = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: GText.bodySmall.copyWith(fontSize: 12.5)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: small ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? kInk,
            ),
          ),
        ),
      ],
    );
  }
}
