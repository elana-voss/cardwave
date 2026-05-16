// mlane/cyberpunk-name-generator loader.
//
// Source: cyberpunk_names.json — pre-materialised handles with
// affiliation/characterClass metadata. ~800-1000 entries.
//
// Fills directly: genre=[cyberpunk], era=nearFuture, race=human, role
// (mapped from characterClass).
// Sentinel: gender (handles are mixed), age, intelligence, allure,
// themes, language_ethnicity (defaults to english — handles are
// English-language).

import 'dart:convert';
import 'dart:io';

import 'candidate_record.dart';
import 'local_taxonomy.dart';

const _datasetPath = '$datasetRoot/cyberpunk-names/cyberpunk_names.json';

LoaderResult loadCyberpunkNames() {
  final file = File(_datasetPath);
  if (!file.existsSync()) {
    stderr.writeln('[cyberpunk-names] $_datasetPath missing.');
    return const LoaderResult();
  }

  final entries = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  final firstNames = <CandidateFirstName>[];

  for (final raw in entries) {
    final entry = raw as Map<String, dynamic>;
    final name = (entry['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    final role = _roleFromCharacterClass(entry['characterClass'] as String?);
    firstNames.add(
      CandidateFirstName(
        name: name,
        gender: GenderEnum.ambiguous,
        languageEthnicity: LanguageEthnicityEnum.english,
        mythology: null,
        race: RaceEnum.human,
        age: [AgeEnum.adult],
        era: [EraEnum.nearFuture],
        role: [role ?? RoleEnum.neutral],
        intelligence: 3,
        allure: 3,
        commonness: CommonnessEnum.uncommon,
        genre: const [GenreEnum.cyberpunk],
        themes: const [],
        sentinelFields: {
          SentinelField.gender,
          SentinelField.age,
          SentinelField.intelligence,
          SentinelField.allure,
          SentinelField.commonness,
          SentinelField.themes,
          if (role == null) SentinelField.role,
        },
      ),
    );
  }

  return LoaderResult(firstNames: firstNames);
}

/// Coarse mapping from the cyberpunk JSON's characterClass strings to our
/// RoleEnum. Triggers are matched against the 17 distinct characterClass
/// values in `cyberpunk_names.json` — anything not listed falls through
/// to null so Phase 2 classifies it. Refresh both this function and the
/// dataset together when the corpus updates.
RoleEnum? _roleFromCharacterClass(String? cls) {
  if (cls == null) return null;
  final lower = cls.toLowerCase();
  if (lower.contains('enforcer') ||
      lower.contains('mercenary') ||
      lower.contains('spy') ||
      lower.contains('ghost')) {
    return RoleEnum.antihero;
  }
  if (lower.contains('prophet')) {
    return RoleEnum.mentor;
  }
  return null;
}
