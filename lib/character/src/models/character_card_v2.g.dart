// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_card_v2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterCardV2 _$CharacterCardV2FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CharacterCardV2',
  json,
  ($checkedConvert) {
    final val = CharacterCardV2(
      name: $checkedConvert('name', (v) => v as String? ?? ''),
      description: $checkedConvert('description', (v) => v as String? ?? ''),
      personality: $checkedConvert('personality', (v) => v as String? ?? ''),
      scenario: $checkedConvert('scenario', (v) => v as String? ?? ''),
      firstMes: $checkedConvert('first_mes', (v) => v as String? ?? ''),
      mesExample: $checkedConvert('mes_example', (v) => v as String? ?? ''),
      creatorNotes: $checkedConvert('creator_notes', (v) => v as String? ?? ''),
      systemPrompt: $checkedConvert('system_prompt', (v) => v as String? ?? ''),
      postHistoryInstructions: $checkedConvert(
        'post_history_instructions',
        (v) => v as String? ?? '',
      ),
      alternateGreetings: $checkedConvert(
        'alternate_greetings',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      tags: $checkedConvert(
        'tags',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      creator: $checkedConvert('creator', (v) => v as String? ?? ''),
      characterVersion: $checkedConvert(
        'character_version',
        (v) => v as String? ?? '',
      ),
      extensions: $checkedConvert(
        'extensions',
        (v) => v as Map<String, dynamic>? ?? {},
      ),
      lorebook: $checkedConvert(
        'character_book',
        (v) => v == null ? null : Lorebook.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'firstMes': 'first_mes',
    'mesExample': 'mes_example',
    'creatorNotes': 'creator_notes',
    'systemPrompt': 'system_prompt',
    'postHistoryInstructions': 'post_history_instructions',
    'alternateGreetings': 'alternate_greetings',
    'characterVersion': 'character_version',
    'lorebook': 'character_book',
  },
);

Map<String, dynamic> _$CharacterCardV2ToJson(CharacterCardV2 instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'personality': instance.personality,
      'scenario': instance.scenario,
      'first_mes': instance.firstMes,
      'mes_example': instance.mesExample,
      'creator_notes': instance.creatorNotes,
      'system_prompt': instance.systemPrompt,
      'post_history_instructions': instance.postHistoryInstructions,
      'alternate_greetings': instance.alternateGreetings,
      'tags': instance.tags,
      'creator': instance.creator,
      'character_version': instance.characterVersion,
      'extensions': instance.extensions,
      'character_book': ?instance.lorebook?.toJson(),
    };
