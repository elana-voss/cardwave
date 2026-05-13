import 'dart:convert';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/models/llm_providers_recovery.dart';

class SettingsRepository {
  late final String _appDataPath;
  String? _currentCardsPath;

  String get appDataPath => _appDataPath;

  void init(String appDataPath) {
    _appDataPath = appDataPath;
  }

  String? pathResolver(StorageDomainEnum domain) {
    switch (domain) {
      case StorageDomainEnum.settings:
        return _appDataPath;
      case StorageDomainEnum.cards:
        return _currentCardsPath;
    }
  }

  void setCardsPath(String? path) {
    _currentCardsPath = path;
  }

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      if (await AppStorage.instance.fileExists(
        StorageDomainEnum.settings,
        AppConstants.settingsFileName,
      )) {
        final content = await AppStorage.instance.readString(
          StorageDomainEnum.settings,
          AppConstants.settingsFileName,
        );
        final map = jsonDecode(content) as Map<String, dynamic>;
        final storedVersion = map[_schemaVersionKey] as String?;
        if (storedVersion != AppConstants.cacheVersion) {
          LoggingService().warning(
            'Settings schema mismatch (stored=${storedVersion ?? '(none)'}, '
            'current=${AppConstants.cacheVersion}) — resetting.',
          );
          await AppStorage.instance.deleteFile(
            StorageDomainEnum.settings,
            AppConstants.settingsFileName,
          );
          return {};
        }
        _currentCardsPath = map['character_path'] as String?;
        return map;
      }
    } on Exception catch (e, stackTrace) {
      LoggingService().warning('Error loading settings: $e', e, stackTrace);
    }
    return {};
  }

  Future<void> saveSettings(Map<String, dynamic> map) async {
    try {
      if (map.containsKey('character_path')) {
        _currentCardsPath = map['character_path'] as String?;
      }
      await AppStorage.instance.writeString(
        StorageDomainEnum.settings,
        AppConstants.settingsFileName,
        jsonEncode(map),
      );
    } on Exception catch (e, stackTrace) {
      LoggingService().error('Error saving settings: $e', e, stackTrace);
    }
  }

  Future<void> saveRecovery(LlmProvidersRecovery recovery) async {
    try {
      await AppStorage.instance.writeString(
        StorageDomainEnum.settings,
        AppConstants.llmProvidersRecoveryFileName,
        jsonEncode(recovery.toJson()),
      );
    } on Exception catch (e, stackTrace) {
      LoggingService().error(
        'Error saving recovery file: $e',
        e,
        stackTrace,
      );
    }
  }

  /// Returns null when the file is absent or can't be decoded. A broken
  /// recovery file should drop us to the fresh-install path, not crash
  /// bootstrap — matches how [loadSettings] swallows decode errors and
  /// returns `{}`.
  Future<LlmProvidersRecovery?> loadRecovery() async {
    try {
      if (await AppStorage.instance.fileExists(
        StorageDomainEnum.settings,
        AppConstants.llmProvidersRecoveryFileName,
      )) {
        final content = await AppStorage.instance.readString(
          StorageDomainEnum.settings,
          AppConstants.llmProvidersRecoveryFileName,
        );
        final map = jsonDecode(content) as Map<String, dynamic>;
        return LlmProvidersRecovery.fromJson(map);
      }
    } on Exception catch (e, stackTrace) {
      LoggingService().warning(
        'Error loading recovery file: $e',
        e,
        stackTrace,
      );
    }
    return null;
  }

  static const String _schemaVersionKey = 'schema_version';
}
