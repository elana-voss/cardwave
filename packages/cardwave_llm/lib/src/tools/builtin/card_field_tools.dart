import 'package:cardwave_llm/src/tools/builtin/builtin_tool_app_data.dart';
import 'package:cardwave_llm/src/tools/builtin/card_field_types.dart';
import 'package:cardwave_llm/src/tools/tool_call_context.dart';
import 'package:cardwave_llm/src/tools/tool_definition.dart';
import 'package:cardwave_llm/src/tools/tool_result.dart';

// Six tool classes live in this one file (deviation from the
// one-tool-per-file convention used by `send_selfie_tool.dart` etc.)
// because the schemas here are tiny and the six share a single
// conceptual feature.
//
// Schema enum lists are derived from the typed enums in
// card_field_types.dart so adding a new field is one place to edit.

final List<String> _scalarFieldEnum = CardFieldScalar.values
    .map((v) => v.jsonKey)
    .toList(growable: false);

final List<String> _listFieldEnum = CardFieldList.values
    .map((v) => v.jsonKey)
    .toList(growable: false);

const String _scalarFieldDescription =
    'Which scalar field of the open character card.';
const String _listFieldDescription =
    'Which list field of the open character card.';

/// Read one scalar field of the open card. No approval; pure read.
class CardFieldGetTool extends ToolDefinition {
  const CardFieldGetTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_get';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Read the current value of one scalar field on the open character '
      'card (description, personality, scenario, etc.). Returns the text '
      'verbatim.';

  @override
  String get systemPromptText =>
      'Use card_field_get when you need to see exactly what is currently '
      'written in a field before suggesting or making a change.';

  @override
  String get progressLabel => 'Reading field…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _scalarFieldDescription,
        'enum': _scalarFieldEnum,
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    if (fieldKey is! String) {
      return const ToolResult.failure('card_field_get missing field.');
    }
    final field = CardFieldScalar.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure('card_field_get unknown field: $fieldKey');
    }
    final data = ctx.appData as BuiltinToolAppData;
    return ToolResult.ok(data: data.readScalar(field));
  }
}

/// Propose a write to one scalar field. Routes through the approval gate
/// (edit modality, or deletion modality when content is empty).
class CardFieldSetTool extends ToolDefinition {
  const CardFieldSetTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_set';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Replace one scalar field on the open character card with the given '
      'content. Passing an empty string clears the field (treated as a '
      'deletion and may require user approval).';

  @override
  String get systemPromptText =>
      'Use card_field_set to rewrite a single scalar field. The user may '
      'be asked to approve the change before it lands. To clear a field, '
      'pass an empty string.';

  @override
  String get progressLabel => 'Updating field…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field', 'content'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _scalarFieldDescription,
        'enum': _scalarFieldEnum,
      },
      'content': {
        'type': 'string',
        'description': 'Full new value for the field. Empty string clears it.',
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    final content = args['content'];
    if (fieldKey is! String || content is! String) {
      return const ToolResult.failure(
        'card_field_set field and content must be text.',
      );
    }
    final field = CardFieldScalar.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure('card_field_set unknown field: $fieldKey');
    }
    final data = ctx.appData as BuiltinToolAppData;
    return data.proposeScalarSet(field, content);
  }
}

/// Read one list field. `index` null returns the entry count as a
/// stringified int so the model can bound subsequent indexed reads.
class CardFieldListGetTool extends ToolDefinition {
  const CardFieldListGetTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_list_get';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Read a list field (alternate greetings, tags, group-only greetings). '
      'Omit index to get the entry count; pass an index to get that one '
      'entry.';

  @override
  String get systemPromptText =>
      'Alternate greetings, group-only greetings, and tags are NOT included '
      'in your context by default. Use card_field_list_get to learn how '
      'many entries exist, then call it again with an index to read each '
      'one before proposing changes.';

  @override
  String get progressLabel => 'Reading list…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _listFieldDescription,
        'enum': _listFieldEnum,
      },
      'index': {
        'type': 'integer',
        'description':
            'Zero-based entry index. Omit to get the total count instead.',
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    if (fieldKey is! String) {
      return const ToolResult.failure('card_field_list_get missing field.');
    }
    final field = CardFieldList.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure(
        'card_field_list_get unknown field: $fieldKey',
      );
    }
    final data = ctx.appData as BuiltinToolAppData;
    final indexRaw = args['index'];
    if (indexRaw == null) {
      return ToolResult.ok(data: data.listSize(field).toString());
    }
    // Accept any numeric type (some providers emit `2.0` for an integer
    // slot); truncate to int. Non-numeric or non-finite (infinity/NaN, which
    // would throw on toInt) → failure.
    if (indexRaw is! num) {
      return const ToolResult.failure(
        'card_field_list_get index must be an integer.',
      );
    }
    if (!indexRaw.isFinite) {
      return const ToolResult.failure(
        'card_field_list_get index must be a finite integer.',
      );
    }
    final index = indexRaw.toInt();
    final size = data.listSize(field);
    if (index < 0 || index >= size) {
      return ToolResult.failure(
        'card_field_list_get index out of bounds; list has $size entries.',
      );
    }
    return ToolResult.ok(data: data.readListEntry(field, index));
  }
}

/// Propose replacing one list entry. Edit modality unless content is empty
/// (deletion modality).
class CardFieldListSetTool extends ToolDefinition {
  const CardFieldListSetTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_list_set';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Replace one entry of a list field. Index must be in-range. Empty '
      'content clears the entry (deletion).';

  @override
  String get systemPromptText =>
      'Use card_field_list_set to rewrite a single alternate greeting, '
      'tag, or group-only greeting. To remove an entry entirely, use '
      'card_field_list_delete instead.';

  @override
  String get progressLabel => 'Updating list entry…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field', 'index', 'content'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _listFieldDescription,
        'enum': _listFieldEnum,
      },
      'index': {
        'type': 'integer',
        'description': 'Zero-based entry index to replace.',
      },
      'content': {
        'type': 'string',
        'description': 'New value for the entry.',
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    final indexRaw = args['index'];
    final content = args['content'];
    // Accept any numeric type for index (some providers emit `2.0` for an
    // integer slot); reject non-numbers and non-finite values (infinity/NaN
    // would throw on toInt).
    if (fieldKey is! String || indexRaw is! num || content is! String) {
      return const ToolResult.failure(
        'card_field_list_set field/index/content invalid.',
      );
    }
    if (!indexRaw.isFinite) {
      return const ToolResult.failure(
        'card_field_list_set index must be a finite integer.',
      );
    }
    final field = CardFieldList.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure(
        'card_field_list_set unknown field: $fieldKey',
      );
    }
    final data = ctx.appData as BuiltinToolAppData;
    return data.proposeListSet(field, indexRaw.toInt(), content);
  }
}

/// Propose appending one entry to a list field.
class CardFieldListAppendTool extends ToolDefinition {
  const CardFieldListAppendTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_list_append';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Append a new entry to a list field on the open card.';

  @override
  String get systemPromptText =>
      'Use card_field_list_append to add a new alternate greeting, tag, '
      'or group-only greeting. Use card_field_list_set to replace an '
      'existing entry instead of growing the list.';

  @override
  String get progressLabel => 'Appending…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field', 'content'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _listFieldDescription,
        'enum': _listFieldEnum,
      },
      'content': {
        'type': 'string',
        'description': 'New entry to add to the end of the list.',
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    final content = args['content'];
    if (fieldKey is! String || content is! String) {
      return const ToolResult.failure(
        'card_field_list_append field and content must be text.',
      );
    }
    final field = CardFieldList.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure(
        'card_field_list_append unknown field: $fieldKey',
      );
    }
    final data = ctx.appData as BuiltinToolAppData;
    return data.proposeListAppend(field, content);
  }
}

/// Propose removing one entry from a list field by index.
class CardFieldListDeleteTool extends ToolDefinition {
  const CardFieldListDeleteTool({required this.maxCallsPerTurn});

  static const String toolName = 'card_field_list_delete';

  @override
  final int maxCallsPerTurn;

  @override
  String get name => toolName;

  @override
  String get description =>
      'Remove one entry from a list field by index. Subsequent entries '
      'shift down by one.';

  @override
  String get systemPromptText =>
      'Use card_field_list_delete to remove an alternate greeting, tag, '
      'or group-only greeting entirely. The user will be asked to '
      'approve the removal by default.';

  @override
  String get progressLabel => 'Deleting list entry…';

  @override
  Map<String, Object?> parametersSchemaFor(Object appData) => {
    'type': 'object',
    'required': const ['field', 'index'],
    'properties': {
      'field': {
        'type': 'string',
        'description': _listFieldDescription,
        'enum': _listFieldEnum,
      },
      'index': {
        'type': 'integer',
        'description': 'Zero-based entry index to remove.',
      },
    },
  };

  @override
  Future<ToolResult> execute(
    ToolCallContext ctx,
    Map<String, dynamic> args,
  ) async {
    final fieldKey = args['field'];
    final indexRaw = args['index'];
    // Accept any numeric type for index (some providers emit `2.0` for an
    // integer slot); reject non-numbers and non-finite values (infinity/NaN
    // would throw on toInt).
    if (fieldKey is! String || indexRaw is! num) {
      return const ToolResult.failure(
        'card_field_list_delete missing field / index.',
      );
    }
    if (!indexRaw.isFinite) {
      return const ToolResult.failure(
        'card_field_list_delete index must be a finite integer.',
      );
    }
    final field = CardFieldList.fromJsonKey(fieldKey);
    if (field == null) {
      return ToolResult.failure(
        'card_field_list_delete unknown field: $fieldKey',
      );
    }
    final data = ctx.appData as BuiltinToolAppData;
    return data.proposeListDelete(field, indexRaw.toInt());
  }
}
