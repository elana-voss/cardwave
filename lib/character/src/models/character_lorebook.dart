import 'package:json_annotation/json_annotation.dart';

part 'lorebook_entry_extensions.dart';

part 'character_lorebook.g.dart';

List<String> _cleanStringList(List<String> list) {
  return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class Lorebook {
  Lorebook({
    required this.entries,
    this.name,
    this.description,
    this.scanDepth,
    this.tokenBudget,
    this.recursiveScanning,
    Map<String, dynamic>? extensions,
  }) : extensions = extensions ?? {};

  factory Lorebook.fromJson(Map<String, dynamic> json) {
    final book = _$LorebookFromJson(json);
    if (book.name != null) book.name = book.name!.trim();
    if (book.description != null) book.description = book.description!.trim();
    return book;
  }
  @JsonKey(defaultValue: [])
  List<LorebookEntry> entries;
  String? name;
  String? description;
  int? scanDepth;
  int? tokenBudget;
  bool? recursiveScanning;
  @JsonKey(defaultValue: {})
  Map<String, dynamic> extensions;

  Map<String, dynamic> toJson() => _$LorebookToJson(this);
}

String? _positionFromJson(dynamic value) {
  if (value is int) {
    if (value == 0) return 'before_char';
    if (value == 1) return 'after_char';
    return value.toString();
  }
  return value as String?;
}

LorebookEntryExtensions _extensionsFromJson(dynamic json) {
  if (json == null) return LorebookEntryExtensions();
  return LorebookEntryExtensions.fromJson(json as Map<String, dynamic>);
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class LorebookEntry {
  LorebookEntry({
    this.id,
    List<String>? keys,
    List<String>? secondaryKeys,
    this.comment,
    this.content,
    this.name,
    this.priority,
    this.constant,
    this.selective,
    this.useProbability,
    this.selectiveLogic,
    this.insertionOrder,
    this.enabled,
    this.position,
    this.useRegex,
    this.caseSensitive,
    this.characterFilter,
    LorebookEntryExtensions? extensions,
  }) : keys = keys ?? [],
       secondaryKeys = secondaryKeys ?? [],
       extensions = extensions ?? LorebookEntryExtensions();

  factory LorebookEntry.fromJson(Map<String, dynamic> json) {
    final entry = _$LorebookEntryFromJson(json);
    entry.keys = _cleanStringList(entry.keys);
    entry.secondaryKeys = _cleanStringList(entry.secondaryKeys);
    if (entry.comment != null) entry.comment = entry.comment!.trim();
    if (entry.content != null) entry.content = entry.content!.trim();
    if (entry.name != null) entry.name = entry.name!.trim();
    return entry;
  }
  // SillyTavern lorebook entry ids are sometimes an int, sometimes a
  // string — kept as-is on round-trip.
  Object? id;
  @JsonKey(defaultValue: [])
  List<String> keys;
  @JsonKey(defaultValue: [])
  List<String> secondaryKeys;
  String? comment;
  String? content;
  String? name;
  int? priority;
  bool? constant;
  bool? selective;

  // SillyTavern stores these two fields at the entry root with camelCase
  // keys (verified against `world-info.js`'s `originalWIDataKeyMap` and the
  // entry-edit code paths). The explicit names override the project-wide
  // field_rename: snake to keep community-card import/export round-tripping.
  @JsonKey(name: 'useProbability')
  bool? useProbability;
  @JsonKey(name: 'selectiveLogic')
  int? selectiveLogic;
  int? insertionOrder;
  bool? enabled;
  @JsonKey(fromJson: _positionFromJson)
  String? position; // Root position (string)
  bool? useRegex;
  bool? caseSensitive;

  CharacterFilter? characterFilter;
  @JsonKey(fromJson: _extensionsFromJson)
  LorebookEntryExtensions extensions;

  Map<String, dynamic> toJson() => _$LorebookEntryToJson(this);
}

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class CharacterFilter {
  CharacterFilter({
    this.names = const [],
    this.tags = const [],
    this.isExclude = false,
  });

  factory CharacterFilter.fromJson(Map<String, dynamic> json) {
    final filter = _$CharacterFilterFromJson(json);
    filter.names = _cleanStringList(filter.names);
    filter.tags = _cleanStringList(filter.tags);
    return filter;
  }
  @JsonKey(defaultValue: [])
  List<String> names;
  @JsonKey(defaultValue: [])
  List<String> tags;
  @JsonKey(defaultValue: false)
  bool isExclude;

  Map<String, dynamic> toJson() => _$CharacterFilterToJson(this);
}

int? _delayFromJson(dynamic value) {
  if (value is bool) {
    return value ? 1 : 0;
  }
  if (value is int) {
    return value;
  }
  return null;
}

int? _extensionPositionFromJson(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    if (value == 'before_char') return 0;
    if (value == 'after_char') return 1;
    return int.tryParse(value);
  }
  return null;
}
