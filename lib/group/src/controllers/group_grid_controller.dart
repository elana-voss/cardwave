import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart' show Color;

/// Stateless orchestrator for the per-group grid item actions — the rename
/// pencil in the header and the popup-menu's "Delete" entry. Each method
/// returns true if it committed a change so the caller can fire its
/// `onChanged` listener; false on cancel/no-op so the listener stays silent.
class GroupGridController {
  const GroupGridController._();

  /// Opens a rename dialog for [group] and persists the new name on confirm.
  /// Returns true when the new name committed; false on cancel, empty input,
  /// or unchanged-name (no save happens in those cases).
  static Future<bool> renameGroup({
    required GroupFileService service,
    required GroupFile group,
  }) async {
    final newName = await NavigationService().showTextInputDialog(
      title: t.group.groupGridController.renameGroupTitle,
      initialText: group.group.name,
      hintText: t.group.groupGridController.groupNameHint,
      maxLines: 1,
    );
    if (newName == null) return false;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == group.group.name) return false;
    group.group.name = trimmed;
    await service.saveGroup(group);
    return true;
  }

  /// Asks the user to confirm, then deletes [group]. Returns true when the
  /// delete committed; false on cancel. [confirmColor] tints the destructive
  /// confirm button — passed in because the controller has no BuildContext
  /// access.
  static Future<bool> confirmAndDelete({
    required GroupFileService service,
    required GroupFile group,
    required Color confirmColor,
  }) async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: t.group.groupGridController.deleteGroupTitle,
      message: t.group.groupGridController.deleteGroupMessage(
        name: group.group.name,
      ),
      confirmText: t.common.actions.delete,
      confirmColor: confirmColor,
    );
    if (!confirmed) return false;
    await service.deleteGroup(group.id);
    return true;
  }
}
