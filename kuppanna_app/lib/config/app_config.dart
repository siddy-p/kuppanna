/// Network configuration for the Kuppanna app.
///
/// Switch between modes using --dart-define at launch:
///   flutter run --dart-define=USE_NGROK=true
///
/// Edit [ngrokBaseUrl] to your active ngrok tunnel URL each session.
/// Edit [localIpBaseUrl] to your machine's local IP if using LAN mode.
class AppConfig {
  AppConfig._();

  /// Set via --dart-define=USE_NGROK=true at launch (defaults to true for Xcode convenience)
  static const bool useNgrok = bool.fromEnvironment('USE_NGROK', defaultValue: true);

  /// Your active ngrok tunnel URL (static domain — no need to update each session)
  static const String ngrokBaseUrl = 'https://swoop-subsiding-treading.ngrok-free.dev';

  /// Your machine's local IP (run `ipconfig getifaddr en0` on Mac)
  static const String localIpBaseUrl = 'http://192.168.1.39:3000';

  /// Resolved base URL — used by ApiService
  static String get baseUrl => useNgrok ? ngrokBaseUrl : localIpBaseUrl;
}
