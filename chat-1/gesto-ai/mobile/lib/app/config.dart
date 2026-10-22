/// Build-time defaults. Override the server with:
///   flutter build apk --dart-define=GESTO_API_BASE=http://192.168.1.10:8000
/// or at runtime from Settings → Backend server.
class AppConfig {
  const AppConfig._();

  static const String defaultBaseUrl = String.fromEnvironment(
    'GESTO_API_BASE',
    defaultValue: 'https://gesto-ai-production.up.railway.app',
  );

  static const String webDemoUrl = 'https://gesto-ai-frontend.vercel.app';
  static const String backendDocsUrl =
      'https://gesto-ai-production.up.railway.app/docs';
  static const String repoUrl = 'https://github.com/ghuzi/gesto-ai';

  static const String version = '1.0.1';
  static const int buildNumber = 2;

  /// ~10 frames per second, matching the web frontend.
  static const int frameIntervalMs = 100;

  /// If the server never answers a frame, resume sending after this long.
  static const int frameTimeoutMs = 2500;

  /// Do not speak the same gesture again within this window (unless it
  /// changes), so repeated identical predictions do not machine-gun the TTS.
  static const int repeatSpeakWindowMs = 5000;
}
