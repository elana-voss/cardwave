import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_cell_action.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_cell.dart';
import 'package:cardwave/llm_app/src/media/widgets/media_settings_grid_field_enum.dart';
import 'package:cardwave/llm_app/src/models/config_media.dart';
import 'package:flutter/material.dart';

const String kEmptyCell = '—';

/// Single shared "—" cell for layers that aren't applicable in the current
/// focus mode (e.g. character column in `appOnly`) or for app-layer cells
/// in dropdown/tristate rows (those fields don't exist at app layer).
const MediaSettingsGridCell kNotApplicableCell = MediaSettingsGridCell(
  text: kEmptyCell,
  state: MediaSettingsGridCellState.notApplicable,
  onTap: null,
);

MediaSettingsGridCellState mediaCellStateFor({
  required MediaSettingsGridLayer layer,
  required bool layerHasOwn,
  required MediaSettingsGridLayer? winner,
}) {
  if (winner == layer) return MediaSettingsGridCellState.winning;
  if (layerHasOwn) return MediaSettingsGridCellState.overridden;
  return MediaSettingsGridCellState.inheriting;
}

/// Anchors any popup menu to the cell that was tapped. Mirrors how
/// `PopupMenuButton` computes its own position — overlay-relative rect
/// of the trigger widget.
RelativeRect? mediaMenuPositionFor(BuildContext cellContext) {
  final cellBox = cellContext.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(cellContext).context.findRenderObject() as RenderBox?;
  if (cellBox == null || overlay == null) return null;
  return RelativeRect.fromRect(
    Rect.fromPoints(
      cellBox.localToGlobal(Offset.zero, ancestor: overlay),
      cellBox.localToGlobal(
        cellBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
}

Future<MediaCellAction?> showMediaLayeredCellActionMenu(
  BuildContext cellContext,
) async {
  final position = mediaMenuPositionFor(cellContext);
  if (position == null) return null;
  return showMenu<MediaCellAction>(
    context: cellContext,
    position: position,
    items: [
      PopupMenuItem(
        value: MediaCellAction.change,
        child: Text(t.llmApp.mediaCellMenu.change),
      ),
      PopupMenuItem(
        value: MediaCellAction.clear,
        child: Text(t.llmApp.mediaCellMenu.clear),
      ),
    ],
  );
}

void ensureCharacterConfigMedia(CharacterFile character) {
  character.configMedia ??= ConfigMediaCharacter();
}

void ensureSessionConfigMedia(ChatSession session) {
  session.configMedia ??= ConfigMediaSession();
}
