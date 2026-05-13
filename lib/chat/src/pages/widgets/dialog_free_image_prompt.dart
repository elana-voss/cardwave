import 'package:cardwave/common/common.dart';
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
                    'Generate image',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Describe what you want to see. A short phrase is fine — '
                    'the model will expand it into a full tag list.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFieldAutotrim(
                    controller: controller,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'cyberpunk alley, neon rain',
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
