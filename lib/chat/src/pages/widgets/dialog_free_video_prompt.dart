import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Collects a free-form subject for video generation. Returns the trimmed
/// string or `null` if cancelled. Copy is deliberately motion-oriented so
/// the user writes "cyberpunk girl smiling in neon rain" rather than a
/// static pose — video models need motion cues to produce something worth
/// watching.
class DialogFreeVideoPrompt {
  const DialogFreeVideoPrompt._();

  static Future<String?> show(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AppDialog(
            builder: (ctx, isMobile) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.chat.freeVideoPromptDialog.title,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.chat.freeVideoPromptDialog.description,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFieldAutotrim(
                    controller: controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: t.chat.freeVideoPromptDialog.subjectLabel,
                      hintText: t.chat.freeVideoPromptDialog.subjectHint,
                    ),
                    onFieldSubmitted: (value) =>
                        Navigator.of(dialogContext).pop(value.trim()),
                  ),
                ],
              );
            },
            actions: [
              FilledButton(
                key: const Key('media-generate-confirm'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: Text(t.chat.freeVideoPromptDialog.generateButton),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}
