// Composes [MediaSettingsGridRow] (the layout widget) with field-type-specific cells.
import 'package:cardwave/character/character.dart';
import 'package:cardwave/llm_app/src/media/media_settings_controller.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_row.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_row_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MediaSettingsTextRow extends StatefulWidget {
  const MediaSettingsTextRow({
    required this.field,
    required this.displayedLayers,
    required this.labelColumnWidth,
    required this.character,
    required this.onChanged,
    super.key,
  });

  final MediaSettingsGridField field;
  final List<MediaSettingsGridLayer> displayedLayers;
  final double labelColumnWidth;
  final CharacterFile? character;
  final VoidCallback onChanged;

  @override
  State<MediaSettingsTextRow> createState() => _MediaSettingsTextRowState();
}

class _MediaSettingsTextRowState extends State<MediaSettingsTextRow> {
  // Character-only field — app and session columns render as not-applicable
  // because the prompt prefix is character-ship persona flavour, with no
  // app-default or per-chat override semantics (see `ConfigMediaCharacter`
  // doc).
  @override
  Widget build(BuildContext context) {
    final charValue = MediaSettingsController.readCharPromptPrefix(
      widget.character,
      widget.field,
    );
    final winner = charValue != null ? MediaSettingsGridLayer.character : null;

    final charCell = widget.character == null
        ? kNotApplicableCell
        : MediaSettingsGridCell(
            text: charValue ?? kEmptyCell,
            state: mediaCellStateFor(
              layer: MediaSettingsGridLayer.character,
              layerHasOwn: charValue != null,
              winner: winner,
            ),
            onTap: (cellContext) => _onTextCellTap(
              cellContext: cellContext,
              currentValue: charValue,
            ),
          );

    return MediaSettingsGridRow(
      label: widget.field.label,
      layers: widget.displayedLayers,
      appCell: kNotApplicableCell,
      characterCell: charCell,
      sessionCell: kNotApplicableCell,
      labelColumnWidth: widget.labelColumnWidth,
    );
  }

  Future<void> _onTextCellTap({
    required BuildContext cellContext,
    required String? currentValue,
  }) async {
    if (currentValue == null) {
      await _openTextPrefixDialog(null);
      return;
    }
    final action = await showMediaLayeredCellActionMenu(cellContext);
    if (action == null || !mounted) return;
    switch (action) {
      case MediaCellAction.change:
        await _openTextPrefixDialog(currentValue);
      case MediaCellAction.clear:
        MediaSettingsController.writePromptPrefix(
          characterService: context.read<CharacterService>(),
          field: widget.field,
          value: null,
          character: widget.character,
        );
        widget.onChanged();
    }
  }

  Future<void> _openTextPrefixDialog(String? currentValue) async {
    final result = await showCharacterPromptPrefixDialog(
      context,
      domain: MediaSettingsController.domainForTextField(widget.field),
      currentValue: currentValue,
    );
    if (result == null || !mounted) return;
    MediaSettingsController.writePromptPrefix(
      characterService: context.read<CharacterService>(),
      field: widget.field,
      value: result,
      character: widget.character,
    );
    widget.onChanged();
  }
}
