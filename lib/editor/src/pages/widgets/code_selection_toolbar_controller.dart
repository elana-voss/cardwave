import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Cut / copy / paste / select-all menu for the raw JSON [CodeEditor].
/// re_editor draws the selection handles but leaves the menu to the host
/// app, so without this the editor shows no selection menu on phones at all.
///
/// Renders the platform's own text-selection toolbar at the anchors
/// re_editor computes. Passing both the above and below anchors lets the
/// toolbar pick its side by fit, so it sits against the selection rather
/// than jumping to a screen corner. Select-all runs the editor's
/// whole-document select, which is how mobile gets a working select-all: the
/// phone keyboard otherwise only ever sees, and selects, the current line.
///
/// Holds one overlay entry. The editor page must call [dispose] so a menu
/// left open when the page closes does not linger.
class CodeSelectionToolbarController implements SelectionToolbarController {
  OverlayEntry? _entry;

  @override
  void hide(BuildContext context) => _remove();

  void dispose() => _remove();

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  /// A menu button that dismisses the menu first, then runs the editor action.
  ContextMenuButtonItem _button(ContextMenuButtonType type, VoidCallback action) {
    return ContextMenuButtonItem(
      type: type,
      onPressed: () {
        _remove();
        action();
      },
    );
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    _remove();
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final bool hasSelection = !controller.selection.isCollapsed;
    // Wrapped in CodeEditorTapRegion so a tap on the menu counts as a tap
    // inside the editor. Without it the editor reads the tap as an outside
    // tap, clears the selection, and the button's action runs on nothing.
    final OverlayEntry entry = OverlayEntry(
      builder: (_) => CodeEditorTapRegion(
        child: AdaptiveTextSelectionToolbar.buttonItems(
          anchors: anchors,
          buttonItems: [
            if (hasSelection)
              _button(ContextMenuButtonType.cut, controller.cut),
            if (hasSelection)
              _button(ContextMenuButtonType.copy, controller.copy),
            _button(ContextMenuButtonType.paste, controller.paste),
            _button(ContextMenuButtonType.selectAll, controller.selectAll),
          ],
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
  }
}
