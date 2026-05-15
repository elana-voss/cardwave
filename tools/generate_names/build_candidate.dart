// Phase 1 of the name-database build. Runs the per-corpus loaders,
// dedupes case-insensitive across sources, fills source-deducible tags
// directly, and marks the rest as sentinels for Phase 2 to fill.
//
// Run from app/ via:
//   dart run tools/generate_names/build_candidate.dart
//
// Output:
//   tools/generate_names/.cache/name_database.candidate.json
//
// The candidate is intentionally written OUTSIDE the package's assets/
// directory so Flutter doesn't bundle the 40+ MB intermediate file with
// the app. Phase 2 reads it from this build-artifact location and
// writes the final asset to packages/cardwave_names/assets/.
//
// No API cost. Re-runnable for free. Inspect the output for "are we
// ingesting the right names?" before paying for Phase 2 classification.

import 'dart:convert';
import 'dart:io';

import 'loaders/candidate_record.dart';
import 'loaders/cyberpunk_names.dart';
import 'loaders/dragon_names.dart';
import 'loaders/philipperemy.dart';

const _outputPath =
    'tools/generate_names/.cache/name_database.candidate.json';

typedef _Loader = ({String tag, LoaderResult Function() run});

const _loaders = <_Loader>[
  // Order matters for the first-wins merge rule: discriminative sources
  // first so a name's primary tags come from the most authoritative
  // corpus. Country-fuzzy sources (philipperemy) land later.
  (tag: 'dragon-names', run: loadDragonNames),
  (tag: 'cyberpunk-names', run: loadCyberpunkNames),
  (tag: 'philipperemy', run: loadPhilipperemy),
];

Future<void> main() async {
  final firstByKey = <String, CandidateFirstName>{};
  final lastByKey = <String, CandidateLastName>{};

  for (final loader in _loaders) {
    stdout.writeln('[load] ${loader.tag}');
    final result = loader.run();
    var firstCount = 0;
    var lastCount = 0;
    for (final entry in result.firstNames) {
      _mergeFirst(firstByKey, entry);
      firstCount++;
    }
    for (final entry in result.lastNames) {
      _mergeLast(lastByKey, entry);
      lastCount++;
    }
    stdout.writeln(
      '       +$firstCount first names, +$lastCount last names '
      '(${firstByKey.length} / ${lastByKey.length} cumulative unique)',
    );
  }

  // Stable order so the candidate file diffs cleanly between runs.
  final firstList = firstByKey.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final lastList = lastByKey.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final output = {
    'first_names': firstList.map((e) => e.toJson()).toList(),
    'last_names': lastList.map((e) => e.toJson()).toList(),
  };

  final outFile = File(_outputPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(jsonEncode(output));
  stdout.writeln(
    '[done] wrote ${firstList.length} first + ${lastList.length} '
    'last names → $_outputPath',
  );
}

/// Merge a new first-name candidate into the accumulator. Same-name
/// records (case-insensitive) collapse via the rule: a real value
/// upgrades a sentinel; first real-vs-real value wins; multi-value
/// fields (genre, themes) union.
void _mergeFirst(
  Map<String, CandidateFirstName> acc,
  CandidateFirstName incoming,
) {
  final key = incoming.name.toLowerCase();
  final existing = acc[key];
  if (existing == null) {
    acc[key] = incoming;
    return;
  }
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.gender,
    () => existing.gender = incoming.gender,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.age,
    () => existing.age = incoming.age,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.era,
    () => existing.era = incoming.era,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.role,
    () => existing.role = incoming.role,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.intelligence,
    () => existing.intelligence = incoming.intelligence,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.allure,
    () => existing.allure = incoming.allure,
  );
  existing.mythology ??= incoming.mythology;
  existing.genre = _unionTags(existing.genre, incoming.genre);
  existing.themes = _unionTags(existing.themes, incoming.themes);
  if (incoming.genre.isNotEmpty) {
    existing.sentinelFields.remove(SentinelField.genre);
  }
  if (incoming.themes.isNotEmpty) {
    existing.sentinelFields.remove(SentinelField.themes);
  }
}

void _mergeLast(
  Map<String, CandidateLastName> acc,
  CandidateLastName incoming,
) {
  final key = incoming.name.toLowerCase();
  final existing = acc[key];
  if (existing == null) {
    acc[key] = incoming;
    return;
  }
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.era,
    () => existing.era = incoming.era,
  );
  existing.mythology ??= incoming.mythology;
  existing.genre = _unionTags(existing.genre, incoming.genre);
  existing.themes = _unionTags(existing.themes, incoming.themes);
  if (incoming.genre.isNotEmpty) {
    existing.sentinelFields.remove(SentinelField.genre);
  }
  if (incoming.themes.isNotEmpty) {
    existing.sentinelFields.remove(SentinelField.themes);
  }
}

void _upgradeIfSentinel(
  Set<SentinelField> existingSentinels,
  Set<SentinelField> incomingSentinels,
  SentinelField field,
  void Function() apply,
) {
  if (existingSentinels.contains(field) &&
      !incomingSentinels.contains(field)) {
    apply();
    existingSentinels.remove(field);
  }
}

List<T> _unionTags<T>(List<T> existing, List<T> incoming) {
  if (incoming.isEmpty) return existing;
  return {...existing, ...incoming}.toList();
}
