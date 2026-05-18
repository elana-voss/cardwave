import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/controllers/providers_controller.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai.dart'
    show SettingsTabAi;
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_tts.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_video.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/domain_pill.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/ai_tab_section_header.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_domain_model.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One provider section inside [SettingsTabAi]'s list. Renders a section
/// header band (provider name + Make-default / Add-Model / overflow menu)
/// followed by one inventory row per adopted (model, preset). Tapping a
/// row opens an inline checkbox menu for assigning that preset to one or
/// more domains — the menu replaces the older dialog round-trip.
class TileProviderProfile extends StatefulWidget {
  const TileProviderProfile({
    required this.profile,
    required this.index,
    super.key,
  });
  final LlmProviderConfig profile;
  final int index;

  @override
  State<TileProviderProfile> createState() => _TileProviderProfileState();
}

class _TileProviderProfileState extends State<TileProviderProfile> {
  @override
  Widget build(BuildContext context) {
    final presets = widget.profile.allModelPresets.toList();
    final settings = context.watch<SettingsService>().settings;
    final domainsByPresetId = <String, List<LlmProviderDomainEnum>>{};

    for (final domain in LlmProviderDomainEnum.values) {
      final id = settings.getAppDomainPresetId(domain);
      if (id == null || id.isEmpty) continue;
      domainsByPresetId.putIfAbsent(id, () => []).add(domain);
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiTabSectionHeader(
          title: LlmProvider.of(widget.profile.providerEnum).label,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _resetDomainsToDefaults,
                child: const Text('Set default'),
              ),
              TextButton(
                onPressed: _openPresetEditor,
                child: const Text('Add Model'),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit, size: 18),
                    onPressed: _editProfile,
                    child: const Text('Edit provider'),
                  ),
                ],
                builder: (_, controller, _) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More',
                  onPressed: () =>
                      controller.isOpen ? controller.close() : controller.open(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        if (presets.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'No Models configured for this provider.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final mp in presets)
            _PresetInventoryRow(
              key: ValueKey(mp.preset.id),
              profile: widget.profile,
              model: mp.model,
              preset: mp.preset,
              assignedDomains: domainsByPresetId[mp.preset.id] ?? const [],
              onEditPreset: () => _openPresetEditor(
                existingModel: mp.model,
                config: mp.preset,
              ),
            ),
      ],
    );
  }

  Future<void> _editProfile() async {
    await ProvidersController.editProvider(
      settingsService: context.read<SettingsService>(),
      mgmt: context.read<LlmManagementService>(),
      profile: widget.profile,
      index: widget.index,
    );
  }

  Future<void> _openPresetEditor({
    LlmModel? existingModel,
    LlmPresetConfig? config,
  }) async {
    final settingsService = context.read<SettingsService>();
    final pureHelpers = context.read<LlmPureHelpers>();
    final mgmt = context.read<LlmManagementService>();
    final activeDomains = <LlmProviderDomainEnum>{};
    if (config != null) {
      for (final d in LlmProviderDomainEnum.values) {
        if (settingsService.settings.getAppDomainPresetId(d) == config.id) {
          activeDomains.add(d);
        }
      }
    }
    final result = await NavigationService().showPresetConfigDialog(
      configuration: config,
      connectionProfile: widget.profile,
      initialModel: existingModel,
      activeDomains: activeDomains,
    );
    if (result == null || !mounted) return;
    mgmt.applyPresetEdit(
      provider: widget.profile,
      targetModel: result.model,
      preset: result.preset,
      previousModel: existingModel,
      previousPreset: config,
    );
    if (config == null) {
      for (final d in LlmProviderDomainEnum.values) {
        if (!pureHelpers.canServeDomain(result.model, d)) continue;
        if (settingsService.settings.getAppDomainPresetId(d) == null) {
          settingsService.settings.setAppDomainPresetId(d, result.preset.id);
        }
      }
    }
    _healAndSave();
  }

  void _healAndSave() {
    final settings = context.read<SettingsService>();
    final mgmt = context.read<LlmManagementService>();
    mgmt.healDomainAssignments(settings: settings.settings);
    unawaited(settings.saveSettings());
  }

  Future<void> _resetDomainsToDefaults() async {
    final providerLabel = LlmProvider.of(widget.profile.providerEnum).label;
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Set $providerLabel as the default for every AI feature?',
      message:
          'You may pick models for unsupported features\n(like image or video) from other providers yourself.',
      confirmText: 'Set default',
      confirmColor: Theme.of(context).colorScheme.primary,
    );
    if (!confirmed || !mounted) return;
    final settings = context.read<SettingsService>();
    final mgmt = context.read<LlmManagementService>();
    mgmt.resetDomainsToProviderDefaults(
      settings: settings.settings,
      profile: widget.profile,
    );
    await settings.saveSettings();
  }
}

/// Inventory row for one (model, preset) under a provider. Tapping the
/// row opens a `MenuAnchor` with one checkbox per domain so the user can
/// assign/unassign this preset without leaving the page. Capability-gated
/// rows are disabled. Owns its own [MenuController] so each row's menu
/// closes independently.
class _PresetInventoryRow extends StatefulWidget {
  const _PresetInventoryRow({
    required this.profile,
    required this.model,
    required this.preset,
    required this.assignedDomains,
    required this.onEditPreset,
    super.key,
  });
  final LlmProviderConfig profile;
  final LlmModel model;
  final LlmPresetConfig preset;
  final List<LlmProviderDomainEnum> assignedDomains;
  final VoidCallback onEditPreset;

  @override
  State<_PresetInventoryRow> createState() => _PresetInventoryRowState();
}

class _PresetInventoryRowState extends State<_PresetInventoryRow> {
  final MenuController _menuController = MenuController();

  // Stateless helper provided once at app scope — grab it here rather
  // than re-reading it from `context` on every build.
  late final LlmPureHelpers _llm;

  @override
  void initState() {
    super.initState();
    _llm = context.read<LlmPureHelpers>();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SettingsService>();
    final settings = service.settings;

    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        for (final domain in LlmProviderDomainEnum.values)
          _DomainCheckboxItem(
            domain: domain,
            capable: _llm.canServeDomain(widget.model, domain),
            isAssigned:
                settings.getAppDomainPresetId(domain) == widget.preset.id,
            onToggle: (on) =>
                service.setDomainPreset(domain, on ? widget.preset.id : null),
          ),
      ],
      child: TileDomainModel(
        leading: widget.assignedDomains.isEmpty
            ? null
            : _DomainPillsColumn(domains: widget.assignedDomains),
        model: widget.model,
        onTap: () => _menuController.isOpen
            ? _menuController.close()
            : _menuController.open(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButtonTestTts(profile: widget.profile, model: widget.model),
            ButtonTestVideo(profile: widget.profile, model: widget.model),
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              tooltip: 'Edit Model',
              onPressed: widget.onEditPreset,
            ),
          ],
        ),
      ),
    );
  }

}

class _DomainCheckboxItem extends StatelessWidget {
  const _DomainCheckboxItem({
    required this.domain,
    required this.capable,
    required this.isAssigned,
    required this.onToggle,
  });
  final LlmProviderDomainEnum domain;
  final bool capable;
  final bool isAssigned;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxMenuButton(
      value: isAssigned,
      closeOnActivate: false,
      onChanged: capable ? (v) => onToggle(v ?? false) : null,
      child: Text(domain.label),
    );
  }
}

/// Vertical stack of [DomainPill] chips fitting inside the 80px label
/// column. One pill per assigned domain; if the list is empty the row
/// passes `null` so the column reserves its width without rendering a
/// placeholder chip.
class _DomainPillsColumn extends StatelessWidget {
  const _DomainPillsColumn({required this.domains});
  final List<LlmProviderDomainEnum> domains;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in domains)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: DomainPill(domain: d),
          ),
      ],
    );
  }
}
