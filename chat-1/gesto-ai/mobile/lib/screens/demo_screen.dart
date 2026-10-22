import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../app/config.dart';
import '../app/l10n.dart';
import '../app/theme.dart';
import '../data/urdu_words.dart';
import '../models/gesture_event.dart';
import '../models/prediction.dart';
import '../services/prediction_socket.dart';
import '../services/tts_service.dart';
import '../widgets/brand_mark.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/connection_chip.dart';
import '../widgets/scanline_overlay.dart';
import '../widgets/section_card.dart';
import 'settings_screen.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, required this.active});

  /// False while another bottom-nav tab is showing — the camera is released
  /// so the phone does not keep streaming in the background.
  final bool active;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> with WidgetsBindingObserver {
  final TtsService _tts = TtsService.instance;

  CameraController? _camera;
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _cameraIndex = 0;

  PredictionSocket? _socket;
  SocketStatus _socketStatus = SocketStatus.idle;
  String? _socketDetail;

  bool _starting = false;
  bool _live = false;
  bool _awaiting = false;
  bool _formatWarned = false;
  bool _wasLiveBeforePause = false;

  DateTime _lastSendAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _awaitingSince = DateTime.now();
  int _framesSent = 0;

  Prediction? _prediction;
  String? _reasonCode;

  String? _errorKey;
  String? _errorDetail;

  String? _lastSpokenGesture;
  DateTime? _lastSpokenAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AppState app = AppScope.read(context);
      if (app.health == null && !app.healthLoading) {
        app.refreshHealth();
      }
      _connectSocket();
    });
  }

  @override
  void didUpdateWidget(covariant DemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _live) {
      unawaited(_stopCamera(pauseOnly: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_live) {
        _wasLiveBeforePause = true;
        unawaited(_stopCamera(pauseOnly: true));
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasLiveBeforePause && widget.active) {
        _wasLiveBeforePause = false;
        unawaited(_startCamera());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final CameraController? cam = _camera;
    _camera = null;
    if (cam != null) {
      unawaited(_releaseCamera(cam));
    }
    _socket?.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  // ------------------------------------------------------------- socket
  void _connectSocket({bool force = false}) {
    if (!mounted) return;
    final AppState app = AppScope.read(context);

    if (_socket != null && !force) return;
    if (_socket != null) {
      _socket!.dispose();
    }

    final PredictionSocket socket = PredictionSocket(
      uri: app.backend.wsUri,
      onMessage: _onMessage,
      onStatus: (SocketStatus status, String? detail) {
        _awaiting = false;
        if (!mounted) return;
        setState(() {
          _socketStatus = status;
          _socketDetail = detail;
        });
      },
    );

    setState(() {
      _socket = socket;
      _socketStatus = SocketStatus.connecting;
      _socketDetail = null;
    });

    unawaited(socket.connect());
  }

  void _onMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    _awaiting = false;

    final String? gesture = (data['gesture'] as String?)?.trim();
    final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0;
    final String? reason = data['reason'] as String?;
    final String? sentence = data['sentence'] as String?;

    setState(() {
      if (gesture != null && gesture.isNotEmpty) {
        _prediction = Prediction(
          gesture: gesture,
          confidence: confidence,
          sentence: sentence,
          at: DateTime.now(),
        );
        _reasonCode = null;
      } else {
        _reasonCode = reason;
        if (reason == 'no_hand' || reason == 'decode_failed') {
          _prediction = null;
        }
      }
    });

    if (gesture != null && gesture.isNotEmpty) {
      AppScope.read(context).addGesture(
        GestureEvent(
          gesture: gesture,
          confidence: confidence,
          at: DateTime.now(),
          sentence: sentence,
        ),
      );
      _maybeSpeak(gesture, sentence);
    }
  }

  void _maybeSpeak(String gesture, String? sentence) {
    final AppState app = AppScope.read(context);
    if (!app.speechEnabled) return;

    final DateTime now = DateTime.now();
    final bool same = _lastSpokenGesture == gesture;
    final bool withinWindow = _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!).inMilliseconds <
            AppConfig.repeatSpeakWindowMs;
    if (same && withinWindow) return;

    _lastSpokenGesture = gesture;
    _lastSpokenAt = now;

    final String urduText =
        (sentence != null && sentence.trim().isNotEmpty)
            ? sentence.trim()
            : urduSentenceFor(gesture);

    unawaited(
      _tts.speak(
        urduText: urduText,
        hindiText: spokenFor(gesture),
        rate: app.speechRate,
      ),
    );
  }

  // ------------------------------------------------------------- camera
  Future<void> _startCamera() async {
    if (_starting || _live) return;
    setState(() {
      _starting = true;
      _errorKey = null;
      _errorDetail = null;
    });

    try {
      final PermissionStatus status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted) {
        setState(() {
          _starting = false;
          _errorKey = status.isPermanentlyDenied ? 'permission_forever' : 'permission';
        });
        return;
      }

      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        setState(() {
          _starting = false;
          _errorKey = 'unavailable';
        });
        return;
      }

      final CameraDescription description =
          _cameras[_cameraIndex % _cameras.length];
      final CameraController controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }
      await controller.startImageStream(_onFrame);

      setState(() {
        _camera = controller;
        _live = true;
        _starting = false;
        _framesSent = 0;
        _formatWarned = false;
      });
      _connectSocket();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _errorKey = 'failed';
        _errorDetail = error.description ?? error.code;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _errorKey = 'failed';
        _errorDetail = error.toString();
      });
    }
  }

  Future<void> _releaseCamera(CameraController cam) async {
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } on Object {
      // Stream already stopped.
    }
    try {
      await cam.dispose();
    } on Object {
      // Controller already disposed.
    }
  }

  Future<void> _stopCamera({bool pauseOnly = false}) async {
    final CameraController? cam = _camera;
    _camera = null;
    if (mounted) {
      setState(() {
        _live = false;
        _starting = false;
        _awaiting = false;
      });
    }

    if (cam != null) {
      await _releaseCamera(cam);
    }

    if (!pauseOnly) {
      _socket?.dispose();
      _socket = null;
      if (mounted) {
        setState(() {
          _socketStatus = SocketStatus.idle;
          _socketDetail = null;
          _prediction = null;
          _reasonCode = null;
        });
      }
    }
  }

  void _onFrame(CameraImage image) {
    if (!_live || !widget.active) return;
    final PredictionSocket? socket = _socket;
    if (socket == null || !socket.isConnected) return;

    final DateTime now = DateTime.now();
    if (now.difference(_lastSendAt).inMilliseconds < AppConfig.frameIntervalMs) {
      return;
    }
    if (_awaiting) {
      if (now.difference(_awaitingSince).inMilliseconds <
          AppConfig.frameTimeoutMs) {
        return;
      }
      _awaiting = false;
    }

    if (image.format.group != ImageFormatGroup.jpeg) {
      if (!_formatWarned) {
        _formatWarned = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).frameFormatUnsupported)),
          );
        }
      }
      return;
    }

    if (image.planes.isEmpty) return;
    final Uint8List bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return;

    _lastSendAt = now;
    _awaitingSince = now;
    if (socket.sendFrame(bytes)) {
      _awaiting = true;
      _framesSent++;
      if (_framesSent % 10 == 0 && mounted) setState(() {});
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    final bool wasLive = _live;
    if (wasLive) {
      await _stopCamera(pauseOnly: true);
    }
    setState(() {
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    if (wasLive) {
      await _startCamera();
    }
  }

  Future<void> _openSettingsApp() async {
    await openAppSettings();
  }

  void _retry() {
    setState(() {
      _errorKey = null;
      _errorDetail = null;
    });
    unawaited(_startCamera());
  }

  // ---------------------------------------------------------------- ui
  @override
  Widget build(BuildContext context) {
    final AppState app = AppScope.of(context);
    final L10n l = L10n.of(context);

    // Server address changed in Settings -> rebuild the socket.
    final PredictionSocket? socket = _socket;
    if (socket != null &&
        socket.uri.toString() != app.backend.wsUri.toString()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connectSocket(force: true);
      });
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Text(l.demo),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: app.speechEnabled ? l.speakerOn : l.speakerOff,
            onPressed: () {
              final bool next = !app.speechEnabled;
              app.setSpeechEnabled(next);
              if (next) {
                _lastSpokenGesture = null;
              } else {
                unawaited(_tts.stop());
              }
            },
            icon: Icon(
              app.speechEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: app.speechEnabled ? kTealDeep : kInkSoft,
            ),
          ),
          IconButton(
            tooltip: l.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _cameraCard(l),
            const SizedBox(height: 14),
            _controls(app, l),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                ConnectionChip(
                  state: _linkState,
                  label: _linkLabel(l),
                  onRetry: () {
                    _socket?.retryNow();
                    if (!_live) _connectSocket(force: true);
                  },
                  retryLabel: l.reconnect,
                ),
                const Spacer(),
                if (_live)
                  Text(
                    l.framesSent(_framesSent),
                    style: GText.mono.copyWith(fontSize: 11),
                  ),
              ],
            ),
            if (_socketDetail != null && _linkState == LinkState.disconnected)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _socketDetail!,
                  style: GText.bodySmall.copyWith(color: kDanger, fontSize: 11.5),
                ),
              ),
            if (app.health != null && !app.modelReady) ...<Widget>[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.warning_amber_rounded,
                color: kAmber,
                text: l.serverNotReadyBanner,
              ),
            ],
            const SizedBox(height: 16),
            _resultCard(l),
            const SizedBox(height: 16),
            _recentCard(app, l),
          ],
        ),
      ),
    );
  }

  LinkState get _linkState {
    switch (_socketStatus) {
      case SocketStatus.connected:
        return LinkState.connected;
      case SocketStatus.connecting:
        return LinkState.connecting;
      case SocketStatus.idle:
      case SocketStatus.disconnected:
        return LinkState.disconnected;
    }
  }

  String _linkLabel(L10n l) {
    switch (_socketStatus) {
      case SocketStatus.connected:
        return l.connected;
      case SocketStatus.connecting:
        return l.connecting;
      case SocketStatus.idle:
        return _live ? l.connecting : l.disconnected;
      case SocketStatus.disconnected:
        return l.disconnected;
    }
  }

  Widget _cameraCard(L10n l) {
    final CameraController? cam = _camera;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: Color(0xFF082226)),
            if (cam != null && cam.value.isInitialized)
              _preview(cam)
            else
              _placeholder(l),
            if (_live) ...<Widget>[
              const ScanlineOverlay(),
              const CornerBrackets(inset: 14),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: <Widget>[
                    _LiveBadge(label: l.live),
                    const Spacer(),
                    if (_framesSent > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: fade(Colors.black, 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_framesSent',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: fade(Colors.black, 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.signHere,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (!_live && _errorKey == null) ...<Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Center(
                  child: Text(
                    l.signHere,
                    style: TextStyle(
                      color: fade(Colors.white, 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            if (_errorKey != null) _errorOverlay(l),
          ],
        ),
      ),
    );
  }

  Widget _preview(CameraController cam) {
    final Size? previewSize = cam.value.previewSize;
    if (previewSize == null) return const SizedBox.shrink();

    // The camera sensor is landscape; swap the dimensions so the preview
    // fills the portrait frame without distortion.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(cam),
      ),
    );
  }

  Widget _placeholder(L10n l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fade(Colors.white, 0.06),
                border: Border.all(color: fade(Colors.white, 0.14)),
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                color: fade(Colors.white, 0.65),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.cameraOff,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.cameraOffHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fade(Colors.white, 0.6),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorOverlay(L10n l) {
    final bool permissionIssue =
        _errorKey == 'permission' || _errorKey == 'permission_forever';

    final String title = permissionIssue
        ? l.cameraDeniedTitle
        : _errorKey == 'unavailable'
            ? l.cameraUnavailable
            : l.cameraFailed;

    final String body = permissionIssue
        ? l.cameraDeniedBody
        : (_errorDetail ?? l.cameraFailed);

    return Positioned.fill(
      child: ColoredBox(
        color: fade(kInk, 0.92),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                permissionIssue
                    ? Icons.no_photography_rounded
                    : Icons.error_outline_rounded,
                color: kAmber,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fade(Colors.white, 0.72),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed:
                    permissionIssue ? _openSettingsApp : _retry,
                style: FilledButton.styleFrom(
                  backgroundColor: kAqua,
                  foregroundColor: kTealDark,
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(
                  permissionIssue ? l.openSettings : l.checkAgain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(AppState app, L10n l) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: _starting
                ? null
                : (_live ? () => _stopCamera() : _startCamera),
            style: FilledButton.styleFrom(
              backgroundColor: _live ? kCard : kTealDeep,
              foregroundColor: _live ? kInk : Colors.white,
              side: _live ? const BorderSide(color: kLine) : null,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: _starting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _live
                        ? Icons.stop_rounded
                        : Icons.videocam_rounded,
                    size: 20,
                  ),
            label: Text(_live ? l.stopCamera : l.startCamera),
          ),
        ),
        const SizedBox(width: 10),
        _SquareButton(
          icon: Icons.cameraswitch_rounded,
          tooltip: l.flipCamera,
          onTap: _cameras.length > 1 ? _flipCamera : null,
        ),
        const SizedBox(width: 10),
        _SquareButton(
          icon: app.speechEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          tooltip: app.speechEnabled ? l.speakerOn : l.speakerOff,
          active: app.speechEnabled,
          onTap: () {
            final bool next = !app.speechEnabled;
            app.setSpeechEnabled(next);
            if (next) {
              _lastSpokenGesture = null;
            } else {
              unawaited(_tts.stop());
            }
          },
        ),
      ],
    );
  }

  Widget _resultCard(L10n l) {
    final Prediction? prediction = _prediction;
    final String status = prediction != null
        ? urduFor(prediction.gesture)
        : l.reason(_reasonCode ?? (_live ? 'no_hand' : null));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l.recognizedGesture.toUpperCase(),
                style: GText.label,
              ),
              const Spacer(),
              if (_live)
                Icon(Icons.graphic_eq_rounded, size: 16, color: fade(kTeal, 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              prediction == null ? '—' : displayGesture(prediction.gesture),
              key: ValueKey<String>(prediction?.gesture ?? 'none'),
              style: GText.h1.copyWith(
                fontSize: 32,
                color: prediction == null ? fade(kInk, 0.25) : kInk,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (prediction != null) ...<Widget>[
            Text(
              urduFor(prediction.gesture),
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 24,
                height: 1.9,
                fontWeight: FontWeight.w700,
                color: kTealDeep,
              ),
            ),
            if (prediction.sentence != null &&
                prediction.sentence!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: fade(kTeal, 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fade(kTeal, 0.14)),
                ),
                child: Text(
                  prediction.sentence!,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 2.0,
                    color: kInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ] else ...<Widget>[
            Text(status, style: GText.bodySmall),
          ],
          const SizedBox(height: 18),
          ConfidenceBar(
            value: prediction?.confidence ?? 0,
            label: l.confidence,
          ),
        ],
      ),
    );
  }

  Widget _recentCard(AppState app, L10n l) {
    final List<GestureEvent> recent = app.history.take(4).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(l.recentGestures.toUpperCase(), style: GText.label),
              const Spacer(),
              if (app.history.isNotEmpty)
                Text(
                  '${app.history.length} ${l.savedGestures}',
                  style: GText.bodySmall.copyWith(fontSize: 11.5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(l.noGesturesYet, style: GText.bodySmall)
          else
            Column(
              children: recent.map((GestureEvent event) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: fade(kTeal, 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.sign_language_rounded,
                          size: 17,
                          color: kTealDeep,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                              style: GText.bodySmall.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(event.confidence * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kTealDeep,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l.speak,
                        onPressed: () => unawaited(
                          _tts.speak(
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
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fade(kDanger, 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fade(color, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fade(color, 0.24)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: fade(kInk, 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? fade(kTeal, 0.12) : kCard,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: active ? fade(kTeal, 0.3) : kLine,
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: onTap == null
                  ? fade(kInkSoft, 0.4)
                  : (active ? kTealDeep : kInk),
            ),
          ),
        ),
      ),
    );
  }
}
