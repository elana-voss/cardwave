import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/src/controllers/character_grid_controller.dart';
import 'package:cardwave/grid/src/pages/widgets/character_grid_item/variant_status_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
      onSelected: (value) {
        final characterService = context.read<CharacterService>();

        if (value is AiActionEnum) {
          final characterAiService = context.read<CharacterAiService>();
          // Only the two global-only AI actions appear in this menu; a switch
          // over the full AiActionEnum needs a dead default: arm.
          // ignore: qcheck/prefer_switch_with_enums
          if (value == AiActionEnum.generatePreview) {
            unawaited(characterAiService.generateDescriptionPreview(file));
          } else if (value == AiActionEnum.autoTag) {
            unawaited(characterAiService.autoTagCharacter(file));
          }
          return;
        }

        final errorColor = Theme.of(context).colorScheme.error;
        unawaited(() async {
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
        }());
      },
      itemBuilder: (context) => [
        ...AiActionEnum.values
            .where((a) => a.isGlobalOnly)
            .map(
              (action) => PopupMenuItem<Object>(
                key: Key('drawer-ai-action-${action.name}'),
                value: action,
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(
                      action.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
          PopupMenuItem<Object>(
            value: _CharacterGridItemActionEnum.editNotes,
            child: Row(
              spacing: 8,
              children: [
                const Icon(Icons.note_alt),
                Text(t.grid.actionMenu.editNotes),
              ],
            ),
          ),
        if (file.isRecent)
          PopupMenuItem<Object>(
            value: _CharacterGridItemActionEnum.dismissRecent,
            child: Row(
              spacing: 8,
              children: [
                const Icon(Icons.history_toggle_off),
                Text(t.grid.actionMenu.dismissRecent),
              ],
            ),
          ),

        const PopupMenuDivider(),
        PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.pngExportV2V3,
          child: Row(
            spacing: 8,
            children: [
              const Icon(Icons.image, size: 20),
              Text(t.grid.actionMenu.exportPngV2V3),
            ],
          ),
        ),
        PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.jsonExportV3,
          child: Row(
            spacing: 8,
            children: [
              const Icon(Icons.data_object, size: 20),
              Text(t.grid.actionMenu.exportJsonV3),
            ],
          ),
        ),
        PopupMenuItem<_CharacterGridItemActionEnum>(
          value: _CharacterGridItemActionEnum.jsonExportV2,
          child: Row(
            spacing: 8,
            children: [
              const Icon(Icons.data_object, size: 20),
              Text(t.grid.actionMenu.exportJsonV2),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _CharacterGridItemActionEnum.duplicate,
          child: Row(
            spacing: 8,
            children: [const Icon(Icons.copy), Text(t.grid.actionMenu.duplicate)],
          ),
        ),
        PopupMenuItem<Object>(
          key: const Key('grid-item-delete'),
          value: _CharacterGridItemActionEnum.delete,
          child: Row(
            spacing: 8,
            children: [
              Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              Text(
                t.common.actions.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.more_vert, size: 20),
    );
  }
}
