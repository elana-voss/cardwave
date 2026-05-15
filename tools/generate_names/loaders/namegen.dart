// ironarachne/namegen loader.
//
// Source: per-culture .go files with `var <base>(Male|Female)?(First|Last)
// Names = []string{...}` declarations. ~38 real cultures plus dwarf /
// elf / fantasy. We regex-extract the array bodies and map the base name
// to (LanguageEthnicityEnum, RaceEnum).
//
// Fills directly: language_ethnicity (mapped from base name), race
// (human for real cultures, dwarf/elf for fantasy ones), gender (when
// the var name has Male/Female).
// Sentinel: age, role, intelligence, allure, themes, genre, era.

import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetRoot = '$datasetRoot/namegen';

/// Maps the lower-camelCase prefix on each namegen variable to (ethnicity,
/// race). The 38 cultures + 3 fantasy buckets that the corpus ships.
const _baseMap = <String, (LanguageEthnicityEnum, RaceEnum)>{
  // 38 real-world cultures.
  'angloSaxon': (LanguageEthnicityEnum.angloSaxon, RaceEnum.human),
  'arabic': (LanguageEthnicityEnum.arabic, RaceEnum.human),
  'chinese': (LanguageEthnicityEnum.chinese, RaceEnum.human),
  'dutch': (LanguageEthnicityEnum.dutch, RaceEnum.human),
  'english': (LanguageEthnicityEnum.english, RaceEnum.human),
  'estonian': (LanguageEthnicityEnum.estonian, RaceEnum.human),
  'finnish': (LanguageEthnicityEnum.finnish, RaceEnum.human),
  'french': (LanguageEthnicityEnum.french, RaceEnum.human),
  'german': (LanguageEthnicityEnum.german, RaceEnum.human),
  'greek': (LanguageEthnicityEnum.greek, RaceEnum.human),
  'hawaiian': (LanguageEthnicityEnum.hawaiian, RaceEnum.human),
  'hindu': (LanguageEthnicityEnum.hindi, RaceEnum.human),
  'icelandic': (LanguageEthnicityEnum.icelandic, RaceEnum.human),
  'indonesian': (LanguageEthnicityEnum.indonesian, RaceEnum.human),
  'irish': (LanguageEthnicityEnum.irishGaelic, RaceEnum.human),
  'italian': (LanguageEthnicityEnum.italian, RaceEnum.human),
  'japanese': (LanguageEthnicityEnum.japanese, RaceEnum.human),
  'korean': (LanguageEthnicityEnum.korean, RaceEnum.human),
  'maori': (LanguageEthnicityEnum.maori, RaceEnum.human),
  'mayan': (LanguageEthnicityEnum.mayan, RaceEnum.human),
  'mongolian': (LanguageEthnicityEnum.mongolian, RaceEnum.human),
  'nepalese': (LanguageEthnicityEnum.nepalese, RaceEnum.human),
  'nigerian': (LanguageEthnicityEnum.nigerian, RaceEnum.human),
  'norwegian': (LanguageEthnicityEnum.norwegian, RaceEnum.human),
  'polish': (LanguageEthnicityEnum.slavicPolish, RaceEnum.human),
  'portuguese': (LanguageEthnicityEnum.portuguese, RaceEnum.human),
  'russian': (LanguageEthnicityEnum.slavicRussian, RaceEnum.human),
  'serbian': (LanguageEthnicityEnum.serbian, RaceEnum.human),
  'somali': (LanguageEthnicityEnum.somali, RaceEnum.human),
  'spanish': (LanguageEthnicityEnum.spanish, RaceEnum.human),
  'swedish': (LanguageEthnicityEnum.swedish, RaceEnum.human),
  'thai': (LanguageEthnicityEnum.thai, RaceEnum.human),
  'turkish': (LanguageEthnicityEnum.turkish, RaceEnum.human),
  'ukrainian': (LanguageEthnicityEnum.ukrainian, RaceEnum.human),
  // Fantasy races.
  'dwarf': (LanguageEthnicityEnum.fantasyDwarven, RaceEnum.dwarf),
  'elf': (LanguageEthnicityEnum.fantasyElvish, RaceEnum.elf),
  // Generic fantasy bucket — names lean English-medieval; tag as human
  // with English ethnicity so they fall into the fantasy-genre branch
  // at runtime via Phase 2 tagging.
  'fantasy': (LanguageEthnicityEnum.english, RaceEnum.human),
};

LoaderResult loadNamegen() {
  final dir = Directory(_datasetRoot);
  if (!dir.existsSync()) {
    stderr.writeln('[namegen] $_datasetRoot missing.');
    return const LoaderResult();
  }

  final firstNames = <CandidateFirstName>[];
  final lastNames = <CandidateLastName>[];

  for (final file in dir.listSync().whereType<File>()) {
    final filename = file.uri.pathSegments.last;
    if (!filename.endsWith('_names.go')) continue;
    if (filename == 'namegen.go') continue; // package-level, not data

    final content = file.readAsStringSync();
    for (final block in _varBlockRe.allMatches(content)) {
      final varName = block.group(1)!;
      final body = block.group(2)!;
      final meta = _parseVarName(varName);
      if (meta == null) continue;

      for (final m in _stringRe.allMatches(body)) {
        final name = m.group(1)!.trim();
        if (name.isEmpty) continue;
        if (meta.isLast) {
          lastNames.add(
            CandidateLastName.sentinel(
              name: name,
              languageEthnicity: meta.ethnicity,
              race: meta.race,
            ),
          );
        } else {
          firstNames.add(
            CandidateFirstName.sentinel(
              name: name,
              languageEthnicity: meta.ethnicity,
              race: meta.race,
              gender: meta.gender,
            ),
          );
        }
      }
    }
  }

  return LoaderResult(firstNames: firstNames, lastNames: lastNames);
}

class _VarMeta {
  const _VarMeta(this.ethnicity, this.race, this.gender, this.isLast);
  final LanguageEthnicityEnum ethnicity;
  final RaceEnum race;
  final GenderEnum? gender;
  final bool isLast;
}

_VarMeta? _parseVarName(String varName) {
  final m = _varNameRe.firstMatch(varName);
  if (m == null) return null;
  final base = m.group(1)!;
  final gender = m.group(2);
  final type = m.group(3)!;
  final culture = _baseMap[base];
  if (culture == null) return null;
  return _VarMeta(
    culture.$1,
    culture.$2,
    switch (gender) {
      'Male' => GenderEnum.male,
      'Female' => GenderEnum.female,
      _ => null,
    },
    type == 'Last',
  );
}

// Matches `<base>(Male|Female)?(First|Last)Names`. The lazy `*?` on the
// CamelCase chunks lets two-word bases (angloSaxon) split correctly:
// the gender token only matches if it's `Male` or `Female`, so the rest
// of the camelCase belongs to the base.
final _varNameRe = RegExp(
  r'^([a-z]+(?:[A-Z][a-z]+)*?)(Male|Female)?(First|Last)Names$',
);

// Match `<word> = []string{...}` blocks. The `[^}]+` body relies on the
// arrays containing no literal `}` — true of all namegen sources.
final _varBlockRe = RegExp(r'(\w+)\s*=\s*\[\]string\{([^}]+)\}');

// Match each quoted string element. Strings in namegen are simple
// (no escapes, no embedded quotes).
final _stringRe = RegExp(r'"([^"]+)"');
