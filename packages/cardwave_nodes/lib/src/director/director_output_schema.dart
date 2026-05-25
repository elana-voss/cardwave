import 'package:cardwave_nodes/src/models/emotion_enum.dart';
import 'package:cardwave_nodes/src/models/physical_enum.dart';
import 'package:cardwave_nodes/src/models/relationship_enum.dart';
import 'package:cardwave_nodes/src/utils/constants.dart';
import 'package:schemantic/schemantic.dart';

// JSON-key names matching `field_rename: snake` in build.yaml. Hoisted as
// constants so the schema and `DirectorOutput.fromJson` cannot drift.
const _keyEmotionDeltas = 'emotion_deltas';
const _keyPhysicalDeltas = 'physical_deltas';
const _keyRelationshipDeltas = 'relationship_deltas';
const _keyFlagSet = 'flag_set';
const _keyDirectiveLines = 'directive_lines';
const _keyEventLogAppend = 'event_log_append';
const _keyText = 'text';
const _keySignificance = 'significance';

/// JSON-schema constraint passed to `LlmRunner.completeStructured`. Covers
/// the v1 director surface — deltas, flag set, directive lines, event log.
/// `knowledge_writes` and `generated_nodes` are intentionally NOT requested
/// from the LLM yet; both round-trip through [DirectorOutput] if a later
/// schema asks for them.
final SchemanticType<Map<String, dynamic>> directorOutputSchema =
    SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: {
    'type': 'object',
    'additionalProperties': false,
    'properties': <String, Object?>{
      _keyEmotionDeltas:
          _enumDeltasSchema(EmotionEnum.values.map((e) => e.name)),
      _keyPhysicalDeltas:
          _enumDeltasSchema(PhysicalEnum.values.map((e) => e.name)),
      _keyRelationshipDeltas:
          _enumDeltasSchema(RelationshipEnum.values.map((e) => e.name)),
      _keyFlagSet: <String, Object?>{
        'type': 'object',
        'additionalProperties': true,
        'description':
            'Flat key/value flags merged into global state.flags.',
      },
      _keyDirectiveLines: <String, Object?>{
        'type': 'array',
        'items': <String, Object?>{'type': 'string'},
        'description':
            'Short authorial nudges injected into the actor prompt this turn.',
      },
      _keyEventLogAppend: <String, Object?>{
        'type': 'array',
        'items': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>[_keyText, _keySignificance],
          'properties': <String, Object?>{
            _keyText: <String, Object?>{'type': 'string'},
            _keySignificance: <String, Object?>{
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
            },
          },
        },
        'description':
            'New entries for the rolling event log; engine stamps `turn`.',
      },
    },
  },
  parse: (json) => (json as Map).cast<String, dynamic>(),
);

Map<String, Object?> _enumDeltasSchema(Iterable<String> enumNames) => {
      'type': 'object',
      'description':
          'Outer key: character id. Inner key: field name. Value: delta in '
          '[$directorDeltaMin, $directorDeltaMax].',
      'additionalProperties': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          for (final name in enumNames)
            name: <String, Object?>{
              'type': 'number',
              'minimum': directorDeltaMin,
              'maximum': directorDeltaMax,
            },
        },
      },
    };
