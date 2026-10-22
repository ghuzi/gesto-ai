import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../app/config.dart';
import '../models/backend_health.dart';

/// What went wrong when talking to the backend, in a form the UI can explain.
enum BackendFailure {
  /// DNS, TLS, refused connection, airplane mode…
  unreachable,

  /// The host answered, but there is no Gesto backend behind it
  /// (Railway returns 404 "Application not found" for deleted services).
  notDeployed,

  /// 502/503/504 — the platform is up, the container is starting/sleeping.
  startingUp,

  /// No answer within the timeout (free tiers can take a minute to wake).
  timeout,

  /// A response we could not use.
  badResponse,
}

class BackendException implements Exception {
  BackendException(
    this.message, {
    this.failure = BackendFailure.unreachable,
    this.statusCode,
  });

  final String message;
  final BackendFailure failure;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin HTTP layer for the FastAPI backend that the web app already uses.
class BackendService {
  BackendService({String baseUrl = AppConfig.defaultBaseUrl})
      : _baseUrl = normalize(baseUrl);

  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) => _baseUrl = normalize(value);

  static String normalize(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return AppConfig.defaultBaseUrl;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Uri get healthUri => Uri.parse('$_baseUrl/health');

  /// https://host -> wss://host/ws/predict
  Uri get wsUri {
    final Uri base = Uri.parse(_baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    String path = base.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '$path/ws/predict',
    );
  }

  /// Free hosts sleep; the first request of the day can take a minute.
  Future<BackendHealth> fetchHealth({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    http.Response response;
    try {
      response = await http.get(
        healthUri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(timeout);
    } on TimeoutException {
      throw BackendException(
        'Timed out after ${timeout.inSeconds}s — the server may be waking up',
        failure: BackendFailure.timeout,
      );
    } on SocketException catch (error) {
      throw BackendException(
        _socketMessage(error),
        failure: BackendFailure.unreachable,
      );
    } on http.ClientException catch (error) {
      throw BackendException(
        error.message,
        failure: BackendFailure.unreachable,
      );
    } on HandshakeException catch (error) {
      throw BackendException(
        'TLS handshake failed (${error.message})',
        failure: BackendFailure.unreachable,
      );
    } on Object catch (error) {
      throw BackendException(error.toString().replaceFirst('Exception: ', ''));
    }

    final int code = response.statusCode;

    if (code == 404) {
      // Railway: {"status":"error","code":404,"message":"Application not found"}
      throw BackendException(
        'HTTP 404 — no backend is deployed at this address',
        failure: BackendFailure.notDeployed,
        statusCode: code,
      );
    }
    if (code == 502 || code == 503 || code == 504) {
      throw BackendException(
        'HTTP $code — the server is starting up',
        failure: BackendFailure.startingUp,
        statusCode: code,
      );
    }
    if (code != 200) {
      throw BackendException(
        'HTTP $code',
        failure: BackendFailure.badResponse,
        statusCode: code,
      );
    }

    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not a JSON object');
      }
      return BackendHealth.fromJson(decoded);
    } on Object {
      throw BackendException(
        'Malformed /health response',
        failure: BackendFailure.badResponse,
        statusCode: code,
      );
    }
  }

  String _socketMessage(SocketException error) {
    final String text = '${error.message} ${error.osError?.message ?? ''}';
    if (text.contains('Failed host lookup')) return 'Unknown host — check the address';
    if (text.contains('Connection refused')) return 'Connection refused';
    if (text.contains('Network is unreachable')) return 'No internet connection';
    return error.message;
  }
}
