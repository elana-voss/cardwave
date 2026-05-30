import 'package:cardwave/common/common.dart';
import 'package:flutter/material.dart';

/// What kind of value an [ObjectValueEditor] is currently editing.
/// Drives the value-input widget the editor shows and the type the
/// value gets parsed back into on commit.
///
/// UI state only: not serialized. The runtime type of the stored
/// value is the source of truth on load.
enum ObjectValueType { string, number, boolean }

/// Reusable editor for an `Object?` value. Type dropdown
/// (string / number / bool) plus a value input whose shape follows
/// the chosen type. Used by both knowledge writes
/// (`KnowledgeRecord.value`) and flag set (`Map<String, Object?>`).
///
/// On load, the type is inferred from the value's runtime type
/// (string / num / bool); on type swap the displayed input changes
/// and the stored value is re-parsed. Invalid number input keeps the
/// last valid value (no error chrome — the field is small and the
/// next valid keystroke recovers).
class ObjectValueEditor extends StatefulWidget {
  const ObjectValueEditor({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<ObjectValueEditor> createState() => _ObjectValueEditorState();
}

class _ObjectValueEditorState extends State<ObjectValueEditor> {
  late ObjectValueType _type;
  late final TextEditingController _stringController;
  late final TextEditingController _numberController;
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    _type = _typeOf(widget.value);
    _stringController = TextEditingController(
      text: _type == ObjectValueType.string
          ? (widget.value?.toString() ?? '')
          : '',
    );
    _numberController = TextEditingController(
      text: _type == ObjectValueType.number ? widget.value.toString() : '',
    );
    _boolValue = widget.value is bool ? widget.value! as bool : false;

    _stringController.onTextChanged(() {
      if (_type != ObjectValueType.string) return;
      widget.onChanged(_stringController.text);
    });
    _numberController.onTextChanged(() {
      if (_type != ObjectValueType.number) return;
      final parsed = num.tryParse(_numberController.text);
      if (parsed == null) return;
      widget.onChanged(parsed);
    });
  }

  @override
  void dispose() {
    _stringController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  /// Infers the editor type from the runtime type of [value]. Null
  /// and any other type fall back to `string` (the safest default
  /// since every value has a string representation).
  static ObjectValueType _typeOf(Object? value) {
    if (value is bool) return ObjectValueType.boolean;
    if (value is num) return ObjectValueType.number;
    return ObjectValueType.string;
  }

  void _onTypeChanged(ObjectValueType? type) {
    if (type == null || type == _type) return;
    setState(() => _type = type);
    switch (type) {
      case ObjectValueType.string:
        widget.onChanged(_stringController.text);
      case ObjectValueType.number:
        final parsed = num.tryParse(_numberController.text);
        widget.onChanged(parsed ?? 0);
      case ObjectValueType.boolean:
        widget.onChanged(_boolValue);
    }
  }

  void _onBoolChanged(bool value) {
    setState(() => _boolValue = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: DropdownButton<ObjectValueType>(
            isExpanded: true,
            value: _type,
            items: const [
              DropdownMenuItem(
                value: ObjectValueType.string,
                child: Text('string'),
              ),
              DropdownMenuItem(
                value: ObjectValueType.number,
                child: Text('number'),
              ),
              DropdownMenuItem(
                value: ObjectValueType.boolean,
                child: Text('bool'),
              ),
            ],
            onChanged: _onTypeChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _valueInput()),
      ],
    );
  }

  Widget _valueInput() {
    return switch (_type) {
      ObjectValueType.string => TextFieldCard.singleLine(
          controller: _stringController,
          label: '',
        ),
      ObjectValueType.number => TextFieldCard.singleLine(
          controller: _numberController,
          label: '',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
      ObjectValueType.boolean => Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: _boolValue,
            onChanged: _onBoolChanged,
          ),
        ),
    };
  }
}
