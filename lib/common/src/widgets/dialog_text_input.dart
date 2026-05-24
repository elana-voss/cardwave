import 'package:flutter/material.dart';

class DialogTextInput extends StatefulWidget {
  const DialogTextInput({
    required this.title,
    required this.initialText,
    required this.hintText,
    required this.confirmText,
    required this.cancelText,
    required this.maxLines,
    super.key,
  });
  final String title;
  final String initialText;
  final String hintText;
  final String confirmText;
  final String cancelText;
  final int maxLines;

  @override
  State<DialogTextInput> createState() => _DialogTextInputState();
}

class _DialogTextInputState extends State<DialogTextInput> {
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        maxLines: widget.maxLines,
      ),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          key: const Key('dialog-save'),
          onPressed: () => Navigator.pop(context, _controller!.text.trim()),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}
