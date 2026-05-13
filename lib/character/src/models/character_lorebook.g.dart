// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_lorebook.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lorebook _$LorebookFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Lorebook',
  json,
  ($checkedConvert) {
    final val = Lorebook(
      entries: $checkedConvert(
        'entries',
        (v) =>
            (v as List<dynamic>?)
                ?.map((e) => LorebookEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      ),
      name: $checkedConvert('name', (v) => v as String?),
      description: $checkedConvert('description', (v) => v as String?),
      scanDepth: $checkedConvert('scan_depth', (v) => (v as num?)?.toInt()),
      tokenBudget: $checkedConvert('token_budget', (v) => (v as num?)?.toInt()),
      recursiveScanning: $checkedConvert(
        'recursive_scanning',
        (v) => v as bool?,
      ),
      extensions: $checkedConvert(
        'extensions',
        (v) => v as Map<String, dynamic>? ?? {},
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'scanDepth': 'scan_depth',
    'tokenBudget': 'token_budget',
    'recursiveScanning': 'recursive_scanning',
  },
);

Map<String, dynamic> _$LorebookToJson(Lorebook instance) => <String, dynamic>{
  'entries': instance.entries.map((e) => e.toJson()).toList(),
  'name': ?instance.name,
  'description': ?instance.description,
  'scan_depth': ?instance.scanDepth,
  'token_budget': ?instance.tokenBudget,
  'recursive_scanning': ?instance.recursiveScanning,
  'extensions': instance.extensions,
};

LorebookEntry _$LorebookEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LorebookEntry',
      json,
      ($checkedConvert) {
        final val = LorebookEntry(
          id: $checkedConvert('id', (v) => v),
          keys: $checkedConvert(
            'keys',
            (v) =>
                (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
          ),
          secondaryKeys: $checkedConvert(
            'secondary_keys',
            (v) =>
                (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
          ),
          comment: $checkedConvert('comment', (v) => v as String?),
          content: $checkedConvert('content', (v) => v as String?),
          name: $checkedConvert('name', (v) => v as String?),
          priority: $checkedConvert('priority', (v) => (v as num?)?.toInt()),
          constant: $checkedConvert('constant', (v) => v as bool?),
          selective: $checkedConvert('selective', (v) => v as bool?),
          useProbability: $checkedConvert('useProbability', (v) => v as bool?),
          selectiveLogic: $checkedConvert(
            'selectiveLogic',
            (v) => (v as num?)?.toInt(),
          ),
          insertionOrder: $checkedConvert(
            'insertion_order',
            (v) => (v as num?)?.toInt(),
          ),
          enabled: $checkedConvert('enabled', (v) => v as bool?),
          position: $checkedConvert('position', (v) => _positionFromJson(v)),
          useRegex: $checkedConvert('use_regex', (v) => v as bool?),
          caseSensitive: $checkedConvert('case_sensitive', (v) => v as bool?),
          characterFilter: $checkedConvert(
            'character_filter',
            (v) => v == null
                ? null
                : CharacterFilter.fromJson(v as Map<String, dynamic>),
          ),
          extensions: $checkedConvert(
            'extensions',
            (v) => _extensionsFromJson(v),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'secondaryKeys': 'secondary_keys',
        'insertionOrder': 'insertion_order',
        'useRegex': 'use_regex',
        'caseSensitive': 'case_sensitive',
        'characterFilter': 'character_filter',
      },
    );

Map<String, dynamic> _$LorebookEntryToJson(LorebookEntry instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'keys': instance.keys,
      'secondary_keys': instance.secondaryKeys,
      'comment': ?instance.comment,
      'content': ?instance.content,
      'name': ?instance.name,
      'priority': ?instance.priority,
      'constant': ?instance.constant,
      'selective': ?instance.selective,
      'useProbability': ?instance.useProbability,
      'selectiveLogic': ?instance.selectiveLogic,
      'insertion_order': ?instance.insertionOrder,
      'enabled': ?instance.enabled,
      'position': ?instance.position,
      'use_regex': ?instance.useRegex,
      'case_sensitive': ?instance.caseSensitive,
      'character_filter': ?instance.characterFilter?.toJson(),
      'extensions': instance.extensions.toJson(),
    };

CharacterFilter _$CharacterFilterFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CharacterFilter', json, ($checkedConvert) {
      final val = CharacterFilter(
        names: $checkedConvert(
          'names',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        ),
        tags: $checkedConvert(
          'tags',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        ),
        isExclude: $checkedConvert('is_exclude', (v) => v as bool? ?? false),
      );
      return val;
    }, fieldKeyMap: const {'isExclude': 'is_exclude'});

Map<String, dynamic> _$CharacterFilterToJson(CharacterFilter instance) =>
    <String, dynamic>{
      'names': instance.names,
      'tags': instance.tags,
      'is_exclude': instance.isExclude,
    };

LorebookEntryExtensions _$LorebookEntryExtensionsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'LorebookEntryExtensions',
  json,
  ($checkedConvert) {
    final val = LorebookEntryExtensions(
      position: $checkedConvert(
        'position',
        (v) => _extensionPositionFromJson(v),
      ),
      excludeRecursion: $checkedConvert('exclude_recursion', (v) => v as bool?),
      displayIndex: $checkedConvert(
        'display_index',
        (v) => (v as num?)?.toInt(),
      ),
      probability: $checkedConvert('probability', (v) => (v as num?)?.toInt()),
      depth: $checkedConvert('depth', (v) => (v as num?)?.toInt()),
      outletName: $checkedConvert('outlet_name', (v) => v as String?),
      group: $checkedConvert('group', (v) => v as String?),
      groupOverride: $checkedConvert('group_override', (v) => v as bool?),
      groupWeight: $checkedConvert('group_weight', (v) => (v as num?)?.toInt()),
      preventRecursion: $checkedConvert('prevent_recursion', (v) => v as bool?),
      delayUntilRecursion: $checkedConvert(
        'delay_until_recursion',
        (v) => _delayFromJson(v),
      ),
      scanDepth: $checkedConvert('scan_depth', (v) => (v as num?)?.toInt()),
      matchWholeWords: $checkedConvert('match_whole_words', (v) => v as bool?),
      useGroupScoring: $checkedConvert('use_group_scoring', (v) => v as bool?),
      caseSensitive: $checkedConvert('case_sensitive', (v) => v as bool?),
      automationId: $checkedConvert('automation_id', (v) => v as String?),
      role: $checkedConvert('role', (v) => (v as num?)?.toInt()),
      vectorized: $checkedConvert('vectorized', (v) => v as bool?),
      sticky: $checkedConvert('sticky', (v) => (v as num?)?.toInt()),
      cooldown: $checkedConvert('cooldown', (v) => (v as num?)?.toInt()),
      delay: $checkedConvert('delay', (v) => (v as num?)?.toInt()),
      matchPersonaDescription: $checkedConvert(
        'match_persona_description',
        (v) => v as bool?,
      ),
      matchCharacterDescription: $checkedConvert(
        'match_character_description',
        (v) => v as bool?,
      ),
      matchCharacterPersonality: $checkedConvert(
        'match_character_personality',
        (v) => v as bool?,
      ),
      matchCharacterDepthPrompt: $checkedConvert(
        'match_character_depth_prompt',
        (v) => v as bool?,
      ),
      matchScenario: $checkedConvert('match_scenario', (v) => v as bool?),
      matchCreatorNotes: $checkedConvert(
        'match_creator_notes',
        (v) => v as bool?,
      ),
      triggers: $checkedConvert(
        'triggers',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      ignoreBudget: $checkedConvert('ignore_budget', (v) => v as bool?),
    );
    return val;
  },
  fieldKeyMap: const {
    'excludeRecursion': 'exclude_recursion',
    'displayIndex': 'display_index',
    'outletName': 'outlet_name',
    'groupOverride': 'group_override',
    'groupWeight': 'group_weight',
    'preventRecursion': 'prevent_recursion',
    'delayUntilRecursion': 'delay_until_recursion',
    'scanDepth': 'scan_depth',
    'matchWholeWords': 'match_whole_words',
    'useGroupScoring': 'use_group_scoring',
    'caseSensitive': 'case_sensitive',
    'automationId': 'automation_id',
    'matchPersonaDescription': 'match_persona_description',
    'matchCharacterDescription': 'match_character_description',
    'matchCharacterPersonality': 'match_character_personality',
    'matchCharacterDepthPrompt': 'match_character_depth_prompt',
    'matchScenario': 'match_scenario',
    'matchCreatorNotes': 'match_creator_notes',
    'ignoreBudget': 'ignore_budget',
  },
);

Map<String, dynamic> _$LorebookEntryExtensionsToJson(
  LorebookEntryExtensions instance,
) => <String, dynamic>{
  'position': ?instance.position,
  'exclude_recursion': ?instance.excludeRecursion,
  'display_index': ?instance.displayIndex,
  'probability': ?instance.probability,
  'depth': ?instance.depth,
  'outlet_name': ?instance.outletName,
  'group': ?instance.group,
  'group_override': ?instance.groupOverride,
  'group_weight': ?instance.groupWeight,
  'prevent_recursion': ?instance.preventRecursion,
  'delay_until_recursion': ?instance.delayUntilRecursion,
  'scan_depth': ?instance.scanDepth,
  'match_whole_words': ?instance.matchWholeWords,
  'use_group_scoring': ?instance.useGroupScoring,
  'case_sensitive': ?instance.caseSensitive,
  'automation_id': ?instance.automationId,
  'role': ?instance.role,
  'vectorized': ?instance.vectorized,
  'sticky': ?instance.sticky,
  'cooldown': ?instance.cooldown,
  'delay': ?instance.delay,
  'match_persona_description': ?instance.matchPersonaDescription,
  'match_character_description': ?instance.matchCharacterDescription,
  'match_character_personality': ?instance.matchCharacterPersonality,
  'match_character_depth_prompt': ?instance.matchCharacterDepthPrompt,
  'match_scenario': ?instance.matchScenario,
  'match_creator_notes': ?instance.matchCreatorNotes,
  'triggers': instance.triggers,
  'ignore_budget': ?instance.ignoreBudget,
};
