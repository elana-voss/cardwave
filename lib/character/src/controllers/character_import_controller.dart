import 'package:cardwave/character/src/services/character_service.dart';
import 'package:cardwave/common/common.dart';

/// Stateless orchestrator for bulk character imports. Drives the file picker
/// (via [CharacterService]), the parse-error dialog, the conflict-confirmation
/// dialog, and the per-file failure / success snackbars.
///
/// The service stays pure: it parses, categorizes, and imports — but never
/// shows UI. This controller decides which dialog/snackbar fires based on the
/// typed results the service returns.
class CharacterImportController {
  const CharacterImportController._();

  static Future<void> runBulkImport(CharacterService service) async {
    final nav = NavigationService();

    final parsed = await service.pickAndParseImportFiles();
    if (parsed == null) return;

    if (parsed.parseFailures.isNotEmpty) {
      await nav.showImportErrorsDialog(parsed.parseFailures);
    }
    if (parsed.validFiles.isEmpty) return;

    final categorized = service.categorizeImportFiles(parsed.validFiles);

    if (categorized.conflicts.isNotEmpty) {
      final conflictingNames = categorized.conflicts
          .map((f) => f.name)
          .toSet()
          .toList();
      final shouldProceed = await nav.showImportConflictsDialog(
        conflictingNames,
      );
      if (!shouldProceed) return;
    }

    final result = await service.importParsedFiles([
      ...categorized.conflicts,
      ...categorized.nonConflicts,
    ]);

    for (final fileName in result.failedFileNames) {
      nav.showSnackBar('Failed to import $fileName.');
    }
    if (result.importedCount > 0) {
      nav.showSnackBar('Imported ${result.importedCount} characters');
    }
  }
}
