import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/src/utils/logging_service.dart';
import 'package:cardwave/common/src/widgets/ai_action_enum.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Wand button hosted next to a text field. Runs proofread / compact /
/// translate on the field's current text, opens the diff dialog, then
/// hands the user-accepted text back to the owning widget via [onApply].
///
/// Ownership is inverted on purpose: the popup never holds a reference to
/// a `TextEditingController` it doesn't own. The owner provides
/// [currentText] (called at click time so live edits aren't lost) and
/// [onApply] (which owns the lifecycle check and the write). Use
/// [aiPopupApply] from a `State` to build a safe [onApply] in one line.
class AiActionTextfieldPopup extends StatelessWidget {
  const AiActionTextfieldPopup({
    required this.currentText,
    required this.onApply,
    required this.fieldName,
    required this.contextCard,
    super.key,
  });

  /// Read at click time inside `onSelected`. Passing a getter (rather than
  /// a captured String) preserves the original "see what's actually in the
  /// field right now" behaviour, including text the user typed since the
  /// owner's last build.
  final ValueGetter<String> currentText;

  /// Called with the user-accepted text on a successful diff confirm. The
  /// owner is responsible for any `mounted`/lifecycle check before
  /// writing — see [aiPopupApply].
  final ValueChanged<String> onApply;

  final String fieldName;
  final CharacterCardV3 contextCard;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AiActionEnum>(
      icon: Icon(
        Icons.auto_awesome,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: t.common.aiActionsTooltip,
      onSelected: (action) {
        final service = context.read<CharacterAiService>();
        unawaited(() async {
          final newText = await AiActionController.runAndConfirmTextAction(
            service: service,
            action: action,
            currentText: currentText(),
            fieldName: fieldName,
            contextCard: contextCard,
          );
          if (newText != null) onApply(newText);
        }());
      },
      itemBuilder: (context) {
        return AiActionEnum.values.where((a) => !a.isGlobalOnly).map((action) {
          return PopupMenuItem<AiActionEnum>(
            value: action,
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Text(action.label),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

/// Builds an [AiActionTextfieldPopup.onApply] callback that writes the
/// AI-suggested text into [controller] only when [state] is still mounted.
///
/// `state.mounted` flips false in the same `dispose()` body that disposes
/// the controller, so this check is safe in a way that the popup's own
/// `BuildContext.mounted` is not.
///
/// In debug builds an assertion fires loudly with [fieldName] in the
/// message so the cause is obvious. In release builds the assertion is
/// stripped and we log a warning instead — the drop stays observable in
/// the in-app log viewer without crashing the user.
ValueChanged<String> aiPopupApply(
  State state,
  TextEditingController controller,
  String fieldName,
) {
  return (newText) {
    if (!state.mounted) {
      // Intentional tripwire — fires loudly in debug when a State is disposed
      // mid-AI-flow so the cause can be investigated; in release it just logs.
      // ignore: qcheck/avoid_constant_assert_conditions
      assert(false, '$fieldName: AI write dropped — State disposed mid-flow');
      LoggingService().warning(
        '$fieldName: AI write dropped — State disposed mid-flow',
      );
      return;
    }
    if (newText != controller.text) {
      controller.text = newText;
    }
  };
}
