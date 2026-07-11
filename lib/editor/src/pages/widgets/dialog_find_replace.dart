import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class DialogFindReplace extends StatefulWidget {
  const DialogFindReplace({required this.onApply, super.key});
  final Function(String Function(String)) onApply;

  @override
  State<DialogFindReplace> createState() => _DialogFindReplaceState();
}

class _DialogFindReplaceState extends State<DialogFindReplace> {
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  Future<void> _confirmAndApply(String Function(String) processor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editor.findReplaceDialog.confirmReplaceAllTitle),
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

    if (confirmed == true && mounted) {
      widget.onApply(processor);
    }
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
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
              t.editor.findReplaceDialog.title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _findController,
              decoration: InputDecoration(
                labelText: t.editor.findReplaceDialog.findLabel,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replaceController,
              decoration: InputDecoration(
                labelText: t.editor.findReplaceDialog.replaceWithLabel,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _confirmAndApply(
                (text) => text.replaceAll(
                  _findController.text,
                  _replaceController.text,
                ),
              ),
              child: Text(t.editor.findReplaceDialog.replaceAllButton),
            ),
          ],
        ),
      ),
    );
  }
}
