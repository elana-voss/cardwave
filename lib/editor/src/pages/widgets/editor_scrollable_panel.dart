import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/pages/widgets/panel_enum.dart';
import 'package:flutter/material.dart';

/// Wraps an editor panel's content in a centered, max-width, scrollable
/// column. Returns an [Expanded], so it must be a child of the editor
/// view's [Row]/[Column]. `editorVersion` keys the subtree so a global
/// "clean all strings" / AI-action mutation forces a rebuild.
class EditorScrollablePanel extends StatelessWidget {
  const EditorScrollablePanel({
    required this.panel,
    required this.editorVersion,
    required this.content,
    super.key,
  });
  final PanelEnum panel;
  final int editorVersion;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      key: ValueKey(editorVersion),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.editorMaxWidth,
          ),
          child: SingleChildScrollView(
            key: ValueKey(panel),
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      ),
    );
  }
}
