import 'dart:convert';

import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

class DialogJsonPrompt extends StatelessWidget {
  const DialogJsonPrompt({required this.rawContent, super.key});
  final String rawContent;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    var content = rawContent;
    try {
      if (content.isNotEmpty) {
        final parsed = jsonDecode(content);
        content = const JsonEncoder.withIndent('  ').convert(parsed);
      }
    } on Exception {
      // ignore — show raw text
    }
    return AppDialog(
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            t.common.jsonPromptDialog.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SelectionArea(child: JsonPromptViewer(jsonContent: content)),
        ],
      ),
    );
  }
}
