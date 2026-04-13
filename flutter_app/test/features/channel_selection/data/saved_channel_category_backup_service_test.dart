import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dataviewer/features/channel_selection/data/saved_channel_category_backup_service.dart';
import 'package:dataviewer/features/channel_selection/data/saved_channel_category_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports saved configs to a persisted Android backup folder', () async {
    String? capturedDirectoryUri;
    Uint8List? capturedPayload;
    final preferences = await _createPreferences();
    final repository = _InMemorySavedChannelCategoryRepository(
      categories: const <SavedChannelCategory>[
        SavedChannelCategory(
          id: 'saved-1',
          label: 'Thermal',
          channelNames: <String>['V1:TEMP_A', 'V1:TEMP_B'],
        ),
      ],
    );
    final service = SavedChannelCategoryBackupService(
      repository: repository,
      preferences: preferences,
      pickDirectory: () async => 'content://tree/backup',
      writeBackupToDirectory: ({
        required String directoryUri,
        required Uint8List data,
        required String fileName,
        required String mimeType,
      }) async {
        capturedDirectoryUri = directoryUri;
        capturedPayload = data;
        return 'content://document/backup/$fileName';
      },
      platformOverride: TargetPlatform.android,
    );

    final savedPath = await service.exportBackup();

    expect(savedPath,
        'content://document/backup/${SavedChannelCategoryBackupService.backupFileName}');
    expect(capturedDirectoryUri, 'content://tree/backup');
    expect(
      preferences.getString(
        'dataviewer.saved_channel_categories.backup_directory_uri.v1',
      ),
      'content://tree/backup',
    );
    final payload = utf8.decode(capturedPayload!);
    expect(payload, contains('"version":1'));
    expect(payload, contains('"Thermal"'));
  });

  test('imports saved configs from backup JSON and replaces repository data',
      () async {
    final preferences = await _createPreferences();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'dataviewer-backup-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final backupFile = File('${tempDirectory.path}/backup.json');
    await backupFile.writeAsString(
      jsonEncode(<String, Object>{
        'version': 1,
        'categories': <Object>[
          <String, Object>{
            'id': 'saved-1',
            'label': 'Imported',
            'channelNames': <String>['V1:B', 'V1:A'],
          },
        ],
      }),
    );

    final repository = _InMemorySavedChannelCategoryRepository(
      categories: const <SavedChannelCategory>[
        SavedChannelCategory(
          id: 'saved-old',
          label: 'Old',
          channelNames: <String>['V1:OLD'],
        ),
      ],
    );
    final service = SavedChannelCategoryBackupService(
      repository: repository,
      preferences: preferences,
      pickFile: (OpenFileDialogParams params) async => backupFile.path,
      platformOverride: TargetPlatform.android,
    );

    final result = await service.importBackup();

    expect(result, isNotNull);
    expect(result!.categoryCount, 1);
    expect(repository.categories, hasLength(1));
    expect(repository.categories.first.label, 'Imported');
    expect(repository.categories.first.channelNames,
        const <String>['V1:A', 'V1:B']);
  });

  test('decodes legacy list-only backups', () {
    final categories = SavedChannelCategoryBackupService.decodeCategories(
      '[{"id":"saved-1","label":"Legacy","channelNames":["V1:A"]}]',
    );

    expect(categories, hasLength(1));
    expect(categories.first.label, 'Legacy');
  });

  test('syncConfiguredBackup rewrites the configured backup file', () async {
    final preferences = await _createPreferences(
      <String, Object>{
        'dataviewer.saved_channel_categories.backup_directory_uri.v1':
            'content://tree/backup',
      },
    );
    Uint8List? capturedPayload;
    final repository = _InMemorySavedChannelCategoryRepository(
      categories: const <SavedChannelCategory>[
        SavedChannelCategory(
          id: 'saved-1',
          label: 'Acquisition',
          channelNames: <String>['V1:LOCK'],
        ),
      ],
    );
    final service = SavedChannelCategoryBackupService(
      repository: repository,
      preferences: preferences,
      writeBackupToDirectory: ({
        required String directoryUri,
        required Uint8List data,
        required String fileName,
        required String mimeType,
      }) async {
        capturedPayload = data;
        return 'content://document/backup/$fileName';
      },
      platformOverride: TargetPlatform.android,
    );

    final savedPath = await service.syncConfiguredBackup();

    expect(savedPath,
        'content://document/backup/${SavedChannelCategoryBackupService.backupFileName}');
    expect(utf8.decode(capturedPayload!), contains('"Acquisition"'));
  });
}

Future<SharedPreferences> _createPreferences([
  Map<String, Object> initialValues = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  return SharedPreferences.getInstance();
}

class _InMemorySavedChannelCategoryRepository
    implements SavedChannelCategoryRepository {
  _InMemorySavedChannelCategoryRepository({
    List<SavedChannelCategory> categories = const <SavedChannelCategory>[],
  }) : categories = List<SavedChannelCategory>.from(categories);

  List<SavedChannelCategory> categories;

  @override
  Future<void> deleteCategory(String id) async {
    categories = categories
        .where((SavedChannelCategory category) => category.id != id)
        .toList(growable: false);
  }

  @override
  Future<List<SavedChannelCategory>> fetchSavedCategories() async {
    return categories;
  }

  @override
  Future<void> replaceCategories(
      List<SavedChannelCategory> nextCategories) async {
    categories = List<SavedChannelCategory>.from(nextCategories);
  }

  @override
  Future<SavedChannelCategory> saveCategory({
    required String label,
    required List<String> channelNames,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SavedChannelCategory> updateCategory({
    required String id,
    required String label,
    required List<String> channelNames,
  }) {
    throw UnimplementedError();
  }
}
