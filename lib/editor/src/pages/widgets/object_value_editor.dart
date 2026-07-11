import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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
  final TextEditingController _stringController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  late bool _boolValue;

  @override
  void initState() {
    super.initState();
    _type = _typeOf(widget.value);
    _stringController.text = _type == ObjectValueType.string
        ? (widget.value?.toString() ?? '')
        : '';
    _numberController.text =
        _type == ObjectValueType.number ? widget.value.toString() : '';
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
      spacing: 8,
      children: [
        SizedBox(
          width: 110,
          child: DropdownButton<ObjectValueType>(
            isExpanded: true,
            value: _type,
            items: [
              DropdownMenuItem(
                value: ObjectValueType.string,
                child: Text(t.editor.objectValueEditor.stringType),
              ),
              DropdownMenuItem(
                value: ObjectValueType.number,
                child: Text(t.editor.objectValueEditor.numberType),
              ),
              DropdownMenuItem(
                value: ObjectValueType.boolean,
                child: Text(t.editor.objectValueEditor.boolType),
              ),
            ],
            onChanged: _onTypeChanged,
          ),
        ),
        Expanded(
          child: _ObjectValueInput(
            type: _type,
            stringController: _stringController,
            numberController: _numberController,
            boolValue: _boolValue,
            onBoolChanged: _onBoolChanged,
          ),
        ),
      ],
    );
  }
}

/// The right-hand value widget whose shape follows the type dropdown.
/// Extracted from `_ObjectValueEditorState` so the type swap rebuilds
/// only this subtree (and so the analyzer's `avoid_returning_widgets`
/// rule is satisfied).
class _ObjectValueInput extends StatelessWidget {
  const _ObjectValueInput({
    required this.type,
    required this.stringController,
    required this.numberController,
    required this.boolValue,
    required this.onBoolChanged,
  });

  final ObjectValueType type;
  final TextEditingController stringController;
  final TextEditingController numberController;
  final bool boolValue;
  final ValueChanged<bool> onBoolChanged;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      ObjectValueType.string => TextFieldCard.singleLine(
          controller: stringController,
          label: '',
        ),
      ObjectValueType.number => TextFieldCard.singleLine(
          controller: numberController,
          label: '',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
      ObjectValueType.boolean => Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: boolValue,
            onChanged: onBoolChanged,
          ),
        ),
    };
  }
}
