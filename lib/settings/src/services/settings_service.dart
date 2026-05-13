import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/models/app_settings.dart';
import 'package:cardwave/settings/src/models/llm_providers_recovery.dart';
import 'package:cardwave/settings/src/repositories/settings_repository.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';

class SettingsService extends ChangeNotifier {
  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();
  static final SettingsService _instance = SettingsService._internal();

  final SettingsRepository _settingsRepository = SettingsRepository();
  AppSettings _settings = AppSettings();

  /// True when [init] found settings.json missing but a non-empty
  /// recovery file present. The rebuild runs after bootstrap (see
  /// [rebuildFromRecovery]) so the UI can mount and show progress — if
  /// we fetched models inside [init], the native splash would stay up
  /// through the entire parallel fetch with no feedback.
  bool _needsRebuildFromRecovery = false;

  bool _isLoading = false;
  String _loadingStatus = '';
  double? _loadingProgress;

  AppSettings get settings => _settings;

  bool get isLoading => _isLoading;
  String get loadingStatus => _loadingStatus;
  double? get loadingProgress => _loadingProgress;

  String? pathResolver(StorageDomainEnum domain) =>
      _settingsRepository.pathResolver(domain);

  Future<void> init(String appDataPath) async {
    _settingsRepository.init(appDataPath);
    await AppStorage.instance.init(pathResolver);

    final map = await _settingsRepository.loadSettings();
    if (map.isNotEmpty) {
      _settings = AppSettings.fromJson(map);
    } else {
      // settings.json missing or just invalidated by a schema bump —
      // before falling through to the fresh-install defaults, see if
      // the recovery mirror can seed the providers. Only the user-
      // entered credentials come back; models and presets regenerate
      // during [rebuildFromRecovery]. `onboardingComplete` is flipped
      // to true because the only path that writes the mirror is a
      // save after the user has already finished onboarding.
      final recovery = await _settingsRepository.loadRecovery();
      if (recovery != null && recovery.providers.isNotEmpty) {
        _settings = AppSettings(
          characterPath: recovery.characterPath,
          connectionProfiles: [
            for (final entry in recovery.providers)
              LlmProviderConfig(
                id: entry.id,
                apiKey: entry.apiKey,
                baseUrl: entry.baseUrl,
                providerEnum: entry.providerType,
                models: [],
              ),
          ],
          onboardingComplete: true,
        );
        _needsRebuildFromRecovery = true;
      }
    }

    _settings.characterPath ??= await getNativeDefaultCharacterPath();
    _settingsRepository.setCardsPath(_settings.characterPath);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _settingsRepository.saveSettings(_settings.toJson());
    await _settingsRepository.saveRecovery(
      LlmProvidersRecovery(
        characterPath: _settings.characterPath!,
        providers: [
          for (final p in _settings.providerConfigs)
            LlmProviderRecoveryEntry(
              id: p.id,
              providerType: p.providerEnum,
              apiKey: p.apiKey,
              baseUrl: p.baseUrl,
            ),
        ],
      ),
    );
    notifyListeners();
  }

  /// Runs the deferred rebuild queued by [init] when settings.json was
  /// missing but the recovery mirror existed. Fetches models for each
  /// seeded provider in parallel, then persists a complete settings.json
  /// (which re-writes the mirror as a happy side effect). Called once
  /// per launch from `MyApp`'s first-frame callback. Safe to call when
  /// the flag is unset — early-returns.
  ///
  /// `refreshProviderModels` catches its own per-provider errors and
  /// returns them in a tuple, so a bad provider doesn't throw here. If
  /// some providers fail, their configs persist with empty `models` and
  /// the user can retry from Settings → Refresh.
  Future<void> rebuildFromRecovery(LlmManagementService mgmt) async {
    if (!_needsRebuildFromRecovery) return;
    _needsRebuildFromRecovery = false;

    final profiles = _settings.providerConfigs;
    final total = profiles.length;

    _isLoading = true;
    _loadingStatus = 'Restoring providers…';
    _loadingProgress = null;
    notifyListeners();

    var completed = 0;
    await Future.wait([
      for (final profile in profiles)
        () async {
          await mgmt.refreshProviderModels(
            settings: _settings,
            profile: profile,
            trigger: ModelRefreshTriggerEnum.recoveryRebuild,
          );
          completed++;
          _loadingStatus = 'Fetching models ($completed/$total)…';
          _loadingProgress = completed / total;
          notifyListeners();
        }(),
    ]);

    await saveSettings();

    _isLoading = false;
    _loadingStatus = '';
    _loadingProgress = null;
    notifyListeners();
  }

  /// Assigns [presetId] as the active preset for [domain], overwriting any
  /// previous mapping. Pass `null` to clear the domain. Persists + notifies.
  Future<void> setDomainPreset(
    LlmProviderDomainEnum domain,
    String? presetId,
  ) async {
    _settings.setAppDomainPresetId(domain, presetId);
    await saveSettings();
  }

  /// Per-section "Show advanced" expander state in the chat drawer.
  /// Persists + notifies.
  Future<void> setDrawerSectionAdvanced(String section, bool value) async {
    _settings.drawerSectionAdvanced[section] = value;
    await saveSettings();
  }
}
