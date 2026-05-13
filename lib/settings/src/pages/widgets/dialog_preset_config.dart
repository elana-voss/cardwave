import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

part 'dialog_preset_config_form_body.dart';
part 'dialog_preset_config_parameter_input_widget.dart';

typedef DialogPresetResult = ({LlmModel model, LlmPresetConfig preset});

/// Modal editor for a single model preset: name, model selection,
/// parameter values (temperature etc.), reasoning effort, test-message
/// probe, and delete. Pops a [DialogPresetResult] {model, preset} on save.
/// Delete is hidden when the preset is currently assigned to any domain —
/// the user must unassign it first via the inventory row's domain menu.
class DialogPresetConfig extends StatefulWidget {
  const DialogPresetConfig({
    required this.connectionProfile,
    super.key,
    this.configuration,
    this.initialModel,
    this.activeDomains = const {},
  });
  final LlmPresetConfig? configuration;
  final LlmProviderConfig connectionProfile;

  /// The [LlmModel] the [configuration] is currently attached to. Required
  /// for edit; null for add (model picked via dialog). Used to seed initial
  /// parameter bounds before the live fetch completes.
  final LlmModel? initialModel;
  final Set<LlmProviderDomainEnum> activeDomains;

  @override
  State<DialogPresetConfig> createState() => _DialogPresetConfigState();
}

class _DialogPresetConfigState extends State<DialogPresetConfig> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();
  final Map<LlmParameterDefinitionIdEnum, TextEditingController>
  _parameterControllers = {};
  bool _isTesting = false;
  bool? _connectionStatus;
  List<LlmModel> _availableModels = [];
  String? _selectedModel;
  final TextEditingController _modelTextController = TextEditingController();
  List<LlmParameterDefinition> _activeParameters = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.configuration?.name ?? '',
    );
    _selectedModel = widget.initialModel?.id;
    if (_selectedModel != null) {
      _modelTextController.text = _selectedModel!;
    }

    final initialModel = widget.initialModel ?? LlmModel.fallback('');

    final supportedParams = commonParameters.where((p) {
      if (p.id == LlmParameterDefinitionIdEnum.contextSize) return true;
      return initialModel.supportedParameters.contains(p.id);
    });

    for (final paramDefinition in supportedParams) {
      var max = paramDefinition.max;
      var defaultVal = paramDefinition.defaultValue;

      if (paramDefinition.id == LlmParameterDefinitionIdEnum.contextSize) {
        max = initialModel.contextLength.toDouble();
        defaultVal = max;
      } else if (paramDefinition.id ==
          LlmParameterDefinitionIdEnum.maxResponseLength) {
        max = initialModel.maxOutputTokens.toDouble();
      }

      if (initialModel.defaultParameters.containsKey(paramDefinition.id)) {
        defaultVal = initialModel.defaultParameters[paramDefinition.id]!;
      }

      _activeParameters.add(
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

    for (final param in _activeParameters) {
      var value = param.defaultValue;
      if (widget.configuration != null) {
        value =
            widget.configuration!.parameterValues[param.id] ??
            param.defaultValue;
      }

      if (param.type == LLmParameterDefinitionTypeEnum.integer) {
        _parameterControllers[param.id] = TextEditingController(
          text: value.toInt().toString(),
        );
      } else {
        _parameterControllers[param.id] = TextEditingController(
          text: value.toStringAsFixed(2),
        );
      }
    }

    _loadAvailableModelsFromProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    _modelTextController.dispose();
    super.dispose();
  }

  /// Reads the provider's full catalog directly from settings.json via
  /// [widget.connectionProfile.models] and filters to models that can serve
  /// every active domain. Synchronous — no network hop, no spinner — since
  /// the catalog is refreshed only at app-start / onboarding / add-provider
  /// / manual-refresh (see `LlmPureHelpers.refreshProviderModels`).
  void _loadAvailableModelsFromProfile() {
    final pureHelpers = context.read<LlmPureHelpers>();
    final requiredModalities = widget.activeDomains
        .map(pureHelpers.getRequiredOutputModality)
        .toSet();

    _availableModels = widget.connectionProfile.models.where((model) {
      if (requiredModalities.isEmpty) return true;
      final outputModalities = model.capabilities.outputModalities;
      if (outputModalities.isEmpty) {
        return requiredModalities.length == 1 &&
            requiredModalities.contains(LlmModelCapabilitiesEnum.text);
      }
      return requiredModalities.every(outputModalities.contains);
    }).toList();

    if (_selectedModel != null &&
        !_availableModels.any((m) => m.id == _selectedModel)) {
      _selectedModel = null;
      _modelTextController.clear();
    } else if (_selectedModel != null) {
      final model = _availableModels.firstWhere(
        (m) => m.id == _selectedModel,
        orElse: () => throw StateError(
          'selected model "$_selectedModel" missing from available list',
        ),
      );
      _updateParametersForModel(model);
    }
  }

  Future<void> _showModelSelectionDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => DialogModelSelection(
        models: _availableModels,
        provider: widget.connectionProfile.providerEnum,
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedModel = selected;
        _modelTextController.text = selected;

        final model = _availableModels.firstWhere(
          (m) => m.id == selected,
          orElse: () =>
              throw StateError('picked model "$selected" missing from list'),
        );
        // Seed the preset name from the model on first pick so the user gets
        // a reasonable default without typing. Only fill when the field is
        // whitespace-empty — we never overwrite user-typed or previously-
        // auto-filled content, even if they switch models afterward.
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = model.name;
        }
        _updateParametersForModel(model, maximizeContext: true);
      });
    }
  }

  void _updateParametersForModel(
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
        max = model.contextSize.toDouble();
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

    // Mutations land directly (no setState): this runs either during
    // initState (via _loadAvailableModelsFromProfile, before the first
    // build) or already inside _showModelSelectionDialog's setState — so
    // wrapping it in its own setState would be a redundant nested rebuild.
    _activeParameters = newActiveParameters;

    // 3. Ensure controllers exist for all active parameters and are within bounds
    for (final param in _activeParameters) {
      // "If there's no controller yet, create one; otherwise validate the
      // existing one" — the negated form is the natural phrasing here, and
      // the else-body is too large to swap cleanly.
      // ignore: qcheck/avoid_negated_conditions
      if (!_parameterControllers.containsKey(param.id)) {
        // Initialize new controller if missing (e.g. switching to a model that supports more params)
        var val = param.defaultValue;
        if (maximizeContext &&
            param.id == LlmParameterDefinitionIdEnum.contextSize) {
          val = param.max;
        }
        _parameterControllers[param.id] = TextEditingController(
          text: param.type == LLmParameterDefinitionTypeEnum.integer
              ? val.toInt().toString()
              : val.toStringAsFixed(2),
        );
      } else {
        // Validate existing value against new max limit
        final controller = _parameterControllers[param.id]!;
        if (maximizeContext &&
            param.id == LlmParameterDefinitionIdEnum.contextSize) {
          final newText = param.type == LLmParameterDefinitionTypeEnum.integer
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
            final newText = param.type == LLmParameterDefinitionTypeEnum.integer
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

  Map<LlmParameterDefinitionIdEnum, double> _collectParameters() {
    final parameterValues = <LlmParameterDefinitionIdEnum, double>{};

    for (final param in _activeParameters) {
      final controller = _parameterControllers[param.id];
      if (controller == null) continue;

      final text = controller.text;
      final val = param.type == LLmParameterDefinitionTypeEnum.integer
          ? (int.tryParse(text) ?? param.defaultValue.toInt())
          : (double.tryParse(text) ?? param.defaultValue);

      final clampedVal = val.toDouble().clamp(param.min, param.max);
      parameterValues[param.id] = clampedVal;

      final newText = param.type == LLmParameterDefinitionTypeEnum.integer
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
  bool get _canShowTestButton {
    final model = _resolveSelectedModel();
    if (model == null) return true;
    final mods = model.capabilities.outputModalities;
    if (mods.isEmpty) return true;
    return mods.contains(LlmModelCapabilitiesEnum.text);
  }

  Future<void> _sendTestMessage() async {
    if (_selectedModel == null) {
      return;
    }

    setState(() {
      _isTesting = true;
      _connectionStatus = null;
    });

    LoggingService().info('Sending test message to ${_selectedModel ?? '?'}...');

    try {
      if (_formKey.currentState?.validate() != true) {
        setState(() => _isTesting = false);
        return;
      }

      final parameterValues = _collectParameters();
      final apiKey = widget.connectionProfile.apiKey;

      final providerEnum = widget.connectionProfile.providerEnum;

      parameterValues[LlmParameterDefinitionIdEnum.maxResponseLength] = 10;

      final modelObj = _availableModels.firstWhere(
        (m) => m.id == _selectedModel,
        orElse: () => throw StateError(
          'selected model "${_selectedModel ?? '?'}" missing from available list',
        ),
      );
      final runner = context.read<LlmPureHelpers>().createRunnerRaw(
        providerEnum: providerEnum,
        apiKey: apiKey,
        model: modelObj,
        paramValues: parameterValues,
      );

      final reply = await runner.complete(
        context.read<PromptRepository>().testMessage,
      );

      LoggingService().info('Test message received successfully');

      if (mounted) {
        setState(() {
          _isTesting = false;
          _connectionStatus = true;
        });
        await NavigationService().showAlertConfirmDialog(
          title: 'Response',
          message: reply,
        );
      }
    } on Exception catch (e, stackTrace) {
      LoggingService().error('Test message failed', e, stackTrace);
      if (mounted) {
        setState(() {
          _connectionStatus = false;
          _isTesting = false;
        });
      }
    }
  }

  LlmModel? _resolveSelectedModel() {
    final id = _selectedModel;
    if (id == null) return null;
    final fromFetched = _availableModels.where((m) => m.id == id).firstOrNull;
    if (fromFetched != null) return fromFetched;
    if (widget.initialModel?.id == id) return widget.initialModel;
    return null;
  }

  bool get _isLocked {
    final target = widget.configuration;
    if (target == null) return false;
    return context
        .read<SettingsService>()
        .settings
        .activeAppDomainPresetIds
        .contains(target.id);
  }

  Future<void> _confirmDelete() async {
    final target = widget.configuration;
    if (target == null) return;
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete Model?',
      message: 'Permanently delete "${target.name}"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;

    final settingsService = context.read<SettingsService>();
    context.read<LlmManagementService>().deletePreset(
      settings: settingsService.settings,
      presetId: target.id,
    );
    await settingsService.saveSettings();
    if (mounted) Navigator.pop(context);
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final parameterValues = _collectParameters();

    final preset = LlmPresetConfig(
      id: widget.configuration?.id ?? UtilsApp.generateId(_nameController.text),
      name: _nameController.text,
      parameterValues: parameterValues,
      reasoningEffort:
          widget.configuration?.reasoningEffort ??
          LlmPresetConfigReasoningEffortEnum.off,
    );
    final modelObj = _availableModels.firstWhere(
      (m) => m.id == _selectedModel,
      orElse: () => widget.initialModel ?? LlmModel.fallback(_selectedModel!),
    );

    Navigator.pop<DialogPresetResult>(context, (
      model: modelObj,
      preset: preset,
    ));
  }

  void _resetToDefaults() {
    setState(() {
      for (final param in _activeParameters) {
        final controller = _parameterControllers[param.id];
        if (controller != null) {
          final val = param.defaultValue;
          final newText = param.type == LLmParameterDefinitionTypeEnum.integer
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDelete = widget.configuration != null && !_isLocked;
    final showTestButton = _canShowTestButton;
    return AppDialog(
      actions: [
        if (showTestButton)
          OutlinedButton.icon(
            onPressed: _selectedModel != null && !_isTesting
                ? _sendTestMessage
                : null,
            icon: _isTesting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Test Message'),
          ),
        if (showTestButton && _connectionStatus != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Text(
                _connectionStatus! ? 'Success' : 'Failed',
                style: TextStyle(
                  color: _connectionStatus!
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
              if (!_connectionStatus!)
                IconButton(
                  icon: Icon(
                    Icons.bug_report,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomLogScreen(),
                    ),
                  ),
                ),
            ],
          ),
        const Spacer(),
        if (showDelete)
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        if (showDelete) const SizedBox(width: 24),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(
            isEditing: widget.configuration != null,
            onReset: _resetToDefaults,
          ),
          const SizedBox(height: 16),
          _DialogFormBody(
            formKey: _formKey,
            nameController: _nameController,
            nameFocusNode: _nameFocusNode,
            modelTextController: _modelTextController,
            onShowModelSelectionDialog: _showModelSelectionDialog,
            activeParameters: _activeParameters,
            parameterControllers: _parameterControllers,
            isMobile: isMobile,
            activeDomains: widget.activeDomains,
            selectedModel: _resolveSelectedModel(),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.isEditing, required this.onReset});
  final bool isEditing;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          isEditing ? 'Edit Model' : 'Add Model',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.restore),
          tooltip: 'Reset to Defaults',
          onPressed: onReset,
        ),
      ],
    );
  }
}

class _ParameterInputWidgetState extends State<ParameterInputWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _clampValue();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double get _currentValue =>
      (double.tryParse(widget.controller.text) ?? widget.parameter.defaultValue)
          .clamp(widget.parameter.min, widget.parameter.max);

  void _setValue(double value) {
    final clamped = value.clamp(widget.parameter.min, widget.parameter.max);
    final newText =
        widget.parameter.type == LLmParameterDefinitionTypeEnum.integer
        ? clamped.toInt().toString()
        : clamped.toStringAsFixed(2);

    if (widget.controller.text != newText) {
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _clampValue() {
    final parsed = double.tryParse(widget.controller.text);
    if (parsed != null) _setValue(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.parameter;
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    def.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: def.description,
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isMobile) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Slider(
                    padding: EdgeInsets.zero,
                    value: _currentValue,
                    min: def.min,
                    max: def.max,
                    divisions:
                        def.type == LLmParameterDefinitionTypeEnum.integer
                        ? (def.max - def.min).toInt()
                        : 100,
                    label: value.text,
                    onChanged: _setValue,
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextFieldAutotrim(
              controller: controller,
              focusNode: _focusNode,
              onFieldSubmitted: (_) => _clampValue(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(
                    def.type == LLmParameterDefinitionTypeEnum.integer
                        ? (def.min < 0 ? r'^-?\d*$' : r'^\d*$')
                        : (def.min < 0 ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$'),
                  ),
                ),
              ],
              keyboardType: TextInputType.numberWithOptions(
                decimal: def.type == LLmParameterDefinitionTypeEnum.double,
                signed: def.min < 0,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                errorStyle: TextStyle(height: 0),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final parsed = double.tryParse(value);
                if (parsed == null) {
                  return 'Invalid';
                }
                if (parsed < def.min || parsed > def.max) {
                  return '${def.min} - ${def.max}';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
