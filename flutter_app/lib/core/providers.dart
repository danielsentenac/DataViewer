import 'package:dataviewer/core/config/app_config.dart';
import 'package:dataviewer/core/networking/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isConfigured) {
    throw StateError(config.configurationError!);
  }
  final client = ApiClient(config);
  ref.onDispose(client.close);
  return client;
});
