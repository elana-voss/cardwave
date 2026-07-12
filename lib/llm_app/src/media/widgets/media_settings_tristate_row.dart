// Composes [MediaSettingsGridRow] (the layout widget) with field-type-specific cells.
import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/src/media/media_settings_controller.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_row_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MediaSettingsTristateRow extends StatefulWidget {
  const MediaSettingsTristateRow({
    required this.field,
    required this.displayedLayers,
    required this.labelColumnWidth,
    required this.character,
    required this.chatSession,
    required this.chatPageController,
    required this.onChanged,
    super.key,
  });

  final MediaSettingsGridField field;
  final List<MediaSettingsGridLayer> displayedLayers;
  final double labelColumnWidth;
  final CharacterFile? character;
  final ChatSession? chatSession;
  final ChatPageController? chatPageController;
  final VoidCallback onChanged;

  @override
  State<MediaSettingsTristateRow> createState() =>
      _MediaSettingsTristateRowState();
}

class _MediaSettingsTristateRowState extends State<MediaSettingsTristateRow> {
  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final charValue = MediaSettingsController.readCharBool(
      widget.character,
      widget.field,
    );
    final sessValue = MediaSettingsController.readSessBool(
      widget.chatSession,
      widget.field,
    );

    final winner = sessValue != null
        ? MediaSettingsGridLayer.session
        : charValue != null
        ? MediaSettingsGridLayer.character
        : null;

    // App stores no tristate fields, so character's fallback is `false`
    // and session's fallback is whatever character set (or `false`).
    String labelForColumn(bool? own, bool inherited) {
      final v = own ?? inherited;
      return v ? t.llmApp.tristate.on : t.llmApp.tristate.off;
    }

    const appCell = kNotApplicableCell;
    final charCell = widget.character == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(charValue, false),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTristateCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.character,
              currentValue: charValue,
            ),
          );
    final sessCell = widget.chatSession == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: labelForColumn(sessValue, charValue ?? false),
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.session,
              layerHasOwn: sessValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTristateCellTap(
              cellContext: cellContext,
              layer: MediaSettingsGridLayer.session,
              currentValue: sessValue,
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

  Future<void> _onTristateCellTap({
    required BuildContext cellContext,
    required MediaSettingsGridLayer layer,
    required bool? currentValue,
  }) async {
    final position = mediaMenuPositionFor(cellContext);
    if (position == null) return;
    final picked = await showMenu<_TristatePick>(
      context: cellContext,
      position: position,
      items: [
        CheckedPopupMenuItem(
          value: _TristatePick.on,
          checked: currentValue == true,
          child: Text(t.llmApp.tristate.on),
        ),
        CheckedPopupMenuItem(
          value: _TristatePick.off,
          checked: currentValue == false,
          child: Text(t.llmApp.tristate.off),
        ),
        CheckedPopupMenuItem(
          value: _TristatePick.inherit,
          checked: currentValue == null,
          child: Text(t.llmApp.tristate.inherit),
        ),
      ],
    );
    if (!mounted || picked == null) return;
    MediaSettingsController.writeTristate(
      characterService: context.read<CharacterService>(),
      field: widget.field,
      layer: layer,
      value: switch (picked) {
        _TristatePick.on => true,
        _TristatePick.off => false,
        _TristatePick.inherit => null,
      },
      character: widget.character,
      session: widget.chatSession,
      chatPageController: widget.chatPageController,
    );
    widget.onChanged();
  }
}

enum _TristatePick { on, off, inherit }
