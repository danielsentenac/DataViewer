import 'dart:convert';
import 'dart:io';

import 'package:dataviewer/features/channel_selection/data/saved_channel_category_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();
typedef ApplicationSupportDirectoryLoader = Future<Directory> Function();

class SharedPreferencesSavedChannelCategoryRepository
    implements SavedChannelCategoryRepository {
  SharedPreferencesSavedChannelCategoryRepository({
    SharedPreferencesLoader? loadPreferences,
    ApplicationSupportDirectoryLoader? loadStorageDirectory,
  })  : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
        _loadStorageDirectory =
            loadStorageDirectory ?? getApplicationSupportDirectory;

  static const String _legacyStorageKey =
      'dataviewer.saved_channel_categories.v1';
  static const String _storageFileName = 'saved_channel_configs.json';

  final SharedPreferencesLoader _loadPreferences;
  final ApplicationSupportDirectoryLoader _loadStorageDirectory;

  @override
  Future<void> deleteCategory(String id) async {
    final categories = await _loadCategories();
    final updatedCategories = categories
        .where((SavedChannelCategory category) => category.id != id)
        .toList(growable: false);
    await _writeCategories(updatedCategories);
  }

  @override
  Future<List<SavedChannelCategory>> fetchSavedCategories() {
    return _loadCategories();
  }

  @override
  Future<SavedChannelCategory> saveCategory({
    required String label,
    required List<String> channelNames,
  }) async {
    final normalizedLabel = _normalizeLabel(label);
    final normalizedChannels = _normalizeChannels(channelNames);
    final categories = await _loadCategories();
    _ensureLabelIsUnique(categories, normalizedLabel);

    final category = SavedChannelCategory(
      id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
      label: normalizedLabel,
      channelNames: normalizedChannels,
    );
    final updatedCategories = <SavedChannelCategory>[...categories, category]
      ..sort(_compareCategoriesByLabel);
    await _writeCategories(updatedCategories);
    return category;
  }

  @override
  Future<SavedChannelCategory> updateCategory({
    required String id,
    required String label,
    required List<String> channelNames,
  }) async {
    final normalizedLabel = _normalizeLabel(label);
    final normalizedChannels = _normalizeChannels(channelNames);
    final categories = await _loadCategories();
    final index = categories.indexWhere(
      (SavedChannelCategory category) => category.id == id,
    );
    if (index < 0) {
      throw StateError('Saved config no longer exists.');
    }
    _ensureLabelIsUnique(
      categories,
      normalizedLabel,
      excludingId: id,
    );

    final updatedCategory = categories[index].copyWith(
      label: normalizedLabel,
      channelNames: normalizedChannels,
    );
    final updatedCategories = <SavedChannelCategory>[
      ...categories.take(index),
      updatedCategory,
      ...categories.skip(index + 1),
    ]..sort(_compareCategoriesByLabel);
    await _writeCategories(updatedCategories);
    return updatedCategory;
  }

  @override
  Future<void> replaceCategories(List<SavedChannelCategory> categories) async {
    final normalizedCategories = _normalizeImportedCategories(categories);
    await _writeCategories(normalizedCategories);
  }

  Future<List<SavedChannelCategory>> _loadCategories() async {
    final storageFile = await _resolveStorageFile();
    if (await storageFile.exists()) {
      final rawJson = await storageFile.readAsString();
      final categories = _tryDecodeCategories(rawJson);
      if (categories != null) {
        await _writeLegacyBackup(categories);
        return categories;
      }
    }

    final preferences = await _loadPreferences();
    final rawJson = preferences.getString(_legacyStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const <SavedChannelCategory>[];
    }

    final categories = _tryDecodeCategories(rawJson);
    if (categories == null) {
      return const <SavedChannelCategory>[];
    }
    await _writeCategories(categories);
    return categories;
  }

  Future<File> _resolveStorageFile() async {
    final directory = await _loadStorageDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_storageFileName');
  }

  List<SavedChannelCategory>? _tryDecodeCategories(String rawJson) {
    if (rawJson.trim().isEmpty) {
      return const <SavedChannelCategory>[];
    }

    try {
      final decoded = jsonDecode(rawJson);
      final rawCategories = switch (decoded) {
        List<dynamic> list => list,
        Map<String, dynamic> map =>
          map['categories'] as List<dynamic>? ?? const <dynamic>[],
        _ => const <dynamic>[],
      };
      final categories = rawCategories
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => SavedChannelCategory.fromJson(
              Map<String, dynamic>.from(item),
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
      return null;
    }
  }

  Future<void> _writeCategories(List<SavedChannelCategory> categories) async {
    final storageFile = await _resolveStorageFile();
    final payload = jsonEncode(<String, Object>{
      'version': 2,
      'categories': categories
          .map((SavedChannelCategory category) => category.toJson())
          .toList(growable: false),
    });
    await storageFile.writeAsString(payload, flush: true);
    await _writeLegacyBackup(categories);
  }

  Future<void> _writeLegacyBackup(List<SavedChannelCategory> categories) async {
    final preferences = await _loadPreferences();
    final payload = jsonEncode(
      categories
          .map((SavedChannelCategory category) => category.toJson())
          .toList(growable: false),
    );
    await preferences.setString(_legacyStorageKey, payload);
  }

  static String _normalizeLabel(String label) {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      throw StateError('Config name cannot be empty.');
    }
    return normalizedLabel;
  }

  static List<String> _normalizeChannels(List<String> channelNames) {
    final normalizedChannels = channelNames
        .map((String channel) => channel.trim())
        .where((String channel) => channel.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    if (normalizedChannels.isEmpty) {
      throw StateError('Select at least one channel before saving.');
    }
    return normalizedChannels;
  }

  static void _ensureLabelIsUnique(
    List<SavedChannelCategory> categories,
    String normalizedLabel, {
    String? excludingId,
  }) {
    final hasDuplicateLabel = categories.any(
      (SavedChannelCategory category) =>
          category.id != excludingId &&
          category.label.toLowerCase() == normalizedLabel.toLowerCase(),
    );
    if (hasDuplicateLabel) {
      throw StateError(
        'A saved config named "$normalizedLabel" already exists.',
      );
    }
  }

  static int _compareCategoriesByLabel(
    SavedChannelCategory left,
    SavedChannelCategory right,
  ) {
    return left.label.toLowerCase().compareTo(right.label.toLowerCase());
  }

  static List<SavedChannelCategory> _normalizeImportedCategories(
    List<SavedChannelCategory> categories,
  ) {
    final normalizedByLabel = <String, SavedChannelCategory>{};
    for (final SavedChannelCategory category in categories) {
      final normalizedLabel = category.label.trim();
      if (normalizedLabel.isEmpty) {
        continue;
      }

      final normalizedChannels = category.channelNames
          .map((String channel) => channel.trim())
          .where((String channel) => channel.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
      if (normalizedChannels.isEmpty) {
        continue;
      }

      final normalizedCategory = SavedChannelCategory(
        id: category.id.isEmpty
            ? 'saved-${DateTime.now().microsecondsSinceEpoch}-${normalizedByLabel.length}'
            : category.id,
        label: normalizedLabel,
        channelNames: normalizedChannels,
      );
      normalizedByLabel[normalizedLabel.toLowerCase()] = normalizedCategory;
    }

    final normalizedCategories = normalizedByLabel.values
        .toList(growable: false)
      ..sort(_compareCategoriesByLabel);
    return normalizedCategories;
  }
}
