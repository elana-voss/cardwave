// repushko/mythology_names_dataset loader.
//
// Source: dataset.csv — 4069 names tagged by pantheon ("Greek mythology",
// "Norse mythology", "Egyptian mythology", …). 42 distinct pantheons; we
// map the ten that have an enum, the rest get mythology=sentinel (Phase 2
// fills or leaves null).
//
// Fills directly: era=ancient, race=human (creatures stay race=human for
// now — Phase 2 can reclassify obvious monsters), mythology (where the
// pantheon maps to our enum).
// Sentinel: gender, language_ethnicity (most names have no specific
// living-language mapping), age, role, intelligence, allure, themes,
// genre.

import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetPath = '$datasetRoot/mythology-names/dataset.csv';

const _pantheonToMythology = <String, MythologyEnum>{
  'Greek mythology': MythologyEnum.greek,
  'Norse mythology': MythologyEnum.norse,
  'Roman mythology': MythologyEnum.roman,
  'Celtic mythology': MythologyEnum.celtic,
  'Egyptian mythology': MythologyEnum.egyptian,
  'Hindu mythology': MythologyEnum.hindu,
  'Japanese mythology': MythologyEnum.japanese,
  'Slavic mythology': MythologyEnum.slavic,
  'Mesopotamian mythology': MythologyEnum.mesopotamian,
  'Native American mythology': MythologyEnum.nativeAmerican,
  // Close-enough mappings: Germanic mythology is North-European; lumping
  // with norse keeps Týr / Wotan-style names in the norse bucket.
  'Germanic mythology': MythologyEnum.norse,
};

/// A handful of pantheons line up with a living-language ethnicity even
/// when the mythology axis can't carry them. Used for names whose
/// pantheon isn't in our MythologyEnum but does have a cultural anchor.
/// Loose fits (Aztec→mayan, Baltic→slavicOther) reflect the closest
/// available enum value, not strict linguistic membership.
const _pantheonToEthnicity = <String, LanguageEthnicityEnum>{
  // Real-world languages with direct enum matches.
  'Chinese mythology': LanguageEthnicityEnum.chinese,
  'Japanese mythology': LanguageEthnicityEnum.japanese,
  'Hindu mythology': LanguageEthnicityEnum.hindi,
  'Maori mythology': LanguageEthnicityEnum.maori,
  'Hawaiian mythology': LanguageEthnicityEnum.hawaiian,
  'Finnish mythology': LanguageEthnicityEnum.finnish,
  'Thai mythology': LanguageEthnicityEnum.thai,
  'Indonesian mythology': LanguageEthnicityEnum.indonesian,
  'Yoruba mythology': LanguageEthnicityEnum.yoruba,
  'Native American mythology': LanguageEthnicityEnum.nativeAmerican,
  'Greek mythology': LanguageEthnicityEnum.greek,
  'Roman mythology': LanguageEthnicityEnum.latin,
  'Norse mythology': LanguageEthnicityEnum.scandinavian,
  'Germanic mythology': LanguageEthnicityEnum.scandinavian,
  'Celtic mythology': LanguageEthnicityEnum.irishGaelic,
  // Closest available enum.
  'Maya mythology': LanguageEthnicityEnum.mayan,
  'Aztec mythology': LanguageEthnicityEnum.mayan,
  'Mesoamerican mythology': LanguageEthnicityEnum.mayan,
  'Slavic mythology': LanguageEthnicityEnum.slavicOther,
  'Lithuanian mythology': LanguageEthnicityEnum.slavicOther,
  'Latvian mythology': LanguageEthnicityEnum.slavicOther,
  'Baltic mythology': LanguageEthnicityEnum.slavicOther,
  'Egyptian mythology': LanguageEthnicityEnum.arabic,
  'Mesopotamian mythology': LanguageEthnicityEnum.arabic,
  'Middle-eastern mythology': LanguageEthnicityEnum.arabic,
  'Canaanite mythology': LanguageEthnicityEnum.hebrew,
  'Hittite mythology': LanguageEthnicityEnum.turkish,
  'Etruscan mythology': LanguageEthnicityEnum.italian,
};

LoaderResult loadMythologyNames() {
  final file = File(_datasetPath);
  if (!file.existsSync()) {
    stderr.writeln('[mythology-names] $_datasetPath missing.');
    return const LoaderResult();
  }

  final lines = file.readAsLinesSync();
  if (lines.isEmpty) return const LoaderResult();

  // Skip header. CSV columns: name, pantheon, url, title, alternatives.
  // Some rows have a quoted "alternatives" field with commas; we only
  // need name + pantheon (cols 0 + 1), so a comma-split-at-first-two
  // is enough — we don't have to round-trip the trailing columns.
  final firstNames = <CandidateFirstName>[];

  for (var i = 1; i < lines.length; i++) {
    final row = lines[i];
    if (row.trim().isEmpty) continue;
    final firstComma = row.indexOf(',');
    if (firstComma < 0) continue;
    final secondComma = row.indexOf(',', firstComma + 1);
    if (secondComma < 0) continue;
    final name = row.substring(0, firstComma).trim();
    final pantheon = row.substring(firstComma + 1, secondComma).trim();
    if (name.isEmpty) continue;

    final mythology = _pantheonToMythology[pantheon];
    final ethnicity =
        _pantheonToEthnicity[pantheon] ?? LanguageEthnicityEnum.english;

    firstNames.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: ethnicity,
        mythology: mythology,
        era: EraEnum.ancient,
      ),
    );
  }

  return LoaderResult(firstNames: firstNames);
}
