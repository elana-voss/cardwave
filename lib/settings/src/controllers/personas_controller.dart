import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/src/models/chat_persona.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:flutter/material.dart' show Color;

/// Stateless orchestrator for the personas list in `SettingsTabPersonas` —
/// add, edit, and delete. The widget keeps `context.watch<SettingsService>`
/// for reactive list rebuilds; everything that opens a dialog or mutates
/// settings lives here.
class PersonasController {
  const PersonasController._();

  /// Opens the persona editor for a new persona. On confirm, appends to
  /// `settings.personas` and persists. Returns true if a new persona
  /// committed, false on cancel.
  static Future<bool> addPersona({
    required SettingsService settingsService,
  }) async {
    final newPersona = await NavigationService().showPersonaEditDialog();
    if (newPersona == null) return false;
    settingsService.settings.personas.add(newPersona);
    await settingsService.saveSettings();
    return true;
  }

  /// Opens the persona editor pre-filled with [persona]. On confirm, replaces
  /// the matching entry in `settings.personas` (matched by id) and persists.
  /// Returns true if an edit committed, false on cancel.
  static Future<bool> editPersona({
    required SettingsService settingsService,
    required ChatPersona persona,
  }) async {
    final updated = await NavigationService().showPersonaEditDialog(
      persona: persona,
    );
    if (updated == null) return false;
    final index = settingsService.settings.personas.indexWhere(
      (p) => p.id == persona.id,
    );
    if (index == -1) return false;
    settingsService.settings.personas[index] = updated;
    await settingsService.saveSettings();
    return true;
  }

  /// Deletes [persona] after a confirm dialog. Refuses to delete the default
  /// persona — surfaces a snackbar instead and returns false. Returns true on
  /// confirmed delete, false on cancel or refusal. [confirmColor] tints the
  /// destructive confirm button — passed in because the controller has no
  /// `BuildContext` access.
  static Future<bool> confirmAndDelete({
    required SettingsService settingsService,
    required ChatPersona persona,
    required Color confirmColor,
  }) async {
    if (settingsService.settings.defaultPersonaId == persona.id) {
      NavigationService().showSnackBar('Cannot delete the default persona.');
      return false;
    }
    final confirmed = await NavigationService().showConfirmCancelDialog(
      title: 'Delete Persona',
      message: 'Are you sure you want to delete "${persona.name}"?',
      confirmText: 'Delete',
      confirmColor: confirmColor,
    );
    if (!confirmed) return false;
    settingsService.settings.personas.removeWhere((p) => p.id == persona.id);
    await settingsService.saveSettings();
    return true;
  }
}
