import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

/// Asks the user whether to allow the chat model to fetch [url] before
/// the `fetch_website` tool runs. Returns `true` to allow, `false` to
/// deny (the model receives a failure result and can apologise).
class DialogUrlFetchReview {
  const DialogUrlFetchReview._();

  static Future<bool> show(
    BuildContext context, {
    required String url,
    String? purpose,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          showDismissButton: false,
          builder: (ctx, isMobile) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Allow web fetch?',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'The character wants to read the contents of this URL.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  url,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                if (purpose != null && purpose.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Purpose:',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    purpose.trim(),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ],
            );
          },
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Deny'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
