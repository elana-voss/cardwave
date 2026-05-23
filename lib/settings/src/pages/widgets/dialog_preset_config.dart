import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/controllers/dialog_preset_config_controller.dart';
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
  final FocusNode _nameFocusNode = FocusNode();
  late final DialogPresetConfigController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DialogPresetConfigController(
      configuration: widget.configuration,
      connectionProfile: widget.connectionProfile,
      initialModel: widget.initialModel,
      activeDomains: widget.activeDomains,
      pureHelpers: context.read<LlmPureHelpers>(),
      settingsService: context.read<SettingsService>(),
      llmManagementService: context.read<LlmManagementService>(),
      promptRepository: context.read<PromptRepository>(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onShowModelSelectionDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => DialogModelSelection(
        models: _controller.availableModels,
        provider: widget.connectionProfile.providerEnum,
      ),
    );
    if (selected != null) {
      _controller.applySelectedModel(selected);
    }
  }

  void _onSave() {
    if (_formKey.currentState?.validate() != true) return;
    final model = _controller.resolvedSelectedModel;
    if (model == null) return;
    final preset = _controller.buildSavedPreset();
    Navigator.pop<DialogPresetResult>(
      context,
      (model: model, preset: preset),
    );
  }

  Future<void> _onTest() async {
    if (_formKey.currentState?.validate() != true) return;
    await _controller.sendTestMessage();
  }

  Future<void> _onDelete() async {
    final name = _controller.configurationName;
    if (name == null) return;
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete Model?',
      message: 'Permanently delete "$name"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirmed || !mounted) return;
    await _controller.performDeletion();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DialogPresetConfigController>.value(
      value: _controller,
      child: Consumer<DialogPresetConfigController>(
        builder: (context, controller, _) {
          final showDelete =
              widget.configuration != null && !controller.isLocked;
          final showTestButton = controller.canShowTestButton;
          return AppDialog(
            actions: [
              if (showTestButton)
                OutlinedButton.icon(
                  onPressed:
                      controller.selectedModel != null && !controller.isTesting
                      ? _onTest
                      : null,
                  icon: controller.isTesting
                      ? const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Test Message'),
                ),
              if (showTestButton && controller.connectionStatus != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      controller.connectionStatus! ? 'Success' : 'Failed',
                      style: TextStyle(
                        color: controller.connectionStatus!
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (!controller.connectionStatus!)
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
                  onPressed: _onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              if (showDelete) const SizedBox(width: 24),
              FilledButton(onPressed: _onSave, child: const Text('Save')),
            ],
            builder: (context, isMobile) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _DialogHeader(
                  isEditing: widget.configuration != null,
                  onReset: controller.resetToDefaults,
                ),
                _DialogFormBody(
                  formKey: _formKey,
                  nameController: controller.nameController,
                  nameFocusNode: _nameFocusNode,
                  modelTextController: controller.modelTextController,
                  onShowModelSelectionDialog: _onShowModelSelectionDialog,
                  activeParameters: controller.activeParameters,
                  parameterControllers: controller.parameterControllers,
                  isMobile: isMobile,
                  activeDomains: widget.activeDomains,
                  selectedModel: controller.resolvedSelectedModel,
                ),
              ],
            ),
          );
        },
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
