// sigpwned/popular-names-by-country-dataset loader.
//
// Two CSV files: common-forenames-by-country.csv (with gender) and
// common-surnames-by-country.csv. Per-country top names.
//
// Fills directly: language_ethnicity (via country map), gender
// (forenames only), race=human.
// Sentinel: age, role, intelligence, allure, themes, genre, era.
//
// Romanized Name is preferred over Localized Name so the candidate JSON
// stays ASCII-ish where possible — the runtime database compares names
// case-insensitive, and a mix of scripts in the same culture bucket
// causes weird collisions.

import 'dart:io';

import 'candidate_record.dart';
import 'country_map.dart';
import 'local_taxonomy.dart';

const _forenamesPath =
    '$datasetRoot/popular-names-by-country/common-forenames-by-country.csv';
const _surnamesPath =
    '$datasetRoot/popular-names-by-country/common-surnames-by-country.csv';

LoaderResult loadPopularNames() {
  final firstNames = _loadForenames();
  final lastNames = _loadSurnames();
  return LoaderResult(firstNames: firstNames, lastNames: lastNames);
}

List<CandidateFirstName> _loadForenames() {
  final file = File(_forenamesPath);
  if (!file.existsSync()) {
    stderr.writeln('[popular-names] $_forenamesPath missing.');
    return const [];
  }
  // Columns: Country, Country Group, Region, Population, Note, Year,
  // Romanization, Index, Name Group, Gender, Localized Name,
  // Romanized Name
  final lines = file.readAsLinesSync();
  final result = <CandidateFirstName>[];
  for (var i = 1; i < lines.length; i++) {
    final cols = _splitCsv(lines[i]);
    if (cols.length < 12) continue;
    final country = cols.first.trim();
    final genderCode = cols[9].trim();
    final romanizedName = cols[11].trim();
    if (romanizedName.isEmpty || country.isEmpty) continue;
    final ethnicity = isoCountryToEthnicity[country];
    if (ethnicity == null) continue;

    result.add(
      CandidateFirstName.sentinel(
        name: romanizedName,
        languageEthnicity: ethnicity,
        gender: _genderFromCode(genderCode),
      ),
    );
  }
  return result;
}

List<CandidateLastName> _loadSurnames() {
  final file = File(_surnamesPath);
  if (!file.existsSync()) {
    stderr.writeln('[popular-names] $_surnamesPath missing.');
    return const [];
  }
  // Columns: Country, Rank, Index, Name Group, Localized Name,
  // Romanized Name, Count, Percent
  final lines = file.readAsLinesSync();
  final result = <CandidateLastName>[];
  for (var i = 1; i < lines.length; i++) {
    final cols = _splitCsv(lines[i]);
    if (cols.length < 6) continue;
    final country = cols.first.trim();
    final romanizedName = cols[5].trim();
    if (romanizedName.isEmpty || country.isEmpty) continue;
    final ethnicity = isoCountryToEthnicity[country];
    if (ethnicity == null) continue;

    result.add(
      CandidateLastName.sentinel(
        name: romanizedName,
        languageEthnicity: ethnicity,
      ),
    );
  }
  return result;
}

GenderEnum? _genderFromCode(String code) => switch (code) {
  'M' => GenderEnum.male,
  'F' => GenderEnum.female,
  _ => null,
};

/// Minimal CSV splitter — handles quoted fields and leading BOM, which
/// is all this corpus needs. Does NOT handle every CSV edge case (escaped
/// quotes inside fields), because the corpus doesn't use them.
List<String> _splitCsv(String line) {
  if (line.startsWith('﻿')) line = line.substring(1);
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
    } else if (ch == ',' && !inQuotes) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}
