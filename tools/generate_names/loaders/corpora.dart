// dariusk/corpora loader.
//
// CC0 public-domain bot corpora. We pick a curated subset from
// data/humans/ (US-Census first/last, gender-neutral, Spanish, Norway)
// and data/mythology/ (lovecraft + per-pantheon god lists). The full
// directory has many irrelevant files (occupations, body parts, …); we
// only load the ones below.
//
// tolkienCharacterNames.json is intentionally skipped — too IP-
// recognizable, would make NPCs feel referential.
// monsters.json is skipped — it's creature TYPES (angel, centaur), not
// personal names.
// hebrew_god.json is skipped — single entry.

import 'dart:convert';
import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _humansRoot = '$datasetRoot/corpora/data/humans';
const _mythologyRoot = '$datasetRoot/corpora/data/mythology';

/// Cap per human-name list. Country-frequency lists in corpora (US
/// Census firstNames, Norway Statistics) carry immigrant names at lower
/// ranks; capping at 100 keeps mostly native names. Mythology lists are
/// not capped — they're already small and curated by pantheon.
const _topNPerHumanList = 100;

LoaderResult loadCorpora() {
  final firstNames = <CandidateFirstName>[];
  final lastNames = <CandidateLastName>[];

  // ---- humans ----
  _readFirstNames(
    '$_humansRoot/firstNames.json',
    listKey: 'firstNames',
    ethnicity: LanguageEthnicityEnum.english,
    gender: null, // mixed-gender pool
    into: firstNames,
  );
  _readLastNames(
    '$_humansRoot/lastNames.json',
    listKey: 'lastNames',
    ethnicity: LanguageEthnicityEnum.english,
    into: lastNames,
  );
  _readFirstNames(
    '$_humansRoot/neutralNames.json',
    listKey: 'neutralNames',
    ethnicity: LanguageEthnicityEnum.english,
    gender: GenderEnum.ambiguous,
    into: firstNames,
  );
  _readFirstNames(
    '$_humansRoot/spanishFirstNames.json',
    listKey: 'firstNames',
    ethnicity: LanguageEthnicityEnum.spanish,
    gender: null,
    into: firstNames,
  );
  _readLastNames(
    '$_humansRoot/spanishLastNames.json',
    listKey: 'lastNames',
    ethnicity: LanguageEthnicityEnum.spanish,
    into: lastNames,
  );
  _readFirstNames(
    '$_humansRoot/norwayFirstNamesBoys.json',
    listKey: 'firstnames_boys_norwegian',
    ethnicity: LanguageEthnicityEnum.norwegian,
    gender: GenderEnum.male,
    into: firstNames,
  );
  _readFirstNames(
    '$_humansRoot/norwayFirstNamesGirls.json',
    listKey: 'firstnames_girls_norwegian',
    ethnicity: LanguageEthnicityEnum.norwegian,
    gender: GenderEnum.female,
    into: firstNames,
  );
  _readLastNames(
    '$_humansRoot/norwayLastNames.json',
    listKey: 'lastnames_norwegian',
    ethnicity: LanguageEthnicityEnum.norwegian,
    into: lastNames,
  );

  // ---- mythology ----
  _readMythology(
    '$_mythologyRoot/greek_gods.json',
    listKey: 'greek_gods',
    mythology: MythologyEnum.greek,
    ethnicity: LanguageEthnicityEnum.greek,
    into: firstNames,
  );
  _readMythology(
    '$_mythologyRoot/greek_titans.json',
    listKey: 'greek_titans',
    mythology: MythologyEnum.greek,
    ethnicity: LanguageEthnicityEnum.greek,
    into: firstNames,
  );
  _readMythology(
    '$_mythologyRoot/greek_monsters.json',
    listKey: 'greek_monsters',
    mythology: MythologyEnum.greek,
    ethnicity: LanguageEthnicityEnum.greek,
    into: firstNames,
  );
  _readMythology(
    '$_mythologyRoot/roman_deities.json',
    listKey: 'roman_deities',
    mythology: MythologyEnum.roman,
    ethnicity: LanguageEthnicityEnum.latin,
    into: firstNames,
  );
  _readMythology(
    '$_mythologyRoot/egyptian_gods.json',
    listKey: 'egyptian_gods',
    isObjectKeys: true,
    mythology: MythologyEnum.egyptian,
    ethnicity: LanguageEthnicityEnum.arabic,
    into: firstNames,
  );
  _readNorseGods(into: firstNames);
  _readLovecraft(into: firstNames);

  return LoaderResult(firstNames: firstNames, lastNames: lastNames);
}

void _readFirstNames(
  String path, {
  required String listKey,
  required LanguageEthnicityEnum ethnicity,
  required GenderEnum? gender,
  required List<CandidateFirstName> into,
}) {
  final names = _readStringList(path, listKey).take(_topNPerHumanList);
  for (final name in names) {
    into.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: ethnicity,
        gender: gender,
      ),
    );
  }
}

void _readLastNames(
  String path, {
  required String listKey,
  required LanguageEthnicityEnum ethnicity,
  required List<CandidateLastName> into,
}) {
  final names = _readStringList(path, listKey).take(_topNPerHumanList);
  for (final name in names) {
    into.add(
      CandidateLastName.sentinel(
        name: name,
        languageEthnicity: ethnicity,
      ),
    );
  }
}

void _readMythology(
  String path, {
  required String listKey,
  bool isObjectKeys = false,
  required MythologyEnum mythology,
  required LanguageEthnicityEnum ethnicity,
  required List<CandidateFirstName> into,
}) {
  final names = isObjectKeys
      ? _readObjectKeys(path, listKey)
      : _readStringList(path, listKey);
  for (final name in names) {
    into.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: ethnicity,
        mythology: mythology,
        era: const [EraEnum.ancient],
      ),
    );
  }
}

void _readNorseGods({required List<CandidateFirstName> into}) {
  final file = File('$_mythologyRoot/norse_gods.json');
  if (!file.existsSync()) return;
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final deities = root['norse_deities'] as Map<String, dynamic>?;
  if (deities == null) return;
  void emit(String key, GenderEnum gender) {
    final list = (deities[key] as List?)?.cast<String>() ?? const [];
    for (final name in list) {
      into.add(
        CandidateFirstName.sentinel(
          name: name,
          languageEthnicity: LanguageEthnicityEnum.scandinavian,
          mythology: MythologyEnum.norse,
          era: const [EraEnum.ancient],
          gender: gender,
        ),
      );
    }
  }

  emit('gods', GenderEnum.male);
  emit('goddesses', GenderEnum.female);
}

void _readLovecraft({required List<CandidateFirstName> into}) {
  final names = _readStringList('$_mythologyRoot/lovecraft.json', 'deities');
  for (final name in names) {
    into.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: LanguageEthnicityEnum.english,
        mythology: MythologyEnum.lovecraft,
        era: const [EraEnum.modern],
        genre: const [GenreEnum.horror],
      ),
    );
  }
}

List<String> _readStringList(String path, String key) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('[corpora] $path missing.');
    return const [];
  }
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final raw = root[key];
  if (raw is! List) return const [];
  return raw.cast<String>().where((s) => s.trim().isNotEmpty).toList();
}

List<String> _readObjectKeys(String path, String key) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final raw = root[key];
  if (raw is! Map) return const [];
  return raw.keys.cast<String>().where((s) => s.trim().isNotEmpty).toList();
}
