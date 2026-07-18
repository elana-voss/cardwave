import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.settingsService,
    required LlmPureHelpers pureHelpers,
    required LlmManagementService llmManagementService,
  }) : _llmService = pureHelpers,
       _llmManagementService = llmManagementService;
  final SettingsService settingsService;
  final LlmPureHelpers _llmService;
  final LlmManagementService _llmManagementService;

  int currentStep = 0;

  String? selectedPath;
  bool useDefaultPath = true;

  String apiKey = '';
  LLMProviderEnum? selectedProvider;
  bool isFetchingModels = false;
  List<LlmModel> models = [];
  String? selectedModelId;
  String? fetchError;
  bool requireZdr = false;

  String personaName = '';
  bool acceptedDisclaimer = false;

  Timer? _fetchDebounce;
  bool _isDisposed = false;
  static const Duration _fetchDebounceDelay = Duration(milliseconds: 500);
  static const int _minKeyLengthForFetch = 20;

  bool get skipStorageStep =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Desktop adds a folder-pick step; web/mobile go straight to the form.
  bool get hasMultipleSteps => !skipStorageStep;

  int get storageStepIndex => skipStorageStep ? -1 : 0;
  int get setupStepIndex => skipStorageStep ? 0 : 1;

  bool get hasAiConnected =>
      selectedProvider != null && selectedModelId != null;

  /// Set after the user opens the in-process GGUF dialog and confirms a
  /// loaded model. Onboarding finish persists this profile to settings the
  /// same way it persists a cloud-API profile.
  LlmProviderConfig? localGgufProfile;

  bool get hasLocalGgufConfigured => localGgufProfile != null;

  /// Mirrors the Finish Setup button's enabled state.
  bool get canFinish =>
      !isFetchingModels && personaName.trim().isNotEmpty && acceptedDisclaimer;

  /// Opens the in-process GGUF add dialog. Same dialog as Settings, so the
  /// detection / recommendation / load flow stays in one place. Result is
  /// stored on the controller and surfaced in the onboarding page; final
  /// persistence happens in [finishOnboarding].
  Future<void> pickLocalGguf() async {
    final profile = await NavigationService().showLocalGgufProviderAddDialog();
    if (profile == null) return;
    localGgufProfile = profile;
    _safeNotify();
  }

  void init() {
    final existingPath = settingsService.settings.characterPath;
    if (existingPath != null && existingPath.isNotEmpty) {
      selectedPath = existingPath;
      useDefaultPath = false;
    }
    final persona = settingsService.settings.activePersona;
    personaName = persona.name;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fetchDebounce?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  Future<void> pickDirectory() async {
    final directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      selectedPath = directoryPath;
      useDefaultPath = false;
      _safeNotify();
    }
  }

  void selectDefaultPath() {
    useDefaultPath = true;
    selectedPath = null;
    _safeNotify();
  }

  void nextStep() {
    currentStep += 1;
    _safeNotify();
  }

  void previousStep() {
    if (currentStep > 0) {
      currentStep -= 1;
      _safeNotify();
    }
  }

  void updateApiKey(String key) {
    apiKey = key;
    fetchError = null;
    final detected = LlmProvider.detectFromApiKey(key);

    if (detected != selectedProvider) {
      selectedProvider = detected;
      models = [];
      selectedModelId = null;
    }
    _safeNotify();

    _fetchDebounce?.cancel();
    if (detected != null && key.length >= _minKeyLengthForFetch) {
      _fetchDebounce = Timer(_fetchDebounceDelay, fetchModels);
    }
  }

  void updateRequireZdr(bool value) {
    if (requireZdr == value) return;
    requireZdr = value;
    models = [];
    selectedModelId = null;
    fetchError = null;
    _safeNotify();
    if (apiKey.isNotEmpty) unawaited(fetchModels());
  }

  void updatePersonaName(String name) {
    personaName = name;
    _safeNotify();
  }

  void updateAcceptedDisclaimer(bool accepted) {
    acceptedDisclaimer = accepted;
    _safeNotify();
  }

  Future<void> fetchModels() async {
    if (selectedProvider == null || _isDisposed) return;

    isFetchingModels = true;
    fetchError = null;
    models = [];
    selectedModelId = null;
    _safeNotify();

    try {
      final fetched = await _llmService.fetchModels(
        provider: selectedProvider!,
        apiKey: apiKey,
        requireZdr: requireZdr,
      );
      if (_isDisposed) return;
      models = fetched;

      if (models.isNotEmpty) {
        final resolvedId = _llmService.resolveModelForDomain(
          LlmProviderDomainEnum.chat,
          _llmService.getDefaultModelPreferencesForDomain(
            selectedProvider!,
            LlmProviderDomainEnum.chat,
          ),
          models,
        );
        selectedModelId = resolvedId.isEmpty ? models.first.id : resolvedId;
      } else {
        fetchError = t.onboarding.fetchError.noModels;
      }
    } on Exception catch (e, st) {
      LoggingService().error('Onboarding model fetch failed', e, st);
      fetchError = t.onboarding.fetchError.connectionFailed;
    } finally {
      isFetchingModels = false;
      _safeNotify();
    }
  }

  Future<void> finishOnboarding() async {
    if (skipStorageStep) {
      settingsService.settings.characterPath =
          await getNativeDefaultCharacterPath(AppConstants.appPackageName);
    } else if (selectedPath != null) {
      settingsService.settings.characterPath = selectedPath;
    } else if (useDefaultPath) {
      settingsService.settings.characterPath =
          await getNativeDefaultCharacterPath(AppConstants.appPackageName);
    }

    if (hasAiConnected) {
      // `hasAiConnected` is only true when a provider was selected.
      final provider = selectedProvider!;
      final profile = LlmProviderConfig(
        id: UtilsApp.generateId(provider.name),
        apiKey: apiKey,
        providerEnum: provider,
        models: [],
        requireZdr: requireZdr,
      );
      settingsService.settings.providerConfigs.add(profile);
      try {
        await _llmManagementService.refreshProviderModels(
          settings: settingsService.settings,
          profile: profile,
          trigger: ModelRefreshTriggerEnum.manual,
          preFetchedModels: models,
        );
      } catch (_) {
        // Roll back the half-added provider before rethrowing, so a retry
        // (tapping Finish again) doesn't duplicate it and no phantom
        // empty-model provider is left stranded in Settings.
        settingsService.settings.providerConfigs.removeWhere(
          (p) => p.id == profile.id,
        );
        rethrow;
      }
    }

    if (localGgufProfile != null) {
      // The dialog already warmed the model and built the LlmModel
      // stub, so no remote fetch is needed — `refreshProviderModels`
      // short-circuits for localGguf, but its preset-seeding step
      // (`_seedDefaultDomainPresetsIfEmpty`) is still required. Without
      // it the new profile shows up in providerConfigs but has no
      // chat/system preset assigned, and the user lands on
      // an empty chat after finishing onboarding. Same call the
      // Settings "Add Local GGUF" flow makes via `applyProviderAdd`.
      final localProfile = localGgufProfile!;
      settingsService.settings.providerConfigs.add(localProfile);
      try {
        await _llmManagementService.refreshProviderModels(
          settings: settingsService.settings,
          profile: localProfile,
          trigger: ModelRefreshTriggerEnum.manual,
          preFetchedModels: localProfile.models,
        );
      } catch (_) {
        // Same rollback as the cloud-provider block above.
        settingsService.settings.providerConfigs.removeWhere(
          (p) => p.id == localProfile.id,
        );
        rethrow;
      }
    }

    settingsService.settings.activePersona.name = personaName.trim();
    settingsService.settings.onboardingComplete = true;

    await settingsService.saveSettings();
  }
}
