/// Environment-specific API settings, kept out of UI and data code.
///
/// The base URL is injected at build time:
///   flutter run --dart-define=API_BASE_URL=https://<id>.mockapi.io/api/v1
///   flutter build apk --dart-define=API_BASE_URL=https://<id>.mockapi.io/api/v1
class ApiConfig {
  const ApiConfig._();

  static const String _placeholderMarker = 'YOUR_PROJECT_ID';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://6ae04fe6be3bc8fead96dfa6.mockapi.io/api/v1',
  );

  /// Path of the visitors resource, relative to [baseUrl].
  static const String visitorsPath = '/visitors';

  /// Path of the visits resource (one record per visit session).
  static const String visitsPath = '/visits';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// False while the base URL is still the placeholder, so the app can show a
  /// setup screen instead of pretending requests will work.
  static bool get isConfigured =>
      baseUrl.isNotEmpty && !baseUrl.contains(_placeholderMarker);
}
