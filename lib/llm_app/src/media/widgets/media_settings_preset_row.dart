// Composes [MediaSettingsGridRow] (the layout widget) with field-type-specific cells.
import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/src/media/media_settings_controller.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_cell_action.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_row_shared.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MediaSettingsPresetRow extends StatefulWidget {
  const MediaSettingsPresetRow({
    required this.field,
    required this.displayedLayers,
    required this.labelColumnWidth,
    required this.character,
    required this.chatSession,
    required this.chatPageController,
    required this.settings,
    required this.pureHelpers,
    required this.onChanged,
    super.key,
  });

  final MediaSettingsGridField field;
  final List<MediaSettingsGridLayer> displayedLayers;
  final double labelColumnWidth;
  final CharacterFile? character;
  final ChatSession? chatSession;
  final ChatPageController? chatPageController;
  final AppSettings settings;
  final LlmPureHelpers pureHelpers;
  final VoidCallback onChanged;

  @override
  State<MediaSettingsPresetRow> createState() => _MediaSettingsPresetRowState();
}

class _MediaSettingsPresetRowState extends State<MediaSettingsPresetRow> {
  @override
  Widget build(BuildContext context) {
    final domain = MediaSettingsController.domainForPresetField(widget.field);
    final profiles = widget.settings.providerConfigs;

    final appId = widget.settings.getAppDomainPresetId(domain);
    final charId = MediaSettingsController.readCharPresetId(
      widget.character,
      widget.field,
    );
    final sessId = MediaSettingsController.readSessPresetId(
      widget.chatSession,
      widget.field,
    );

    final winner = sessId != null
        ? MediaSettingsGridLayer.session
        : charId != null
        ? MediaSettingsGridLayer.character
        : appId != null
        ? MediaSettingsGridLayer.app
        : null;

    // Cache label resolution by id — `_presetLabelOrFallback` scans every
    // provider × model × preset, and the same id is read up to three times
    // per preset row (winning + cell-by-cell) when layers share an id.
    final labelsById = <String, String>{};
    String labelOfId(String id) => labelsById.putIfAbsent(
      id,
      () => _presetLabelOrFallback(profiles, id),
    );

    // Per-column display id walks only the layers below the current
    // column: app has nothing below it, character falls back to app,
    // session falls back to character then app.
    String labelForColumn(String? own, String? inherited) {
      final id = own ?? inherited;
      return id == null ? kEmptyCell : labelOfId(id);
    }

    final appCell = MediaSettingsGridCell(
      text: labelForColumn(appId, null),
      state: mediaCellStateFor(
        layer: MediaSettingsGridLayer.app,
        layerHasOwn: appId != null,
        winner: winner,
      ),
      onTap: (cellContext) => _onPresetCellTap(
        cellContext: cellContext,
        layer: MediaSettingsGridLayer.app,
        layerHasOwn: appId != null,
        profiles: profiles,
        currentLayerId: appId,
      ),
    );
    final charCell = widget.character == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(charId, appId),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charId != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onPresetCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charId != null,
              profiles: profiles,
              currentLayerId: charId,
            ),
          );
    final sessCell = widget.chatSession == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(sessId, charId ?? appId),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessId != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onPresetCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessId != null,
              profiles: profiles,
              currentLayerId: sessId,
            ),
          );

    return MediaSettingsGridRow(
      label: widget.field.label,
      layers: widget.displayedLayers,
      appCell: appCell,
      characterCell: charCell,
      sessionCell: sessCell,
      labelColumnWidth: widget.labelColumnWidth,
    );
  }

  Future<void> _onPresetCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required List<LlmProviderConfig> profiles,
    required String? currentLayerId,
  }) async {
    if (layer == MediaSettingsGridLayer.app) {
      final ok = await NavigationService().showConfirmCancelDialog(
        title: t.llmApp.presetRow.changeAppDefaultTitle,
        message: t.llmApp.presetRow.changeAppDefaultMessage,
        confirmText: t.llmApp.presetRow.continueButton,
        confirmColor: Theme.of(context).colorScheme.primary,
      );
      if (!ok || !mounted) return;
    }

    if (!layerHasOwn) {
      await _openPresetPicker(layer, profiles, null);
      return;
    }
    if (!cellContext.mounted) return;
    final action = await showMediaLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case MediaCellAction.change:
        await _openPresetPicker(layer, profiles, currentLayerId);
      case MediaCellAction.clear:
        MediaSettingsController.clearPreset(
          settingsService: context.read<SettingsService>(),
          characterService: context.read<CharacterService>(),
          field: widget.field,
          layer: layer,
          character: widget.character,
          session: widget.chatSession,
          chatPageController: widget.chatPageController,
        );
        widget.onChanged();
    }
  }

  Future<void> _openPresetPicker(
    MediaSettingsGridLayer layer,
    List<LlmProviderConfig> profiles,
    String? activePresetId,
  ) async {
    final domain = MediaSettingsController.domainForPresetField(widget.field);
    final validPresets = widget.pureHelpers.getValidPresetsForDomain(
      domain,
      profiles,
    );
    if (validPresets.isEmpty || !mounted) return;
    final pickedId = await DialogPresetPicker.show(
      context: context,
      title: Text(
        t.llmApp.presetRow.chooseModelTitle(
          domain: domain.label.toLowerCase(),
        ),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      validPresets: validPresets,
      activePresetId: activePresetId,
    );
    if (pickedId == null || !mounted) return;
    final newPreset = widget.pureHelpers.resolvePresetOrNull(
      configId: pickedId,
      providers: profiles,
    );
    if (newPreset == null) return;
    MediaSettingsController.writePreset(
      settingsService: context.read<SettingsService>(),
      characterService: context.read<CharacterService>(),
      field: widget.field,
      layer: layer,
      presetId: pickedId,
      model: newPreset.model,
      character: widget.character,
      session: widget.chatSession,
      chatPageController: widget.chatPageController,
    );
    widget.onChanged();
  }

  String _presetLabelOrFallback(
    List<LlmProviderConfig> profiles,
    String presetId,
  ) {
    final resolved = widget.pureHelpers.resolvePresetOrNull(
      configId: presetId,
      providers: profiles,
    );
    if (resolved == null) return presetId;
    return '${LlmProvider.of(resolved.provider.providerEnum).label} · '
        '${resolved.preset.name}';
  }
}
