import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/controllers/providers_controller.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai.dart'
    show SettingsTabAi;
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_tts.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_video.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/ai_tab_section_header.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/domain_pill.dart';
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
  /// `LlmPresetConfig.id` of the row whose domain-assignment chips are
  /// currently revealed. `null` = all rows collapsed.
  String? _expandedPresetId;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final presets = widget.profile.allModelPresets.toList();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AiTabSectionHeader(
          title: widget.profile.displayLabel,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _resetDomainsToDefaults,
                child: Text(t.settings.aiTab.setDefaultButton),
              ),
              TextButton(
                onPressed: _openPresetEditor,
                child: Text(t.settings.aiTab.addModelButton),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit, size: 18),
                    onPressed: _editProfile,
                    child: Text(t.settings.aiTab.editProviderMenuItem),
                  ),
                ],
                builder: (_, controller, _) => IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: t.settings.aiTab.moreTooltip,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              t.settings.aiTab.noModelsForProvider,
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
              isExpanded: _expandedPresetId == mp.preset.id,
              onToggleExpanded: () => setState(() {
                _expandedPresetId = _expandedPresetId == mp.preset.id
                    ? null
                    : mp.preset.id;
              }),
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
    final providerLabel = widget.profile.displayLabel;
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: t.settings.aiTab.setDefaultConfirmTitle(provider: providerLabel),
      message: t.settings.aiTab.setDefaultConfirmMessage,
      confirmText: t.settings.aiTab.setDefaultButton,
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
/// row toggles the FilterChip strip beneath it via the parent's
/// `_expandedPresetId` so only one strip shows at a time. Capable-but-
/// not-assigned pills filtered out of the title so stale assignments
/// (model lost a capability) don't render misleading badges.
class _PresetInventoryRow extends StatefulWidget {
  const _PresetInventoryRow({
    required this.profile,
    required this.model,
    required this.preset,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onEditPreset,
    super.key,
  });
  final LlmProviderConfig profile;
  final LlmModel model;
  final LlmPresetConfig preset;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onEditPreset;

  @override
  State<_PresetInventoryRow> createState() => _PresetInventoryRowState();
}

class _PresetInventoryRowState extends State<_PresetInventoryRow> {
  // App-scope stateless helper — read once and cache so the build path
  // doesn't trip the avoid_read_inside_build lint.
  late final LlmPureHelpers _llm;

  @override
  void initState() {
    super.initState();
    _llm = context.read<LlmPureHelpers>();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final service = context.watch<SettingsService>();
    final settings = service.settings;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7);

    final capableDomains = [
      for (final d in LlmProviderDomainEnum.values)
        if (_llm.canServeDomain(widget.model, d)) d,
    ];
    final assignedDomains = [
      for (final d in capableDomains)
        if (settings.getAppDomainPresetId(d) == widget.preset.id) d,
    ];
    final metaLine =
        _localGgufSubtitle(widget.profile, widget.model) ??
        <String>[
          widget.model.contextLabel,
          ?widget.model.priceLabel,
        ].join(' · ');
    // Temperature is the per-preset knob users most often tune to tell
    // two presets of the same model apart, so it gets a primary-colored
    // semibold tail on the subtitle. Hidden when the preset uses the
    // resolver default (nothing for the user to distinguish on yet).
    final temperature =
        widget.preset.parameterValues[LlmParameterDefinitionIdEnum.temperature];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          onTap: capableDomains.isEmpty ? null : widget.onToggleExpanded,
          title: Row(
            spacing: 6,
            children: [
              if (widget.model.isUnavailable) const BadgeModelUnavailable(),
              Flexible(
                child: Text(widget.model.name, overflow: TextOverflow.ellipsis),
              ),
              for (final d in assignedDomains) DomainPill(domain: d),
            ],
          ),
          subtitle: Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              children: [
                TextSpan(text: metaLine),
                if (temperature != null) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: t.settings.aiTab.temperatureLabel(
                      value: temperature.toStringAsFixed(1),
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButtonTestTts(profile: widget.profile, model: widget.model),
              ButtonTestVideo(profile: widget.profile, model: widget.model),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                tooltip: t.settings.aiTab.editModelTooltip,
                onPressed: widget.onEditPreset,
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: widget.isExpanded && capableDomains.isNotEmpty
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final domain in capableDomains)
                  FilterChip(
                    label: Text(domain.label),
                    selected:
                        settings.getAppDomainPresetId(domain) ==
                        widget.preset.id,
                    onSelected: (on) => service.setDomainPreset(
                      domain,
                      on ? widget.preset.id : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Builds the meta line for a local-GGUF inventory row: `<loaded> ctx
/// (max <native>) · KV <type>`. The native cap comes from the GGUF
/// metadata via [LlmModel.contextLength]; the loaded value and KV
/// quantization live on the profile. Returns null for any other
/// provider type so the default `contextLabel · priceLabel` line shows.
String? _localGgufSubtitle(LlmProviderConfig profile, LlmModel model) {
  if (profile.providerEnum != LLMProviderEnum.localGguf) return null;
  final loaded = profile.contextSize;
  if (loaded == null) return null;
  final native = model.contextLength;
  final nativeLabel = native >= 1000 ? '${native ~/ 1000}k' : '$native';
  final kv = profile.kvCacheType;
  final kvLabel = kv == null ? 'fp16' : kv.name;
  return t.settings.aiTab.localGgufSubtitle(
    loaded: loaded,
    native: nativeLabel,
    kv: kvLabel,
  );
}

