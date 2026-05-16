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
// The candidate is intentionally written into .cache/ (not data/) so
// the 40+ MB intermediate file stays out of git. The pipeline is:
//   build_candidate.dart  → .cache/name_database.candidate.json
//   slim_candidate.dart   → data/name_database.slim.json   (committed)
//   classify.dart         → data/name_database.tagged.json (committed)
//   emit_dart.dart        → packages/cardwave_names/lib/src/services/
//                           name_database_data.dart        (committed)
//
// No API cost. Re-runnable for free. Inspect the output for "are we
// ingesting the right names?" before paying for Phase 2 classification.

import 'dart:convert';
import 'dart:io';

import 'loaders/candidate_record.dart';
import 'loaders/corpora.dart';
import 'loaders/local_taxonomy.dart';
import 'loaders/cyberpunk_names.dart';
import 'loaders/dragon_names.dart';
import 'loaders/mythology_names.dart';
import 'loaders/namegen.dart';
import 'loaders/philipperemy.dart';
import 'loaders/popular_names.dart';
import 'loaders/ssa_baby_names.dart';

const _outputPath =
    'tools/generate_names/.cache/name_database.candidate.json';

typedef _Loader = ({String tag, LoaderResult Function() run});

const _loaders = <_Loader>[
  // Order matters for the first-wins merge rule: discriminative sources
  // first so a name's primary tags come from the most authoritative
  // corpus. Country-fuzzy sources (philipperemy) land later.
  //
  // Specialised buckets first.
  (tag: 'dragon-names', run: loadDragonNames),
  (tag: 'cyberpunk-names', run: loadCyberpunkNames),
  // Mythology-tagged names — fixed pantheons.
  (tag: 'mythology-names', run: loadMythologyNames),
  (tag: 'corpora', run: loadCorpora),
  // Era-locked English names. Drops names that span eras — only the
  // era-pure ones land here.
  (tag: 'ssa-baby-names', run: loadSsaBabyNames),
  // Per-culture curated lists.
  (tag: 'namegen', run: loadNamegen),
  // Country-tagged top names (broad but well-sourced).
  (tag: 'popular-names-by-country', run: loadPopularNames),
  // Largest source, country-fuzzy — lands last so its country mapping
  // doesn't overwrite better tags from the specialised sources.
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
  if (!_isValidName(incoming.name)) return;
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
  _upgradeOrUnionList<AgeEnum>(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.age,
    existing.age,
    incoming.age,
    (merged) => existing.age = merged,
  );
  _upgradeOrUnionList<EraEnum>(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.era,
    existing.era,
    incoming.era,
    (merged) => existing.era = merged,
  );
  _upgradeOrUnionList<RoleEnum>(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.role,
    existing.role,
    incoming.role,
    (merged) => existing.role = merged,
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
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.commonness,
    () => existing.commonness = incoming.commonness,
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
  if (!_isValidName(incoming.name)) return;
  final key = incoming.name.toLowerCase();
  final existing = acc[key];
  if (existing == null) {
    acc[key] = incoming;
    return;
  }
  _upgradeOrUnionList<EraEnum>(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.era,
    existing.era,
    incoming.era,
    (merged) => existing.era = merged,
  );
  _upgradeIfSentinel(
    existing.sentinelFields,
    incoming.sentinelFields,
    SentinelField.commonness,
    () => existing.commonness = incoming.commonness,
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

/// Merge a multi-value field (era / role / age) across two candidate
/// records. Four cases:
///   - both sentinel: keep existing (sentinel default stands).
///   - existing sentinel, incoming non-sentinel: REPLACE existing with
///     incoming, clear the sentinel flag.
///   - existing non-sentinel, incoming sentinel: keep existing (don't
///     dilute real data with a default).
///   - both non-sentinel: UNION the lists, field stays non-sentinel.
void _upgradeOrUnionList<T>(
  Set<SentinelField> existingSentinels,
  Set<SentinelField> incomingSentinels,
  SentinelField field,
  List<T> existingList,
  List<T> incomingList,
  void Function(List<T>) setList,
) {
  final existingIsSentinel = existingSentinels.contains(field);
  final incomingIsSentinel = incomingSentinels.contains(field);
  if (existingIsSentinel && !incomingIsSentinel) {
    setList(List.of(incomingList));
    existingSentinels.remove(field);
    return;
  }
  if (!existingIsSentinel && !incomingIsSentinel) {
    setList(_unionTags(existingList, incomingList));
  }
  // Other two cases (both sentinel, or incoming sentinel) leave existing
  // alone.
}

/// Reject transliteration junk before it reaches the merge accumulator:
/// names must be non-empty and start with a letter. Catches strays like
/// `'ليا` (leading apostrophe + Arabic script — a transliteration mishap
/// in the source corpus) that confuse the Phase 2 classifier.
final _leadsWithLetter = RegExp(r'^\p{L}', unicode: true);
bool _isValidName(String name) =>
    name.isNotEmpty && _leadsWithLetter.hasMatch(name);
