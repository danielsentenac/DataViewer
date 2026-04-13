import 'dart:io';

import 'package:dataviewer/features/channel_selection/data/shared_preferences_saved_channel_category_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacyStorageKey = 'dataviewer.saved_channel_categories.v1';
  const storageFileName = 'saved_channel_configs.json';

  late Directory storageDirectory;
  late SharedPreferences preferences;
  late SharedPreferencesSavedChannelCategoryRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    storageDirectory = await Directory.systemTemp.createTemp(
      'dataviewer-saved-configs-test-',
    );
    repository = SharedPreferencesSavedChannelCategoryRepository(
      loadPreferences: () async => preferences,
      loadStorageDirectory: () async => storageDirectory,
    );
  });

  tearDown(() async {
    if (await storageDirectory.exists()) {
      await storageDirectory.delete(recursive: true);
    }
  });

  test('saves normalized channel categories', () async {
    final saved = await repository.saveCategory(
      label: '  Thermal ',
      channelNames: const <String>['V1:B', 'V1:A', 'V1:B', '   '],
    );

    expect(saved.label, 'Thermal');
    expect(saved.channelNames, const <String>['V1:A', 'V1:B']);

    final categories = await repository.fetchSavedCategories();
    expect(categories, hasLength(1));
    expect(categories.first.label, 'Thermal');
    expect(categories.first.channelNames, const <String>['V1:A', 'V1:B']);
    expect(categories.first.count, 2);

    final file = File(
      '${storageDirectory.path}${Platform.pathSeparator}$storageFileName',
    );
    expect(await file.exists(), isTrue);
  });

  test('rejects duplicate names regardless of case', () async {
    await repository.saveCategory(
      label: 'Vacuum',
      channelNames: const <String>['V1:VAC_A'],
    );

    expect(
      () => repository.saveCategory(
        label: 'vacuum',
        channelNames: const <String>['V1:VAC_B'],
      ),
      throwsStateError,
    );
  });

  test('updates saved categories by id', () async {
    final saved = await repository.saveCategory(
      label: 'Cooling',
      channelNames: const <String>['V1:COOL_A'],
    );

    final updated = await repository.updateCategory(
      id: saved.id,
      label: 'Cooling updated',
      channelNames: const <String>['V1:COOL_B', 'V1:COOL_A', 'V1:COOL_B'],
    );

    expect(updated.label, 'Cooling updated');
    expect(updated.channelNames, const <String>['V1:COOL_A', 'V1:COOL_B']);

    final categories = await repository.fetchSavedCategories();
    expect(categories, hasLength(1));
    expect(categories.first.id, saved.id);
    expect(categories.first.label, 'Cooling updated');
    expect(categories.first.channelNames,
        const <String>['V1:COOL_A', 'V1:COOL_B']);
  });

  test('deletes saved categories by id', () async {
    final saved = await repository.saveCategory(
      label: 'Cooling',
      channelNames: const <String>['V1:COOL_A'],
    );

    await repository.deleteCategory(saved.id);

    expect(await repository.fetchSavedCategories(), isEmpty);
  });

  test('replaces saved categories from imported backup data', () async {
    await repository.saveCategory(
      label: 'Old config',
      channelNames: const <String>['V1:OLD'],
    );

    await repository.replaceCategories(
      const <SavedChannelCategory>[
        SavedChannelCategory(
          id: 'saved-import-1',
          label: 'Imported A',
          channelNames: <String>['V1:B', 'V1:A'],
        ),
        SavedChannelCategory(
          id: '',
          label: 'Imported B',
          channelNames: <String>['V1:C'],
        ),
      ],
    );

    final categories = await repository.fetchSavedCategories();
    expect(categories, hasLength(2));
    expect(categories[0].label, 'Imported A');
    expect(categories[0].channelNames, const <String>['V1:A', 'V1:B']);
    expect(categories[1].label, 'Imported B');
    expect(categories[1].id, isNotEmpty);
  });

  test('migrates legacy shared preferences storage into the JSON file',
      () async {
    await preferences.setString(
      legacyStorageKey,
      '[{"id":"saved-1","label":"Legacy","channelNames":["V1:LEGACY_B","V1:LEGACY_A"]}]',
    );

    final categories = await repository.fetchSavedCategories();

    expect(categories, hasLength(1));
    expect(categories.first.label, 'Legacy');
    expect(categories.first.channelNames,
        const <String>['V1:LEGACY_A', 'V1:LEGACY_B']);

    final file = File(
      '${storageDirectory.path}${Platform.pathSeparator}$storageFileName',
    );
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), contains('"version":2'));
  });

  test('falls back to legacy storage when the JSON file is malformed',
      () async {
    final file = File(
      '${storageDirectory.path}${Platform.pathSeparator}$storageFileName',
    );
    await file.writeAsString('{', flush: true);
    await preferences.setString(
      legacyStorageKey,
      '[{"id":"saved-2","label":"Recovered","channelNames":["V1:RECOVERED"]}]',
    );

    final categories = await repository.fetchSavedCategories();

    expect(categories, hasLength(1));
    expect(categories.first.label, 'Recovered');
    expect(await file.readAsString(), contains('"Recovered"'));
  });
}
