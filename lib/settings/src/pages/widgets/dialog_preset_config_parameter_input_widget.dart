part of 'dialog_preset_config.dart';

class ParameterInputWidget extends StatefulWidget {
  const ParameterInputWidget({
    required this.parameter,
    required this.controller,
    required this.isMobile,
    super.key,
  });
  final LlmParameterDefinition parameter;
  final TextEditingController controller;
  final bool isMobile;

  @override
  State<ParameterInputWidget> createState() => _ParameterInputWidgetState();
}

class _ParameterInputWidgetState extends State<ParameterInputWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _clampValue();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double get _currentValue =>
      (double.tryParse(widget.controller.text) ?? widget.parameter.defaultValue)
          .clamp(widget.parameter.min, widget.parameter.max);

  void _setValue(double value) {
    final clamped = value.clamp(widget.parameter.min, widget.parameter.max);
    final newText =
        widget.parameter.type == LLmParameterDefinitionTypeEnum.integer
        ? clamped.toInt().toString()
        : clamped.toStringAsFixed(2);

    if (widget.controller.text != newText) {
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _clampValue() {
    final parsed = double.tryParse(widget.controller.text);
    if (parsed != null) _setValue(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.parameter;
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    def.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: def.description,
                  child: const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.isMobile) ...[
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return Slider(
                    padding: EdgeInsets.zero,
                    value: _currentValue,
                    min: def.min,
                    max: def.max,
                    divisions:
                        def.type == LLmParameterDefinitionTypeEnum.integer
                        ? (def.max - def.min).toInt()
                        : 100,
                    label: value.text,
                    onChanged: _setValue,
                  );
                },
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextFieldAutotrim(
              controller: controller,
              focusNode: _focusNode,
              onFieldSubmitted: (_) => _clampValue(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(
                    def.type == LLmParameterDefinitionTypeEnum.integer
                        ? (def.min < 0 ? r'^-?\d*$' : r'^\d*$')
                        : (def.min < 0 ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$'),
                  ),
                ),
              ],
              keyboardType: TextInputType.numberWithOptions(
                decimal: def.type == LLmParameterDefinitionTypeEnum.double,
                signed: def.min < 0,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                errorStyle: TextStyle(height: 0),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final parsed = double.tryParse(value);
                if (parsed == null) {
                  return 'Invalid';
                }
                if (parsed < def.min || parsed > def.max) {
                  return '${def.min} - ${def.max}';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
