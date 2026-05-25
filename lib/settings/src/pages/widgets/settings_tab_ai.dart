import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/controllers/providers_controller.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_default_models.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_provider_profile.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings tab for AI providers. Renders the "New Provider" button and
/// the model-refresh menu in a pinned header, then a scrollable list with
/// [TileDefaultModels] on top (per-domain overview) followed by one
/// [TileProviderProfile] per configured provider. Owns the add-provider
/// flow and auto-heals domain→preset assignments on init.
class SettingsTabAi extends StatefulWidget {
  const SettingsTabAi({super.key});

  @override
  State<SettingsTabAi> createState() => _SettingsTabAiState();
}

class _SettingsTabAiState extends State<SettingsTabAi> {
  late final SettingsService _settingsService;
  bool _isRefreshing = false;

  /// True from the moment a New Provider dialog returns a result until
  /// `refreshProviderModels` + `saveSettings` finishes. While true, a
  /// `PopScope` blocks the back button and an absorbing overlay disables
  /// taps on the body, so the user can't dismiss the AI Settings dialog
  /// mid-write. Tap-outside on the showDialog barrier is a residual
  /// dismissal vector — would require changing the showDialog call site
  /// in `settings_gear_menu.dart` (out of scope for this widget).
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _settingsService = context.read<SettingsService>();
    _healAssignments();
  }

  Future<void> _runManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final mgmt = context.read<LlmManagementService>();
    try {
      final summary = await mgmt.refreshAdoptedModelMetadata(
        settings: _settingsService.settings,
        trigger: ModelRefreshTriggerEnum.manual,
      );
      await _settingsService.saveSettings();
      _healAssignments();
      NavigationService().showSnackBar(
        'Refreshed ${summary.updated} models, '
        '${summary.markedUnavailable} unavailable, '
        '${summary.errorsByProfile.length} errors.',
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _setRefreshPolicy(ModelRefreshPolicyEnum policy) {
    if (_settingsService.settings.refreshPolicy == policy) return;
    setState(() {
      _settingsService.settings.refreshPolicy = policy;
    });
    unawaited(_settingsService.saveSettings());
  }

  void _healAssignments() {
    final mutated = context.read<LlmManagementService>().healDomainAssignments(
      settings: _settingsService.settings,
    );
    if (mutated) unawaited(_settingsService.saveSettings());
  }

  Future<void> _addProvider() => _addProviderWithSpinner(isLocal: false);

  Future<void> _addLocalProvider() => _addProviderWithSpinner(isLocal: true);

  Future<void> _addLocalGgufProvider() => _addProviderWithGgufFlow();

  /// Opens the add-provider dialog, then runs the post-dialog persistence
  /// under the "Adding provider..." spinner. The split is deliberate: the
  /// spinner only flips on AFTER the dialog closes — while the dialog is up
  /// the user is still filling fields, and an overlay underneath would just
  /// be visual noise.
  Future<void> _addProviderWithSpinner({required bool isLocal}) async {
    final added = await ProvidersController.openProviderAddDialog(
      isLocal: isLocal,
    );
    if (added == null || !mounted) return;
    // Capture the LlmManagementService reference up-front so the post-await
    // calls don't reach into a context that may have been disposed if the
    // user managed to slip out of the dialog before the spinner kicked in.
    final mgmt = context.read<LlmManagementService>();
    setState(() => _isAdding = true);
    try {
      await ProvidersController.applyProviderAdd(
        settingsService: _settingsService,
        mgmt: mgmt,
        added: added,
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  /// In-process GGUF add flow. The dialog has already warmed the model
  /// and constructed the [LlmModel] stub. Persistence reuses
  /// [ProvidersController.applyProviderAdd] so the localGguf branch of
  /// `refreshProviderModels` seeds default presets (without that step the
  /// new profile would render as "No Models configured").
  Future<void> _addProviderWithGgufFlow() async {
    final profile = await ProvidersController.openLocalGgufProviderAddDialog();
    if (profile == null || !mounted) return;
    final mgmt = context.read<LlmManagementService>();
    setState(() => _isAdding = true);
    try {
      await ProvidersController.applyProviderAdd(
        settingsService: _settingsService,
        mgmt: mgmt,
        added: (profile: profile, fetchedModels: profile.models),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>().settings;
    final providers = settings.providerConfigs;

    final providerByPresetId = <String, LLMProviderEnum>{};
    for (final profile in providers) {
      for (final mp in profile.allModelPresets) {
        providerByPresetId[mp.preset.id] = profile.providerEnum;
      }
    }
    final activeProviders = <LLMProviderEnum>{};
    for (final domain in LlmProviderDomainEnum.values) {
      final id = settings.getAppDomainPresetId(domain);
      if (id == null || id.isEmpty) continue;
      final provider = providerByPresetId[id];
      if (provider != null) activeProviders.add(provider);
    }

    final body = IconTheme.merge(
      data: const IconThemeData(size: 20),
      child: ListTileTheme(
        data: const ListTileThemeData(dense: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wrap (not Row) so the labels don't have to truncate on narrow
            // phone widths — the second button drops to a new line instead.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _isAdding ? null : _addProvider,
                    icon: const Icon(Icons.add),
                    label: const Text('New Provider'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isAdding ? null : _addLocalProvider,
                    icon: const Icon(Icons.computer),
                    label: const Text('New Local Provider'),
                  ),
                  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android)
                    OutlinedButton.icon(
                      onPressed: _isAdding ? null : _addLocalGgufProvider,
                      icon: const Icon(Icons.memory),
                      label: const Text('New Local GGUF'),
                    ),
                  _RefreshMenuButton(
                    policy: settings.refreshPolicy,
                    lastRefreshMillis: settings.lastModelRefreshAtMillis,
                    isRefreshing: _isRefreshing,
                    onRefresh: () => unawaited(_runManualRefresh()),
                    onPolicyChanged: _setRefreshPolicy,
                  ),
                ],
              ),
            ),
            // -----------------------------------------------------------
            // Dashboard + per-provider sections. Each [AiTabSectionHeader]
            // owns its own thick top divider; 24dp gap above adds breathing
            // room before the divider lands.
            // -----------------------------------------------------------
            if (providers.any((p) => p.allPresets.isNotEmpty)) ...[
              TileDefaultModels(
                profiles: providers,
                activeProviders: activeProviders.toList(),
                onChanged: () {
                  _healAssignments();
                  unawaited(_settingsService.saveSettings());
                },
              ),
              const SizedBox(height: 24),
            ],
            if (providers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No API providers configured.')),
              )
            else
              for (final (i, p) in providers.indexed) ...[
                if (i > 0) const SizedBox(height: 24),
                TileProviderProfile(key: ObjectKey(p), profile: p, index: i),
              ],
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !_isAdding,
      child: Stack(
        children: [
          body,
          if (_isAdding)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      CircularProgressIndicator(),
                      Text(
                        'Adding provider…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefreshMenuButton extends StatelessWidget {
  const _RefreshMenuButton({
    required this.policy,
    required this.lastRefreshMillis,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onPolicyChanged,
  });
  final ModelRefreshPolicyEnum policy;
  final int? lastRefreshMillis;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final ValueChanged<ModelRefreshPolicyEnum> onPolicyChanged;

  @override
  Widget build(BuildContext context) {
    final lastLabel = lastRefreshMillis == null
        ? 'Never refreshed'
        : 'Last refreshed: ${UtilsApp.timeAgo(lastRefreshMillis)}';
    return MenuAnchor(
      builder: (context, controller, _) => TextButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: isRefreshing
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: const Text('Refresh models'),
      ),
      menuChildren: [
        MenuItemButton(
          child: Text(
            lastLabel,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.refresh),
          onPressed: onRefresh,
          child: const Text('Refresh now'),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            policy == ModelRefreshPolicyEnum.never ? Icons.check : null,
          ),
          onPressed: () => onPolicyChanged(ModelRefreshPolicyEnum.never),
          child: const Text('Auto: Never'),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            policy == ModelRefreshPolicyEnum.daily ? Icons.check : null,
          ),
          onPressed: () => onPolicyChanged(ModelRefreshPolicyEnum.daily),
          child: const Text('Auto: Daily on startup'),
        ),
      ],
    );
  }
}
