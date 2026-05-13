import 'package:cardwave/common/common.dart';
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
                    'Generate video',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Describe a short moment of motion — what is moving, '
                    'how, where. The system model will expand it into a '
                    'cinematic T2V prompt.',
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
                      hintText: 'she walks through neon rain, slow motion',
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
