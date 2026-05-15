// hackerb9/ssa-baby-names loader.
//
// Source: raw-data/yob<YYYY>.txt — per-year US SSA name counts. Format
// per line: `<name>,<F|M>,<count>`. 1880–present (~145 years × ~2000
// names per year = a lot of rows; most names appear in many years).
//
// Era logic: this corpus exists in the build to add era-locked tags for
// names that fell out of favour. A name that appears across centuries
// shouldn't get era=victorian just because SSA records it from 1880. So
// we accumulate which years each name appeared in, then emit a record
// ONLY for names whose years lie entirely within one of the three named
// slices below. Names that span eras are dropped — other loaders
// (philipperemy, corpora) handle them with era=modern as a sentinel.
//
// Fills directly: gender (from per-year vote — majority gender wins for
// ambiguous names), language_ethnicity=english, race=human, era (one of
// victorian / nineteenTwenties / midcentury).
// Sentinel: age, role, intelligence, allure, themes, genre.

import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetRoot = '$datasetRoot/ssa-baby-names/raw-data';

const _victorianMin = 1880;
const _victorianMax = 1901;
const _twentiesMin = 1920;
const _twentiesMax = 1929;
const _midcenturyMin = 1940;
const _midcenturyMax = 1969;

LoaderResult loadSsaBabyNames() {
  final dir = Directory(_datasetRoot);
  if (!dir.existsSync()) {
    stderr.writeln('[ssa-baby-names] $_datasetRoot missing.');
    return const LoaderResult();
  }

  // name → { gender → count, years → set<int> }
  final byName = <String, _NameStats>{};

  for (final entity in dir.listSync().whereType<File>()) {
    final filename = entity.uri.pathSegments.last;
    final match = _yobFilenameRe.firstMatch(filename);
    if (match == null) continue;
    final year = int.parse(match.group(1)!);

    for (final line in entity.readAsLinesSync()) {
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      final name = parts[0].trim();
      final genderCode = parts[1].trim();
      final count = int.tryParse(parts[2].trim()) ?? 0;
      if (name.isEmpty || count <= 0) continue;

      final stats = byName.putIfAbsent(name, _NameStats.new);
      stats.years.add(year);
      if (genderCode == 'M') stats.maleCount += count;
      if (genderCode == 'F') stats.femaleCount += count;
    }
  }

  final firstNames = <CandidateFirstName>[];

  for (final entry in byName.entries) {
    final name = entry.key;
    final stats = entry.value;
    final era = _eraIfLockedToSlice(stats.years);
    if (era == null) continue;
    firstNames.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: LanguageEthnicityEnum.english,
        gender: _majorityGender(stats),
        era: era,
      ),
    );
  }

  return LoaderResult(firstNames: firstNames);
}

EraEnum? _eraIfLockedToSlice(Set<int> years) {
  bool inSlice(int y, int min, int max) => y >= min && y <= max;
  final allVictorian = years.every((y) => inSlice(y, _victorianMin, _victorianMax));
  if (allVictorian) return EraEnum.victorian;
  final allTwenties = years.every((y) => inSlice(y, _twentiesMin, _twentiesMax));
  if (allTwenties) return EraEnum.nineteenTwenties;
  final allMidcentury = years.every((y) => inSlice(y, _midcenturyMin, _midcenturyMax));
  if (allMidcentury) return EraEnum.midcentury;
  return null;
}

GenderEnum _majorityGender(_NameStats stats) {
  if (stats.maleCount == 0 && stats.femaleCount == 0) return GenderEnum.ambiguous;
  if (stats.maleCount > stats.femaleCount * 4) return GenderEnum.male;
  if (stats.femaleCount > stats.maleCount * 4) return GenderEnum.female;
  return GenderEnum.ambiguous;
}

class _NameStats {
  final Set<int> years = {};
  int maleCount = 0;
  int femaleCount = 0;
}

final _yobFilenameRe = RegExp(r'^yob(\d{4})\.txt$');
