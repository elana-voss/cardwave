part of 'text_field_card.dart';

class _ExpandedEditorDialog extends StatefulWidget {
  const _ExpandedEditorDialog({
    required this.controller,
    required this.label,
    required this.showTokenCount,
    this.trailing,
  });
  final TextEditingController controller;
  final String label;
  final bool showTokenCount;
  final Widget? trailing;

  @override
  State<_ExpandedEditorDialog> createState() => _ExpandedEditorDialogState();
}
