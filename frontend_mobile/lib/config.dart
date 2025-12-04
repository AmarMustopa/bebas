// Simple runtime config for API base URL
class AppConfig {
  // Django API server (production server dengan InfluxDB)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://103.151.63.80:8000',
  );
}
