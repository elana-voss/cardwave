import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

class DialogContentCleaner extends StatelessWidget {
  const DialogContentCleaner({required this.onApply, super.key});
  final Function(String Function(String)) onApply;

  Future<void> _confirmAndApply(
    BuildContext context,
    String actionName,
    String Function(String) processor,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $actionName'),
        content: const Text(
          'Are you sure you want to proceed?\nThis action is irreversible and affects all fields.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      onApply(processor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      builder: (context, isMobile) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Content Cleaner',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                'Normalize Fancy Chars',
                UtilsApp.normalizeFancyChars,
              ),
              child: const Text(
                'Normalize Fancy Chars (𝑻𝒉𝒆 𝒑𝒍𝒂𝒄𝒆)',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  _confirmAndApply(context, 'Purge HTML', UtilsApp.purgeHtml),
              child: const Text('Purge HTML Tags'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                'Purge Markdown Links/Images',
                UtilsApp.purgeMarkdownLinksImages,
              ),
              child: const Text('Purge Markdown Links/Images'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                'Purge Emojis',
                UtilsApp.purgeEmojis,
              ),
              child: const Text('Purge Emojis'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                'Purge Extra Spaces',
                UtilsApp.purgeExtraSpaces,
              ),
              child: const Text('Purge Extra Spaces'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                'Yolo Purge',
                (text) => UtilsApp.purgeExtraSpaces(
                  UtilsApp.purgeEmojis(
                    UtilsApp.purgeMarkdownLinksImages(
                      UtilsApp.purgeHtml(
                        UtilsApp.normalizeFancyChars(text),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Apply All Above'),
            ),
          ],
        ),
      ),
    );
  }
}
