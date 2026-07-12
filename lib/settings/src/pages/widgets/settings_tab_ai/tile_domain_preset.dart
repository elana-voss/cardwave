import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_tts.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/button_test_video.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/dialog_preset_picker.dart';
import 'package:cardwave/settings/src/pages/widgets/settings_tab_ai/tile_domain_model.dart';
import 'package:cardwave/settings/src/services/llm_management_service.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row inside the "Default Models" dashboard. Leading column shows
/// the domain label as small-caps text (e.g. "CHAT") — distinct from the
/// filled chips used in the inventory section so the two never read as
/// the same affordance. Tap swaps presets via [DialogPresetPicker]; gear
/// icon edits the active preset's config via [DialogPresetConfig]. When
/// [domain] is null, lists every preset across all providers (used by
/// the overview section, not tied to any specific task assignment).
class TileDomainPreset extends StatelessWidget {
  const TileDomainPreset({
    required this.domain,
    required this.profiles,
    required this.onChanged,
    super.key,
  });
  final LlmProviderDomainEnum? domain;
  final List<LlmProviderConfig> profiles;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final d = domain;
    final validPresets = _resolveValidPresets(context);
    final activePresetId = _resolveActivePresetId(context);
    final activeEntry = validPresets
        .where((e) => e.config.id == activePresetId)
        .firstOrNull;

    final trailing = activeEntry == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d == LlmProviderDomainEnum.audioTts)
                ButtonTestTts(
                  profile: activeEntry.profile,
                  model: activeEntry.model,
                ),
              if (d == LlmProviderDomainEnum.video)
                ButtonTestVideo(
                  profile: activeEntry.profile,
                  model: activeEntry.model,
                ),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                tooltip: t.settings.aiTab.editModelTooltip,
                onPressed: () => _editActivePreset(context, activeEntry),
              ),
            ],
          );

    return TileDomainModel(
      leading: d != null ? _DomainTextLabel(domain: d) : null,
      model: activeEntry?.model,
      preset: activeEntry?.config,
      placeholderTitle: validPresets.isEmpty
          ? (d == null
                ? t.settings.aiTab.noModelsPlaceholder
                : t.settings.aiTab.noCompatibleModelsPlaceholder)
          : t.settings.aiTab.tapToChoosePlaceholder,
      onTap: activeEntry == null && validPresets.isEmpty
          ? null
          : () => _openPicker(context, validPresets, activePresetId),
      trailing: trailing,
    );
  }

  Future<void> _editActivePreset(
    BuildContext context,
    ({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})
    activeEntry,
  ) async {
    final d = domain;
    final result = await NavigationService().showPresetConfigDialog(
      configuration: activeEntry.config,
      connectionProfile: activeEntry.profile,
      initialModel: activeEntry.model,
      activeDomains: d != null ? {d} : <LlmProviderDomainEnum>{},
    );
    if (result == null || !context.mounted) return;
    context.read<LlmManagementService>().applyPresetEdit(
      provider: activeEntry.profile,
      targetModel: result.model,
      preset: result.preset,
      previousModel: activeEntry.model,
      previousPreset: activeEntry.config,
    );
    onChanged();
  }

  List<({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})>
  _resolveValidPresets(BuildContext context) {
    final d = domain;
    if (d != null) {
      return context.read<LlmPureHelpers>().getValidPresetsForDomain(
        d,
        profiles,
      );
    }
    return [
      for (final profile in profiles)
        for (final model in profile.models)
          for (final preset in model.presets)
            (profile: profile, model: model, config: preset),
    ];
  }

  String? _resolveActivePresetId(BuildContext context) {
    final d = domain;
    if (d == null) return null;
    return context.read<SettingsService>().settings.getAppDomainPresetId(d);
  }

  Future<void> _openPicker(
    BuildContext context,
    List<({LlmProviderConfig profile, LlmModel model, LlmPresetConfig config})>
    validPresets,
    String? activePresetId,
  ) async {
    final settingsService = context.read<SettingsService>();
    final mgmt = context.read<LlmManagementService>();
    final d = domain;
    final theme = Theme.of(context);
    final pickedId = await DialogPresetPicker.show(
      context: context,
      title: d != null
          ? Text.rich(
              TextSpan(
                style: theme.textTheme.titleLarge,
                children: [
                  TextSpan(text: t.settings.aiTab.modelUsedForPrefix),
                  TextSpan(
                    text: d.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  TextSpan(text: t.settings.aiTab.modelUsedForSuffix),
                ],
              ),
            )
          : Text(
              t.settings.aiTab.chooseModelTitle,
              style: theme.textTheme.titleLarge,
            ),
      validPresets: validPresets,
      activePresetId: activePresetId,
    );
    if (pickedId == null) return;
    if (d != null) {
      mgmt.assignDomainPreset(
        settings: settingsService.settings,
        domain: d,
        presetId: pickedId,
      );
    }
    onChanged();
  }
}

/// Plain small-caps domain label used in dashboard rows. Visually distinct
/// from [DomainPill] (filled chip) so the same column position carries
/// only one meaning per surface: text = "this row IS this slot",
/// chip = "this preset is currently used here".
class _DomainTextLabel extends StatelessWidget {
  const _DomainTextLabel({required this.domain});
  final LlmProviderDomainEnum domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        domain.label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
