import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/text_field_autotrim.dart';
import 'package:flutter/material.dart';

class DialogMessageEdit extends StatefulWidget {
  const DialogMessageEdit({required this.initialContent, super.key});
  final String initialContent;

  @override
  State<DialogMessageEdit> createState() => _DialogMessageEditState();
}

class _DialogMessageEditState extends State<DialogMessageEdit> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      actions: [
        FilledButton(
          key: const Key('dialog-save'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Message', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
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
