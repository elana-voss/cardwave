import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:json_annotation/json_annotation.dart';

part 'name_surname.g.dart';

/// Surname-only record. Carries the culture, mythology, race, era and
/// genre/theme tags but not the person-level fields (gender, age, role,
/// intelligence, allure) — those are properties of the bearer, not
/// the family name.
@JsonSerializable(explicitToJson: true)
class NameSurname {
  const NameSurname({
    required this.name,
    required this.languageEthnicity,
    this.mythology,
    required this.race,
    required this.era,
    required this.genre,
    required this.themes,
  });

  factory NameSurname.fromJson(Map<String, dynamic> json) =>
      _$NameSurnameFromJson(json);

  final String name;
  final LanguageEthnicityEnum languageEthnicity;
  final MythologyEnum? mythology;
  final RaceEnum race;
  final EraEnum era;

  @JsonKey(defaultValue: <GenreEnum>[])
  final List<GenreEnum> genre;

  @JsonKey(defaultValue: <ThemeEnum>[])
  final List<ThemeEnum> themes;

  Map<String, dynamic> toJson() => _$NameSurnameToJson(this);
}
