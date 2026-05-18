part of 'character_lorebook.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true, checked: true)
class LorebookEntryExtensions {
  LorebookEntryExtensions({
    this.position,
    this.excludeRecursion,
    this.displayIndex,
    this.probability,
    this.depth,
    this.outletName,
    this.group,
    this.groupOverride,
    this.groupWeight,
    this.preventRecursion,
    this.delayUntilRecursion,
    this.scanDepth,
    this.matchWholeWords,
    this.useGroupScoring,
    this.caseSensitive,
    this.automationId,
    this.role,
    this.vectorized,
    this.sticky,
    this.cooldown,
    this.delay,
    this.matchPersonaDescription,
    this.matchCharacterDescription,
    this.matchCharacterPersonality,
    this.matchCharacterDepthPrompt,
    this.matchScenario,
    this.matchCreatorNotes,
    List<String>? triggers,
    this.ignoreBudget,
  }) : triggers = triggers ?? [];

  factory LorebookEntryExtensions.fromJson(Map<String, dynamic> json) {
    final exts = _$LorebookEntryExtensionsFromJson(json);
    exts.triggers = _cleanStringList(exts.triggers);
    return exts;
  }
  @JsonKey(fromJson: _extensionPositionFromJson)
  int? position; // Numeric position (0-7)
  bool? excludeRecursion;
  int? displayIndex;
  int? probability;
  int? depth;
  String? outletName;
  String? group;
  bool? groupOverride;
  int? groupWeight;
  bool? preventRecursion;
  @JsonKey(fromJson: _delayFromJson)
  int? delayUntilRecursion;
  int? scanDepth;
  bool? matchWholeWords;
  bool? useGroupScoring;
  bool? caseSensitive;
  String? automationId;
  int? role;
  bool? vectorized;
  int? sticky;
  int? cooldown;
  int? delay;
  bool? matchPersonaDescription;
  bool? matchCharacterDescription;
  bool? matchCharacterPersonality;
  bool? matchCharacterDepthPrompt;
  bool? matchScenario;
  bool? matchCreatorNotes;
  @JsonKey(defaultValue: [])
  List<String> triggers;
  bool? ignoreBudget;

  Map<String, dynamic> toJson() => _$LorebookEntryExtensionsToJson(this);
}
