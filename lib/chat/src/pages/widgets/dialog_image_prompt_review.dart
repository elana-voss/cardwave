import 'package:cardwave/common/common.dart';
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
                    'Review image prompt',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Edit the prompt below before generating, or tap '
                    'Generate to use it as-is.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFieldAutotrim(
                    controller: controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Image prompt',
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
                child: const Text('Generate'),
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
