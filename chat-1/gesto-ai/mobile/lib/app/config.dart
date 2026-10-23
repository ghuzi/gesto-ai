/// Build-time defaults. Override the server with:
///   flutter build apk --dart-define=GESTO_API_BASE=http://192.168.1.10:8000
/// or at runtime from Settings → Backend server.
class AppConfig {
  const AppConfig._();

  /// Live backend (Railway project `exciting-strength`, service `gesto-backend`).
  static const String defaultBaseUrl = String.fromEnvironment(
    'GESTO_API_BASE',
    defaultValue: 'https://gesto-backend-production.up.railway.app',
  );

  /// Addresses that used to be the default but no longer host a backend.
  /// A saved value matching one of these is migrated to [defaultBaseUrl] on
  /// start-up, so people who already installed an older APK heal after the
  /// update without touching Settings.
  static const Set<String> retiredDefaults = <String>{
    'https://gesto-ai-production.up.railway.app',
    'http://gesto-ai-production.up.railway.app',
    'https://gesto-ai.up.railway.app',
    'https://gesto-ai-backend.up.railway.app',
    'https://gesto-ai-api.up.railway.app',
  };

  static const String webDemoUrl = 'https://gesto-ai-demo.vercel.app';

  static String get backendDocsUrl => '$defaultBaseUrl/docs';

  static const String repoUrl = 'https://github.com/ghuzi/gesto-ai';

  static const String version = '1.0.2';
  static const int buildNumber = 3;

  /// ~10 frames per second, matching the web frontend.
  static const int frameIntervalMs = 100;

  /// If the server never answers a frame, resume sending after this long.
  static const int frameTimeoutMs = 2500;

  /// Do not speak the same gesture again within this window (unless it
  /// changes), so repeated identical predictions do not machine-gun the TTS.
  static const int repeatSpeakWindowMs = 5000;
}
