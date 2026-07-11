import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Shows the generated image prompt for review and optional editing before
/// sending it to the image API. Returns the (possibly edited) prompt, or
/// `null` if the user cancels.
class DialogImagePromptReview {
  const DialogImagePromptReview._();

  static Future<String?> show(
    BuildContext context, {
    required String prompt,
  }) async {
    final controller = TextEditingController(text: prompt);
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
                    t.chat.imagePromptReviewDialog.title,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.chat.imagePromptReviewDialog.description,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFieldAutotrim(
                    controller: controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: t.chat.imagePromptReviewDialog.fieldLabel,
                    ),
                  ),
                ],
              );
            },
            actions: [
              FilledButton(
                key: const Key('media-generate-confirm'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: Text(t.chat.imagePromptReviewDialog.generateButton),
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
