// Intermediate records the Phase 1 loaders emit. Fields the loader could
// fill from the source corpus hold real values; fields it couldn't fill
// hold sentinel defaults and their names appear in [sentinelFields].
// Phase 2 reads [sentinelFields] to decide which fields to ask Claude to
// classify.

import 'local_taxonomy.dart';

/// Shared parent path for every per-corpus loader. Loaders join their
/// own subfolder name onto this — keeps the relative-from-app/ knowledge
/// in one place.
const datasetRoot = '../memory-bank/name_datasets';

/// Identifies which fields on a candidate record hold a sentinel value
/// rather than a source-derived one. Phase 2 reads this set to know
/// what to ask Claude to fill. Field names match the wire JSON keys so
/// the LLM prompt can reference them directly.
enum SentinelField {
  gender,
  age,
  era,
  role,
  intelligence,
  allure,
  commonness,
  genre,
  themes,
}

const _sentinelGender = GenderEnum.ambiguous;
const _sentinelAge = <AgeEnum>[AgeEnum.adult];
const _sentinelRole = <RoleEnum>[RoleEnum.neutral];
const _sentinelIntelligence = 3;
const _sentinelAllure = 3;
const _sentinelCommonness = CommonnessEnum.uncommon;

/// Era sentinel by race. Non-human entries have no Earth-era binding
/// so they default to `timeless`; humans default to `modern`. The
/// human case stays sentinel so Phase 2 can revise it; the non-human
/// case is locked (era is removed from sentinelFields for non-human).
List<EraEnum> _defaultEraFor(RaceEnum race) =>
    race == RaceEnum.human ? const [EraEnum.modern] : const [EraEnum.timeless];

/// First-name candidate. Mutable so the merge step can upgrade sentinel
/// fields when a later corpus contributes a real value.
class CandidateFirstName {
  CandidateFirstName({
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
    required this.sentinelFields,
  });

  /// Build a record with every subjective field as sentinel. Loaders fill
  /// in what the source tells them and remove those keys from
  /// [sentinelFields].
  factory CandidateFirstName.sentinel({
    required String name,
    required LanguageEthnicityEnum languageEthnicity,
    GenderEnum? gender,
    MythologyEnum? mythology,
    RaceEnum race = RaceEnum.human,
    List<EraEnum>? era,
    List<AgeEnum>? age,
    List<RoleEnum>? role,
    List<GenreEnum> genre = const [],
    List<ThemeEnum> themes = const [],
  }) {
    final isHuman = race == RaceEnum.human;
    final fields = <SentinelField>{
      if (gender == null) SentinelField.gender,
      if (age == null) SentinelField.age,
      if (era == null && isHuman) SentinelField.era,
      if (role == null) SentinelField.role,
      SentinelField.intelligence,
      SentinelField.allure,
      SentinelField.commonness,
      if (themes.isEmpty) SentinelField.themes,
      if (genre.isEmpty) SentinelField.genre,
    };
    return CandidateFirstName(
      name: name,
      gender: gender ?? _sentinelGender,
      languageEthnicity: languageEthnicity,
      mythology: mythology,
      race: race,
      age: age ?? _sentinelAge,
      era: era ?? _defaultEraFor(race),
      role: role ?? _sentinelRole,
      intelligence: _sentinelIntelligence,
      allure: _sentinelAllure,
      commonness: _sentinelCommonness,
      genre: List.of(genre),
      themes: List.of(themes),
      sentinelFields: fields,
    );
  }

  final String name;
  GenderEnum gender;
  LanguageEthnicityEnum languageEthnicity;
  MythologyEnum? mythology;
  RaceEnum race;
  List<AgeEnum> age;
  List<EraEnum> era;
  List<RoleEnum> role;
  int intelligence;
  int allure;
  CommonnessEnum commonness;
  List<GenreEnum> genre;
  List<ThemeEnum> themes;
  Set<SentinelField> sentinelFields;

  Map<String, dynamic> toJson() => {
    'name': name,
    'gender': gender.name,
    'language_ethnicity': languageEthnicity.name,
    'mythology': mythology?.name,
    'race': race.name,
    'age': age.map((e) => e.name).toList(),
    'era': era.map((e) => e.name).toList(),
    'role': role.map((e) => e.name).toList(),
    'intelligence': intelligence,
    'allure': allure,
    'commonness': commonness.name,
    'genre': genre.map((e) => e.name).toList(),
    'themes': themes.map((e) => e.name).toList(),
    'sentinel_fields': (sentinelFields.map((e) => e.name).toList()..sort()),
  };
}

/// Surname candidate. Subset of first-name fields — surnames don't carry
/// person-level axes.
class CandidateLastName {
  CandidateLastName({
    required this.name,
    required this.languageEthnicity,
    this.mythology,
    required this.race,
    required this.era,
    required this.commonness,
    required this.genre,
    required this.themes,
    required this.sentinelFields,
  });

  factory CandidateLastName.sentinel({
    required String name,
    required LanguageEthnicityEnum languageEthnicity,
    MythologyEnum? mythology,
    RaceEnum race = RaceEnum.human,
    List<EraEnum>? era,
    List<GenreEnum> genre = const [],
    List<ThemeEnum> themes = const [],
  }) {
    final isHuman = race == RaceEnum.human;
    final fields = <SentinelField>{
      if (era == null && isHuman) SentinelField.era,
      SentinelField.commonness,
      if (themes.isEmpty) SentinelField.themes,
      if (genre.isEmpty) SentinelField.genre,
    };
    return CandidateLastName(
      name: name,
      languageEthnicity: languageEthnicity,
      mythology: mythology,
      race: race,
      era: era ?? _defaultEraFor(race),
      commonness: _sentinelCommonness,
      genre: List.of(genre),
      themes: List.of(themes),
      sentinelFields: fields,
    );
  }

  final String name;
  LanguageEthnicityEnum languageEthnicity;
  MythologyEnum? mythology;
  RaceEnum race;
  List<EraEnum> era;
  CommonnessEnum commonness;
  List<GenreEnum> genre;
  List<ThemeEnum> themes;
  Set<SentinelField> sentinelFields;

  Map<String, dynamic> toJson() => {
    'name': name,
    'language_ethnicity': languageEthnicity.name,
    'mythology': mythology?.name,
    'race': race.name,
    'era': era.map((e) => e.name).toList(),
    'commonness': commonness.name,
    'genre': genre.map((e) => e.name).toList(),
    'themes': themes.map((e) => e.name).toList(),
    'sentinel_fields': (sentinelFields.map((e) => e.name).toList()..sort()),
  };
}

/// What a per-corpus loader returns. Iterables, not Lists, so a huge
/// corpus (philipperemy with 700k+ names) doesn't have to materialise the
/// whole record set in memory before the merge step picks it up.
class LoaderResult {
  const LoaderResult({
    this.firstNames = const [],
    this.lastNames = const [],
  });

  final Iterable<CandidateFirstName> firstNames;
  final Iterable<CandidateLastName> lastNames;
}
