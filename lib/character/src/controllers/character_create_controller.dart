import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/services/character_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Stateless orchestrator for the "create new character" flow. Drives the
/// platform-specific entry point (a save-as picker on desktop Windows; a
/// name-input dialog elsewhere), the validation/retry loop, and the failure
/// snackbar. The service stays pure: it validates paths, parses them, and
/// creates files — but never opens dialogs.
class CharacterCreateController {
  const CharacterCreateController._();

  static Future<CharacterFile?> runInteractive(CharacterService service) {
    final isDesktopWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    if (isDesktopWindows) {
      return _runDesktopWindows(service);
    }
    return _runWithNameDialog(service);
  }

  /// Desktop-Windows path: full save-as picker with a retry loop on either
  /// invalid-location or creation failure.
  static Future<CharacterFile?> _runDesktopWindows(
    CharacterService service,
  ) async {
    final nav = NavigationService();
    final logging = LoggingService();
    const typeGroup = XTypeGroup(label: 'PNG Images', extensions: ['png']);

    while (true) {
      final pick = await getSaveLocation(
        initialDirectory: service.cardRootPath,
        suggestedName: 'New Character.png',
        acceptedTypeGroups: [typeGroup],
      );
      if (pick == null) return null;

      final invalidReason = service.validateCharacterSavePath(pick.path);
      if (invalidReason != null) {
        final tryAgain = await nav.showTryAgainDialog(
          title: 'Invalid Location',
          content: invalidReason,
        );
        if (tryAgain) continue;
        return null;
      }

      final parsed = service.parseCharacterSavePath(pick.path);
      try {
        return await service.createCharacterAt(
          name: parsed.name,
          targetDirectory: parsed.targetDirectory,
        );
      } on Exception catch (e, stackTrace) {
        logging.error('Character creation failed', e, stackTrace);
        final tryAgain = await nav.showTryAgainDialog(
          title: 'Creation Failed',
          content: 'Could not create the character. Check logs for details.',
        );
        if (tryAgain) continue;
        return null;
      }
    }
  }

  /// Non-desktop-Windows path: ask for a name via the standard dialog. No
  /// retry loop — a single failure surfaces a snackbar and returns null.
  static Future<CharacterFile?> _runWithNameDialog(
    CharacterService service,
  ) async {
    final nav = NavigationService();
    final name = await nav.showCreateCharacterDialog();
    if (name == null) return null;

    try {
      return await service.createCharacterAt(name: name);
    } on Exception catch (e, stackTrace) {
      LoggingService().error('Character creation failed', e, stackTrace);
      nav.showSnackBar(
        'Could not create the character. Check logs for details.',
      );
      return null;
    }
  }
}
