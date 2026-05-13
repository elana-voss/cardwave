import 'package:cardwave/character/src/models/character_card_v3.dart';
import 'package:cardwave/character/src/models/character_lorebook.dart';
import 'package:json_annotation/json_annotation.dart';

part 'character_card_v2.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class CharacterCardV2 {
  CharacterCardV2({
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
    Map<String, dynamic>? extensions,
    this.lorebook,
  }) : extensions = extensions ?? {};

  factory CharacterCardV2.fromJson(Map<String, dynamic> json) =>
      _$CharacterCardV2FromJson(json);
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
  @JsonKey(defaultValue: [])
  List<String> tags;
  @JsonKey(defaultValue: '')
  String creator;
  @JsonKey(defaultValue: '')
  String characterVersion;
  @JsonKey(defaultValue: {})
  Map<String, dynamic> extensions;
  @JsonKey(name: 'character_book')
  Lorebook? lorebook;
  Map<String, dynamic> toJson() => _$CharacterCardV2ToJson(this);

  CharacterCardV3 toV3() {
    final json = toJson();
    json['assets'] = [
      {'type': 'icon', 'uri': 'ccdefault:', 'name': 'main', 'ext': 'png'},
    ];
    return CharacterCardV3.fromJson(json);
  }
}
