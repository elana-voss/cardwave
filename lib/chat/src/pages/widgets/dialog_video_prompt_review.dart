import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

/// Shows the compacted video prompt for review and optional editing before
/// submitting to the video provider. Returns the (possibly edited) prompt
/// or `null` if the user cancels. Video generation is expensive and
/// multi-minute — this review step is much more load-bearing than the
/// image-gen counterpart because a bad prompt here costs real money and
/// real time before the user finds out.
class DialogVideoPromptReview {
  const DialogVideoPromptReview._();

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
                    'Review video prompt',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Edit the prompt below before submitting, or tap '
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
                      labelText: 'Video prompt',
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
