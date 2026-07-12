import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/workspace/src/models/workspace_base_enum.dart';
import 'package:flutter/material.dart';

class WorkspaceBaseToggle extends StatelessWidget {
  const WorkspaceBaseToggle({
    required this.base,
    required this.onBaseChanged,
    this.compact = false,
    super.key,
  });
  final WorkspaceBaseEnum base;
  final ValueChanged<WorkspaceBaseEnum> onBaseChanged;

  /// When true, segments render as icon-only — saves horizontal width
  /// in narrow AppBars where the title or other actions would
  /// otherwise be squashed.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return SegmentedButton<WorkspaceBaseEnum>(
      segments: [
        ButtonSegment(
          value: WorkspaceBaseEnum.chat,
          icon: const Icon(Icons.chat, size: 18),
          label: compact ? null : Text(t.group.groupChatPageEndDrawer.chatSectionHeader),
        ),
        ButtonSegment(
          value: WorkspaceBaseEnum.editor,
          icon: const Icon(Icons.edit, size: 18),
          label: compact ? null : Text(t.chat.messageActionsRow.editAction),
        ),
      ],
      selected: {base},
      onSelectionChanged: (s) => onBaseChanged(s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
