import 'package:dataviewer/core/config/app_config.dart';
import 'package:dataviewer/core/networking/api_client.dart';
import 'package:dataviewer/core/networking/tomcat_session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden during app startup.',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final preferences = ref.watch(sharedPreferencesProvider);
  if (!config.isConfigured) {
    throw StateError(config.configurationError!);
  }
  final client = ApiClient(
    config,
    sessionStore: SharedPreferencesTomcatSessionStore(preferences),
  );
  ref.onDispose(client.close);
  return client;
});
