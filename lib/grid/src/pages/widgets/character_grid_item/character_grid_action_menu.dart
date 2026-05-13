import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/controllers/character_grid_controller.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _CharacterGridItemActionEnum {
  duplicate,
  editNotes,
  dismissRecent,
  delete,
  jsonExportV2,
  jsonExportV3,
  pngExportV2V3,
}

class CharacterGridActionMenu extends StatelessWidget {
  const CharacterGridActionMenu({
    required this.file,
    required this.variantStatus,
    required this.showVariantNotes,
    super.key,
  });
  final CharacterFile file;
  final VariantStatusEnum variantStatus;
  final bool showVariantNotes;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        final characterService = context.read<CharacterService>();

        if (value is AiActionEnum) {
          final characterAiService = context.read<CharacterAiService>();
          // Only the two global-only AI actions appear in this menu; a switch
          // over the full AiActionEnum needs a dead default: arm.
          // ignore: qcheck/prefer_switch_with_enums
          if (value == AiActionEnum.generatePreview) {
            await characterAiService.generateDescriptionPreview(file);
          } else if (value == AiActionEnum.autoTag) {
            await characterAiService.autoTagCharacter(file);
          }
          return;
        }

        final errorColor = Theme.of(context).colorScheme.error;
        switch (value as _CharacterGridItemActionEnum) {
          case _CharacterGridItemActionEnum.duplicate:
            await CharacterGridController.duplicateAndShowError(
              service: characterService,
              file: file,
            );
          case _CharacterGridItemActionEnum.editNotes:
            await CharacterGridController.editVariantNotes(
              service: characterService,
              file: file,
            );
          case _CharacterGridItemActionEnum.dismissRecent:
            await CharacterGridController.dismissRecent(
              service: characterService,
              file: file,
            );
          case _CharacterGridItemActionEnum.pngExportV2V3:
            await CharacterGridController.exportPngAndShowError(
              service: characterService,
              file: file,
            );
          case _CharacterGridItemActionEnum.jsonExportV2:
            await CharacterGridController.exportJsonAndShowError(
              service: characterService,
              file: file,
              asV2: true,
            );
          case _CharacterGridItemActionEnum.jsonExportV3:
            await CharacterGridController.exportJsonAndShowError(
              service: characterService,
              file: file,
            );
          case _CharacterGridItemActionEnum.delete:
            await CharacterGridController.confirmAndDelete(
              service: characterService,
              file: file,
              confirmColor: errorColor,
            );
        }
      },
      itemBuilder: (context) => [
        ...AiActionEnum.values
            .where((a) => a.isGlobalOnly)
            .map(
              (action) => PopupMenuItem<Object>(
                key: Key('drawer-ai-action-${action.name}'),
                value: action,
                child: Row(
                  children: [
                    Icon(
                      action.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(action.label),
                  ],
                ),
              ),
            ),

        if (variantStatus == VariantStatusEnum.original ||
            showVariantNotes ||
            file.isRecent)
          const PopupMenuDivider(),

        if (variantStatus == VariantStatusEnum.original || showVariantNotes)
          const PopupMenuItem<Object>(
            value: _CharacterGridItemActionEnum.editNotes,
            child: Row(
              children: [
                Icon(Icons.note_alt),
                SizedBox(width: 8),
                Text('Edit Notes'),
              ],
            ),
          ),
        if (file.isRecent)
          const PopupMenuItem<Object>(
            value: _CharacterGridItemActionEnum.dismissRecent,
            child: Row(
              children: [
                Icon(Icons.history_toggle_off),
                SizedBox(width: 8),
                Text('Dismiss Recent'),
              ],
            ),
          ),

        const PopupMenuDivider(),
        const PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.pngExportV2V3,
          child: Row(
            children: [
              Icon(Icons.image, size: 20),
              SizedBox(width: 8),
              Text('Export as PNG (V2/V3)'),
            ],
          ),
        ),
        const PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.jsonExportV3,
          child: Row(
            children: [
              Icon(Icons.data_object, size: 20),
              SizedBox(width: 8),
              Text('Export as JSON (V3)'),
            ],
          ),
        ),
        const PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.jsonExportV2,
          child: Row(
            children: [
              Icon(Icons.data_object, size: 20),
              SizedBox(width: 8),
              Text('Export as JSON (V2)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          value: _CharacterGridItemActionEnum.duplicate,
          child: Row(
            children: [Icon(Icons.copy), SizedBox(width: 8), Text('Duplicate')],
          ),
        ),
        PopupMenuItem<Object>(
          key: const Key('grid-item-delete'),
          value: _CharacterGridItemActionEnum.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.more_vert, size: 20),
    );
  }
}
