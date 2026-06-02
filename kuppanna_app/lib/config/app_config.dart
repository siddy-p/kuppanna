/// Network configuration for the Kuppanna app.
///
/// The backend is now permanently hosted on Render.
/// No more ngrok or local IP needed!
class AppConfig {
  AppConfig._();

  /// Production backend on Render — always available, no setup needed
  static const String renderBaseUrl = 'https://kuppanna-backend.onrender.com';

  /// Your machine's local IP (only used during local development)
  /// Run `ipconfig getifaddr en0` on Mac to get your IP
  static const String localIpBaseUrl = 'http://192.168.1.39:3000';

  /// Set via --dart-define=USE_LOCAL=true to use local backend instead
  static const bool useLocal = bool.fromEnvironment('USE_LOCAL', defaultValue: false);

  /// Resolved base URL — uses Render by default, local only if USE_LOCAL=true
  static String get baseUrl => useLocal ? localIpBaseUrl : renderBaseUrl;
}
