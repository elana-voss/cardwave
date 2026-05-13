import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_file.dart';
import 'package:cardwave/character/src/services/character_ai_service.dart';
import 'package:cardwave/common/common.dart';

class AiActionController {
  const AiActionController._();

  /// Runs a local (text-field-level) AI action, shows progress + diff dialogs,
  /// and returns the suggested text if the user confirmed. Returns null on
  /// empty input, no proposal, cancel, or error.
  static Future<String?> runAndConfirmTextAction({
    required CharacterAiService service,
    required AiActionEnum action,
    required String currentText,
    required String fieldName,
    required CharacterCardV3 contextCard,
  }) async {
    if (currentText.trim().isEmpty) return null;

    final nav = NavigationService();
    final logging = LoggingService();

    String? suggestedText;
    try {
      await nav.runWithProgressDialog(
        title: action.label,
        onCancel: service.cancelAllActiveAiTasks,
        task: (handle) async {
          suggestedText = await service.getLocalAiTextProposal(
            action: action,
            currentText: currentText,
            fieldName: fieldName,
            contextCard: contextCard,
          );
          // The user can press Cancel between when the LLM call returns
          // and when the success window closes (or even during the call —
          // HTTP requests aren't cancellable). Discarding the result here
          // means the controller's null check below short-circuits the
          // diff dialog instead of asking the user to confirm changes
          // they already cancelled.
          if (handle.isCancelled) suggestedText = null;
        },
      );

      if (suggestedText == null) return null;

      final shouldApply = await nav.showAiDiffConfirmationDialog(
        originalText: currentText,
        suggestedText: suggestedText!,
      );
      return shouldApply == true ? suggestedText : null;
    } on AiCancelledException {
      logging.info('[LOCAL AI ACTION] Cancelled');
      return null;
    } on Exception catch (e, st) {
      logging.error(
        '[AI ACTION] Failed to execute local ${action.label}',
        e,
        st,
      );
      nav.showSnackBar('AI Action failed. Check logs for details.');
      return null;
    }
  }

  /// Runs a per-character [operation] over [targets] inside a progress dialog.
  /// Per-file errors are logged and the loop continues. Empty [targets] surface
  /// [emptyMessage] as a snackbar without opening a dialog.
  static Future<void> runCharacterBatchAndShow({
    required String title,
    required String emptyMessage,
    required List<CharacterFile> targets,
    required Future<void> Function(CharacterFile) operation,
    required void Function() onCancel,
    String batchLogTag = 'Batch',
  }) async {
    final nav = NavigationService();
    if (targets.isEmpty) {
      nav.showSnackBar(emptyMessage);
      return;
    }

    final logging = LoggingService();
    final startTime = DateTime.now();

    await nav.runWithProgressDialog<void>(
      title: title,
      onCancel: onCancel,
      task: (handle) async {
        for (var i = 0; i < targets.length; i++) {
          if (handle.isCancelled) break;
          final file = targets[i];
          handle.update(
            progressValue: i / targets.length,
            messageValue:
                'Processing ${file.card.name} (${i + 1}/${targets.length})...${_etaString(startTime, i, targets.length)}',
          );
          try {
            await operation(file);
          } on Exception catch (e, st) {
            logging.error(
              '[$batchLogTag] Error for ${file.card.name}: $e',
              e,
              st,
            );
          }
        }
      },
    );
  }

  static String _etaString(DateTime startTime, int currentIndex, int total) {
    if (currentIndex == 0) return '';
    final elapsed = DateTime.now().difference(startTime);
    final msPerItem = elapsed.inMilliseconds / currentIndex;
    final remainingMs = (total - currentIndex) * msPerItem;
    final d = Duration(milliseconds: remainingMs.toInt());
    if (d.inHours > 0) return ' ETA: ${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return ' ETA: ${d.inMinutes}m ${d.inSeconds % 60}s';
    return ' ETA: ${d.inSeconds}s';
  }
}
