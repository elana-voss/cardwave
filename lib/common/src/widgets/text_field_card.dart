import 'dart:async';

import 'package:cardwave/common/src/utils/app_constants.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'text_field_card_expanded_editor_dialog.dart';

class TextFieldCard extends StatefulWidget {
  const TextFieldCard._({
    required this.controller,
    required this.label,
    super.key,
    this.keyboardType,
    this.enabled,
    this.showTokenCount = false,
    this.maxLines,
    this.minLines,
    this.autoTrim = true,
    this.trailing,
    this.headerLeading,
    this.headerTrailing,
    this.focusNode,
  });

  factory TextFieldCard.singleLine({
    required TextEditingController controller,
    required String label,
    Key? key,
    TextInputType? keyboardType,
    bool? enabled,
    bool showTokenCount = false,
    bool autoTrim = true,
    Widget? trailing,
    Widget? headerLeading,
    Widget? headerTrailing,
    FocusNode? focusNode,
  }) {
    return TextFieldCard._(
      key: key,
      controller: controller,
      label: label,
      keyboardType: keyboardType,
      enabled: enabled,
      showTokenCount: showTokenCount,
      maxLines: 1,
      autoTrim: autoTrim,
      trailing: trailing,
      headerLeading: headerLeading,
      headerTrailing: headerTrailing,
      focusNode: focusNode,
    );
  }

  factory TextFieldCard.multiLine({
    required TextEditingController controller,
    required String label,
    Key? key,
    bool? enabled,
    bool showTokenCount = false,
    int? minLines,
    bool autoTrim = true,
    Widget? trailing,
    Widget? headerLeading,
    Widget? headerTrailing,
    FocusNode? focusNode,
  }) {
    return TextFieldCard._(
      key: key,
      controller: controller,
      label: label,
      keyboardType: TextInputType.multiline,
      enabled: enabled,
      showTokenCount: showTokenCount,
      minLines: minLines,
      autoTrim: autoTrim,
      trailing: trailing,
      headerLeading: headerLeading,
      headerTrailing: headerTrailing,
      focusNode: focusNode,
    );
  }
  final TextEditingController controller;
  final String label;

  /// if this is TextInputType.number,
  /// the inputFormatters will be set accordingly
  final TextInputType? keyboardType;
  final bool? enabled;
  final bool showTokenCount;
  final int? maxLines;
  final int? minLines;
  final bool autoTrim;
  final Widget? trailing;

  /// Optional widget placed at the start of the label row (e.g. a drag
  /// handle). When non-null, the label header becomes a Row instead of a
  /// bare Text. Defaults to null so existing callers render unchanged.
  final Widget? headerLeading;

  /// Optional widget placed at the end of the label row (e.g. a delete
  /// button). Pairs with [headerLeading] to free horizontal width for the
  /// field below by hosting row-level chrome in the label area.
  final Widget? headerTrailing;
  final FocusNode? focusNode;

  @override
  State<TextFieldCard> createState() => TextFieldCardState();
}

class TextFieldCardState extends State<TextFieldCard> {
  static final FilteringTextInputFormatter onlyDigits =
      FilteringTextInputFormatter.allow(RegExp('[0-9]'));
  Timer? _debounceTimer;
  late final FocusNode _focusNode;
  bool _isInternalFocusNode = false;
  final ValueNotifier<int> _tokenCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _isInternalFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
    if (widget.showTokenCount) {
      unawaited(_initTokenCount());
      widget.controller.addListener(_onControllerTextChanged);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.autoTrim) {
      final currentText = widget.controller.text;
      final trimmed = currentText.trim();
      if (currentText != trimmed) {
        widget.controller.text = trimmed;
      }
    }
  }

  void _onControllerTextChanged() {
    updateTokenCount(widget.controller.text);
  }

  Future<void> _initTokenCount() async {
    final count = await UtilsLlm.countTokens(widget.controller.text);
    _tokenCount.value = count;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    if (widget.showTokenCount) {
      widget.controller.removeListener(_onControllerTextChanged);
    }
    _debounceTimer?.cancel();
    _tokenCount.dispose();
    super.dispose();
  }

  void updateTokenCount(String text) {
    if (!widget.showTokenCount) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(() async {
        final count = await UtilsLlm.countTokens(text);
        if (!mounted) return;
        _tokenCount.value = count;
      }());
    });
  }

  void showExpandedEditor(BuildContext context) {
    unawaited(
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) {
                return FadeTransition(
                  opacity: animation,
                  child: _ExpandedEditorDialog(
                    controller: widget.controller,
                    label: widget.label,
                    showTokenCount: widget.showTokenCount,
                    trailing: widget.trailing,
                  ),
                );
              },
            ),
          )
          .then((_) {
            if (widget.autoTrim) {
              final currentText = widget.controller.text;
              final trimmed = currentText.trim();
              if (currentText != trimmed) {
                widget.controller.text = trimmed;
              }
            }
            if (widget.showTokenCount) {
              updateTokenCount(widget.controller.text);
            }
            if (mounted) {
              // Rebuild after the (external) controller's text changed —
              // re-renders the trim / token-count display.
              // ignore: qcheck/avoid_empty_setstate
              setState(() {});
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMultiLine = widget.maxLines == null;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        suffixIcon: (!isMultiLine) ? widget.trailing : null,
        contentPadding: isMultiLine
            ? const EdgeInsets.fromLTRB(12, 16, 40, 16)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      maxLines: widget.maxLines,
      minLines: isMultiLine ? (widget.minLines ?? 4) : widget.minLines,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      inputFormatters: widget.keyboardType == TextInputType.number
          ? [onlyDigits]
          : [],
    );

    final Widget labelText = widget.showTokenCount
        ? ValueListenableBuilder<int>(
            valueListenable: _tokenCount,
            builder: (context, count, child) {
              return Text('${widget.label} - $count tokens', style: textStyle);
            },
          )
        : Text(widget.label, style: textStyle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              if (widget.headerLeading != null) ...[
                widget.headerLeading!,
                const SizedBox(width: 8),
              ],
              Expanded(child: labelText),
              if (widget.headerTrailing != null) widget.headerTrailing!,
            ],
          ),
        ),
        if (isMultiLine)
          Stack(
            children: [
              field,
              Positioned(
                top: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.grey),
                      onPressed: () => showExpandedEditor(context),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
              ),
            ],
          )
        else
          field,
      ],
    );
  }
}

class _ExpandedEditorDialogState extends State<_ExpandedEditorDialog> {
  Timer? _localDebounce;
  late final ValueNotifier<int> _localTokenCount;

  @override
  void initState() {
    super.initState();
    _localTokenCount = ValueNotifier<int>(0);
    if (widget.showTokenCount) {
      unawaited(_initTokenCount());
      widget.controller.addListener(_onControllerTextChanged);
    }
  }

  Future<void> _initTokenCount() async {
    final count = await UtilsLlm.countTokens(widget.controller.text);
    if (!mounted) return;
    _localTokenCount.value = count;
  }

  void _onControllerTextChanged() {
    if (_localDebounce?.isActive ?? false) {
      _localDebounce!.cancel();
    }
    _localDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(() async {
        if (!widget.showTokenCount) return;
        final count = await UtilsLlm.countTokens(widget.controller.text);
        if (!mounted) return;
        _localTokenCount.value = count;
      }());
    });
  }

  @override
  void dispose() {
    _localDebounce?.cancel();
    _localTokenCount.dispose();
    if (widget.showTokenCount) {
      widget.controller.removeListener(_onControllerTextChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            constraints.maxWidth >= AppConstants.tabletBreakpoint;
        final padding = isWideScreen ? 32.0 : 0.0;

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(widget.label),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actionsPadding: const EdgeInsets.only(right: 16),
            actions: [
              if (widget.showTokenCount)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _localTokenCount,
                      builder: (context, count, child) {
                        return Text(
                          '$count t',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                    ),
                  ),
                ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(padding),
            child: TextFormField(
              autofocus: true,
              controller: widget.controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        );
      },
    );
  }
}
