import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
                  t.chat.urlFetchReviewDialog.title,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  t.chat.urlFetchReviewDialog.description,
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
                    t.chat.urlFetchReviewDialog.purposeLabel,
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
              child: Text(t.chat.urlFetchReviewDialog.denyButton),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.chat.urlFetchReviewDialog.allowButton),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
