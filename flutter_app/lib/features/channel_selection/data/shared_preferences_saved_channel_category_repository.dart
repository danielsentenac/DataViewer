import 'dart:convert';

import 'package:dataviewer/features/channel_selection/data/saved_channel_category_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

class SharedPreferencesSavedChannelCategoryRepository
    implements SavedChannelCategoryRepository {
  SharedPreferencesSavedChannelCategoryRepository({
    SharedPreferencesLoader? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const String _storageKey = 'dataviewer.saved_channel_categories.v1';

  final SharedPreferencesLoader _loadPreferences;

  @override
  Future<void> deleteCategory(String id) async {
    final preferences = await _loadPreferences();
    final categories = _readCategories(preferences)
        .where((SavedChannelCategory category) => category.id != id)
        .toList(growable: false);
    await _writeCategories(preferences, categories);
  }

  @override
  Future<List<SavedChannelCategory>> fetchSavedCategories() async {
    final preferences = await _loadPreferences();
    return _readCategories(preferences);
  }

  @override
  Future<SavedChannelCategory> saveCategory({
    required String label,
    required List<String> channelNames,
  }) async {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      throw StateError('Category name cannot be empty.');
    }

    final normalizedChannels = channelNames
        .map((String channel) => channel.trim())
        .where((String channel) => channel.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    if (normalizedChannels.isEmpty) {
      throw StateError('Select at least one channel before saving.');
    }

    final preferences = await _loadPreferences();
    final categories = _readCategories(preferences);
    final hasDuplicateLabel = categories.any(
      (SavedChannelCategory category) =>
          category.label.toLowerCase() == normalizedLabel.toLowerCase(),
    );
    if (hasDuplicateLabel) {
      throw StateError(
          'A saved category named "$normalizedLabel" already exists.');
    }

    final category = SavedChannelCategory(
      id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
      label: normalizedLabel,
      channelNames: normalizedChannels,
    );
    final updatedCategories = <SavedChannelCategory>[...categories, category]
      ..sort(_compareCategoriesByLabel);
    await _writeCategories(preferences, updatedCategories);
    return category;
  }

  List<SavedChannelCategory> _readCategories(SharedPreferences preferences) {
    final rawJson = preferences.getString(_storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <SavedChannelCategory>[];
    }

    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      final categories = decoded
          .map(
            (dynamic item) => SavedChannelCategory.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where(
            (SavedChannelCategory category) =>
                category.id.isNotEmpty &&
                category.label.trim().isNotEmpty &&
                category.channelNames.isNotEmpty,
          )
          .toList(growable: false)
        ..sort(_compareCategoriesByLabel);
      return categories;
    } on FormatException {
      return const <SavedChannelCategory>[];
    }
  }

  Future<void> _writeCategories(
    SharedPreferences preferences,
    List<SavedChannelCategory> categories,
  ) async {
    final payload = jsonEncode(
      categories
          .map((SavedChannelCategory category) => category.toJson())
          .toList(growable: false),
    );
    await preferences.setString(_storageKey, payload);
  }

  static int _compareCategoriesByLabel(
    SavedChannelCategory left,
    SavedChannelCategory right,
  ) {
    return left.label.toLowerCase().compareTo(right.label.toLowerCase());
  }
}
