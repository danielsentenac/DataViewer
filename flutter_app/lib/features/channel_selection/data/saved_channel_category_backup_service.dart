import 'dart:convert';
import 'dart:io';
import 'package:dataviewer/features/channel_selection/data/saved_channel_category_repository.dart';
import 'package:dataviewer/shared/models/channel_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BackupFilePicker = Future<String?> Function(
    OpenFileDialogParams params);
typedef BackupFileSaver = Future<String?> Function(SaveFileDialogParams params);
typedef BackupDirectoryPicker = Future<String?> Function();
typedef BackupDirectoryWriter = Future<String?> Function({
  required String directoryUri,
  required Uint8List data,
  required String fileName,
  required String mimeType,
});

class SavedChannelCategoryBackupImportResult {
  const SavedChannelCategoryBackupImportResult({
    required this.filePath,
    required this.categoryCount,
  });

  final String filePath;
  final int categoryCount;
}

class SavedChannelCategoryBackupService {
  SavedChannelCategoryBackupService({
    required SavedChannelCategoryRepository repository,
    required SharedPreferences preferences,
    BackupFilePicker? pickFile,
    BackupFileSaver? saveFile,
    BackupDirectoryPicker? pickDirectory,
    BackupDirectoryWriter? writeBackupToDirectory,
    TargetPlatform? platformOverride,
  })  : _repository = repository,
        _preferences = preferences,
        _pickFile = pickFile ??
            ((OpenFileDialogParams params) =>
                FlutterFileDialog.pickFile(params: params)),
        _saveFile = saveFile ??
            ((SaveFileDialogParams params) =>
                FlutterFileDialog.saveFile(params: params)),
        _pickDirectory = pickDirectory ?? _pickAndroidBackupDirectory,
        _writeBackupToDirectory =
            writeBackupToDirectory ?? _writeAndroidBackupFile,
        _platformOverride = platformOverride;

  static const String backupFileName = 'dataviewer-saved-configs.json';
  static const String _backupDirectoryPreferenceKey =
      'dataviewer.saved_channel_categories.backup_directory_uri.v1';
  static const MethodChannel _androidBackupChannel =
      MethodChannel('org.virgo.dataviewer/backup');

  final SavedChannelCategoryRepository _repository;
  final SharedPreferences _preferences;
  final BackupFilePicker _pickFile;
  final BackupFileSaver _saveFile;
  final BackupDirectoryPicker _pickDirectory;
  final BackupDirectoryWriter _writeBackupToDirectory;
  final TargetPlatform? _platformOverride;

  bool get hasConfiguredAutoBackupTarget =>
      _configuredAndroidBackupDirectoryUri != null;

  String? get _configuredAndroidBackupDirectoryUri {
    final rawValue = _preferences.getString(_backupDirectoryPreferenceKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    return rawValue;
  }

  Future<String?> exportBackup() async {
    _ensureSupportedPlatform();
    final categories = await _repository.fetchSavedCategories();
    if (categories.isEmpty) {
      throw StateError('No saved configs to export.');
    }

    final payload = _encodeCategoriesPayload(categories);
    final platform = _platformOverride ?? defaultTargetPlatform;
    if (platform == TargetPlatform.android) {
      final backupDirectoryUri =
          await _resolveAndroidBackupDirectoryUri(allowPick: true);
      if (backupDirectoryUri == null) {
        return null;
      }
      return _writeBackupPayloadToAndroidDirectory(
        backupDirectoryUri: backupDirectoryUri,
        payload: payload,
      );
    }

    return _saveFile(
      SaveFileDialogParams(
        data: payload,
        fileName: backupFileName,
        mimeTypesFilter: const <String>['application/json', 'text/json'],
        localOnly: true,
      ),
    );
  }

  Future<String?> syncConfiguredBackup() async {
    _ensureSupportedPlatform();
    final platform = _platformOverride ?? defaultTargetPlatform;
    if (platform != TargetPlatform.android) {
      return null;
    }

    final backupDirectoryUri = _configuredAndroidBackupDirectoryUri;
    if (backupDirectoryUri == null) {
      return null;
    }

    final categories = await _repository.fetchSavedCategories();
    final payload = _encodeCategoriesPayload(categories);
    return _writeBackupPayloadToAndroidDirectory(
      backupDirectoryUri: backupDirectoryUri,
      payload: payload,
    );
  }

  Future<SavedChannelCategoryBackupImportResult?> importBackup() async {
    _ensureSupportedPlatform();
    final filePath = await _pickFile(
      const OpenFileDialogParams(
        fileExtensionsFilter: <String>['json'],
        mimeTypesFilter: <String>['application/json', 'text/json'],
        localOnly: true,
        copyFileToCacheDir: true,
      ),
    );
    if (filePath == null) {
      return null;
    }

    final rawJson = await File(filePath).readAsString();
    final categories = decodeCategories(rawJson);
    if (categories.isEmpty) {
      throw StateError(
          'The selected backup file does not contain any saved configs.');
    }

    await _repository.replaceCategories(categories);
    await syncConfiguredBackup();
    return SavedChannelCategoryBackupImportResult(
      filePath: filePath,
      categoryCount: categories.length,
    );
  }

  static String encodeCategories(List<SavedChannelCategory> categories) {
    return jsonEncode(<String, Object>{
      'version': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'categories': categories
          .map((SavedChannelCategory category) => category.toJson())
          .toList(growable: false),
    });
  }

  static List<SavedChannelCategory> decodeCategories(String rawJson) {
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
                category.label.trim().isNotEmpty &&
                category.channelNames.isNotEmpty,
          )
          .toList(growable: false);
      return categories;
    } on FormatException {
      throw StateError('The selected backup file is not valid JSON.');
    }
  }

  Uint8List _encodeCategoriesPayload(List<SavedChannelCategory> categories) {
    return Uint8List.fromList(utf8.encode(encodeCategories(categories)));
  }

  Future<String?> _resolveAndroidBackupDirectoryUri({
    required bool allowPick,
  }) async {
    final configuredUri = _configuredAndroidBackupDirectoryUri;
    if (configuredUri != null) {
      return configuredUri;
    }
    if (!allowPick) {
      return null;
    }

    final pickedUri = await _pickDirectory();
    if (pickedUri == null || pickedUri.trim().isEmpty) {
      return null;
    }

    await _preferences.setString(_backupDirectoryPreferenceKey, pickedUri);
    return pickedUri;
  }

  Future<String?> _writeBackupPayloadToAndroidDirectory({
    required String backupDirectoryUri,
    required Uint8List payload,
  }) async {
    try {
      return await _writeBackupToDirectory(
        directoryUri: backupDirectoryUri,
        data: payload,
        fileName: backupFileName,
        mimeType: 'application/json',
      );
    } on PlatformException catch (error) {
      if (error.code == 'backup_directory_not_found' ||
          error.code == 'backup_permission_denied') {
        await _preferences.remove(_backupDirectoryPreferenceKey);
      }
      rethrow;
    }
  }

  static Future<String?> _pickAndroidBackupDirectory() {
    return _androidBackupChannel.invokeMethod<String>('pickBackupDirectory');
  }

  static Future<String?> _writeAndroidBackupFile({
    required String directoryUri,
    required Uint8List data,
    required String fileName,
    required String mimeType,
  }) {
    return _androidBackupChannel.invokeMethod<String>(
      'writeBackupFile',
      <String, Object>{
        'directoryUri': directoryUri,
        'data': data,
        'fileName': fileName,
        'mimeType': mimeType,
      },
    );
  }

  void _ensureSupportedPlatform() {
    final platform = _platformOverride ?? defaultTargetPlatform;
    if (platform != TargetPlatform.android && platform != TargetPlatform.iOS) {
      throw StateError(
        'Backup export/import is available on Android and iOS builds.',
      );
    }
  }
}
