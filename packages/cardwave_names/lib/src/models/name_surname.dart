import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:json_annotation/json_annotation.dart';

part 'name_surname.g.dart';

/// Surname-only record. Carries the culture, mythology, race, era,
/// genre, themes, commonness, plus the surname-applicable person-level
/// tags `role` (Blackwood → villain-coded) and `allure` (Featherstonehaugh
/// reads sophisticated). Gender / age / intelligence carry too weak a
/// signal on surnames to be classified.
@JsonSerializable(explicitToJson: true)
class NameSurname {
  const NameSurname({
    required this.name,
    required this.languageEthnicity,
    this.mythology,
    required this.race,
    required this.era,
    required this.role,
    required this.allure,
    required this.commonness,
    required this.genre,
    required this.themes,
  });

  factory NameSurname.fromJson(Map<String, dynamic> json) =>
      _$NameSurnameFromJson(json);

  final String name;
  final LanguageEthnicityEnum languageEthnicity;
  final MythologyEnum? mythology;
  final RaceEnum race;

  /// Eras the surname evokes. Multi-value to match the first-name side,
  /// though in practice surname loaders only assign one era per entry
  /// today (the classifier doesn't expand surname era).
  @JsonKey(defaultValue: <EraEnum>[])
  final List<EraEnum> era;

  /// Narrative archetypes the surname evokes. Multi-value: Blackwood
  /// fits villain AND antihero; Ashford reads mentor + hero.
  @JsonKey(defaultValue: <RoleEnum>[])
  final List<RoleEnum> role;

  /// How aesthetically attractive the surname sounds.
  final AllureEnum allure;

  /// How recognizable / frequent the surname is. Common = Smith, Garcia;
  /// rare = Polkinghorne, Featherstonehaugh.
  final CommonnessEnum commonness;

  @JsonKey(defaultValue: <GenreEnum>[])
  final List<GenreEnum> genre;

  @JsonKey(defaultValue: <ThemeEnum>[])
  final List<ThemeEnum> themes;

  Map<String, dynamic> toJson() => _$NameSurnameToJson(this);
}
