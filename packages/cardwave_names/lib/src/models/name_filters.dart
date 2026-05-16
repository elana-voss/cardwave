import 'package:cardwave_names/src/models/name_filter_field.dart';
import 'package:cardwave_names/src/models/name_taxonomy.dart';
import 'package:json_annotation/json_annotation.dart';

part 'name_filters.g.dart';

/// Request payload for [NameDatabase.pickName]. Every field optional —
/// nulls mean "don't constrain on this axis". Built from the LLM's
/// tool-call args dict via [NameFilters.fromJson].
@JsonSerializable(explicitToJson: true)
class NameFilters {
  const NameFilters({
    this.gender,
    this.languageEthnicity,
    this.mythology,
    this.race,
    this.age,
    this.era,
    this.role,
    this.intelligence,
    this.allure,
    this.commonness,
    this.genre,
    this.themes,
  });

  factory NameFilters.fromJson(Map<String, dynamic> json) =>
      _$NameFiltersFromJson(json);

  final GenderEnum? gender;
  final LanguageEthnicityEnum? languageEthnicity;
  final MythologyEnum? mythology;
  final RaceEnum? race;
  final AgeEnum? age;
  final EraEnum? era;
  final RoleEnum? role;
  final IntelligenceEnum? intelligence;
  final AllureEnum? allure;
  final CommonnessEnum? commonness;
  final GenreEnum? genre;
  final List<ThemeEnum>? themes;

  /// Returns a copy with the named [field] cleared to null. Used by the
  /// degradation loop to drop one constraint at a time when the candidate
  /// pool is empty.
  NameFilters withoutField(NameFilterField field) {
    return NameFilters(
      gender: field == NameFilterField.gender ? null : gender,
      languageEthnicity: field == NameFilterField.languageEthnicity
          ? null
          : languageEthnicity,
      mythology: field == NameFilterField.mythology ? null : mythology,
      race: field == NameFilterField.race ? null : race,
      age: field == NameFilterField.age ? null : age,
      era: field == NameFilterField.era ? null : era,
      role: field == NameFilterField.role ? null : role,
      intelligence: field == NameFilterField.intelligence ? null : intelligence,
      allure: field == NameFilterField.allure ? null : allure,
      commonness: field == NameFilterField.commonness ? null : commonness,
      genre: field == NameFilterField.genre ? null : genre,
      themes: field == NameFilterField.themes ? null : themes,
    );
  }

  Map<String, dynamic> toJson() => _$NameFiltersToJson(this);
}
