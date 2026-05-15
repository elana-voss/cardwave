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
  final AgeEnum age;
  final EraEnum era;
  final RoleEnum role;

  /// 1 (very dim) .. 5 (very intelligent). LLM-facing tool param uses
  /// the [IntelligenceBucketEnum] coarse buckets.
  final int intelligence;

  /// 1 (very plain) .. 5 (very sexy). Same bucket mapping as
  /// [intelligence].
  final int allure;

  @JsonKey(defaultValue: <GenreEnum>[])
  final List<GenreEnum> genre;

  @JsonKey(defaultValue: <ThemeEnum>[])
  final List<ThemeEnum> themes;

  Map<String, dynamic> toJson() => _$NameEntryToJson(this);
}
