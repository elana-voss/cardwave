// hackerb9/ssa-baby-names loader.
//
// Source: raw-data/yob<YYYY>.txt — per-year US SSA name counts. Format
// per line: `<name>,<F|M>,<count>`. 1880–present (~145 years × ~2000
// names per year = a lot of rows; most names appear in many years).
//
// Era logic: peak-based. For each name, we sum the SSA counts in each
// of three decade slices (victorian = 1880-1901, twenties = 1920-1929,
// midcentury = 1940-1969). The slice with the highest total is the
// name's peak era. Any other slice whose count is ≥50% of the peak is
// emitted as a secondary era so names like "Eleanor" (peak victorian,
// strong midcentury) land in both pools. Names with no occurrences in
// any slice are dropped — they're either pre-1880 (won't happen, SSA
// data starts there) or modern-only, in which case other loaders pick
// them up with the modern sentinel default.
//
// Fills directly: gender (from per-year vote — majority gender wins for
// ambiguous names), language_ethnicity=english, race=human, era (list
// drawn from victorian / nineteenTwenties / midcentury).
// Sentinel: age, role, intelligence, allure, themes, genre.

import 'dart:io';

import 'package:path/path.dart' as p;

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetRoot = '$datasetRoot/ssa-baby-names/raw-data';

/// Era slices: name → era based on which decade the SSA count peaks in.
/// Ordered for deterministic tie-breaking (earliest decade wins) and so
/// the emitted era list reads chronologically.
const _eraSlices = <_EraSlice>[
  _EraSlice(EraEnum.victorian, 1880, 1901),
  _EraSlice(EraEnum.nineteenTwenties, 1920, 1929),
  _EraSlice(EraEnum.midcentury, 1940, 1969),
];

/// A non-peak slice qualifies as a secondary era when its tally is at
/// least this fraction of the peak slice's tally. 0.5 = "comparable to
/// peak" — captures cross-era reach without inflating to every slice
/// the name ever appeared in.
const _secondarySliceRatio = 0.5;

LoaderResult loadSsaBabyNames() {
  final dir = Directory(_datasetRoot);
  if (!dir.existsSync()) {
    stderr.writeln('[ssa-baby-names] $_datasetRoot missing.');
    return const LoaderResult();
  }

  final byName = <String, _NameStats>{};

  for (final entity in dir.listSync().whereType<File>()) {
    final filename = p.basename(entity.path);
    final match = _yobFilenameRe.firstMatch(filename);
    if (match == null) continue;
    final year = int.parse(match.group(1)!);
    final slice = _sliceForYear(year);
    // Skip yob files outside the three era slices entirely. They're
    // ~110 of 144 total (1902-1919, 1930-1939, 1970-2024) and would
    // never contribute to any name's era assignment — only inflate
    // gender tallies for names that wouldn't be kept anyway.
    if (slice == null) continue;

    for (final line in entity.readAsLinesSync()) {
      if (line.isEmpty) continue;
      final parts = line.split(',');
      if (parts.length < 3) continue;
      final name = parts.first.trim();
      final genderCode = parts[1].trim();
      final count = int.tryParse(parts[2].trim()) ?? 0;
      if (name.isEmpty || count <= 0) continue;

      final stats = byName.putIfAbsent(name, _NameStats.new);
      if (genderCode == 'M') stats.maleCount += count;
      if (genderCode == 'F') stats.femaleCount += count;
      stats.countByEra[slice] = (stats.countByEra[slice] ?? 0) + count;
    }
  }

  final firstNames = <CandidateFirstName>[];

  for (final entry in byName.entries) {
    final name = entry.key;
    final stats = entry.value;
    final eras = _erasFromPeak(stats.countByEra);
    if (eras.isEmpty) continue;
    firstNames.add(
      CandidateFirstName.sentinel(
        name: name,
        languageEthnicity: LanguageEthnicityEnum.english,
        gender: _majorityGender(stats),
        era: eras,
      ),
    );
  }

  return LoaderResult(firstNames: firstNames);
}

EraEnum? _sliceForYear(int year) {
  for (final slice in _eraSlices) {
    if (year >= slice.minYear && year <= slice.maxYear) return slice.era;
  }
  return null;
}

/// Pick the era(s) for a name from its per-slice counts. The peak slice
/// is the era with the highest count; any other slice with count ≥
/// [_secondarySliceRatio] × peak joins as a secondary era. Returns an
/// empty list when the name has no SSA presence in any slice.
List<EraEnum> _erasFromPeak(Map<EraEnum, int> countByEra) {
  if (countByEra.isEmpty) return const [];
  final peakCount = countByEra.values.reduce((a, b) => a > b ? a : b);
  final threshold = peakCount * _secondarySliceRatio;
  return [
    for (final slice in _eraSlices)
      if ((countByEra[slice.era] ?? 0) >= threshold) slice.era,
  ];
}

GenderEnum _majorityGender(_NameStats stats) {
  if (stats.maleCount == 0 && stats.femaleCount == 0) return GenderEnum.ambiguous;
  if (stats.maleCount > stats.femaleCount * 4) return GenderEnum.male;
  if (stats.femaleCount > stats.maleCount * 4) return GenderEnum.female;
  return GenderEnum.ambiguous;
}

class _EraSlice {
  const _EraSlice(this.era, this.minYear, this.maxYear);
  final EraEnum era;
  final int minYear;
  final int maxYear;
}

class _NameStats {
  final Map<EraEnum, int> countByEra = {};
  int maleCount = 0;
  int femaleCount = 0;
}

final _yobFilenameRe = RegExp(r'^yob(\d{4})\.txt$');
