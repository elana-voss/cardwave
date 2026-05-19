import 'package:cardwave/character/src/models/character_card_v2.dart';
import 'package:cardwave/character/src/models/character_lorebook.dart';
import 'package:cardwave/character/src/utils/tag_normalizer.dart';
import 'package:cardwave/common/common.dart';
import 'package:json_annotation/json_annotation.dart';

part 'character_card_v3.g.dart';

List<String> _tagsFromJson(dynamic value) {
  if (value is List) {
    return value
        .where((e) => e != null)
        .map((e) => normalizeTagEntry(e.toString()))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
  return [];
}

List<String> _cleanStringList(List<String> list) {
  return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class CharacterCardV3 {
  CharacterCardV3({
    required this.name,
    required this.description,
    required this.personality,
    required this.scenario,
    required this.firstMes,
    required this.mesExample,
    required this.creatorNotes,
    required this.systemPrompt,
    required this.postHistoryInstructions,
    required this.alternateGreetings,
    required this.tags,
    required this.creator,
    required this.characterVersion,
    required this.groupOnlyGreetings,
    List<Asset>? assets,
    this.lorebook,
    this.nickname,
    Map<String, String>? creatorNotesMultilingual,
    List<String>? source,
    Map<String, dynamic>? extensions,
    this.creationDate,
    this.modificationDate,
    this.systemName,
    this.avatar,
  }) : assets = assets ?? [],
       creatorNotesMultilingual = creatorNotesMultilingual ?? {},
       source = source ?? [],
       extensions = extensions ?? {};

  factory CharacterCardV3.fromJson(Map<String, dynamic> json) {
    final card = _$CharacterCardV3FromJson(json);

    card.name = card.name.trim();
    card.description = card.description.trim();
    card.personality = card.personality.trim();
    card.scenario = card.scenario.trim();
    card.firstMes = card.firstMes.trim();
    card.mesExample = card.mesExample.trim();
    card.creatorNotes = card.creatorNotes.trim();
    card.systemPrompt = card.systemPrompt.trim();
    card.postHistoryInstructions = card.postHistoryInstructions.trim();
    card.creator = card.creator.trim();
    card.characterVersion = card.characterVersion.trim();

    if (card.nickname != null) card.nickname = card.nickname!.trim();
    if (card.systemName != null) card.systemName = card.systemName!.trim();

    card.alternateGreetings = _cleanStringList(card.alternateGreetings);
    card.groupOnlyGreetings = _cleanStringList(card.groupOnlyGreetings);

    return card;
  }

  factory CharacterCardV3.createDefault() {
    return CharacterCardV3(
      name: 'New Character',
      description: '',
      firstMes: '',
      mesExample: '',
      personality: '',
      scenario: '',
      systemPrompt: '',
      postHistoryInstructions: '',
      alternateGreetings: [],
      tags: [],
      creator: '',
      characterVersion: '',
      extensions: {},
      creatorNotes: '',
      groupOnlyGreetings: [],
      assets: [
        Asset(type: 'icon', uri: 'ccdefault:', name: 'main', ext: 'png'),
      ],
    );
  }
  @JsonKey(defaultValue: '')
  String name;
  @JsonKey(defaultValue: '')
  String description;
  @JsonKey(defaultValue: '')
  String personality;
  @JsonKey(defaultValue: '')
  String scenario;
  @JsonKey(defaultValue: '')
  String firstMes;
  @JsonKey(defaultValue: '')
  String mesExample;
  @JsonKey(defaultValue: '')
  String creatorNotes;
  @JsonKey(defaultValue: '')
  String systemPrompt;
  @JsonKey(defaultValue: '')
  String postHistoryInstructions;
  @JsonKey(defaultValue: [])
  List<String> alternateGreetings;
  @JsonKey(fromJson: _tagsFromJson)
  List<String> tags;
  @JsonKey(defaultValue: '')
  String creator;
  @JsonKey(defaultValue: '')
  String characterVersion;
  @JsonKey(defaultValue: [])
  List<String> groupOnlyGreetings;
  @JsonKey(name: 'character_book')
  Lorebook? lorebook;
  @JsonKey(defaultValue: [])
  List<Asset> assets;

  // V3 specific & Extensions
  String? nickname;
  @JsonKey(defaultValue: {})
  Map<String, String> creatorNotesMultilingual;
  @JsonKey(defaultValue: [])
  List<String> source;
  @JsonKey(defaultValue: {})
  Map<String, dynamic> extensions;
  int? creationDate;
  int? modificationDate;
  String? systemName;
  String? avatar;

  @JsonKey(includeFromJson: false, includeToJson: false)
  CardwaveExtension? _cardwaveDataCache;

  @JsonKey(includeFromJson: false, includeToJson: false)
  DepthPrompt? _depthPromptCache;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool _depthPromptCacheSet = false;

  Map<String, dynamic> toJson() {
    if (_cardwaveDataCache != null) {
      extensions['cardwave'] = _cardwaveDataCache!.toJson();
    }
    if (_depthPromptCacheSet) {
      if (_depthPromptCache == null) {
        extensions.remove('depth_prompt');
      } else {
        extensions['depth_prompt'] = _depthPromptCache!.toJson();
      }
    }
    return _$CharacterCardV3ToJson(this);
  }

  CharacterCardV2 toV2() {
    return CharacterCardV2.fromJson(toJson());
  }

  /// User-facing name. Prefers [nickname] when set, otherwise [name].
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get displayName => nickname ?? name;

  @JsonKey(includeFromJson: false, includeToJson: false)
  CardwaveExtension get cardwaveData {
    if (_cardwaveDataCache != null) return _cardwaveDataCache!;
    final data = extensions['cardwave'];
    if (data is Map<String, dynamic>) {
      try {
        _cardwaveDataCache = CardwaveExtension.fromJson(data);
        return _cardwaveDataCache!;
      } on Exception catch (e, stackTrace) {
        LoggingService().warning(
          'Malformed cardwave extension on card "$name" — using defaults',
          e,
          stackTrace,
        );
      }
    }
    _cardwaveDataCache = CardwaveExtension();
    return _cardwaveDataCache!;
  }

  set cardwaveData(CardwaveExtension value) {
    _cardwaveDataCache = value;
    extensions['cardwave'] = value.toJson();
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  DepthPrompt? get depthPrompt {
    if (_depthPromptCacheSet) return _depthPromptCache;
    final data = extensions['depth_prompt'];
    if (data is Map<String, dynamic>) {
      try {
        _depthPromptCache = DepthPrompt.fromJson(data);
      } on Exception {
        _depthPromptCache = null;
      }
    } else {
      _depthPromptCache = null;
    }
    _depthPromptCacheSet = true;
    return _depthPromptCache;
  }

  set depthPrompt(DepthPrompt? value) {
    _depthPromptCache = value;
    _depthPromptCacheSet = true;
    if (value == null) {
      extensions.remove('depth_prompt');
    } else {
      extensions['depth_prompt'] = value.toJson();
    }
  }

  void transformAllStrings(String Function(String) processor) {
    name = processor(name);
    description = processor(description);
    personality = processor(personality);
    scenario = processor(scenario);
    firstMes = processor(firstMes);
    mesExample = processor(mesExample);
    creatorNotes = processor(creatorNotes);
    systemPrompt = processor(systemPrompt);
    postHistoryInstructions = processor(postHistoryInstructions);
    creator = processor(creator);
    characterVersion = processor(characterVersion);
    if (nickname != null) nickname = processor(nickname!);
    if (systemName != null) systemName = processor(systemName!);

    alternateGreetings = alternateGreetings.map(processor).toList();
    groupOnlyGreetings = groupOnlyGreetings.map(processor).toList();
    tags = tags.map(processor).toList();

    if (lorebook != null) {
      for (final entry in lorebook!.entries) {
        if (entry.comment != null) entry.comment = processor(entry.comment!);
        if (entry.content != null) entry.content = processor(entry.content!);
        if (entry.name != null) entry.name = processor(entry.name!);
        entry.keys = entry.keys.map(processor).toList();
        entry.secondaryKeys = entry.secondaryKeys.map(processor).toList();
      }
    }

    final currentDepthPrompt = depthPrompt;
    if (currentDepthPrompt != null) {
      currentDepthPrompt.prompt = processor(currentDepthPrompt.prompt);
      depthPrompt = currentDepthPrompt;
    }
  }
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class Asset {
  Asset({
    required this.type,
    required this.uri,
    required this.name,
    required this.ext,
  });

  factory Asset.fromJson(Map<String, dynamic> json) => _$AssetFromJson(json);
  String type;
  String uri;
  String name;
  String ext;
  Map<String, dynamic> toJson() => _$AssetToJson(this);
}

enum DepthPromptRoleEnum {
  @JsonValue('system')
  system,
  @JsonValue('user')
  user,
  @JsonValue('assistant')
  assistant,
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class DepthPrompt {
  DepthPrompt({required this.prompt, required this.depth, required this.role});

  factory DepthPrompt.fromJson(Map<String, dynamic> json) =>
      _$DepthPromptFromJson(json);
  @JsonKey(defaultValue: '')
  String prompt;

  @JsonKey(defaultValue: 4)
  int depth;

  @JsonKey(
    defaultValue: DepthPromptRoleEnum.system,
    unknownEnumValue: DepthPromptRoleEnum.system,
  )
  DepthPromptRoleEnum role;
  Map<String, dynamic> toJson() => _$DepthPromptToJson(this);
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class CardwaveExtension {
  CardwaveExtension({
    this.isFavorite = false,
    this.isForLater = false,
    this.isArchived = false,
    this.chatTheme,
    this.previewDescription,
    this.appThemeString,
    this.talkativeness = 0.5,
    this.customAvatar,
  });

  factory CardwaveExtension.fromJson(Map<String, dynamic> json) =>
      _$CardwaveExtensionFromJson(json);
  @JsonKey(defaultValue: false)
  bool isFavorite;

  @JsonKey(defaultValue: false)
  bool isForLater;

  @JsonKey(defaultValue: false)
  bool isArchived;

  String? chatTheme;

  String? previewDescription;

  @JsonKey(name: 'app_theme')
  String? appThemeString;

  @JsonKey(defaultValue: 0.5)
  double talkativeness;

  /// Relative path (cards-domain) to a user-chosen image that replaces the
  /// card PNG for display purposes (thumbnail, background, grid).
  String? customAvatar;
  Map<String, dynamic> toJson() => _$CardwaveExtensionToJson(this);

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isDarkTheme => appThemeString == 'dark';
  void setDarkTheme(bool value) => appThemeString = value ? 'dark' : null;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isBrightTheme => appThemeString == 'bright';
  void setBrightTheme(bool value) => appThemeString = value ? 'bright' : null;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isSystemTheme => appThemeString == 'system';
  void setSystemTheme(bool value) => appThemeString = value ? 'system' : null;
}
