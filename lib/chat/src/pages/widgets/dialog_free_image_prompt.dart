import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Shows a small dialog that asks the user for a subject / free prompt for
/// image generation. Returns the trimmed string, or `null` if cancelled.
class DialogFreeImagePrompt {
  const DialogFreeImagePrompt._();

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
                    t.chat.freeImagePromptDialog.title,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.chat.freeImagePromptDialog.description,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFieldAutotrim(
                    controller: controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: t.chat.freeImagePromptDialog.subjectLabel,
                      hintText: t.chat.freeImagePromptDialog.subjectHint,
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
                child: Text(t.chat.freeImagePromptDialog.generateButton),
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
