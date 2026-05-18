// Composes [MediaSettingsGridRow] (the layout widget) with field-type-specific cells.
import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/src/media/media_settings_controller.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_cell_action.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_row_shared.dart';
import 'package:cardwave/llm_app/src/models/config_media.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MediaSettingsDropdownRow extends StatefulWidget {
  const MediaSettingsDropdownRow({
    required this.field,
    required this.displayedLayers,
    required this.labelColumnWidth,
    required this.character,
    required this.chatSession,
    required this.chatPageController,
    required this.characterView,
    required this.sessionView,
    required this.onChanged,
    super.key,
  });

  final MediaSettingsGridField field;
  final List<MediaSettingsGridLayer> displayedLayers;
  final double labelColumnWidth;
  final CharacterFile? character;
  final ChatSession? chatSession;
  final ChatPageController? chatPageController;
  final ConfigMediaResolved characterView;
  final ConfigMediaResolved sessionView;
  final VoidCallback onChanged;

  @override
  State<MediaSettingsDropdownRow> createState() =>
      _MediaSettingsDropdownRowState();
}

class _MediaSettingsDropdownRowState extends State<MediaSettingsDropdownRow> {
  @override
  Widget build(BuildContext context) {
    final charValue = MediaSettingsController.readCharDropdownValue(
      widget.character,
      widget.field,
    );
    final sessValue = MediaSettingsController.readSessDropdownValue(
      widget.chatSession,
      widget.field,
    );

    final winner = sessValue != null
        ? MediaSettingsGridLayer.session
        : charValue != null
        ? MediaSettingsGridLayer.character
        : null;

    // Each column's preset comes from its own perspective view, so
    // dropdown options/labels match the model that column would apply
    // in isolation. A column without a preset at this perspective (no
    // own id and no fallback below) renders as not-applicable.
    final charPreset = _resolvedPresetFor(widget.characterView);
    final sessPreset = _resolvedPresetFor(widget.sessionView);

    String labelFromView(ConfigMediaResolved view, ResolvedPreset preset) {
      final value = _seededDropdownValue(view);
      return value == null
          ? kEmptyCell
          : _dropdownLabelFor(preset.model, value);
    }

    const appCell = kNotApplicableCell;
    final charCell = widget.character == null || charPreset == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelFromView(widget.characterView, charPreset),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onDropdownCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              currentValue: charValue,
              preset: charPreset,
            ),
          );
    final sessCell = widget.chatSession == null || sessPreset == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelFromView(widget.sessionView, sessPreset),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onDropdownCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              currentValue: sessValue,
              preset: sessPreset,
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

  Future<void> _onDropdownCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required String? currentValue,
    required ResolvedPreset preset,
  }) async {
    if (_isShortDropdown()) {
      await _openShortDropdownPopup(
        cellContext: cellContext,
        layer: layer,
        layerHasOwn: layerHasOwn,
        currentValue: currentValue,
        preset: preset,
      );
      return;
    }
    if (!layerHasOwn) {
      await _openDropdownPicker(layer, currentValue, preset);
      return;
    }
    final action = await showMediaLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case MediaCellAction.change:
        await _openDropdownPicker(layer, currentValue, preset);
      case MediaCellAction.clear:
        MediaSettingsController.clearDropdown(
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

  /// Aspect ratio, resolution, duration — short fixed lists where a
  /// popup menu (with optional Clear) replaces the dialog. TTS voice
  /// and language stay on the dialog flow because they can run to
  /// dozens of options with subtitles.
  bool _isShortDropdown() {
    return switch (widget.field) {
      MediaSettingsGridField.imageAspectRatio ||
      MediaSettingsGridField.videoResolution ||
      MediaSettingsGridField.videoAspectRatio ||
      MediaSettingsGridField.videoDuration => true,
      // Only the four short fixed-list dropdowns qualify; the wildcard
      // deliberately covers every other field — listing all thirteen here
      // would duplicate the enum and obscure the intent.
      // ignore: qcheck/avoid_wildcard_cases_with_enums
      _ => false,
    };
  }

  Future<void> _openShortDropdownPopup({
    required BuildContext cellContext,
    required MediaSettingsGridLayer layer,
    required bool layerHasOwn,
    required String? currentValue,
    required ResolvedPreset preset,
  }) async {
    final options = _dropdownOptionsFor(preset.model);
    if (options.isEmpty) return;
    final position = mediaMenuPositionFor(cellContext);
    if (position == null) return;
    final picked = await showMenu<_ShortDropdownPick>(
      context: cellContext,
      position: position,
      items: [
        for (final opt in options)
          CheckedPopupMenuItem<_ShortDropdownPick>(
            value: _ShortDropdownValue(opt.value),
            checked: opt.value == currentValue,
            child: Text(opt.label),
          ),
        if (layerHasOwn) const PopupMenuDivider(),
        if (layerHasOwn)
          const PopupMenuItem<_ShortDropdownPick>(
            value: _ShortDropdownClear(),
            child: Text('Clear'),
          ),
      ],
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case _ShortDropdownValue(:final value):
        MediaSettingsController.writeDropdown(
          characterService: context.read<CharacterService>(),
          field: widget.field,
          layer: layer,
          value: value,
          character: widget.character,
          session: widget.chatSession,
          chatPageController: widget.chatPageController,
        );
      case _ShortDropdownClear():
        MediaSettingsController.clearDropdown(
          characterService: context.read<CharacterService>(),
          field: widget.field,
          layer: layer,
          character: widget.character,
          session: widget.chatSession,
          chatPageController: widget.chatPageController,
        );
    }
    widget.onChanged();
  }

  Future<void> _openDropdownPicker(
    MediaSettingsGridLayer layer,
    String? currentValue,
    ResolvedPreset preset,
  ) async {
    final options = _dropdownOptionsFor(preset.model);
    if (options.isEmpty || !mounted) return;
    final picked = await showSelectionDialog<String>(
      context: context,
      title: widget.field.label,
      activeValue: currentValue ?? options.first.value,
      options: options,
    );
    if (picked == null || !mounted) return;
    MediaSettingsController.writeDropdown(
      characterService: context.read<CharacterService>(),
      field: widget.field,
      layer: layer,
      value: picked,
      character: widget.character,
      session: widget.chatSession,
      chatPageController: widget.chatPageController,
    );
    widget.onChanged();
  }

  ResolvedPreset? _resolvedPresetFor(ConfigMediaResolved resolved) {
    switch (widget.field) {
      case MediaSettingsGridField.imageAspectRatio:
        return resolved.imagePreset;
      case MediaSettingsGridField.videoResolution:
      case MediaSettingsGridField.videoAspectRatio:
      case MediaSettingsGridField.videoDuration:
        return resolved.videoPreset;
      case MediaSettingsGridField.ttsVoice:
      case MediaSettingsGridField.ttsLanguage:
        return resolved.ttsPreset;
      default:
        return null;
    }
  }

  String? _seededDropdownValue(ConfigMediaResolved resolved) {
    switch (widget.field) {
      case MediaSettingsGridField.imageAspectRatio:
        return resolved.imageAspectRatioId;
      case MediaSettingsGridField.videoResolution:
        return resolved.videoResolutionId;
      case MediaSettingsGridField.videoAspectRatio:
        return resolved.videoAspectRatioId;
      case MediaSettingsGridField.videoDuration:
        return resolved.videoDurationSeconds?.toString();
      case MediaSettingsGridField.ttsVoice:
        return resolved.ttsVoiceId;
      case MediaSettingsGridField.ttsLanguage:
        return resolved.ttsLanguageCode;
      default:
        return null;
    }
  }

  List<SelectionOption<String>> _dropdownOptionsFor(LlmModel model) {
    switch (widget.field) {
      case MediaSettingsGridField.imageAspectRatio:
        final aspects =
            model.optionsImage?.aspectRatios ?? const <ImageAspectRatio>[];
        return [
          for (final a in aspects)
            SelectionOption(value: a.id, label: a.label),
        ];
      case MediaSettingsGridField.videoResolution:
        final resolutions =
            model.optionsVideo?.resolutions ?? const <VideoResolution>[];
        return [
          for (final r in resolutions)
            SelectionOption(value: r.id, label: r.label),
        ];
      case MediaSettingsGridField.videoAspectRatio:
        final aspects =
            model.optionsVideo?.aspectRatios ?? const <VideoAspectRatio>[];
        return [
          for (final a in aspects)
            SelectionOption(value: a.id, label: a.label),
        ];
      case MediaSettingsGridField.videoDuration:
        final durations =
            model.optionsVideo?.durations ?? const <VideoDuration>[];
        return [
          for (final d in durations)
            SelectionOption(value: d.seconds.toString(), label: d.label),
        ];
      case MediaSettingsGridField.ttsVoice:
        final voices = model.optionsTts?.voices ?? const <TtsVoice>[];
        return [
          for (final v in voices)
            SelectionOption(value: v.id, label: v.label, subtitle: v.tone),
        ];
      case MediaSettingsGridField.ttsLanguage:
        final languages = model.optionsTts?.languages ?? const <TtsLanguage>[];
        return [
          for (final l in languages)
            SelectionOption(value: l.code, label: l.label, subtitle: l.code),
        ];
      default:
        return const [];
    }
  }

  String _dropdownLabelFor(LlmModel model, String value) {
    final options = _dropdownOptionsFor(model);
    final hit = options.where((o) => o.value == value).firstOrNull;
    return hit?.label ?? value;
  }
}

/// Result of a short-dropdown popup. Two variants so the dispatcher can
/// tell "user picked option X" from "user picked Clear" without resorting
/// to magic-string sentinels in the menu values.
sealed class _ShortDropdownPick {
  const _ShortDropdownPick();
}

final class _ShortDropdownValue extends _ShortDropdownPick {
  const _ShortDropdownValue(this.value);
  final String value;
}

final class _ShortDropdownClear extends _ShortDropdownPick {
  const _ShortDropdownClear();
}
