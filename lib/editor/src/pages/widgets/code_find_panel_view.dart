import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Find/replace panel for [CodeEditor]. re_editor ships the
/// [CodeFindController] and the `findBuilder` hook but not a panel widget,
/// so this is adapted from the package's upstream example (re_editor 0.8.0
/// `example/lib/find.dart`) and themed from the app color scheme.
const double _kPanelWidth = 360;
const double _kRowHeight = 36;
const double _kFindIconSize = 16;
const double _kInputFontSize = 13;
const double _kResultFontSize = 12;
const double _kFindFieldWidth = _kPanelWidth / 1.75;

class CodeFindPanelView extends StatelessWidget implements PreferredSizeWidget {
  const CodeFindPanelView({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  bool get _replaceVisible =>
      (controller.value?.replaceMode ?? false) && !readOnly;

  @override
  Size get preferredSize {
    // Height 0 when the find panel is closed, so the editor reserves no
    // top padding for it (re_editor adds find.preferredSize.height to the
    // editor's top inset whenever a findBuilder is set).
    if (controller.value == null) return const Size(double.infinity, 0);
    return Size(double.infinity, _replaceVisible ? _kRowHeight * 2 : _kRowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 10),
      alignment: Alignment.topRight,
      height: preferredSize.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _kPanelWidth,
          child: Column(
            children: [
              _FindRow(controller: controller, value: value),
              if (_replaceVisible)
                _ReplaceRow(controller: controller, value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindRow extends StatelessWidget {
  const _FindRow({required this.controller, required this.value});

  final CodeFindController controller;
  final CodeFindValue value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = value.result == null
        ? t.editor.codeFindPanel.noneResult
        : '${value.result!.index + 1}/${value.result!.matches.length}';
    return Row(
      children: [
        SizedBox(
          width: _kFindFieldWidth,
          height: _kRowHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _FindField(
                textController: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                trailingIconsWidth: _kFindIconSize * 3,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ToggleText(
                    text: 'Aa',
                    checked: value.option.caseSensitive,
                    onPressed: controller.toggleCaseSensitive,
                  ),
                  _ToggleText(
                    text: '.*',
                    checked: value.option.regex,
                    onPressed: controller.toggleRegex,
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          result,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: _kResultFontSize,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _FindIconButton(
                icon: Icons.arrow_upward,
                tooltip: t.editor.codeFindPanel.previousTooltip,
                onPressed: value.result == null ? null : controller.previousMatch,
              ),
              _FindIconButton(
                icon: Icons.arrow_downward,
                tooltip: t.editor.codeFindPanel.nextTooltip,
                onPressed: value.result == null ? null : controller.nextMatch,
              ),
              _FindIconButton(
                icon: Icons.close,
                tooltip: t.editor.codeFindPanel.closeTooltip,
                onPressed: controller.close,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReplaceRow extends StatelessWidget {
  const _ReplaceRow({required this.controller, required this.value});

  final CodeFindController controller;
  final CodeFindValue value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _kFindFieldWidth,
          height: _kRowHeight,
          child: _FindField(
            textController: controller.replaceInputController,
            focusNode: controller.replaceInputFocusNode,
          ),
        ),
        _FindIconButton(
          icon: Icons.done,
          tooltip: t.editor.codeFindPanel.replaceTooltip,
          onPressed: value.result == null ? null : controller.replaceMatch,
        ),
        _FindIconButton(
          icon: Icons.done_all,
          tooltip: t.editor.codeFindPanel.replaceAllTooltip,
          onPressed: value.result == null ? null : controller.replaceAllMatches,
        ),
      ],
    );
  }
}

class _FindField extends StatelessWidget {
  const _FindField({
    required this.textController,
    required this.focusNode,
    this.trailingIconsWidth = 0,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final double trailingIconsWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
      child: TextField(
        controller: textController,
        focusNode: focusNode,
        maxLines: 1,
        style: const TextStyle(fontSize: _kInputFontSize),
        decoration: InputDecoration(
          filled: true,
          contentPadding: EdgeInsets.only(left: 5, right: 5 + trailingIconsWidth),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(0)),
            gapPadding: 0,
          ),
        ),
      ),
    );
  }
}

class _ToggleText extends StatelessWidget {
  const _ToggleText({
    required this.text,
    required this.checked,
    required this.onPressed,
  });

  final String text;
  final bool checked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _kFindIconSize * 1.5,
          child: Text(
            text,
            style: TextStyle(
              color: checked ? cs.primary : cs.onSurfaceVariant,
              fontSize: _kInputFontSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _FindIconButton extends StatelessWidget {
  const _FindIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: _kFindIconSize),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
    );
  }
}
