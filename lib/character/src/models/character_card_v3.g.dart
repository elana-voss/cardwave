// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_card_v3.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterCardV3 _$CharacterCardV3FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CharacterCardV3',
  json,
  ($checkedConvert) {
    final val = CharacterCardV3(
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
      tags: $checkedConvert('tags', (v) => _tagsFromJson(v)),
      creator: $checkedConvert('creator', (v) => v as String? ?? ''),
      characterVersion: $checkedConvert(
        'character_version',
        (v) => v as String? ?? '',
      ),
      groupOnlyGreetings: $checkedConvert(
        'group_only_greetings',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      assets: $checkedConvert(
        'assets',
        (v) =>
            (v as List<dynamic>?)
                ?.map((e) => Asset.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      ),
      lorebook: $checkedConvert(
        'character_book',
        (v) => v == null ? null : Lorebook.fromJson(v as Map<String, dynamic>),
      ),
      nickname: $checkedConvert('nickname', (v) => v as String?),
      creatorNotesMultilingual: $checkedConvert(
        'creator_notes_multilingual',
        (v) =>
            (v as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(k, e as String),
            ) ??
            {},
      ),
      source: $checkedConvert(
        'source',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      extensions: $checkedConvert(
        'extensions',
        (v) => v as Map<String, dynamic>? ?? {},
      ),
      creationDate: $checkedConvert(
        'creation_date',
        (v) => (v as num?)?.toInt(),
      ),
      modificationDate: $checkedConvert(
        'modification_date',
        (v) => (v as num?)?.toInt(),
      ),
      systemName: $checkedConvert('system_name', (v) => v as String?),
      avatar: $checkedConvert('avatar', (v) => v as String?),
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
    'groupOnlyGreetings': 'group_only_greetings',
    'lorebook': 'character_book',
    'creatorNotesMultilingual': 'creator_notes_multilingual',
    'creationDate': 'creation_date',
    'modificationDate': 'modification_date',
    'systemName': 'system_name',
  },
);

Map<String, dynamic> _$CharacterCardV3ToJson(CharacterCardV3 instance) =>
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
      'group_only_greetings': instance.groupOnlyGreetings,
      'character_book': ?instance.lorebook?.toJson(),
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'nickname': ?instance.nickname,
      'creator_notes_multilingual': instance.creatorNotesMultilingual,
      'source': instance.source,
      'extensions': instance.extensions,
      'creation_date': ?instance.creationDate,
      'modification_date': ?instance.modificationDate,
      'system_name': ?instance.systemName,
      'avatar': ?instance.avatar,
    };

Asset _$AssetFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Asset', json, ($checkedConvert) {
      final val = Asset(
        type: $checkedConvert('type', (v) => v as String),
        uri: $checkedConvert('uri', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        ext: $checkedConvert('ext', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$AssetToJson(Asset instance) => <String, dynamic>{
  'type': instance.type,
  'uri': instance.uri,
  'name': instance.name,
  'ext': instance.ext,
};

DepthPrompt _$DepthPromptFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DepthPrompt', json, ($checkedConvert) {
      final val = DepthPrompt(
        prompt: $checkedConvert('prompt', (v) => v as String? ?? ''),
        depth: $checkedConvert('depth', (v) => (v as num?)?.toInt() ?? 4),
        role: $checkedConvert(
          'role',
          (v) =>
              $enumDecodeNullable(
                _$DepthPromptRoleEnumEnumMap,
                v,
                unknownValue: DepthPromptRoleEnum.system,
              ) ??
              DepthPromptRoleEnum.system,
        ),
      );
      return val;
    });

Map<String, dynamic> _$DepthPromptToJson(DepthPrompt instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
      'depth': instance.depth,
      'role': _$DepthPromptRoleEnumEnumMap[instance.role]!,
    };

const _$DepthPromptRoleEnumEnumMap = {
  DepthPromptRoleEnum.system: 'system',
  DepthPromptRoleEnum.user: 'user',
  DepthPromptRoleEnum.assistant: 'assistant',
};

CardwaveExtension _$CardwaveExtensionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CardwaveExtension',
  json,
  ($checkedConvert) {
    final val = CardwaveExtension(
      isFavorite: $checkedConvert('is_favorite', (v) => v as bool? ?? false),
      isForLater: $checkedConvert('is_for_later', (v) => v as bool? ?? false),
      isArchived: $checkedConvert('is_archived', (v) => v as bool? ?? false),
      chatTheme: $checkedConvert('chat_theme', (v) => v as String?),
      previewDescription: $checkedConvert(
        'preview_description',
        (v) => v as String?,
      ),
      appThemeString: $checkedConvert('app_theme', (v) => v as String?),
      talkativeness: $checkedConvert(
        'talkativeness',
        (v) => (v as num?)?.toDouble() ?? 0.5,
      ),
      customAvatar: $checkedConvert('custom_avatar', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'isFavorite': 'is_favorite',
    'isForLater': 'is_for_later',
    'isArchived': 'is_archived',
    'chatTheme': 'chat_theme',
    'previewDescription': 'preview_description',
    'appThemeString': 'app_theme',
    'customAvatar': 'custom_avatar',
  },
);

Map<String, dynamic> _$CardwaveExtensionToJson(CardwaveExtension instance) =>
    <String, dynamic>{
      'is_favorite': instance.isFavorite,
      'is_for_later': instance.isForLater,
      'is_archived': instance.isArchived,
      'chat_theme': ?instance.chatTheme,
      'preview_description': ?instance.previewDescription,
      'app_theme': ?instance.appThemeString,
      'talkativeness': instance.talkativeness,
      'custom_avatar': ?instance.customAvatar,
    };
