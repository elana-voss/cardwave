import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:flutter/material.dart';

class AppDialogActionRow extends StatelessWidget {
  const AppDialogActionRow({
    required this.actions,
    super.key,
    this.showDismissButton = true,
  });
  final List<Widget> actions;
  final bool showDismissButton;

  @override
  Widget build(BuildContext context) {
    const paddingValue = 16.0;

    final List<Widget> rowChildren;
    if (showDismissButton) {
      final closeButton = TextButton(
        key: AppDialog.dismissKey,
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      );
      rowChildren = actions.isEmpty
          ? [const Spacer(), closeButton]
          : [closeButton, const Spacer(), ...actions];
    } else {
      rowChildren = actions;
    }

    return Padding(
      padding: const EdgeInsets.all(paddingValue),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: rowChildren,
      ),
    );
  }
}
