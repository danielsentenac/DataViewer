import 'package:dataviewer/core/config/app_config.dart';
import 'package:dataviewer/core/networking/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return const AppConfig(baseUrl: 'http://olserver135.virgo.infn.it:8081');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient(config);
  ref.onDispose(client.close);
  return client;
});
