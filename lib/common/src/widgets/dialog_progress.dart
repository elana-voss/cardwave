import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class ProgressDialogHandle {
  ProgressDialogHandle(this._closeCallback);
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
  final ValueNotifier<String> message = ValueNotifier<String>(
    t.common.progressDialog.defaultMessage,
  );
  final VoidCallback _closeCallback;
  bool isCancelled = false;
  bool _isClosed = false;

  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _closeCallback();
  }

  void update({double? progressValue, String? messageValue}) {
    if (_isClosed) return;
    if (progressValue != null) progress.value = progressValue;
    if (messageValue != null) message.value = messageValue;
  }

  void dispose() {
    progress.dispose();
    message.dispose();
  }
}

class DialogProgress extends StatefulWidget {
  const DialogProgress({
    required this.title,
    required this.handle,
    this.onCancel,
    super.key,
  });
  final String title;
  final ProgressDialogHandle handle;
  final VoidCallback? onCancel;

  @override
  State<DialogProgress> createState() => _DialogProgressState();
}

class _DialogProgressState extends State<DialogProgress> {
  @override
  void dispose() {
    widget.handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: widget.handle.message,
              builder: (ctx, msg, _) => Text(msg),
            ),
            ValueListenableBuilder<double?>(
              valueListenable: widget.handle.progress,
              builder: (ctx, prog, _) => LinearProgressIndicator(value: prog),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.handle.isCancelled = true;
              widget.onCancel?.call();
              widget.handle.close();
            },
            child: Text(t.common.actions.cancel),
          ),
        ],
      ),
    );
  }
}
