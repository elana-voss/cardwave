import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:json_annotation/json_annotation.dart';

part 'name_entry.g.dart';

@JsonSerializable(explicitToJson: true)
class NameEntry {
  const NameEntry({
    required this.name,
    required this.gender,
    required this.languageEthnicity,
    this.mythology,
    required this.race,
    required this.age,
    required this.era,
    required this.role,
    required this.intelligence,
    required this.allure,
    required this.commonness,
    required this.genre,
    required this.themes,
  });

  factory NameEntry.fromJson(Map<String, dynamic> json) =>
      _$NameEntryFromJson(json);

  final String name;
  final GenderEnum gender;
  final LanguageEthnicityEnum languageEthnicity;
  final MythologyEnum? mythology;
  final RaceEnum race;

  /// Lifestages the name evokes. Multi-value: a name like "Liam" reads
  /// youngAdult AND adult; "Eleanor" can read adult AND elder. The
  /// classify schema caps the list at 3.
  @JsonKey(defaultValue: <AgeEnum>[])
  final List<AgeEnum> age;

  /// Eras the name evokes. Multi-value because most period-coded names
  /// span more than one period — "Mildred" peaks victorian but persists
  /// midcentury; "Eleanor" reads across victorian / midcentury / modern.
  @JsonKey(defaultValue: <EraEnum>[])
  final List<EraEnum> era;

  /// Narrative archetypes the name evokes. Multi-value because the same
  /// name often fits multiple roles ("Cassius" reads villain OR
  /// antihero; "Arthur" reads hero OR mentor).
  @JsonKey(defaultValue: <RoleEnum>[])
  final List<RoleEnum> role;

  /// How cerebral the name sounds, on a 5-level scale.
  final IntelligenceEnum intelligence;

  /// How aesthetically attractive the name sounds, on a 5-level scale.
  final AllureEnum allure;

  /// How recognizable / frequent the name is. Common = the LLM's
  /// default-pick territory; rare = distinctive picks for named NPCs.
  final CommonnessEnum commonness;

  @JsonKey(defaultValue: <GenreEnum>[])
  final List<GenreEnum> genre;

  @JsonKey(defaultValue: <ThemeEnum>[])
  final List<ThemeEnum> themes;

  Map<String, dynamic> toJson() => _$NameEntryToJson(this);
}
