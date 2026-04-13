import 'package:dataviewer/core/providers.dart';
import 'package:dataviewer/features/channel_selection/data/channel_catalog_repository.dart';
import 'package:dataviewer/features/channel_selection/data/http_channel_catalog_repository.dart';
import 'package:dataviewer/features/channel_selection/data/saved_channel_category_backup_service.dart';
import 'package:dataviewer/features/channel_selection/data/saved_channel_category_repository.dart';
import 'package:dataviewer/features/channel_selection/data/shared_preferences_saved_channel_category_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final channelCatalogRepositoryProvider = Provider<ChannelCatalogRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return HttpChannelCatalogRepository(client);
});

final savedChannelCategoryRepositoryProvider =
    Provider<SavedChannelCategoryRepository>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesSavedChannelCategoryRepository(
    loadPreferences: () async => preferences,
  );
});

final savedChannelCategoryBackupServiceProvider =
    Provider<SavedChannelCategoryBackupService>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final repository = ref.watch(savedChannelCategoryRepositoryProvider);
  return SavedChannelCategoryBackupService(
    repository: repository,
    preferences: preferences,
  );
});
