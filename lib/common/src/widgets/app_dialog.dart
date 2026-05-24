import 'package:cardwave/common/src/utils/app_constants.dart';
import 'package:cardwave/common/src/widgets/app_dialog_action_row.dart';
import 'package:flutter/material.dart';

/// Modal Dialog on Desktop, Fullscreen Dialog on mobile
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.builder,
    super.key,
    this.actions,
    this.isScrollable = true,
    this.forceMobile = false,
    this.showDismissButton = true,
  });
  final Widget Function(BuildContext context, bool isMobile) builder;
  final List<Widget>? actions;
  final bool isScrollable;
  final bool forceMobile;
  final bool showDismissButton;

  /// Stable Key for the auto-rendered dismiss affordance: a `CloseButton`
  /// in the AppBar leading slot on fullscreen-mobile, a `TextButton('Close')`
  /// in the bottom action row on desktop. Tests use `find.byKey(AppDialog
  /// .dismissKey)` and `.last` to dismiss the topmost dialog when multiple
  /// AppDialogs are stacked.
  // ignore: qcheck/prefer_widget_private_members
  static const dismissKey = Key('app-dialog-dismiss');

  @override
  Widget build(BuildContext context) {
    final isMobile =
        forceMobile ||
        MediaQuery.sizeOf(context).width <= AppConstants.mobileBreakpoint;
    const paddingValue = 16.0;
    final hasActions = actions != null && actions!.isNotEmpty;

    // Mobile fullscreen puts the dismiss in the AppBar's leading slot, so
    // the bottom action row should not also render a Close button.
    final showDismissInRow = showDismissButton && !isMobile;
    final actionRowRendered = hasActions || showDismissInRow;

    var body = builder(context, isMobile);

    body = Padding(
      padding: EdgeInsets.fromLTRB(
        paddingValue,
        paddingValue,
        paddingValue,
        actionRowRendered ? 0.0 : paddingValue,
      ),
      child: body,
    );

    if (isScrollable) {
      body = SingleChildScrollView(child: body);
    }
    final content = Column(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile) Expanded(child: body) else Flexible(child: body),
        if (actionRowRendered)
          AppDialogActionRow(
            actions: actions ?? const [],
            showDismissButton: showDismissInRow,
          ),
      ],
    );

    if (isMobile) {
      if (!showDismissButton) {
        return Dialog.fullscreen(child: SafeArea(child: content));
      }
      return Dialog.fullscreen(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 1,
                  child: CloseButton(key: dismissKey),
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppConstants.dialogMaxWidth,
        ),
        child: content,
      ),
    );
  }
}
