// Simple runtime config for API base URL
class AppConfig {
  // Query API server (use PC IP for APK builds, localhost for development)
  // API server query InfluxDB dengan data real-time
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', 
      defaultValue: 'http://172.20.10.3:5000');
}
