// Slim down the full Phase 1 candidate JSON (~339K names, 67 MB) to a
// ~7,665-name subset that still covers every pool and sub-pool the
// suggest_name runtime cares about.
//
// Run from app/ via:
//   dart run tools/generate_names/slim_candidate.dart
//
// Input:  tools/generate_names/.cache/name_database.candidate.json
// Output: tools/generate_names/data/name_database.slim.json
//
// Per-sub-pool caps come from reference_name_db_pool_ids.md (allocation
// dated 2026-05-16). Sub-pools smaller than their cap keep all entries.
//
// Selection within an over-cap sub-pool is deterministic: each name's
// 32-bit stable hash is computed, names are sorted by that hash ascending,
// the first N are kept. Same input + same cap = same output.

import 'dart:convert';
import 'dart:io';

const _inputPath =
    'tools/generate_names/.cache/name_database.candidate.json';
const _outputPath =
    'tools/generate_names/data/name_database.slim.json';

// Sub-pool caps. Matches reference_name_db_pool_ids.md.
const _humanFirstCap = 50;
const _humanLastCap = 50;
const _mythologyFirstCap = 15;
const _eraLockedFirstCap = 25;
const _cyberpunkCap = 100;
const _nonhumanFirstCap = 50;
const _nonhumanLastCap = 50;

const _eraLockedEras = <String>{'victorian', 'nineteenTwenties', 'midcentury'};

Future<void> main() async {
  final input = File(_inputPath);
  if (!input.existsSync()) {
    stderr.writeln(
      '[slim] $_inputPath missing — run build_candidate.dart first.',
    );
    exit(1);
  }
  stdout.writeln('[load] reading $_inputPath');
  final root = jsonDecode(input.readAsStringSync()) as Map<String, dynamic>;
  final firstNames = (root['first_names'] as List).cast<Map<String, dynamic>>();
  final lastNames = (root['last_names'] as List).cast<Map<String, dynamic>>();
  stdout.writeln(
    '       ${firstNames.length} first names, '
    '${lastNames.length} last names',
  );

  // Bucket each entry into exactly one (pool, sub_key) cell.
  final firstByPool = <String, List<Map<String, dynamic>>>{};
  for (final entry in firstNames) {
    final key = _classifyFirst(entry);
    firstByPool.putIfAbsent(key, () => []).add(entry);
  }
  final lastByPool = <String, List<Map<String, dynamic>>>{};
  for (final entry in lastNames) {
    final key = _classifyLast(entry);
    if (key == null) continue;
    lastByPool.putIfAbsent(key, () => []).add(entry);
  }

  // Apply per-sub-pool caps with deterministic selection. Record
  // raw/kept counts in the same pass so the diagnostic loop doesn't
  // re-run _takeStable on every key.
  final firstKept = <String, int>{};
  final slimFirst = <Map<String, dynamic>>[];
  for (final key in firstByPool.keys) {
    final selected = _takeStable(firstByPool[key]!, _capForFirst(key));
    firstKept[key] = selected.length;
    slimFirst.addAll(selected);
  }
  final lastKept = <String, int>{};
  final slimLast = <Map<String, dynamic>>[];
  for (final key in lastByPool.keys) {
    final selected = _takeStable(lastByPool[key]!, _capForLast(key));
    lastKept[key] = selected.length;
    slimLast.addAll(selected);
  }

  // Stable sort for diff-friendly output.
  slimFirst.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  slimLast.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

  // Report per-sub-pool counts so the user can sanity-check coverage.
  stdout.writeln('[counts] per first-name sub-pool:');
  final firstKeys = firstByPool.keys.toList()..sort();
  for (final key in firstKeys) {
    stdout.writeln(
      '         $key: kept ${firstKept[key]} of ${firstByPool[key]!.length}',
    );
  }
  stdout.writeln('[counts] per last-name sub-pool:');
  final lastKeys = lastByPool.keys.toList()..sort();
  for (final key in lastKeys) {
    stdout.writeln(
      '         $key: kept ${lastKept[key]} of ${lastByPool[key]!.length}',
    );
  }

  final out = File(_outputPath);
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'first_names': slimFirst,
      'last_names': slimLast,
    }),
  );
  stdout.writeln(
    '[done] wrote ${slimFirst.length} first + ${slimLast.length} last '
    'names → $_outputPath',
  );
}

/// Returns the `pool / sub_key` cell for a first-name candidate. First
/// match wins — order is priority order: mythology > nonhuman race >
/// cyberpunk > era-locked English > human. Every candidate maps to one
/// pool (the trailing `human-first-name` branch is the catch-all).
String _classifyFirst(Map<String, dynamic> entry) {
  final mythology = entry['mythology'] as String?;
  if (mythology != null) {
    return 'mythology-first-name / $mythology';
  }
  final race = entry['race'] as String;
  if (race != 'human') {
    return 'nonhuman-first-name / $race';
  }
  final genre = (entry['genre'] as List).cast<String>();
  if (genre.contains('cyberpunk')) {
    return 'cyberpunk-handle';
  }
  final eras = (entry['era'] as List).cast<String>();
  final language = entry['language_ethnicity'] as String;
  final gender = entry['gender'] as String;
  // First matching era wins so a multi-era English name (e.g. era=
  // [victorian, midcentury]) lands in ONE era-locked pool, not several
  // — keeps per-pool caps honest. The entry's era list is emitted in
  // chronological order by the SSA loader, so the earliest era it
  // qualifies for is the bucket it lands in.
  if (language == 'english') {
    for (final era in eras) {
      if (_eraLockedEras.contains(era)) {
        return 'era-locked-first-name / $era-$gender';
      }
    }
  }
  return 'human-first-name / $language-$gender';
}

/// Returns the `pool / sub_key` cell for a last-name candidate, or null
/// to drop the entry. Last-name pools only exist for humans + elf +
/// dwarf; everything else is a single-name race.
String? _classifyLast(Map<String, dynamic> entry) {
  final race = entry['race'] as String;
  if (race == 'elf' || race == 'dwarf') {
    return 'nonhuman-last-name / $race';
  }
  if (race == 'human') {
    final language = entry['language_ethnicity'] as String;
    return 'human-last-name / $language';
  }
  return null;
}

int _capForFirst(String key) {
  if (key.startsWith('mythology-first-name')) return _mythologyFirstCap;
  if (key.startsWith('nonhuman-first-name')) return _nonhumanFirstCap;
  if (key == 'cyberpunk-handle') return _cyberpunkCap;
  if (key.startsWith('era-locked-first-name')) return _eraLockedFirstCap;
  if (key.startsWith('human-first-name')) return _humanFirstCap;
  return 0;
}

int _capForLast(String key) {
  if (key.startsWith('nonhuman-last-name')) return _nonhumanLastCap;
  if (key.startsWith('human-last-name')) return _humanLastCap;
  return 0;
}

/// Stable, run-independent string hash. `String.hashCode` in Dart is
/// randomised per VM run for security, so we need our own. Classic
/// FNV-style multiply-add over code units.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = (h ^ unit) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Pick the first `n` entries from `pool` by stable-hash order. When
/// `pool.length <= n` we return `pool` unsorted — the slim writer
/// alphabetises by `name` at the end, so any hash-sort here would be
/// thrown away. Hash-sort fires only when the cap is binding (the
/// stable selection comes from picking the lowest-hash N entries).
List<Map<String, dynamic>> _takeStable(
  List<Map<String, dynamic>> pool,
  int n,
) {
  if (pool.length <= n) return pool;
  final sorted = [...pool]..sort(
      (a, b) => _stableHash(a['name'] as String)
          .compareTo(_stableHash(b['name'] as String)),
    );
  return sorted.sublist(0, n);
}
