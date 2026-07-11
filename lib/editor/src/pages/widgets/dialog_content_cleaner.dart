import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
        title: Text(
          t.editor.dialogContentCleaner.confirmActionTitle(
            actionName: actionName,
          ),
        ),
        content: Text(
          t.editor.findReplaceDialog.confirmReplaceAllMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.editor.findReplaceDialog.proceedButton),
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
              t.editor.dialogContentCleaner.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.normalizeFancyCharsAction,
                UtilsApp.normalizeFancyChars,
              ),
              child: Text(
                t.editor.dialogContentCleaner.normalizeFancyCharsButton,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.purgeHtmlAction,
                UtilsApp.purgeHtml,
              ),
              child: Text(t.editor.dialogContentCleaner.purgeHtmlButton),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.purgeMarkdownAction,
                UtilsApp.purgeMarkdownLinksImages,
              ),
              child: Text(t.editor.dialogContentCleaner.purgeMarkdownAction),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.purgeEmojisAction,
                UtilsApp.purgeEmojis,
              ),
              child: Text(t.editor.dialogContentCleaner.purgeEmojisAction),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.purgeExtraSpacesAction,
                UtilsApp.purgeExtraSpaces,
              ),
              child: Text(
                t.editor.dialogContentCleaner.purgeExtraSpacesAction,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                context,
                t.editor.dialogContentCleaner.yoloPurgeAction,
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
              child: Text(t.editor.dialogContentCleaner.applyAllAboveButton),
            ),
          ],
        ),
      ),
    );
  }
}
