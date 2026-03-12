class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.receiveTimeout = const Duration(seconds: 10),
    this.configurationError,
  });

  factory AppConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment('DATAVIEWER_BASE_URL');
    final baseUrl = rawBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return const AppConfig(
        baseUrl: '',
        configurationError:
            'DATAVIEWER_BASE_URL is not set. Build or run with '
            '--dart-define=DATAVIEWER_BASE_URL=http://your-tomcat-host:8081/dataviewer',
      );
    }
    return AppConfig(baseUrl: baseUrl);
  }

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final String? configurationError;

  bool get isConfigured => configurationError == null && baseUrl.isNotEmpty;
}
