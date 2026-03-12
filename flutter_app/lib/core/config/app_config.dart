class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 5),
    this.receiveTimeout = const Duration(seconds: 10),
  });

  static const String defaultBaseUrl =
      'http://olserver134.virgo.infn.it:8081/dataviewer';

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
}
