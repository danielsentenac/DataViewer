class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.receiveTimeout = const Duration(seconds: 10),
  });

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment(
      'DATAVIEWER_BASE_URL',
      defaultValue: defaultBaseUrl,
    );

    return AppConfig(baseUrl: _normalizeBaseUrl(configuredBaseUrl));
  }

  static const String defaultBaseUrl =
      'http://olserver134.virgo.infn.it:8081/dataviewer';

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return defaultBaseUrl;
    }
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
