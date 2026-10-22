import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/config.dart';
import '../models/backend_health.dart';

class BackendException implements Exception {
  BackendException(this.message);

  final String message;

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

  Future<BackendHealth> fetchHealth({Duration timeout = const Duration(seconds: 15)}) async {
    http.Response response;
    try {
      response = await http
          .get(healthUri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(timeout);
    } on Exception catch (error) {
      throw BackendException(_humanError(error));
    }

    if (response.statusCode != 200) {
      throw BackendException('HTTP ${response.statusCode}');
    }

    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw BackendException('Unexpected response');
      }
      return BackendHealth.fromJson(decoded);
    } on BackendException {
      rethrow;
    } on Object {
      throw BackendException('Malformed health response');
    }
  }

  String _humanError(Object error) {
    final String text = error.toString();
    if (text.contains('TimeoutException')) {
      return 'Timed out — the server may be waking up';
    }
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Cannot reach the server';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
