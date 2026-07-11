import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/text_field_autotrim.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class DialogMessageEdit extends StatefulWidget {
  const DialogMessageEdit({required this.initialContent, super.key});
  final String initialContent;

  @override
  State<DialogMessageEdit> createState() => _DialogMessageEditState();
}

class _DialogMessageEditState extends State<DialogMessageEdit> {
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      actions: [
        FilledButton(
          key: const Key('dialog-save'),
          onPressed: () => Navigator.pop(context, _controller!.text),
          child: Text(t.common.actions.save),
        ),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            t.common.messageEditDialog.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextFieldAutotrim(
            controller: _controller,
            maxLines: null,
            autofocus: true,
          ),
        ],
      ),
    );
  }
}
