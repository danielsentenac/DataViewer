import 'package:dataviewer/shared/models/channel_models.dart';

abstract class SavedChannelCategoryRepository {
  Future<List<SavedChannelCategory>> fetchSavedCategories();

  Future<SavedChannelCategory> saveCategory({
    required String label,
    required List<String> channelNames,
  });

  Future<SavedChannelCategory> updateCategory({
    required String id,
    required String label,
    required List<String> channelNames,
  });

  Future<void> replaceCategories(List<SavedChannelCategory> categories);

  Future<void> deleteCategory(String id);
}
