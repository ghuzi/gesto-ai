import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketStatus { idle, connecting, connected, disconnected }

/// WebSocket client for `ws(s)://<backend>/ws/predict`.
///
/// Protocol (identical to the web frontend):
///   send:    {"frame": "<base64 jpeg, no data-url prefix>"}
///   receive: {"gesture": "help"|null, "confidence": 0.93, "reason": "..."}
class PredictionSocket {
  PredictionSocket({
    required this.uri,
    required this.onMessage,
    required this.onStatus,
  });

  final Uri uri;
  final void Function(Map<String, dynamic> data) onMessage;
  final void Function(SocketStatus status, String? detail) onStatus;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  SocketStatus _status = SocketStatus.idle;
  bool _disposed = false;
  bool _connecting = false;
  int _attempt = 0;

  SocketStatus get status => _status;
  bool get isConnected => _status == SocketStatus.connected;

  Future<void> connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    _retryTimer?.cancel();
    onStatus(SocketStatus.connecting, null);

    try {
      final WebSocketChannel channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 15));
      if (_disposed) {
        unawaited(channel.sink.close());
        return;
      }
      _channel = channel;
      _status = SocketStatus.connected;
      _attempt = 0;
      onStatus(SocketStatus.connected, null);
      _subscription = channel.stream.listen(
        _handleRaw,
        onError: (Object error) => _fail(error.toString()),
        onDone: () => _fail('Connection closed'),
        cancelOnError: true,
      );
    } on Object catch (error) {
      _fail(_humanError(error));
    } finally {
      _connecting = false;
    }
  }

  void _handleRaw(dynamic raw) {
    if (raw is! String) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) onMessage(decoded);
    } on Object {
      // Ignore malformed payloads — the stream must keep working.
    }
  }

  /// Sends one JPEG frame. Returns false when the socket is not usable.
  bool sendFrame(Uint8List jpegBytes) {
    final WebSocketChannel? channel = _channel;
    if (channel == null || !isConnected || jpegBytes.isEmpty) return false;
    try {
      channel.sink.add(jsonEncode(<String, String>{
        'frame': base64Encode(jpegBytes),
      }));
      return true;
    } on Object {
      return false;
    }
  }

  void _fail(String detail) {
    if (_disposed) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final WebSocketChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        unawaited(channel.sink.close());
      } on Object {
        // Already closed.
      }
    }
    if (_status == SocketStatus.disconnected) return;
    _status = SocketStatus.disconnected;
    onStatus(SocketStatus.disconnected, detail);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _attempt = _attempt > 6 ? 6 : _attempt + 1;
    final int seconds = 1 << (_attempt - 1); // 1,2,4,8,16,32,64s
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds.clamp(1, 30)), () {
      if (!_disposed) unawaited(connect());
    });
  }

  /// Manual retry (the "Reconnect" button) — resets the backoff.
  void retryNow() {
    _attempt = 0;
    _retryTimer?.cancel();
    unawaited(connect());
  }

  String _humanError(Object error) {
    final String text = error.toString();
    if (text.contains('TimeoutException')) return 'Handshake timed out';
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Cannot reach the server';
    }
    return text.replaceFirst('WebSocketException: ', '');
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final WebSocketChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        unawaited(channel.sink.close());
      } on Object {
        // Already closed.
      }
    }
  }
}
