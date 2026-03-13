import 'package:dataviewer/features/channel_selection/data/shared_preferences_saved_channel_category_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesSavedChannelCategoryRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repository = SharedPreferencesSavedChannelCategoryRepository();
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

  test('deletes saved categories by id', () async {
    final saved = await repository.saveCategory(
      label: 'Cooling',
      channelNames: const <String>['V1:COOL_A'],
    );

    await repository.deleteCategory(saved.id);

    expect(await repository.fetchSavedCategories(), isEmpty);
  });
}
