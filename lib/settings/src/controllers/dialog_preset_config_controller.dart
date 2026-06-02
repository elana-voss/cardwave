import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/widgets.dart';

/// Per-instance controller for [DialogPresetConfig]. Owns all the
/// dialog's mutable state: text-edit controllers, the parameter list,
/// the available-models list, the model selection, and the
/// test-message flags. Created in the dialog's [State.initState] from
/// services read via `context.read`, disposed in `State.dispose`,
/// exposed to the dialog subtree via `ChangeNotifierProvider.value`.
class DialogPresetConfigController extends ChangeNotifier {
  DialogPresetConfigController({
    required this.configuration,
    required this.connectionProfile,
    required this.initialModel,
    required this.activeDomains,
    required this.pureHelpers,
    required this.settingsService,
    required this.llmManagementService,
    required this.promptRepository,
  }) {
    nameController.text = configuration?.name ?? '';
    selectedModel = initialModel?.id;
    if (selectedModel != null) {
      modelTextController.text = selectedModel!;
    }

    final seedModel = initialModel ?? LlmModel.fallback('');
    final supportedParams = commonParameters.where((p) {
      if (p.id == LlmParameterDefinitionIdEnum.contextSize) return true;
      return seedModel.supportedParameters.contains(p.id);
    });

    for (final paramDefinition in supportedParams) {
      var max = paramDefinition.max;
      var defaultVal = paramDefinition.defaultValue;

      if (paramDefinition.id == LlmParameterDefinitionIdEnum.contextSize) {
        max = _contextLimitFor(seedModel);
        defaultVal = max;
      } else if (paramDefinition.id ==
          LlmParameterDefinitionIdEnum.maxResponseLength) {
        max = seedModel.maxOutputTokens.toDouble();
      }

      if (seedModel.defaultParameters.containsKey(paramDefinition.id)) {
        defaultVal = seedModel.defaultParameters[paramDefinition.id]!;
      }

      activeParameters.add(
        LlmParameterDefinition(
          id: paramDefinition.id,
          name: paramDefinition.name,
          description: paramDefinition.description,
          min: paramDefinition.min,
          max: max,
          defaultValue: defaultVal,
          type: paramDefinition.type,
        ),
      );
    }

    for (final param in activeParameters) {
      var value = param.defaultValue;
      if (configuration != null) {
        value =
            configuration!.parameterValues[param.id] ?? param.defaultValue;
      }

      if (param.type == LlmParameterDefinitionTypeEnum.integer) {
        parameterControllers[param.id] = TextEditingController(
          text: value.toInt().toString(),
        );
      } else {
        parameterControllers[param.id] = TextEditingController(
          text: value.toStringAsFixed(2),
        );
      }
    }

    _loadAvailableModelsFromProfile();
  }

  final LlmPresetConfig? configuration;
  final LlmProviderConfig connectionProfile;
  final LlmModel? initialModel;
  final Set<LlmProviderDomainEnum> activeDomains;
  final LlmPureHelpers pureHelpers;
  final SettingsService settingsService;
  final LlmManagementService llmManagementService;
  final PromptRepository promptRepository;

  /// Upper bound for the Context Size slider. A local GGUF can only serve the
  /// context it was loaded with, so its limit is the size stored on the
  /// profile — not the model's notional native length, which would let the
  /// user pick a value that overflows the in-VRAM context. Cloud models use
  /// their advertised native length.
  double _contextLimitFor(LlmModel model) {
    final loaded = connectionProfile.contextSize;
    if (connectionProfile.providerEnum == LLMProviderEnum.localGguf &&
        loaded != null) {
      return loaded.toDouble();
    }
    return model.contextLength.toDouble();
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController modelTextController = TextEditingController();
  final Map<LlmParameterDefinitionIdEnum, TextEditingController>
      parameterControllers = {};

  String? selectedModel;
  List<LlmModel> availableModels = [];
  List<LlmParameterDefinition> activeParameters = [];
  bool isTesting = false;
  bool? connectionStatus;

  @override
  void dispose() {
    nameController.dispose();
    modelTextController.dispose();
    for (final controller in parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Reads the provider's full catalog directly from settings.json via
  /// [connectionProfile.models] and filters to models that can serve
  /// every active domain. Synchronous — no network hop, no spinner — since
  /// the catalog is refreshed only at app-start / onboarding / add-provider
  /// / manual-refresh (see `LlmPureHelpers.refreshProviderModels`).
  void _loadAvailableModelsFromProfile() {
    final requiredModalities = activeDomains
        .map(pureHelpers.getRequiredOutputModality)
        .toSet();

    availableModels = connectionProfile.models.where((model) {
      if (requiredModalities.isEmpty) return true;
      final outputModalities = model.capabilities.outputModalities;
      if (outputModalities.isEmpty) {
        return requiredModalities.length == 1 &&
            requiredModalities.contains(LlmModelCapabilitiesEnum.text);
      }
      return requiredModalities.every(outputModalities.contains);
    }).toList();

    if (selectedModel != null &&
        !availableModels.any((m) => m.id == selectedModel)) {
      selectedModel = null;
      modelTextController.clear();
    } else if (selectedModel != null) {
      final model = availableModels.firstWhere(
        (m) => m.id == selectedModel,
        orElse: () => throw StateError(
          'selected model "$selectedModel" missing from available list',
        ),
      );
      updateParametersForModel(model);
    }
  }

  /// Applies a user-picked [modelId] from the model-selection dialog.
  /// Seeds the preset name from the model on first pick so the user gets
  /// a reasonable default without typing. Only fills when the field is
  /// whitespace-empty — never overwrites user-typed or previously
  /// auto-filled content, even if they switch models afterward.
  void applySelectedModel(String modelId) {
    selectedModel = modelId;
    modelTextController.text = modelId;

    final model = availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () =>
          throw StateError('picked model "$modelId" missing from list'),
    );
    if (nameController.text.trim().isEmpty) {
      nameController.text = model.name;
    }
    updateParametersForModel(model, maximizeContext: true);
    notifyListeners();
  }

  void updateParametersForModel(
    LlmModel model, {
    bool maximizeContext = false,
  }) {
    // 1. Filter parameters based on model support
    final supportedParams = commonParameters.where(
      (p) => model.isParameterSupported(p.id),
    );

    // 2. Rebuild active parameters list with updated limits
    final newActiveParameters = <LlmParameterDefinition>[];

    for (final paramDefinition in supportedParams) {
      var max = paramDefinition.max;
      var defaultVal = paramDefinition.defaultValue;

      // Update Context Size Limit (Client-side)
      if (paramDefinition.id == LlmParameterDefinitionIdEnum.contextSize) {
        max = _contextLimitFor(model);
        defaultVal = max;
      }
      // Update Max Response Limit (API)
      else if (paramDefinition.id ==
          LlmParameterDefinitionIdEnum.maxResponseLength) {
        max = model.maxResponseLength.toDouble();
      }

      if (model.defaultParameters.containsKey(paramDefinition.id)) {
        defaultVal = model.defaultParameters[paramDefinition.id]!;
      }

      newActiveParameters.add(
        LlmParameterDefinition(
          id: paramDefinition.id,
          name: paramDefinition.name,
          description: paramDefinition.description,
          min: paramDefinition.min,
          max: max,
          defaultValue: defaultVal,
          type: paramDefinition.type,
        ),
      );
    }

    activeParameters = newActiveParameters;

    // 3. Ensure controllers exist for all active parameters and are within bounds
    for (final param in activeParameters) {
      // "If there's no controller yet, create one; otherwise validate the
      // existing one" — the negated form is the natural phrasing here, and
      // the else-body is too large to swap cleanly.
      // ignore: qcheck/avoid_negated_conditions
      if (!parameterControllers.containsKey(param.id)) {
        // Initialize new controller if missing (e.g. switching to a model that supports more params)
        var val = param.defaultValue;
        if (maximizeContext &&
            param.id == LlmParameterDefinitionIdEnum.contextSize) {
          val = param.max;
        }
        parameterControllers[param.id] = TextEditingController(
          text: param.type == LlmParameterDefinitionTypeEnum.integer
              ? val.toInt().toString()
              : val.toStringAsFixed(2),
        );
      } else {
        // Validate existing value against new max limit
        final controller = parameterControllers[param.id]!;
        if (maximizeContext &&
            param.id == LlmParameterDefinitionIdEnum.contextSize) {
          final newText = param.type == LlmParameterDefinitionTypeEnum.integer
              ? param.max.toInt().toString()
              : param.max.toStringAsFixed(2);
          if (controller.text != newText) {
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newText.length),
            );
          }
        } else {
          final current = double.tryParse(controller.text);
          if (current != null && current > param.max) {
            final newText = param.type == LlmParameterDefinitionTypeEnum.integer
                ? param.max.toInt().toString()
                : param.max.toStringAsFixed(2);
            if (controller.text != newText) {
              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newText.length),
              );
            }
          }
        }
      }
    }
  }

  Map<LlmParameterDefinitionIdEnum, double> collectParameters() {
    final parameterValues = <LlmParameterDefinitionIdEnum, double>{};

    for (final param in activeParameters) {
      final controller = parameterControllers[param.id];
      if (controller == null) continue;

      final text = controller.text;
      final val = param.type == LlmParameterDefinitionTypeEnum.integer
          ? (int.tryParse(text) ?? param.defaultValue.toInt())
          : (double.tryParse(text) ?? param.defaultValue);

      final clampedVal = val.toDouble().clamp(param.min, param.max);
      parameterValues[param.id] = clampedVal;

      final newText = param.type == LlmParameterDefinitionTypeEnum.integer
          ? clampedVal.toInt().toString()
          : clampedVal.toStringAsFixed(2);

      if (controller.text != newText) {
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }
    return parameterValues;
  }

  /// True when the test-message control should be offered in the action bar.
  ///
  /// Test messages run against a text-completion endpoint, so a model that
  /// only emits non-text modalities (image, audio, video) can't be probed
  /// here. Rather than show a button that always errors, we hide it — the
  /// user's save still works; they just can't verify the connection from
  /// this surface. A null selection keeps the (disabled) button visible so
  /// the affordance is present once a model is picked.
  bool get canShowTestButton {
    final model = resolvedSelectedModel;
    if (model == null) return true;
    final mods = model.capabilities.outputModalities;
    if (mods.isEmpty) return true;
    return mods.contains(LlmModelCapabilitiesEnum.text);
  }

  /// Runs the test-message probe. Caller is responsible for form
  /// validation before invoking this — `isTesting` only flips on once
  /// validation has already passed.
  Future<void> sendTestMessage() async {
    if (selectedModel == null) return;

    isTesting = true;
    connectionStatus = null;
    notifyListeners();

    LoggingService().info('Sending test message to $selectedModel...');

    try {
      final parameterValues = collectParameters();
      parameterValues[LlmParameterDefinitionIdEnum.maxResponseLength] = 10;

      final modelObj = availableModels.firstWhere(
        (m) => m.id == selectedModel,
        orElse: () => throw StateError(
          'selected model "$selectedModel" missing from available list',
        ),
      );
      final runner = pureHelpers.createRunnerRaw(
        providerEnum: connectionProfile.providerEnum,
        apiKey: connectionProfile.apiKey,
        model: modelObj,
        paramValues: parameterValues,
        baseUrl: connectionProfile.baseUrl,
        modelPath: connectionProfile.modelPath,
        contextSize: connectionProfile.contextSize,
        kvCacheType: connectionProfile.kvCacheType,
      );

      final reply = await runner.complete(promptRepository.testMessage);

      LoggingService().info('Test message received successfully');
      isTesting = false;
      connectionStatus = true;
      notifyListeners();
      await NavigationService().showAlertConfirmDialog(
        title: 'Response',
        message: reply,
      );
    } on Exception catch (e, stackTrace) {
      LoggingService().error('Test message failed', e, stackTrace);
      isTesting = false;
      connectionStatus = false;
      notifyListeners();
    }
  }

  LlmModel? get resolvedSelectedModel {
    final id = selectedModel;
    if (id == null) return null;
    final fromFetched = availableModels.where((m) => m.id == id).firstOrNull;
    if (fromFetched != null) return fromFetched;
    if (initialModel?.id == id) return initialModel;
    // Stub fallback so Save still completes when the available-models list
    // changed underneath the user mid-dialog. The saved preset's caller
    // will re-resolve the real model on next use.
    return LlmModel.fallback(id);
  }

  bool get isLocked {
    final target = configuration;
    if (target == null) return false;
    return settingsService.settings.activeAppDomainPresetIds.contains(target.id);
  }

  /// Deletes the preset and persists settings. Caller is responsible
  /// for showing the user-facing confirm dialog and for popping the
  /// host dialog afterward — the confirm dialog needs a theme context
  /// that this controller doesn't hold.
  Future<void> performDeletion() async {
    final target = configuration;
    if (target == null) return;
    llmManagementService.deletePreset(
      settings: settingsService.settings,
      presetId: target.id,
    );
    await settingsService.saveSettings();
  }

  /// The preset name shown in the user-facing confirm-delete dialog.
  String? get configurationName => configuration?.name;

  /// Builds the [LlmPresetConfig] to return from the dialog on Save.
  /// Caller is responsible for form validation BEFORE calling this and
  /// for the `Navigator.pop` afterward.
  LlmPresetConfig buildSavedPreset() {
    final parameterValues = collectParameters();
    return LlmPresetConfig(
      id: configuration?.id ?? UtilsApp.generateId(nameController.text),
      name: nameController.text,
      parameterValues: parameterValues,
      reasoningEffort: configuration?.reasoningEffort ??
          LlmPresetConfigReasoningEffortEnum.off,
    );
  }

  void resetToDefaults() {
    for (final param in activeParameters) {
      final controller = parameterControllers[param.id];
      if (controller != null) {
        final val = param.defaultValue;
        final newText = param.type == LlmParameterDefinitionTypeEnum.integer
            ? val.toInt().toString()
            : val.toStringAsFixed(2);
        if (controller.text != newText) {
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
    }
    notifyListeners();
  }
}
