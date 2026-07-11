import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart' show Color;

/// Stateless orchestrator for the per-character grid item action menu. Each
/// method maps to one popup-menu entry — duplicate, edit notes, dismiss
/// recent, export, delete. The widget dispatches its switch-case here so the
/// menu UI doesn't open dialogs or fire snackbars directly. Keeps
/// `CharacterGridActionMenu` purely about layout and selection wiring.
class CharacterGridController {
  const CharacterGridController._();

  /// Duplicates [file]. Logs and surfaces a snackbar on failure.
  static Future<void> duplicateAndShowError({
    required CharacterService service,
    required CharacterFile file,
  }) async {
    try {
      await service.cloneCharacter(file);
    } on Exception catch (e, st) {
      LoggingService().error(
        '[Duplicate] Failed to clone character: ${file.card.name}',
        e,
        st,
      );
      NavigationService().showSnackBar(
        t.grid.controllerMessages.duplicateFailed,
      );
    }
  }

  /// Opens a text-input dialog for the variant notes; on confirm, persists
  /// the new value through [service]. Cancel is a silent no-op.
  static Future<void> editVariantNotes({
    required CharacterService service,
    required CharacterFile file,
  }) async {
    final newNotes = await NavigationService().showTextInputDialog(
      title: t.grid.controllerMessages.editVariantNotesTitle,
      initialText: file.appCardVariantNotes,
      hintText: t.grid.controllerMessages.editVariantNotesHint,
    );
    if (newNotes == null) return;
    file.appCardVariantNotes = newNotes;
    await service.saveJsonInCacheNow(file);
  }

  /// Marks [file] as no longer "recent" by stamping the dismissal timestamp,
  /// then saves. No dialog, no snackbar — the autosave path inside
  /// `saveJsonInCacheNow` already logs failures and there is no user-actionable
  /// recovery for a failed timestamp save.
  static Future<void> dismissRecent({
    required CharacterService service,
    required CharacterFile file,
  }) async {
    file.appCardTimestampLastChattedDismissed =
        DateTime.now().millisecondsSinceEpoch;
    await service.saveJsonInCacheNow(file);
  }

  /// Exports [file] as a v2/v3-compatible PNG with embedded card data. Logs
  /// and surfaces a snackbar on failure.
  static Future<void> exportPngAndShowError({
    required CharacterService service,
    required CharacterFile file,
  }) async {
    try {
      await service.exportAsPng(file);
    } on Exception catch (e, st) {
      LoggingService().error('PNG export failed: ${file.card.name}', e, st);
      NavigationService().showSnackBar(AppConstants.exportFailedMessage);
    }
  }

  /// Exports [file] as JSON. Pass [asV2] true for the v2 schema, false
  /// (default) for v3. Logs and surfaces a snackbar on failure.
  static Future<void> exportJsonAndShowError({
    required CharacterService service,
    required CharacterFile file,
    bool asV2 = false,
  }) async {
    try {
      await service.exportAsJson(file, asV2: asV2);
    } on Exception catch (e, st) {
      final tag = asV2 ? 'V2' : 'V3';
      LoggingService().error(
        'JSON $tag export failed: ${file.card.name}',
        e,
        st,
      );
      NavigationService().showSnackBar(AppConstants.exportFailedMessage);
    }
  }

  /// Asks the user to confirm, then deletes [file]. Returns true if the
  /// delete committed (even if some sidecars failed — that surfaces as a
  /// snackbar but the card is still gone), false on cancel. [confirmColor]
  /// tints the destructive confirm button — passed in because the controller
  /// has no BuildContext access.
  static Future<bool> confirmAndDelete({
    required CharacterService service,
    required CharacterFile file,
    required Color confirmColor,
  }) async {
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: t.grid.controllerMessages.deleteCardTitle,
      message: t.grid.controllerMessages.deleteCardMessage,
      confirmText: t.common.actions.delete,
      confirmColor: confirmColor,
    );
    if (!confirmed) return false;
    try {
      await service.removeCharacterCompletely(file);
    } on Exception catch (e, st) {
      LoggingService().error(
        '[DELETE] Partial failure removing character: ${file.card.name}',
        e,
        st,
      );
      NavigationService().showSnackBar(
        t.grid.controllerMessages.deletePartialFailure,
      );
    }
    return true;
  }
}
